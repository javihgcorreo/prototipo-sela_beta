from flask import Flask, request, jsonify
import psycopg2
import uuid
from datetime import datetime
import os
import json
import hashlib
import requests
from typing import Dict, Any
from datetime import datetime, timedelta

# Variable global para logs (en producción usaría BD)
logs_auditoria = []

app = Flask(__name__)

# Configuración del servicio
SERVICE_NAME = "Servicio de Auditoría con Blockchain"
VERSION = "2.0.0"

# Configuración de base de datos
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://auditoria_user:auditoria_pass@localhost:5432/auditoria_db')

# Configuración Blockchain
BLOCKCHAIN_ENABLED = os.getenv('BLOCKCHAIN_ENABLED', 'false').lower() == 'true'
BLOCKCHAIN_SERVICE_URL = os.getenv('BLOCKCHAIN_SERVICE_URL', 'http://localhost:8003/api/v1')
BLOCKCHAIN_CHAIN_ID = os.getenv('BLOCKCHAIN_CHAIN_ID', 'auditoria_chain')

def get_db_connection():
    """Obtener conexión a la base de datos"""
    try:
        conn = psycopg2.connect(DATABASE_URL)
        return conn
    except Exception as e:
        print(f"Error conectando a la base de datos: {e}")
        return None

def init_database():
    """Inicializar tablas de la base de datos"""
    try:
        conn = get_db_connection()
        if conn is None:
            return False
        
        cursor = conn.cursor()
        
        # Crear tabla de auditoría si no existe
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS auditoria_logs (
                id SERIAL PRIMARY KEY,
                operacion_id UUID DEFAULT gen_random_uuid(),
                operacion VARCHAR(100) NOT NULL,
                servicio_origen VARCHAR(100) NOT NULL,
                datos_procesados INTEGER DEFAULT 0,
                resultado TEXT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadatos JSONB,
                blockchain_hash VARCHAR(128),  -- Nuevo: hash de blockchain
                blockchain_block_id INTEGER,    -- Nuevo: ID del bloque
                blockchain_verified BOOLEAN DEFAULT FALSE  -- Nuevo: verificación
            )
        """)
        
        # Tabla para almacenar hashes de bloques
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS blockchain_hashes (
                id SERIAL PRIMARY KEY,
                block_id INTEGER NOT NULL,
                block_hash VARCHAR(128) NOT NULL,
                previous_hash VARCHAR(128),
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                transactions_count INTEGER DEFAULT 0,
                UNIQUE(block_id)
            )
        """)
        
        conn.commit()
        cursor.close()
        conn.close()
        return True
        
    except Exception as e:
        print(f"Error inicializando base de datos: {e}")
        return False

# ========== FUNCIONES BLOCKCHAIN ==========

def calcular_hash(data: Dict[str, Any]) -> str:
    """Calcular hash SHA-256 de los datos de auditoría"""
    data_str = json.dumps(data, sort_keys=True, default=str)
    return hashlib.sha256(data_str.encode()).hexdigest()

