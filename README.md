


# 🛡️ Sistema SeLA: Smart Enforcement of Licensing Agreements

**Prototipo de Gestión de Licencias de Datos con Cumplimiento Automático del RGPD**

Este sistema es un entorno de microservicios diseñado para garantizar que el intercambio de datos entre entidades (ej. Hospitales y centros de investigación) se realice bajo acuerdos legales verificables, trazables mediante blockchain y con anonimización automática.

## 🚀 Inicio Rápido
Aquí tienes las instrucciones paso a paso, redactadas de forma clara y profesional para que cualquiera (incluido el tribunal) pueda poner en marcha tu TFM en menos de un minuto.

Puedes copiar este bloque directamente en la sección **"Guía de Inicio Rápido"** de tu `README.md`:

---

## 🚀 Instalación y Puesta en Marcha

Sigue estos pasos en tu terminal para desplegar el entorno completo y ejecutar la prueba de concepto:

### 1. Clonar el proyecto

Primero, descarga el repositorio desde GitHub y accede a la carpeta del proyecto:

```powershell
git clone https://github.com/javihgcorreo/prototipo-sela_beta/
cd nombre-del-repo-tfm

```

### 2. Configurar permisos (Solo Windows)

Para poder ejecutar el script de automatización en PowerShell, asegúrate de tener permisos para ejecutar scripts locales:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

```

### 3. Ejecutar la Demo Automática

Lanza el script principal. Este comando se encarga de limpiar contenedores antiguos, levantar los microservicios y validar el funcionamiento del sistema SeLA:

```powershell
.\probar-desde-cero.ps1

```

---

## 📋 ¿Qué esperar tras la ejecución?

Una vez que el script termine (el Paso 9), verás un resumen en verde. El sistema quedará encendido y podrás acceder a las siguientes interfaces:

* **Panel de Control (Demo Tribunal):** [http://localhost:8000/api/v1/demo/tribunal](https://www.google.com/search?q=http://localhost:8000/api/v1/demo/tribunal)
*(Aquí verás que ya existe 1 acuerdo activo creado por el script).*
* **Estado de Infraestructura:** [http://localhost:8000/api/v1/infraestructura](https://www.google.com/search?q=http://localhost:8000/api/v1/infraestructura)
*(Verifica que todos los microservicios están conectados).*

---

> **Nota:** El despliegue inicial puede tardar un par de minutos mientras Docker descarga las imágenes base (Python y PostgreSQL). Las ejecuciones posteriores serán casi instantáneas.

### Requisitos Previos

* **Docker** y **Docker Compose**

---

## 📥 Instalación y Configuración

### 1. Clonar el Repositorio

Primero, descarga el código fuente del proyecto desde GitHub (o la plataforma que utilices):

```bash
git clone https://github.com/tu-usuario/nombre-del-repo-tfm.git
cd nombre-del-repo-tfm

```

### 2. Estructura del Proyecto

Asegúrate de que la estructura de carpetas sea la siguiente para que los scripts funcionen correctamente:

```text
/
├── servicio-sela/       # Microservicio principal (FastAPI)
├── servicio-auditoria/  # Registro de logs y blockchain (Python/Flask)
├── servicio-anon/       # Procesamiento de datos (Python/Flask)
├── docker-compose.yml   # Orquestación de contenedores
└── probar-desde-cero.ps1 # Script de validación automática

```

### 3. Requisitos de Ejecución

* **Docker Desktop:** Instalado y en ejecución.
* **Permisos de PowerShell:** Para ejecutar el script de prueba en Windows, es posible que necesites habilitar la ejecución de scripts localmente:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser


### 💡 Por qué es importante el paso del `Set-ExecutionPolicy`

Muchos tribunales usan ordenadores con políticas de seguridad que bloquean scripts `.ps1` por defecto. Al poner este comando en el README, les ahorras el error de "este script no puede cargarse porque la ejecución de scripts está deshabilitada", lo cual te hace quedar muy profesional y previsor.

**¿Quieres que añada también una sección de "Prerrequisitos" con los enlaces de descarga de Docker por si el tribunal no lo tiene instalado?**
### Despliegue del Sistema

Para levantar toda la infraestructura (API Principal, Anonimización, Auditoría y Base de Datos), ejecuta:

```bash
docker-compose up --build -d

```

### Prueba de Concepto Automática

He incluido un script que limpia el sistema, levanta los servicios y crea un acuerdo de prueba para verificar que todo el flujo funciona:

```powershell
./probar-desde-cero.ps1

```

---

## 🏗️ Arquitectura de Microservicios

| Servicio | Puerto | Descripción |
| --- | --- | --- |
| **SELA-Main** | `8000` | Núcleo del sistema. Gestión de acuerdos y orquestación. |
| **Anonimización** | `8001` | Procesamiento de datos sensibles (Hashing/Ruido). |
| **Auditoría** | `8002` | Registro persistente con integridad Blockchain. |
| **PostgreSQL** | `5432` | Almacenamiento de logs de auditoría y hashes de bloques. |

---

## 🛠️ Funcionalidades Clave para la Defensa

### 1. Creación de Acuerdos Inteligentes

Valida automáticamente los parámetros del RGPD (Base legal, finalidad, nivel de anonimización) antes de emitir un ID de acuerdo único.

### 2. Trazabilidad Blockchain

Cada operación registrada en el servicio de auditoría genera un hash vinculado al anterior, creando una cadena de bloques en la base de datos que garantiza la **no repudiación** de las acciones.

### 3. Service Discovery (Infraestructura)

El sistema permite visualizar el estado de salud de todos los microservicios desde un único endpoint:
👉 `GET http://localhost:8000/api/v1/infraestructura`

