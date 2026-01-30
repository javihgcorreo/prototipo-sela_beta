# Servicio Principal SELA

## Descripción
Microservicio Flask que actúa como coordinador principal del sistema SELA. Orquesta las operaciones entre los diferentes microservicios.

## Funcionalidades
- Coordinación del pipeline completo de procesamiento
- Comunicación entre microservicios
- Monitoreo del estado de servicios dependientes
- API REST principal del sistema

## Endpoints

### GET /health
Verificar el estado de salud del servicio y servicios conectados.

### POST /procesar
Procesar datos a través del pipeline completo SELA.

**Request:**
```json
{
  "nombre": "Juan Pérez",
  "email": "juan@email.com",
  "dni": "12345678A",
  "edad": 35
}
```

**Respuesta:**
```json
{
  "operacion_id": "uuid-generado",
  "timestamp": "2025-01-02T10:30:00",
  "status": "success",
  "mensaje": "Datos procesados correctamente a través del pipeline SELA",
  "pipeline": [
    "anonimizacion_completada",
    "auditoria_registrada"
  ],
  "datos_originales_count": 4,
  "datos_procesados": {
    "nombre": "ANON_a1b2c3d4e5f6",
    "email": "ANON_g7h8i9j0k1l2",
    "dni": "ANON_m3n4o5p6q7r8",
    "edad": 34.2
  },
  "servicio": "Servicio Principal SELA"
}
```

### GET /estado-servicios
Verificar el estado de todos los microservicios conectados.

### GET /info
Obtener información del servicio y sus endpoints.

## Servicios Dependientes
- **Servicio de Anonimización** (Puerto 8001)
- **Servicio de Auditoría** (Puerto 8002)

## Ejecución Local
```bash
# Instalar dependencias
pip install -r requirements.txt

# Configurar variables de entorno (opcional)
export ANONIMIZACION_SERVICE_URL=http://localhost:8001
export AUDITORIA_SERVICE_URL=http://localhost:8002

# Ejecutar servicio
python app.py
```

## Ejecución con Docker
```bash
# Construir imagen
docker build -t servicio-sela .

# Ejecutar contenedor
docker run -p 8000:8000 \
  -e ANONIMIZACION_SERVICE_URL=http://host.docker.internal:8001 \
  -e AUDITORIA_SERVICE_URL=http://host.docker.internal:8002 \
  servicio-sela
```

## Variables de Entorno
- `FLASK_HOST`: Host del servidor (default: 0.0.0.0)
- `FLASK_PORT`: Puerto del servidor (default: 8000)
- `FLASK_DEBUG`: Modo debug (default: False)
- `ANONIMIZACION_SERVICE_URL`: URL del servicio de anonimización
- `AUDITORIA_SERVICE_URL`: URL del servicio de auditoría