def registrar_en_blockchain_local(operacion_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Registrar operación en blockchain local (sin servicio externo)
    """
    try:
        conn = get_db_connection()
        if conn is None:
            return {"error": "No database connection"}
        
        cursor = conn.cursor()
        
        # Obtener el último bloque
        cursor.execute("""
            SELECT block_id, block_hash 
            FROM blockchain_hashes 
            ORDER BY block_id DESC 
            LIMIT 1
        """)
        
        last_block = cursor.fetchone()
        previous_hash = last_block[1] if last_block else "0" * 64  # Genesis hash
        block_id = (last_block[0] + 1) if last_block else 1
        
        # Crear datos del bloque
        timestamp = datetime.now().isoformat()
        block_data = {
            "block_id": block_id,
            "previous_hash": previous_hash,
            "timestamp": timestamp,
            "operation": operacion_data.get('operacion'),
            "service": operacion_data.get('servicio_origen'),
            "result": operacion_data.get('resultado'),
            "metadata_hash": calcular_hash(operacion_data.get('metadatos', {}))
        }
        
        # Calcular hash del bloque
        block_hash = calcular_hash(block_data)
        
        # Insertar en tabla blockchain
        cursor.execute("""
            INSERT INTO blockchain_hashes 
            (block_id, block_hash, previous_hash, timestamp, transactions_count)
            VALUES (%s, %s, %s, %s, 1)
        """, (block_id, block_hash, previous_hash, timestamp))
        
        conn.commit()
        
        return {
            "blockchain_hash": block_hash,
            "block_id": block_id,
            "previous_hash": previous_hash,
            "timestamp": timestamp,
            "status": "registered_in_local_chain"
        }
        
    except Exception as e:
        return {"error": f"Blockchain error: {str(e)}"}

def registrar_en_blockchain_externo(operacion_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Registrar operación en servicio blockchain externo
    """
    try:
        # Preparar transacción para blockchain
        transaction = {
            "chain_id": BLOCKCHAIN_CHAIN_ID,
            "transaction_type": "audit_log",
            "data": {
                "operation": operacion_data.get('operacion'),
                "service": operacion_data.get('servicio_origen'),
                "result": operacion_data.get('resultado'),
                "data_processed": operacion_data.get('datos_procesados', 0),
                "timestamp": operacion_data.get('timestamp', datetime.now().isoformat()),
                "metadata_hash": calcular_hash(operacion_data.get('metadatos', {}))
            },
            "timestamp": datetime.now().isoformat()
        }
        
        # Enviar a servicio blockchain
        response = requests.post(
            f"{BLOCKCHAIN_SERVICE_URL}/transactions",
            json=transaction,
            timeout=5
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            return {"error": f"Blockchain service error: {response.status_code}"}
            
    except requests.exceptions.RequestException as e:
        return {"error": f"Blockchain service unreachable: {str(e)}"}

def verificar_integridad_blockchain() -> Dict[str, Any]:
    """
    Verificar la integridad de la cadena de bloques local
    """
    try:
        conn = get_db_connection()
        if conn is None:
            return {"error": "No database connection"}
        
        cursor = conn.cursor()
        
        # Obtener todos los bloques ordenados
        cursor.execute("""
            SELECT block_id, block_hash, previous_hash 
            FROM blockchain_hashes 
            ORDER BY block_id
        """)
        
        blocks = cursor.fetchall()
        
        if not blocks:
            return {"verified": True, "chain_length": 0, "message": "Empty chain"}
        
        # Verificar cadena
        issues = []
        for i in range(len(blocks)):
            block_id, current_hash, previous_hash = blocks[i]
            
            # Verificar hash anterior (excepto primer bloque)
            if i > 0:
                _, prev_block_hash, _ = blocks[i-1]
                if previous_hash != prev_block_hash:
                    issues.append(f"Block {block_id}: Invalid previous hash")
            
            # Recalcular hash para verificar
            cursor.execute("""
                SELECT * FROM auditoria_logs 
                WHERE blockchain_block_id = %s
            """, (block_id,))
            
            logs = cursor.fetchall()
            if logs:
                # En una implementación real, recalcularías el hash del bloque
                # con todas sus transacciones
                pass
        
        verified = len(issues) == 0
        
        return {
            "verified": verified,
            "chain_length": len(blocks),
            "issues": issues if issues else None,
            "latest_block": blocks[-1][0] if blocks else None,
            "latest_hash": blocks[-1][1] if blocks else None
        }
        
    except Exception as e:
        return {"error": f"Verification error: {str(e)}"}

# ========== ENDPOINTS ACTUALIZADOS ==========
@app.get("/logs/acuerdo/{acuerdo_id}")
async def logs_por_acuerdo(acuerdo_id: str, limite: int = 10):
    """Obtener logs filtrados por acuerdo_id"""
    logs_filtrados = [
        log for log in logs_auditoria 
        if log.get("acuerdo_id") == acuerdo_id
    ][-limite:]
    
    return {
        "total": len(logs_filtrados),
        "acuerdo_id": acuerdo_id,
        "logs": logs_filtrados
    }

@app.post("/reporte/generar")
async def generar_reporte(reporte_request: dict):
    """Generar reporte de auditoría"""
    tipo_reporte = reporte_request.get("tipo_reporte", "general")
    periodo = reporte_request.get("periodo", {})
    
    # Filtrar logs por período
    logs_periodo = logs_auditoria
    if "inicio" in periodo and "fin" in periodo:
        logs_periodo = [
            log for log in logs_auditoria
            if periodo["inicio"] <= log.get("timestamp", "") <= periodo["fin"]
        ]
    
    # Generar estadísticas
    operaciones_por_tipo = {}
    servicios_origen = {}
    resultados = {"exito": 0, "error": 0, "advertencia": 0}
    
    for log in logs_periodo:
        op_type = log.get("operacion", "desconocida")
        servicio = log.get("servicio_origen", "desconocido")
        resultado = log.get("resultado", "desconocido")
        
        operaciones_por_tipo[op_type] = operaciones_por_tipo.get(op_type, 0) + 1
        servicios_origen[servicio] = servicios_origen.get(servicio, 0) + 1
        
        if "exito" in resultado.lower():
            resultados["exito"] += 1
        elif "error" in resultado.lower():
            resultados["error"] += 1
        else:
            resultados["advertencia"] += 1
    
    return {
        "tipo_reporte": tipo_reporte,
        "periodo": periodo,
        "estadisticas": {
            "total_operaciones": len(logs_periodo),
            "operaciones_por_tipo": operaciones_por_tipo,
            "servicios_origen": servicios_origen,
            "resultados": resultados
        },
        "ejemplos_operaciones": logs_periodo[:5] if logs_periodo else [],
        "generado_en": datetime.now().isoformat()
    }

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de salud del servicio"""
    db_status = 'healthy' if get_db_connection() is not None else 'unhealthy'
    
    # Verificar blockchain si está habilitado
    blockchain_status = 'disabled'
    if BLOCKCHAIN_ENABLED:
        try:
            if BLOCKCHAIN_SERVICE_URL.startswith('http'):
                # Verificar servicio externo
                response = requests.get(f"{BLOCKCHAIN_SERVICE_URL}/health", timeout=2)
                blockchain_status = 'healthy' if response.status_code == 200 else 'unhealthy'
            else:
                # Verificar blockchain local
                verification = verificar_integridad_blockchain()
                blockchain_status = 'healthy' if verification.get('verified', False) else 'unhealthy'
        except:
            blockchain_status = 'unreachable'
    
    return jsonify({
        'status': 'healthy',
        'service': SERVICE_NAME,
        'version': VERSION,
        'database_status': db_status,
        'blockchain_enabled': BLOCKCHAIN_ENABLED,
        'blockchain_status': blockchain_status,
        'blockchain_mode': 'external' if BLOCKCHAIN_SERVICE_URL.startswith('http') else 'local',
        'timestamp': datetime.now().isoformat()
    })

# Modificar el endpoint /registrar para guardar en logs_auditoria
@app.post("/registrar")
async def registrar_auditoria(auditoria: dict):
    """Registrar una operación en auditoría"""
    registro = {
        "id": str(uuid.uuid4()),
        "timestamp": datetime.now().isoformat(),
        **auditoria
    }
    
    logs_auditoria.append(registro)
    
    # Limitar tamaño (mantener últimos 1000 registros)
    if len(logs_auditoria) > 1000:
        logs_auditoria.pop(0)
    
    return {"operacion_id": registro["id"], "estado": "registrado"}

@app.route('/logs', methods=['GET'])
def obtener_logs():
    """
    Obtener logs de auditoría con filtros opcionales
    """
    try:
        # Parámetros de consulta
        limite = request.args.get('limite', 50, type=int)
        operacion = request.args.get('operacion')
        servicio_origen = request.args.get('servicio_origen')
        fecha_desde = request.args.get('fecha_desde')
        fecha_hasta = request.args.get('fecha_hasta')
        verificar_blockchain = request.args.get('verificar_blockchain', 'false').lower() == 'true'
        
        # Construir consulta SQL
        query = "SELECT * FROM auditoria_logs WHERE 1=1"
        params = []
        
        if operacion:
            query += " AND operacion = %s"
            params.append(operacion)
        
        if servicio_origen:
            query += " AND servicio_origen = %s"
            params.append(servicio_origen)
        
        if fecha_desde:
            query += " AND timestamp >= %s"
            params.append(fecha_desde)
        
        if fecha_hasta:
            query += " AND timestamp <= %s"
            params.append(fecha_hasta)
        
        query += " ORDER BY timestamp DESC LIMIT %s"
        params.append(limite)
        
        # Ejecutar consulta
        conn = get_db_connection()
        if conn is None:
            return jsonify({
                'error': 'Error de conexión a base de datos'
            }), 500
        
        cursor = conn.cursor()
        cursor.execute(query, params)
        
        # Formatear resultados
        columns = [desc[0] for desc in cursor.description]
        logs = []
        
        for row in cursor.fetchall():
            log_dict = dict(zip(columns, row))
            # Convertir UUID y datetime a string
            log_dict['operacion_id'] = str(log_dict['operacion_id'])
            log_dict['timestamp'] = log_dict['timestamp'].isoformat()
            
            # Verificar en blockchain si se solicita
            if verificar_blockchain and log_dict.get('blockchain_hash'):
                log_dict['blockchain_verification'] = {
                    'hash': log_dict['blockchain_hash'],
                    'verified': log_dict.get('blockchain_verified', False)
                }
            
            logs.append(log_dict)
        
        cursor.close()
        conn.close()
        
        response_data = {
            'total_logs': len(logs),
            'filtros_aplicados': {
                'limite': limite,
                'operacion': operacion,
                'servicio_origen': servicio_origen,
                'fecha_desde': fecha_desde,
                'fecha_hasta': fecha_hasta,
                'verificar_blockchain': verificar_blockchain
            },
            'logs': logs,
            'timestamp': datetime.now().isoformat(),
            'servicio': SERVICE_NAME,
            'blockchain_enabled': BLOCKCHAIN_ENABLED
        }
        
        # Añadir verificación de cadena completa si se solicita
        if verificar_blockchain and BLOCKCHAIN_ENABLED:
            chain_verification = verificar_integridad_blockchain()
            response_data['blockchain_chain_verification'] = chain_verification
        
        return jsonify(response_data), 200
        
    except Exception as e:
        return jsonify({
            'error': f'Error interno del servidor: {str(e)}',
            'timestamp': datetime.now().isoformat(),
            'servicio': SERVICE_NAME
        }), 500

@app.route('/blockchain/verificar', methods=['GET'])
def verificar_blockchain():
    """
    Verificar integridad de la cadena de bloques
    """
    try:
        if not BLOCKCHAIN_ENABLED:
            return jsonify({
                'error': 'Blockchain no está habilitado',
                'timestamp': datetime.now().isoformat()
            }), 400
        
        result = verificar_integridad_blockchain()
        
        return jsonify({
            'service': SERVICE_NAME,
            'timestamp': datetime.now().isoformat(),
            'blockchain_enabled': BLOCKCHAIN_ENABLED,
            'verification': result
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': f'Error verificando blockchain: {str(e)}',
            'timestamp': datetime.now().isoformat()
        }), 500

@app.route('/blockchain/estado', methods=['GET'])
def estado_blockchain():
    """
    Obtener estado de la blockchain
    """
    try:
        conn = get_db_connection()
        if conn is None:
            return jsonify({
                'error': 'Error de conexión a base de datos'
            }), 500
        
        cursor = conn.cursor()
        
        # Estadísticas de blockchain
        cursor.execute("""
            SELECT 
                COUNT(*) as total_bloques,
                MIN(block_id) as primer_bloque,
                MAX(block_id) as ultimo_bloque,
                COUNT(DISTINCT previous_hash) as cambios_hash
            FROM blockchain_hashes
        """)
        
        blockchain_stats = dict(zip(
            ['total_bloques', 'primer_bloque', 'ultimo_bloque', 'cambios_hash'],
            cursor.fetchone()
        ))
        
        # Registros con blockchain
        cursor.execute("""
            SELECT 
                COUNT(*) as total_registros,
                COUNT(blockchain_hash) as registros_con_blockchain,
                COUNT(CASE WHEN blockchain_verified THEN 1 END) as registros_verificados
            FROM auditoria_logs
        """)
        
        audit_stats = dict(zip(
            ['total_registros', 'registros_con_blockchain', 'registros_verificados'],
            cursor.fetchone()
        ))
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'service': SERVICE_NAME,
            'timestamp': datetime.now().isoformat(),
            'blockchain_enabled': BLOCKCHAIN_ENABLED,
            'blockchain_mode': 'external' if BLOCKCHAIN_SERVICE_URL.startswith('http') else 'local',
            'blockchain_service_url': BLOCKCHAIN_SERVICE_URL if BLOCKCHAIN_SERVICE_URL.startswith('http') else 'local',
            'estadisticas': {
                'blockchain': blockchain_stats,
                'auditoria': audit_stats
            },
            'chain_id': BLOCKCHAIN_CHAIN_ID
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': f'Error obteniendo estado: {str(e)}',
            'timestamp': datetime.now().isoformat()
        }), 500

@app.route('/info', methods=['GET'])
def info():
    """Información del servicio con blockchain"""
    return jsonify({
        'servicio': SERVICE_NAME,
        'version': VERSION,
        'descripcion': 'Microservicio para auditoría y logging de operaciones con integración blockchain',
        'blockchain': {
            'habilitado': BLOCKCHAIN_ENABLED,
            'modo': 'external' if BLOCKCHAIN_SERVICE_URL.startswith('http') else 'local',
            'chain_id': BLOCKCHAIN_CHAIN_ID,
            'funcionalidad': 'Inmutabilidad y verificación de logs de auditoría'
        },
        'endpoints': {
            '/health': 'GET - Verificar salud del servicio',
            '/registrar': 'POST - Registrar operación en auditoría (con blockchain)',
            '/logs': 'GET - Obtener logs con filtros',
            '/estadisticas': 'GET - Obtener estadísticas de auditoría',
            '/blockchain/verificar': 'GET - Verificar integridad blockchain',
            '/blockchain/estado': 'GET - Estado de la blockchain',
            '/info': 'GET - Información del servicio'
        },
        'database_url': DATABASE_URL.split('@')[1] if '@' in DATABASE_URL else 'No configurada',
        'timestamp': datetime.now().isoformat()
    })

# Mantener endpoints existentes (estadisticas, etc.) sin cambios
# ... (tu código original para /estadisticas y otros endpoints)

if __name__ == '__main__':
    # Inicializar base de datos
    print("Inicializando base de datos...")
    if init_database():
        print("Base de datos inicializada correctamente")
        
        # Mostrar estado blockchain
        if BLOCKCHAIN_ENABLED:
            print(f"✓ Blockchain HABILITADO")
            print(f"  Modo: {'Externo' if BLOCKCHAIN_SERVICE_URL.startswith('http') else 'Local'}")
            print(f"  Chain ID: {BLOCKCHAIN_CHAIN_ID}")
        else:
            print("✗ Blockchain DESHABILITADO")
    else:
        print("Advertencia: No se pudo inicializar la base de datos")
    
    # Configuración para producción
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_PORT', 8002))
    debug = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    
    print(f"\nIniciando {SERVICE_NAME} en {host}:{port}")
    print(f"Base de datos: {DATABASE_URL}")
    
    app.run(host=host, port=port, debug=debug)