### 4. Panel de Control (Tribunal Demo)

Resumen en tiempo real del estado del sistema para demostración:
👉 `GET http://localhost:8000/api/v1/demo/tribunal`

---

## 📝 Comandos Útiles de Depuración

* **Ver logs de todos los servicios:** `docker-compose logs -f`
* **Reiniciar un servicio específico:** `docker-compose restart servicio-sela`
* **Acceder a la base de datos de auditoría:**
```bash
docker exec -it sela-postgres psql -U auditoria_user -d auditoria_db

```



---

## ⚖️ Licencia

Este proyecto ha sido desarrollado como parte del Trabajo de Fin de Máster (TFM). Todos los derechos reservados.

---
¡Perfecto! Ya tienes el motor funcionando. Para que el **README.md** sea de 10, aquí tienes unos bloques adicionales que resumen la lógica de **anonimización** y el **blockchain**, que son los puntos donde el tribunal te hará más preguntas:

---

### 📂 Estructura sugerida para el README (Continuación)

### 🛡️ Lógica de Anonimización (Cumplimiento RGPD)

El servicio de anonimización aplica diferentes técnicas según el tipo de dato detectado en el JSON:

* **Identificadores Directos (Nombre, DNI, Email):** Aplica un hash `SHA-256` truncado con prefijo `ANON_`. Esto permite la seudonimización (reutilizar el mismo ID para el mismo paciente sin revelar su identidad).
* **Datos Cuantitativos (Edad, Salario):** Aplica una técnica de **Ruido Diferencial**, modificando el valor original en un rango de  para proteger la privacidad individual mientras se mantiene la validez estadística para investigación.

### ⛓️ Integridad mediante Blockchain

El microservicio de **Auditoría** implementa una estructura de cadena de bloques (Blockchain) almacenada en PostgreSQL:

1. Cada log de actividad se vincula a un bloque.
2. Cada bloque contiene el `Hash` del bloque anterior.
3. **Garantía:** Si un administrador intentara borrar un log de la base de datos, la cadena de hashes se rompería, dejando evidencia inmediata de la manipulación.

---
Para el archivo **`probar-desde-cero.ps1`**, las instrucciones en el `README.md` deben resaltar que no es solo un script de test, sino la **herramienta de despliegue y validación automática** de tu TFM.

Aquí tienes el bloque específico para las instrucciones del script:

---

### 🧪 Validación del Prototipo (Script de Prueba)

Para facilitar la evaluación del tribunal, se ha incluido un script de automatización en PowerShell que realiza un ciclo completo de vida del sistema.

#### **Instrucciones de ejecución:**

1. Abre una terminal de **PowerShell** como administrador.
2. Ejecuta el script:
```powershell
.\probar-desde-cero.ps1

```



#### **¿Qué hace este script? (Flujo de la Demo):**

El script automatiza los 9 pasos críticos que demuestran la robustez del sistema:

1. **Limpieza:** Elimina contenedores y volúmenes previos para asegurar una prueba "limpia".
2. **Verificación de Código:** Comprueba que los archivos del núcleo (FastAPI) están presentes.
3. **Despliegue:** Levanta la infraestructura mediante `docker-compose`.
4. **Health Check:** Espera a que los 3 microservicios y la base de datos estén operativos.
5. **Prueba de Conectividad:** Verifica los endpoints de salud de cada componente.
6. **Creación de Acuerdo (Núcleo TFM):** Envía un JSON con un acuerdo de compartición de datos. **Aquí es donde se valida el RGPD.**
7. **Persistencia:** Confirma que el acuerdo ha sido almacenado y tiene un ID único.
8. **Auditoría:** Verifica que el Servicio de Auditoría ha registrado la creación del acuerdo.
9. **Resumen Final:** Muestra las URLs clave para que el tribunal pueda ver los resultados en el navegador.

---

### 💡 Nota técnica para el README sobre el script:

> **Importante:** El script utiliza el comando `Invoke-RestMethod` de PowerShell para interactuar con la API REST. Si el sistema devuelve un **Error 400**, el script está diseñado para capturar la excepción y mostrar el detalle del error de validación de Pydantic (FastAPI), facilitando la depuración en tiempo real durante la defensa.

---


> **Estado actual:** ✅ Funcional (Fase Beta)
> * Orquestación: Docker Compose
> * Comunicación: REST API (Httpx / Flask / FastAPI)
> * Persistencia: PostgreSQL 15
> 
> 

---


## 📁 **ESTRUCTURA FINAL DEL REPOSITORIO:**

