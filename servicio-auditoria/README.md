# Servicio de Auditoría

## Descripción
Microservicio Flask responsable del logging y auditoría de todas las operaciones del sistema SELA. Utiliza PostgreSQL para almacenamiento persistente.

## Funcionalidades
- Registro de operaciones y eventos del sistema
- Almacenamiento en base de datos PostgreSQL
- Consulta de logs con filtros
- Estadísticas de operaciones
- Trazabilidad completa del sistema

## Endpoints

### GET /health
Verificar el estado de salud del servicio y conexión a base de datos.

### POST /registrar
Registrar una operación en el log de auditoría.

**Request:**
```json
{
  "operacion": "procesar_datos",
  "servicio_origen": "Servicio Principal SELA",
  "datos_procesados": 5,
  "resultado": "SUCCESS",
  "timestamp": "2025-01-02T10:30:00",
  "metadatos": {
    "usuario": "sistema",
    "ip": "192.168.1.1"
  }
}
```

### GET /logs
Obtener logs de auditoría con filtros opcionales.

**Parámetros de consulta:**
- `limite`: Número máximo de logs (default: 50)
- `operacion`: Filtrar por tipo de operación
- `servicio_origen`: Filtrar por servicio origen
- `fecha_desde`: Fecha inicial (ISO format)
- `fecha_hasta`: Fecha final (ISO format)

**Ejemplo:**
```
GET /logs?limite=10&operacion=procesar_datos&servicio_origen=Servicio Principal SELA
```

### GET /estadisticas
Obtener estadísticas agregadas de las operaciones.

### GET /info
Obtener información del servicio y sus endpoints.

## Base de Datos

### Tabla: auditoria_logs
```sql
CREATE TABLE auditoria_logs (
    id SERIAL PRIMARY KEY,
    operacion_id UUID DEFAULT gen_random_uuid(),
    operacion VARCHAR(100) NOT NULL,
    servicio_origen VARCHAR(100) NOT NULL,
    datos_procesados INTEGER DEFAULT 0,
    resultado TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadatos JSONB
);
```

## Ejecución Local

### Prerrequisitos
- PostgreSQL ejecutándose
- Base de datos `auditoria_db` creada
- Usuario `auditoria_user` con permisos

```bash
# Instalar dependencias
pip install -r requirements.txt

# Configurar variable de entorno
export DATABASE_URL=postgresql://auditoria_user:auditoria_pass@localhost:5432/auditoria_db

# Ejecutar servicio
python app.py
```

## Ejecución con Docker
```bash
# Construir imagen
docker build -t servicio-auditoria .

# Ejecutar contenedor (requiere PostgreSQL)
docker run -p 8002:8002 \
  -e DATABASE_URL=postgresql://auditoria_user:auditoria_pass@host.docker.internal:5432/auditoria_db \
  servicio-auditoria
```

## Variables de Entorno
- `FLASK_HOST`: Host del servidor (default: 0.0.0.0)
- `FLASK_PORT`: Puerto del servidor (default: 8002)
- `FLASK_DEBUG`: Modo debug (default: False)
- `DATABASE_URL`: URL de conexión a PostgreSQL

## Inicialización Automática
El servicio crea automáticamente las tablas necesarias al iniciar si no existen.
