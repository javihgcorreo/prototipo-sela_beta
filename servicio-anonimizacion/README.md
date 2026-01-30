# Servicio de Anonimización

## Descripción
Microservicio Flask responsable de la anonimización de datos sensibles del sistema SELA.

## Funcionalidades
- Anonimización de campos sensibles (nombres, emails, DNI, etc.)
- Adición de ruido estadístico a datos numéricos
- Generación de hashes determinísticos para mantener consistencia
- API REST para procesamiento de datos

## Endpoints

### GET /health
Verificar el estado de salud del servicio.

**Respuesta:**
```json
{
  "status": "healthy",
  "service": "Servicio de Anonimización",
  "version": "1.0.0",
  "timestamp": "2025-01-02T10:30:00"
}
```

### POST /anonimizar
Anonimizar datos sensibles.

**Request:**
```json
{
  "nombre": "Juan Pérez",
  "email": "juan@email.com",
  "dni": "12345678A",
  "edad": 35,
  "salario": 50000
}
```

**Respuesta:**
```json
{
  "operacion_id": "uuid-generado",
  "timestamp": "2025-01-02T10:30:00",
  "status": "success",
  "mensaje": "Datos anonimizados correctamente",
  "datos_originales_count": 5,
  "datos_anonimizados": {
    "nombre": "ANON_a1b2c3d4e5f6",
    "email": "ANON_g7h8i9j0k1l2",
    "dni": "ANON_m3n4o5p6q7r8",
    "edad": 34.2,
    "salario": 49800.5
  },
  "servicio": "Servicio de Anonimización"
}
```

### GET /info
Obtener información del servicio y sus endpoints.

## Ejecución Local
```bash
# Instalar dependencias
pip install -r requirements.txt

# Ejecutar servicio
python app.py
```

## Ejecución con Docker
```bash
# Construir imagen
docker build -t servicio-anonimizacion .

# Ejecutar contenedor
docker run -p 8001:8001 servicio-anonimizacion
```

## Variables de Entorno
- `FLASK_HOST`: Host del servidor (default: 0.0.0.0)
- `FLASK_PORT`: Puerto del servidor (default: 8001)
- `FLASK_DEBUG`: Modo debug (default: False)