```
prototipo-sela_beta/
│
├── 📁 servicio-sela/
│   ├── 📄 app.py                    # API FastAPI con todos los endpoints
│   ├── 📄 requirements.txt          # Dependencias Python
│   └── 📄 Dockerfile               # Imagen Docker optimizada
│
├── 📁 servicio-anonimizacion/
│   ├── 📄 app.py                    # Servicio Flask de anonimización
│   ├── 📄 requirements.txt          # Dependencias Python
│   └── 📄 Dockerfile               # Imagen Docker
│
├── 📁 servicio-auditoria/
│   ├── 📄 app.py                    # Servicio Flask de auditoría
│   ├── 📄 requirements.txt          # Dependencias Python
│   ├── 📄 wait-for-postgres.sh     # Script para esperar PostgreSQL
│   └── 📄 Dockerfile               # Imagen Docker
│
├── 📄 docker-compose.yml           # Orquestación completa
├── 📄 .env                         # Variables de entorno (plantilla)
├── 📄 .gitignore                   # Archivos a ignorar en Git
│
├── 📄 reconstruir-completo.ps1     # Script Windows - Reconstrucción
├── 📄 reconstruir-completo-linux.sh # Script Linux - Reconstrucción
├── 📄 probar-tfm-completo.ps1      # Script Windows - Pruebas TFM
├── 📄 probar-tfm-completo.sh       # Script Linux - Pruebas TFM
├── 📄 probar-tfm-corregido.ps1     # Script Windows - Pruebas básicas
│
├── 📄 verificar-auditoria.ps1      # Script específico auditoría
├── 📄 README.md                    # Documentación principal
└── 📄 INSTALACION.md               # Guía de instalación detallada
```



## 📄 **4. ARCHIVO README.md:**

```markdown
# 🛡️ Sistema SeLA - TFM
**Sistema de Licencias de Acceso para datos sensibles con cumplimiento RGPD automático**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-✓-blue)](https://www.docker.com/)
[![FastAPI](https://img.shields.io/badge/FastAPI-✓-green)](https://fastapi.tiangolo.com/)

## 📋 Descripción

Sistema distribuido para la gestión de acuerdos de acceso a datos sensibles con validación automática de cumplimiento RGPD, anonimización de datos y auditoría completa.

### 🎯 Características principales:
- ✅ **Gestión de Acuerdos**: Creación y validación automática de acuerdos de acceso
- ✅ **Validación RGPD**: Cumplimiento automático de principios de protección de datos
- ✅ **Anonimización**: K-anonimity y diferentes niveles de protección
- ✅ **Auditoría**: Trazabilidad completa de todas las operaciones
- ✅ **Arquitectura Microservicios**: 3 servicios independientes + PostgreSQL
- ✅ **Scripts automáticos**: Pruebas y reconstrucción completas

## 🚀 Instalación rápida

### Prerrequisitos:
- Docker 20.10+
- Docker Compose 2.0+
- PowerShell 5.1+ (Windows) o Bash (Linux)

### 1. Clonar repositorio:
```bash
git clone https://github.com/tu-usuario/prototipo-sela_beta.git
cd prototipo-sela_beta
```

### Requisitos de Ejecución
Docker Desktop: Instalado y en ejecución.

Permisos de PowerShell: Para ejecutar el script de prueba en Windows, es posible que necesites habilitar la ejecución de scripts localmente:

PowerShell
```Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser```

### 2. Reconstruir sistema completo:
**Windows:**
```powershell
.\probar-desde-cero.ps1
```

**Linux/Mac:**
```bash
chmod +x reconstruir-completo-linux.sh
./probar-desde-cero.sh
```

### 3. Ejecutar pruebas del TFM:
**Windows:**
```powershell
.\probar-tfm-completo.ps1
```

**Linux/Mac:**
```bash
chmod +x probar-tfm-completo.sh
./probar-tfm-completo.sh
```

## 🏗️ Arquitectura

```
localhost:8000 ──► Servicio SELA (FastAPI)
       ├──► Gestión de acuerdos
       ├──► Validación RGPD
       └──► Service Discovery

localhost:8001 ──► Servicio Anonimización (Flask)
       └──► Anonimización de datos sensibles

localhost:8002 ──► Servicio Auditoría (Flask)
       ├──► Registro de operaciones
       ├──► Trazabilidad completa
       └──► Reportes automáticos

localhost:5432 ──► PostgreSQL
       └──► Base de datos de auditoría
