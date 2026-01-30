# Prototipo SELA - Sistema de Microservicios

## Descripción
Sistema de microservicios diseñado para el prototipo SELA con arquitectura distribuida.

## Estructura del Proyecto
```
prototipo-sela/
├── servicio-sela/          # Servicio principal SELA
├── servicio-anonimizacion/ # Servicio de anonimización de datos
├── servicio-auditoria/     # Servicio de auditoría y logs
├── docker-compose.yml      # Orquestación de contenedores
└── README.md              # Este archivo
```

## Servicios

### 1. Servicio Principal SELA (Puerto 8000)
- Servicio principal que coordina las operaciones
- Comunica con los otros microservicios
- API REST principal

### 2. Servicio de Anonimización (Puerto 8001)
- Maneja la anonimización de datos sensibles
- Algoritmos de privacidad diferencial
- API independiente para procesamiento de datos

### 3. Servicio de Auditoría (Puerto 8002)
- Registra todas las operaciones del sistema
- Almacena logs en base de datos PostgreSQL
- Trazabilidad y compliance

### 4. Base de Datos PostgreSQL (Puerto 5432)
- Almacenamiento persistente para auditoría
- Usuario: auditoria_user
- Base de datos: auditoria_db

## Configuración y Despliegue

### Prerrequisitos
- Docker
- Docker Compose

### Comandos de Despliegue
```bash
# Construir y levantar todos los servicios
docker-compose up --build

# Levantar en segundo plano
docker-compose up -d

# Ver logs
docker-compose logs -f

# Parar servicios
docker-compose down
```

## URLs de los Servicios
- Servicio SELA: http://localhost:8000
- Servicio Anonimización: http://localhost:8001
- Servicio Auditoría: http://localhost:8002
- Base de Datos PostgreSQL: localhost:5432

## Red
Todos los servicios están conectados a través de la red `sela-network` para comunicación interna.
