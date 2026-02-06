#!/bin/bash
set -e

host="postgres"
user="auditoria_user"
password="auditoria_pass"
dbname="auditoria_db"

echo "Esperando a PostgreSQL en $host:5432..."
export PGPASSWORD="$password"

for i in {1..30}; do
  if psql -h "$host" -U "$user" -d "$dbname" -c '\q' >/dev/null 2>&1; then
    echo "✅ PostgreSQL disponible después de $i intentos"
    break
  fi
  
  echo "⏳ Intento $i/30: PostgreSQL no disponible..."
  sleep 2
  
  if [ $i -eq 30 ]; then
    echo "❌ ERROR: No se pudo conectar a PostgreSQL después de 30 intentos"
    exit 1
  fi
done

echo "🚀 Iniciando aplicación..."
exec python app.py