```

## 📊 Endpoints principales

### Servicio SELA (8000):
- `GET /api/v1/health` - Estado del servicio
- `GET /api/v1/info` - Información del sistema
- `GET /api/v1/infraestructura` - Service discovery
- `GET /api/v1/demo/tribunal` - Demo para presentación TFM
- `POST /api/v1/acuerdo/crear` - Crear acuerdo SeLA
- `GET /api/v1/acuerdo/{id}/estado` - Estado de acuerdo
- `POST /api/v1/acuerdo/{id}/ejecutar` - Ejecutar operación

### Servicio Anonimización (8001):
- `GET /health` - Estado del servicio
- `POST /anonimizar` - Anonimizar datos
- `POST /verificar/k-anonimity` - Verificar k-anonimity

### Servicio Auditoría (8002):
- `GET /health` - Estado del servicio
- `POST /registrar` - Registrar operación
- `GET /logs` - Consultar logs
- `GET /logs/acuerdo/{id}` - Logs por acuerdo
- `POST /reporte/generar` - Generar reporte

## 🧪 Scripts de pruebas

El repositorio incluye scripts completos para pruebas:

| Script | Descripción | Plataforma |
|--------|-------------|------------|
| `reconstruir-completo.ps1` | Reconstruye todo el sistema desde cero | Windows |
| `reconstruir-completo-linux.sh` | Reconstruye todo el sistema desde cero | Linux/Mac |
| `probar-tfm-completo.ps1` | Pruebas completas del sistema (24 tests) | Windows |
| `probar-tfm-completo.sh` | Pruebas completas del sistema (24 tests) | Linux/Mac |
| `probar-tfm-corregido.ps1` | Pruebas básicas del sistema | Windows |
| `verificar-auditoria.ps1` | Verificación específica de auditoría | Windows |

## 🎓 Para el tribunal del TFM

### Demostración en vivo:
1. **Mostrar arquitectura:**
   ```bash
   docker-compose ps
   ```

2. **Crear acuerdo de prueba: Válido**
   ```bash
   curl -X POST http://localhost:8000/api/v1/acuerdo/crear \
     -H "Content-Type: application/json" \
     -d '{
       "nombre": "Demo Tribunal TFM",
       "partes": {
         "proveedor": "Hospital Universitario",
         "consumidor": "Tribunal TFM"
       },
       "tipo_datos": "datos_salud_fhir",
       "finalidad": "demostracion_tecnica",
       "base_legal": "consentimiento",
       "nivel_anonimizacion": "alto",
       "duracion_horas": 24,
       "volumen_maximo": 1000
     }'
   ```
   ### Resultado esperado:

    SELA-Main: Devuelve un 200 OK con el ID del acuerdo generado.

    ### :
    2.1 ** Auditoría: El sistema enviará automáticamente un log al puerto 8002.**

    *** Verificación: Visite http://localhost:8002/logs para comprobar que el registro se ha guardado de forma inmutable con su correspondiente Hash criptográfico.

    ## 🛡️ Guía de Validación de Cumplimiento (RGPD)

    Para demostrar la capacidad de **Smart Enforcement** del sistema SELA, siga estos pasos:

        ### 1. Intento de creación de acuerdo con base legal NO VÁLIDA
        Utilice Postman o cURL para intentar crear un acuerdo con una justificación jurídica no reconocida por el RGPD:

        **Endpoint:** `POST http://localhost:8000/api/v1/acuerdo/crear`
        **Body (JSON):**
        ```json
        {
        "nombre": "Prueba Denegada",
        "base_legal": "porque si",
        "finalidad": "test"
        }
    ```
    Resultado esperado: El sistema devolverá un error 400 Bad Request indicando que la base legal no es lícita, bloqueando la operación.

3. **Mostrar demo interactiva:**
   ```bash
   # Abrir en navegador:
   http://localhost:8000/api/v1/demo/tribunal
   http://localhost:8000/api/v1/infraestructura
   http://localhost:8002/logs?limite=5
   ```

### Puntos a destacar:
- ✅ **Privacy by Design**: Validación RGPD automática en cada operación
- ✅ **K-anonimity**: Implementación real de anonimización
- ✅ **Trazabilidad**: Auditoría completa de todas las operaciones
- ✅ **Escalabilidad**: Arquitectura microservicios
- ✅ **Automatización**: Scripts de prueba y despliegue

## 🔧 Comandos útiles

```bash
# Ver estado de servicios
docker-compose ps

# Ver logs en tiempo real
docker-compose logs -f

# Ver logs específicos
docker-compose logs servicio-sela
docker-compose logs servicio-anonimizacion
docker-compose logs servicio-auditoria

# Detener sistema
docker-compose down

# Detener y eliminar volúmenes
docker-compose down -v

# Reconstruir un servicio específico
docker-compose build servicio-sela
docker-compose up -d servicio-sela
```

## 📝 Reportes generados

Los scripts de prueba generan reportes automáticos:
- `reporte_pruebas_tfm_YYYYMMDD_HHMMSS.txt`
- Incluye porcentaje de éxito y detalles de pruebas

## 🐛 Solución de problemas

### Problema: FastAPI no está instalado
```bash
# Verificar requirements.txt
cat servicio-sela/requirements.txt

# Reconstruir solo SELA
docker-compose build --no-cache servicio-sela
```

### Problema: PostgreSQL no inicia
```bash
# Verificar logs
docker-compose logs postgres

# Eliminar volumen y recrear
docker-compose down -v
docker-compose up -d
```

### Problema: Servicios no se comunican
```bash
# Verificar red
docker network ls
docker network inspect prototipo-sela_beta_sela-network
```

## 📄 Licencia

Este proyecto fue desarrollado como Trabajo de Fin de Máster (TFM) y se distribuye bajo licencia MIT.

