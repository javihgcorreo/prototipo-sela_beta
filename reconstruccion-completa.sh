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