from flask import Flask, request, jsonify
import psycopg2
import uuid
from datetime import datetime
import os
import json

app = Flask(__name__)

# Configuración del servicio
SERVICE_NAME = "Servicio de Auditoría"
VERSION = "1.0.0"

# Configuración de base de datos
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://auditoria_user:auditoria_pass@localhost:5432/auditoria_db')

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
                metadatos JSONB
            )
        """)
        
        conn.commit()
        cursor.close()
        conn.close()
        return True
        
    except Exception as e:
        print(f"Error inicializando base de datos: {e}")
        return False

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de salud del servicio"""
    # Verificar conexión a base de datos
    db_status = 'healthy' if get_db_connection() is not None else 'unhealthy'
    
    return jsonify({
        'status': 'healthy',
        'service': SERVICE_NAME,
        'version': VERSION,
        'database_status': db_status,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/registrar', methods=['POST'])
def registrar_operacion():
    """
    Registrar una operación en el log de auditoría
    """
    try:
        # Verificar que se envíen datos JSON
        if not request.is_json:
            return jsonify({
                'error': 'Content-Type debe ser application/json'
            }), 400
        
        datos = request.get_json()
        
        # Campos requeridos
        operacion = datos.get('operacion')
        servicio_origen = datos.get('servicio_origen')
        resultado = datos.get('resultado')
        
        if not all([operacion, servicio_origen, resultado]):
            return jsonify({
                'error': 'Campos requeridos: operacion, servicio_origen, resultado'
            }), 400
        
        # Campos opcionales
        datos_procesados = datos.get('datos_procesados', 0)
        timestamp = datos.get('timestamp', datetime.now().isoformat())
        metadatos = datos.get('metadatos', {})
        
        # Insertar en base de datos
        conn = get_db_connection()
        if conn is None:
            return jsonify({
                'error': 'Error de conexión a base de datos'
            }), 500
        
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO auditoria_logs 
            (operacion, servicio_origen, datos_procesados, resultado, timestamp, metadatos)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING operacion_id, id
        """, (operacion, servicio_origen, datos_procesados, resultado, timestamp, json.dumps(metadatos)))
        
        operacion_id, log_id = cursor.fetchone()
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'status': 'success',
            'mensaje': 'Operación registrada correctamente',
            'operacion_id': str(operacion_id),
            'log_id': log_id,
            'timestamp': datetime.now().isoformat(),
            'servicio': SERVICE_NAME
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': f'Error interno del servidor: {str(e)}',
            'timestamp': datetime.now().isoformat(),
            'servicio': SERVICE_NAME
        }), 500

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
            logs.append(log_dict)
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'total_logs': len(logs),
            'filtros_aplicados': {
                'limite': limite,
                'operacion': operacion,
                'servicio_origen': servicio_origen,
                'fecha_desde': fecha_desde,
                'fecha_hasta': fecha_hasta
            },
            'logs': logs,
            'timestamp': datetime.now().isoformat(),
            'servicio': SERVICE_NAME
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': f'Error interno del servidor: {str(e)}',
            'timestamp': datetime.now().isoformat(),
            'servicio': SERVICE_NAME
        }), 500

@app.route('/estadisticas', methods=['GET'])
def obtener_estadisticas():
    """
    Obtener estadísticas de auditoría
    """
    try:
        conn = get_db_connection()
        if conn is None:
            return jsonify({
                'error': 'Error de conexión a base de datos'
            }), 500
        
        cursor = conn.cursor()
        
        # Total de operaciones
        cursor.execute("SELECT COUNT(*) FROM auditoria_logs")
        total_operaciones = cursor.fetchone()[0]
        
        # Operaciones por servicio
        cursor.execute("""
            SELECT servicio_origen, COUNT(*) 
            FROM auditoria_logs 
            GROUP BY servicio_origen
        """)
        operaciones_por_servicio = dict(cursor.fetchall())
        
        # Operaciones por tipo
        cursor.execute("""
            SELECT operacion, COUNT(*) 
            FROM auditoria_logs 
            GROUP BY operacion
        """)
        operaciones_por_tipo = dict(cursor.fetchall())
        
        # Operaciones exitosas vs errores
        cursor.execute("""
            SELECT 
                CASE WHEN resultado LIKE 'ERROR%' THEN 'errores' ELSE 'exitosas' END as tipo,
                COUNT(*)
            FROM auditoria_logs 
            GROUP BY CASE WHEN resultado LIKE 'ERROR%' THEN 'errores' ELSE 'exitosas' END
        """)
        estado_operaciones = dict(cursor.fetchall())
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'estadisticas': {
                'total_operaciones': total_operaciones,
                'operaciones_por_servicio': operaciones_por_servicio,
                'operaciones_por_tipo': operaciones_por_tipo,
                'estado_operaciones': estado_operaciones
            },
            'timestamp': datetime.now().isoformat(),
            'servicio': SERVICE_NAME
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': f'Error interno del servidor: {str(e)}',
            'timestamp': datetime.now().isoformat(),
            'servicio': SERVICE_NAME
        }), 500

@app.route('/info', methods=['GET'])
def info():
    """Información del servicio"""
    return jsonify({
        'servicio': SERVICE_NAME,
        'version': VERSION,
        'descripcion': 'Microservicio para auditoría y logging de operaciones',
        'endpoints': {
            '/health': 'GET - Verificar salud del servicio',
            '/registrar': 'POST - Registrar operación en auditoría',
            '/logs': 'GET - Obtener logs con filtros',
            '/estadisticas': 'GET - Obtener estadísticas de auditoría',
            '/info': 'GET - Información del servicio'
        },
        'database_url': DATABASE_URL.split('@')[1] if '@' in DATABASE_URL else 'No configurada',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    # Inicializar base de datos
    print("Inicializando base de datos...")
    if init_database():
        print("Base de datos inicializada correctamente")
    else:
        print("Advertencia: No se pudo inicializar la base de datos")
    
    # Configuración para producción
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_PORT', 8002))
    debug = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    
    print(f"Iniciando {SERVICE_NAME} en {host}:{port}")
    print(f"Base de datos: {DATABASE_URL}")
    
    app.run(host=host, port=port, debug=debug)
