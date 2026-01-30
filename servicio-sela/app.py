from flask import Flask, request, jsonify
import requests
import uuid
from datetime import datetime
import os

app = Flask(__name__)

# Configuración del servicio
SERVICE_NAME = "Servicio Principal SELA"
VERSION = "1.0.0"

# URLs de otros microservicios
ANONIMIZACION_SERVICE_URL = os.getenv('ANONIMIZACION_SERVICE_URL', 'http://localhost:8001')
AUDITORIA_SERVICE_URL = os.getenv('AUDITORIA_SERVICE_URL', 'http://localhost:8002')

def registrar_auditoria(operacion, datos, resultado):
    """Registrar operación en el servicio de auditoría"""
    try:
        payload = {
            'operacion': operacion,
            'servicio_origen': SERVICE_NAME,
            'datos_procesados': len(datos) if isinstance(datos, dict) else 0,
            'resultado': resultado,
            'timestamp': datetime.now().isoformat()
        }
        
        response = requests.post(
            f"{AUDITORIA_SERVICE_URL}/registrar",
            json=payload,
            timeout=5
        )
        return response.status_code == 200
    except Exception as e:
        print(f"Error registrando auditoría: {e}")
        return False

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de salud del servicio"""
    # Verificar conexión con otros servicios
    servicios_status = {}
    
    try:
        resp_anon = requests.get(f"{ANONIMIZACION_SERVICE_URL}/health", timeout=3)
        servicios_status['anonimizacion'] = 'healthy' if resp_anon.status_code == 200 else 'unhealthy'
    except:
        servicios_status['anonimizacion'] = 'unreachable'
    
    try:
        resp_audit = requests.get(f"{AUDITORIA_SERVICE_URL}/health", timeout=3)
        servicios_status['auditoria'] = 'healthy' if resp_audit.status_code == 200 else 'unhealthy'
    except:
        servicios_status['auditoria'] = 'unreachable'
    
    return jsonify({
        'status': 'healthy',
        'service': SERVICE_NAME,
        'version': VERSION,
        'servicios_conectados': servicios_status,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/procesar', methods=['POST'])
def procesar_datos():
    """
    Endpoint principal para procesar datos a través del pipeline SELA
    """
    try:
        # Verificar que se envíen datos JSON
        if not request.is_json:
            return jsonify({
                'error': 'Content-Type debe ser application/json'
            }), 400
        
        datos = request.get_json()
        
        # Validar que existan datos
        if not datos:
            return jsonify({
                'error': 'No se proporcionaron datos para procesar'
            }), 400
        
        # Generar ID único para la operación
        operacion_id = str(uuid.uuid4())
        
        # Paso 1: Anonimizar datos
        try:
            response_anon = requests.post(
                f"{ANONIMIZACION_SERVICE_URL}/anonimizar",
                json=datos,
                timeout=10
            )
            
            if response_anon.status_code != 200:
                raise Exception(f"Error en anonimización: {response_anon.text}")
            
            datos_anonimizados = response_anon.json()['datos_anonimizados']
            
        except Exception as e:
            error_msg = f"Error comunicando con servicio de anonimización: {str(e)}"
            registrar_auditoria('procesar_datos', datos, f'ERROR: {error_msg}')
            return jsonify({'error': error_msg}), 500
        
        # Paso 2: Registrar en auditoría
        registrar_auditoria('procesar_datos', datos, 'SUCCESS')
        
        # Preparar respuesta
        respuesta = {
            'operacion_id': operacion_id,
            'timestamp': datetime.now().isoformat(),
            'status': 'success',
            'mensaje': 'Datos procesados correctamente a través del pipeline SELA',
            'pipeline': [
                'anonimizacion_completada',
                'auditoria_registrada'
            ],
            'datos_originales_count': len(datos),
            'datos_procesados': datos_anonimizados,
            'servicio': SERVICE_NAME
        }
        
        return jsonify(respuesta), 200
        
    except Exception as e:
        error_msg = f'Error interno del servidor: {str(e)}'
        registrar_auditoria('procesar_datos', {}, f'ERROR: {error_msg}')
        return jsonify({
            'error': error_msg,
            'timestamp': datetime.now().isoformat(),
            'servicio': SERVICE_NAME
        }), 500

@app.route('/estado-servicios', methods=['GET'])
def estado_servicios():
    """Verificar estado de todos los microservicios"""
    servicios = {}
    
    # Verificar servicio de anonimización
    try:
        resp = requests.get(f"{ANONIMIZACION_SERVICE_URL}/health", timeout=3)
        servicios['anonimizacion'] = {
            'status': 'healthy' if resp.status_code == 200 else 'unhealthy',
            'url': ANONIMIZACION_SERVICE_URL,
            'response_time': resp.elapsed.total_seconds() if resp else None
        }
    except Exception as e:
        servicios['anonimizacion'] = {
            'status': 'error',
            'url': ANONIMIZACION_SERVICE_URL,
            'error': str(e)
        }
    
    # Verificar servicio de auditoría
    try:
        resp = requests.get(f"{AUDITORIA_SERVICE_URL}/health", timeout=3)
        servicios['auditoria'] = {
            'status': 'healthy' if resp.status_code == 200 else 'unhealthy',
            'url': AUDITORIA_SERVICE_URL,
            'response_time': resp.elapsed.total_seconds() if resp else None
        }
    except Exception as e:
        servicios['auditoria'] = {
            'status': 'error',
            'url': AUDITORIA_SERVICE_URL,
            'error': str(e)
        }
    
    return jsonify({
        'servicio_principal': SERVICE_NAME,
        'timestamp': datetime.now().isoformat(),
        'servicios_dependientes': servicios
    })

@app.route('/info', methods=['GET'])
def info():
    """Información del servicio"""
    return jsonify({
        'servicio': SERVICE_NAME,
        'version': VERSION,
        'descripcion': 'Servicio principal que coordina el pipeline SELA',
        'endpoints': {
            '/health': 'GET - Verificar salud del servicio',
            '/procesar': 'POST - Procesar datos a través del pipeline completo',
            '/estado-servicios': 'GET - Estado de todos los microservicios',
            '/info': 'GET - Información del servicio'
        },
        'servicios_conectados': {
            'anonimizacion': ANONIMIZACION_SERVICE_URL,
            'auditoria': AUDITORIA_SERVICE_URL
        },
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    # Configuración para producción
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_PORT', 8000))
    debug = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    
    print(f"Iniciando {SERVICE_NAME} en {host}:{port}")
    print(f"Conectando a:")
    print(f"  - Anonimización: {ANONIMIZACION_SERVICE_URL}")
    print(f"  - Auditoría: {AUDITORIA_SERVICE_URL}")
    
    app.run(host=host, port=port, debug=debug)
