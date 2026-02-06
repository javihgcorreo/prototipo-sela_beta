FROM python:3.11-slim

# Instalar dependencias del sistema para PostgreSQL y utilidades de limpieza 
RUN apt-get update && apt-get install -y \
    libpq-dev gcc postgresql-client dos2unix \
    && rm -rf /var/lib/apt/lists/*

# Establecer directorio de trabajo 
WORKDIR /app

# Copiar archivos de dependencias 
COPY requirements.txt .

# Instalar dependencias (FastAPI, Uvicorn, etc.) [cite: 2]
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código de la aplicación [cite: 2]
COPY . .

# CORRECCIÓN: Limpiar caracteres de Windows (CRLF) y dar permisos al script 
RUN dos2unix wait-for-postgres.sh && chmod +x wait-for-postgres.sh

# Variables de entorno actualizadas para FastAPI
ENV APP_MODULE=app:app
ENV HOST=0.0.0.0
ENV PORT=8002

# Exponer puerto 
EXPOSE 8002

# Comando para ejecutar la aplicación con espera 
# El script wait-for-postgres.sh debe terminar ejecutando uvicorn
CMD ["./wait-for-postgres.sh"]
