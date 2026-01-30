# Usar imagen base de Python
FROM python:3.11-slim

# Instalar dependencias del sistema para PostgreSQL
RUN apt-get update && apt-get install -y \
    libpq-dev gcc \
    && rm -rf /var/lib/apt/lists/*

# Establecer directorio de trabajo
WORKDIR /app

# Copiar archivos de dependencias
COPY requirements.txt .

# Instalar dependencias
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código de la aplicación
COPY . .

# Variables de entorno
ENV FLASK_HOST=0.0.0.0
ENV FLASK_PORT=8002
ENV FLASK_DEBUG=False

# Exponer puerto
EXPOSE 8002

# Comando para ejecutar la aplicación
CMD ["python", "app.py"]