## 👨‍💻 Autor

Tu Nombre - Máster en Ciencia de Datos/Ingeniería de Software  
Universidad: Tu Universidad  
Contacto: tu.email@universidad.edu  
GitHub: [@tu-usuario](https://github.com/tu-usuario)

---

⭐ **Si este proyecto te resulta útil, ¡déjale una estrella en GitHub!**
```

## 📄 **5. ARCHIVO INSTALACION.md:**

```markdown
# 📚 Guía de instalación detallada - Sistema SeLA

## 📋 Tabla de contenidos
1. [Prerrequisitos](#prerrequisitos)
2. [Instalación en Windows](#instalación-en-windows)
3. [Instalación en Linux/Mac](#instalación-en-linuxmac)
4. [Instalación manual](#instalación-manual)
5. [Verificación](#verificación)
6. [Solución de problemas](#solución-de-problemas)

## 🖥️ Prerrequisitos

### Para todas las plataformas:
- **Docker Desktop** (Windows/Mac) o **Docker Engine** (Linux)
- **Docker Compose** (incluido en Docker Desktop)
- **Git** (para clonar el repositorio)

### Específico por plataforma:
- **Windows**: PowerShell 5.1+ (Windows 10/11)
- **Linux**: Bash shell, permisos de sudo para Docker
- **Mac**: Terminal, Homebrew (opcional)

## 🪟 Instalación en Windows

### Paso 1: Instalar Docker Desktop
1. Descargar Docker Desktop desde [docker.com](https://www.docker.com/products/docker-desktop/)
2. Instalar con configuración por defecto
3. Reiniciar el equipo si es necesario
4. Verificar instalación:
   ```powershell
   docker --version
   docker-compose --version
   ```

### Paso 2: Configurar PowerShell
```powershell
# Permitir ejecución de scripts (si es necesario)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Confirmar cambios
Get-ExecutionPolicy -List
```

### Paso 3: Clonar y ejecutar
```powershell
# Clonar repositorio
git clone https://github.com/tu-usuario/prototipo-sela_beta.git
cd prototipo-sela_beta

# Reconstruir sistema completo
.\reconstruir-completo.ps1

# Ejecutar pruebas
.\probar-tfm-completo.ps1
```

## 🐧 Instalación en Linux/Mac

### Paso 1: Instalar Docker y Docker Compose

**Ubuntu/Debian:**
```bash
# Actualizar sistema
sudo apt update
sudo apt upgrade -y

# Instalar Docker
sudo apt install docker.io docker-compose -y

# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Cerrar sesión y volver a entrar
```

**Mac (con Homebrew):**
```bash
# Instalar Homebrew si no está instalado
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar Docker Desktop
brew install --cask docker

# O instalar Docker Engine y Compose
brew install docker docker-compose
```

### Paso 2: Clonar y ejecutar
```bash
# Clonar repositorio
git clone https://github.com/tu-usuario/prototipo-sela_beta.git
cd prototipo-sela_beta

# Dar permisos de ejecución
chmod +x reconstruir-completo-linux.sh probar-tfm-completo.sh

# Reconstruir sistema
./reconstruir-completo-linux.sh

# Ejecutar pruebas
./probar-tfm-completo.sh
```

## 🔧 Instalación manual

### Paso 1: Configurar entorno
```bash
# Crear estructura de directorios
mkdir -p servicio-sela servicio-anonimizacion servicio-auditoria

# Crear archivo .env
cp .env.example .env
```

### Paso 2: Iniciar servicios manualmente
```bash
# Iniciar PostgreSQL
docker run -d \
  --name sela-postgres \
  -e POSTGRES_DB=auditoria_db \
  -e POSTGRES_USER=auditoria_user \
  -e POSTGRES_PASSWORD=auditoria_pass \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:15

# Construir e iniciar SELA
cd servicio-sela
docker build -t servicio-sela .
docker run -d --name sela-main -p 8000:8000 servicio-sela

# Construir e iniciar Anonimización
cd ../servicio-anonimizacion
docker build -t servicio-anonimizacion .
docker run -d --name sela-anonimizacion -p 8001:8001 servicio-anonimizacion

# Construir e iniciar Auditoría
cd ../servicio-auditoria
docker build -t servicio-auditoria .
docker run -d --name sela-auditoria -p 8002:8002 servicio-auditoria
```

## ✅ Verificación

### Verificar que todo funciona:
```bash
# Ver estado de contenedores
docker ps

# Verificar salud de servicios
curl http://localhost:8000/api/v1/health
curl http://localhost:8001/health
curl http://localhost:8002/health

# Probar endpoints principales
curl http://localhost:8000/api/v1/info
curl http://localhost:8000/api/v1/demo/tribunal
```

### Verificar conectividad entre servicios:
```bash
# Desde dentro de un contenedor
docker exec sela-main curl -s http://servicio-anonimizacion:8001/health
docker exec sela-main curl -s http://servicio-auditoria:8002/health
```

## 🐛 Solución de problemas

### Problema 1: "No module named 'fastapi'"
```bash
# Verificar requirements.txt
cat servicio-sela/requirements.txt

# Reinstalar dependencias dentro del contenedor
docker exec sela-main pip install fastapi uvicorn httpx pydantic

# Reconstruir imagen
docker-compose build --no-cache servicio-sela
```

### Problema 2: Puerto ya en uso
```bash
# Ver qué proceso usa el puerto
netstat -ano | findstr :8000  # Windows
lsof -i :8000                 # Linux/Mac

# Cambiar puertos en docker-compose.yml
sed -i 's/8000:8000/8003:8000/g' docker-compose.yml
```

### Problema 3: PostgreSQL no se conecta
```bash
# Ver logs de PostgreSQL
docker-compose logs postgres

# Verificar conexión manual
docker exec sela-postgres pg_isready -U auditoria_user

# Reiniciar servicios dependientes
docker-compose restart servicio-auditoria
```

### Problema 4: Permisos en Linux
```bash
# Si hay problemas de permisos con Docker
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

# Verificar
docker ps
```

### Problema 5: Memoria insuficiente
```bash
# Limpiar recursos Docker
docker system prune -a
docker volume prune

# Aumentar memoria en Docker Desktop (Windows/Mac)
# Settings -> Resources -> Memory
```

## 🔍 Diagnóstico avanzado

### Verificar redes Docker:
```bash
docker network ls
docker network inspect prototipo-sela_beta_sela-network
```

### Verificar logs detallados:
```bash
# Todos los logs
docker-compose logs --tail=50

# Logs específicos con timestamps
docker-compose logs --tail=20 -t servicio-sela

# Seguir logs en tiempo real
docker-compose logs -f
```

### Verificar dependencias instaladas:
```bash
# Dentro del contenedor SELA
docker exec sela-main pip list | grep -E "fastapi|uvicorn|httpx|pydantic"

# Dentro del contenedor Flask
docker exec sela-anonimizacion pip list | grep -E "flask|python"
```

## 📈 Monitoreo

### Estadísticas de contenedores:
```bash
# Uso de recursos
docker stats

# Espacio en disco
docker system df

# Información detallada
docker inspect sela-main
```

### Endpoints de monitoreo:
- http://localhost:8000/api/v1/health/detallado
- http://localhost:8000/api/v1/estadisticas
- http://localhost:8002/logs?limite=10

## 🔄 Actualización

### Actualizar desde Git:
```bash
# Guardar cambios locales si los hay
git stash

# Obtener última versión
git pull origin main

# Reconstruir
./reconstruir-completo-linux.sh  # Linux
# o
.\reconstruir-completo.ps1       # Windows
```

### Actualizar dependencias:
```bash
# Actualizar requirements.txt
# Luego reconstruir
docker-compose build --no-cache
docker-compose up -d
```

---

## 📞 Soporte

Si encuentras problemas:
1. Revisa la sección de [Solución de problemas](#solución-de-problemas)
2. Verifica los logs con `docker-compose logs`
3. Crea un issue en el repositorio de GitHub
4. Contacta al autor: tu.email@universidad.edu

## 📚 Recursos adicionales

- [Documentación de Docker](https://docs.docker.com/)
- [Documentación de FastAPI](https://fastapi.tiangolo.com/)
- [Guía de Docker Compose](https://docs.docker.com/compose/)
- [Principios RGPD](https://ec.europa.eu/info/law/law-topic/data-protection_es)
```

## 🚀 **PARA SUBIR AL REPOSITORIO:**

### **Paso 1: Crear repositorio en GitHub**
1. Ve a [github.com](https://github.com)
2. Crea nuevo repositorio: `prototipo-sela_beta`
3. Marca como público o privado según necesites
4. No agregues README.md inicial (ya lo tenemos)

### **Paso 2: Configurar Git localmente**
```bash
# Inicializar repositorio (si no está ya)
git init

# Configurar usuario
git config user.name "Tu Nombre"
git config user.email "tu.email@universidad.edu"

# Agregar todos los archivos
git add .

# Commit inicial
git commit -m "Sistema SeLA completo - TFM Final"

# Agregar repositorio remoto
git remote add origin https://github.com/tu-usuario/prototipo-sela_beta.git

# Subir al repositorio
git push -u origin main
```

### **Paso 3: Verificar que todo subió correctamente**
```bash
# Clonar en otra carpeta para probar
cd ..
mkdir prueba-repo
cd prueba-repo
git clone https://github.com/tu-usuario/prototipo-sela_beta.git
cd prototipo-sela_beta

# Probar que funciona
.\reconstruir-completo.ps1  # Windows
# o
./reconstruir-completo-linux.sh  # Linux
```

## 🎯 **PUNTOS CLAVE PARA TU TFM:**

1. **Documentación completa**: README.md e INSTALACION.md
2. **Scripts automáticos**: Reconstrucción y pruebas
3. **Arquitectura limpia**: 3 servicios + PostgreSQL
4. **Pruebas automáticas**: Reportes generados
5. **Demo para tribunal**: Endpoint específico
6. **Cumplimiento RGPD**: Validación automática

## 📦 **ARCHIVOS CRÍTICOS QUE DEBEN SUBIRSE:**

Asegúrate de que estos archivos existan antes de subir:

```powershell
# Verificar estructura
Get-ChildItem -Recurse | Where-Object { $_.Name -match "\.(py|txt|yml|ps1|sh|md|Dockerfile)$" } | Select-Object Name
```

## ✅ **RESULTADO FINAL:**

Tu repositorio estará listo para:
- ✅ **Defensa del TFM**: Demostración en vivo
- ✅ **Evaluación**: Scripts de prueba automáticos
- ✅ **Reproducibilidad**: Cualquier tribunal puede clonar y probar
- ✅ **Documentación**: Instrucciones claras y completas

-------------------
Linux
Aquí tienes la versión adaptada del script PowerShell para Linux (Bash Shell) compatible con linux (basado en Ubuntu):

```bash
#!/bin/bash
# reconstruir-completo-corregido.sh
# Versión para Linux/LliureX 21

echo -e "\033[1;36mRECONSTRUCCION COMPLETA DEL SISTEMA SeLA (CORREGIDO)\033[0m"
echo -e "\033[1;36m======================================================\033[0m"

# Detectar directorio del script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo -e "\033[0;37mDirectorio del script: $SCRIPT_DIR\033[0m"

# 1. VERIFICAR ARCHIVOS CRÍTICOS
echo -e "\n\033[1;33m1. VERIFICANDO ARCHIVOS NECESARIOS:\033[0m"

critical_files=(
    "docker-compose.yml"
    "servicio-sela/Dockerfile"
    "servicio-sela/requirements.txt"
    "servicio-sela/app.py"
    "servicio-anonimizacion/Dockerfile"
    "servicio-anonimizacion/requirements.txt"
    "servicio-anonimizacion/app.py"
    "servicio-auditoria/Dockerfile"
    "servicio-auditoria/requirements.txt"
    "servicio-auditoria/app.py"
)

all_files_ok=true
for file in "${critical_files[@]}"; do
    full_path="$SCRIPT_DIR/$file"
    if [ -f "$full_path" ]; then
        size=$(stat -c%s "$full_path" 2>/dev/null || stat -f%z "$full_path" 2>/dev/null)
        echo -e "   \033[1;32m[OK]\033[0m $file ($size bytes)"
    else
        echo -e "   \033[1;31m[ERROR]\033[0m $file NO ENCONTRADO"
        all_files_ok=false
    fi
done

if [ "$all_files_ok" = false ]; then
    exit 1
fi

# 2. CREAR REQUIREMENTS.TXT SI NO EXISTEN
echo -e "\n\033[1;33m2. ASEGURANDO REQUIREMENTS:\033[0m"

# Requirements para servicio-sela
sela_requirements="$SCRIPT_DIR/servicio-sela/requirements.txt"
if [ ! -f "$sela_requirements" ] || [ ! -s "$sela_requirements" ]; then
    echo -e "   \033[0;37mCreando requirements.txt para servicio-sela...\033[0m"
    cat > "$sela_requirements" << EOF
fastapi==0.104.1
uvicorn[standard]==0.24.0
httpx==0.25.1
pydantic==2.5.0
EOF
    echo -e "   \033[1;32m[OK]\033[0m requirements.txt creado para servicio-sela"
fi

# 3. DETENER Y LIMPIAR
echo -e "\n\033[1;33m3. LIMPIANDO SISTEMA PREVIO:\033[0m"
docker-compose down 2>/dev/null
docker-compose down -v 2>/dev/null
docker system prune -f 2>/dev/null
echo -e "   \033[1;32m[OK]\033[0m Sistema limpiado"

# 4. CONSTRUIR CON LOGS DETALLADOS
echo -e "\n\033[1;33m4. CONSTRUYENDO IMAGENES:\033[0m"
echo -e "   Esto puede tomar varios minutos...\033[0m"

# Construir cada servicio por separado para ver errores
echo -e "\n   Construyendo servicio-sela..."
docker-compose build servicio-sela

echo -e "\n   Construyendo servicio-anonimizacion..."
docker-compose build servicio-anonimizacion

echo -e "\n   Construyendo servicio-auditoria..."
docker-compose build servicio-auditoria

echo -e "\n   \033[1;32m[OK]\033[0m Todas las imagenes construidas"

# 5. INICIAR SISTEMA
echo -e "\n\033[1;33m5. INICIANDO SISTEMA:\033[0m"
docker-compose up -d

echo -e "   Esperando inicializacion (60 segundos)...\033[0m"
sleep 60

# 6. VERIFICAR ESTADO
echo -e "\n\033[1;33m6. ESTADO DE CONTENEDORES:\033[0m"
docker-compose ps

# 7. VERIFICAR LOGS DE ERRORES
echo -e "\n\033[1;33m7. VERIFICANDO LOGS DE ERROR:\033[0m"
logs=$(docker-compose logs --tail=20 2>/dev/null)

if echo "$logs" | grep -q "ModuleNotFoundError\|ImportError\|No module named"; then
    echo -e "   \033[1;31m[ERROR]\033[0m Hay problemas de dependencias en los logs"
    echo -e "   Mostrando logs relevantes:\033[0m"
    echo "$logs" | grep -A 5 -B 5 "ModuleNotFoundError\|ImportError\|No module named\|Traceback"
else
    echo -e "   \033[1;32m[OK]\033[0m No se encontraron errores de dependencias en logs"
fi

# 8. PRUEBA DE CONECTIVIDAD
echo -e "\n\033[1;33m8. PRUEBA DE CONECTIVIDAD:\033[0m"

# Array de servicios a probar
services=(
    "SELA - Puerto 8000:8000:/api/v1/health"
    "Anonimizacion - Puerto 8001:8001:/health"
    "Auditoria - Puerto 8002:8002:/health"
)

for service in "${services[@]}"; do
    IFS=':' read -r name port path <<< "$service"
    url="http://localhost:$port$path"
    
    if curl -s --max-time 10 "$url" > /dev/null 2>&1; then
        echo -e "   \033[1;32m[OK]\033[0m $name"
    else
        echo -e "   \033[1;31m[ERROR]\033[0m $name"
        
        # Mostrar logs específicos del servicio que falla
        if [[ "$name" == *"SELA"* ]]; then
            echo -e "   Mostrando logs de sela-main:\033[0m"
            docker-compose logs servicio-sela --tail=10 2>/dev/null
        fi
    fi
done

# 9. RESOLVER PROBLEMAS COMUNES
echo -e "\n\033[1;33m9. SOLUCIONANDO PROBLEMAS COMUNES:\033[0m"

# Si SELA sigue fallando, intentar reinstalar dependencias
if ! curl -s --max-time 5 "http://localhost:8000/api/v1/health" > /dev/null 2>&1; then
    echo -e "   SELA sigue fallando. Intentando reinstalacion de dependencias...\033[0m"
    
    # Ejecutar pip install dentro del contenedor
    echo -e "   Instalando dependencias en contenedor sela-main...\033[0m"
    docker exec sela-main pip install fastapi uvicorn httpx pydantic 2>/dev/null
    
    echo -e "   Reiniciando servicio...\033[0m"
    docker-compose restart servicio-sela
    
    echo -e "   Esperando 30 segundos...\033[0m"
    sleep 30
    
    # Verificar nuevamente
    if curl -s --max-time 10 "http://localhost:8000/api/v1/health" > /dev/null 2>&1; then
        echo -e "   \033[1;32m[OK]\033[0m SELA ahora funciona correctamente"
    else
        echo -e "   \033[1;31m[ERROR]\033[0m SELA sigue sin funcionar"
        echo -e "   Verifica manualmente con: docker-compose logs servicio-sela\033[0m"
    fi
fi

# 10. RESUMEN FINAL
echo -e "\n\033[1;36m10. RESUMEN FINAL:\033[0m"

echo -e "\n\033[1;33mCOMANDOS UTILES PARA DIAGNOSTICO:\033[0m"
echo -e "   \033[0;37m- Ver todos los logs: docker-compose logs\033[0m"
echo -e "   \033[0;37m- Logs de SELA: docker-compose logs servicio-sela\033[0m"
echo -e "   \033[0;37m- Entrar al contenedor: docker exec -it sela-main bash\033[0m"
echo -e "   \033[0;37m- Ver pip list: docker exec sela-main pip list\033[0m"
echo -e "   \033[0;37m- Reconstruir solo SELA: docker-compose build servicio-sela\033[0m"

echo -e "\n\033[1;31mSI EL PROBLEMA PERSISTE:\033[0m"
echo -e "   \033[0;37m1. Verifica que servicio-sela/requirements.txt existe\033[0m"
echo -e "   \033[0;37m2. Verifica que el Dockerfile copia requirements.txt\033[0m"
echo -e "   \033[0;37m3. Revisa el archivo app.py linea 1\033[0m"
echo -e "   \033[0;37m4. Prueba: docker-compose build --no-cache servicio-sela\033[0m"

echo -e "\n\033[0;37mPresiona Enter para finalizar...\033[0m"
read -r
```

**Instrucciones para usar el script en LliureX 21:**

1. **Guardar el script:**
```bash
nano reconstruir-completo-corregido.sh
```
(Pega el contenido y guarda con Ctrl+X, luego Y, Enter)

2. **Dar permisos de ejecución:**
```bash
chmod +x reconstruir-completo-corregido.sh
```

3. **Ejecutar el script:**
```bash
./reconstruir-completo-corregido.sh
```

**Requisitos previos en LliureX 21:**
```bash
# Instalar Docker si no está presente
sudo apt update
sudo apt install docker.io docker-compose curl

# Añadir usuario al grupo docker (necesario reiniciar sesión)
sudo usermod -aG docker $USER
```

**Características adaptadas para Linux:**
- Convertido de PowerShell a Bash Shell
- Usa `curl` en lugar de `Invoke-RestMethod`
- Manejo de colores ANSI para terminal
- Compatible con `stat` para obtener tamaño de archivos
- Usa `sleep` en lugar de `Start-Sleep`
- Manejo de arrays en Bash
- Compatible con Ubuntu/LliureX 21

El script mantiene toda la funcionalidad original pero adaptada al entorno Linux.