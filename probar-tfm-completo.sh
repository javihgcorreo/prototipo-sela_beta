#!/bin/bash
# probar-tfm-completo.sh
# Script para probar todas las funcionalidades del sistema SeLA (TFM)

echo -e "\033[1;36m======================================================\033[0m"
echo -e "\033[1;36m   PRUEBAS COMPLETAS SISTEMA SeLA - TFM\033[0m"
echo -e "\033[1;36m======================================================\033[0m"

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Variables
TEST_RESULTS=()
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Funciones auxiliares
function write_header {
    echo -e "\n${CYAN}=== $1 ===${NC}"
}

function write_test {
    echo -e "\n${BLUE}Prueba $1: $2${NC}"
    ((TOTAL_TESTS++))
}

function pass_test {
    echo -e "   ${GREEN}✓ PASÓ: $1${NC}"
    TEST_RESULTS+=("PASS: $1")
    ((PASSED_TESTS++))
}

function fail_test {
    echo -e "   ${RED}✗ FALLÓ: $1${NC}"
    echo -e "   ${GRAY}Error: $2${NC}"
    TEST_RESULTS+=("FAIL: $1 - $2")
    ((FAILED_TESTS++))
}

function test_endpoint {
    local name=$1
    local method=$2
    local url=$3
    local data=$4
    local expected_code=${5:-200}
    
    local response_code=0
    local response_body=""
    
    if [[ "$method" == "GET" ]]; then
        response_code=$(curl -s -o /tmp/response.json -w "%{http_code}" "$url" --max-time 10)
        response_body=$(cat /tmp/response.json 2>/dev/null)
    elif [[ "$method" == "POST" ]]; then
        response_code=$(curl -s -o /tmp/response.json -w "%{http_code}" -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "$data" \
            --max-time 10)
        response_body=$(cat /tmp/response.json 2>/dev/null)
    elif [[ "$method" == "PUT" ]]; then
        response_code=$(curl -s -o /tmp/response.json -w "%{http_code}" -X PUT "$url" \
            -H "Content-Type: application/json" \
            -d "$data" \
            --max-time 10)
        response_body=$(cat /tmp/response.json 2>/dev/null)
    fi
    
    if [[ "$response_code" == "$expected_code" ]]; then
        pass_test "$name"
        return 0
    else
        fail_test "$name" "Código $response_code (esperado $expected_code)"
        return 1
    fi
}

function check_service_running {
    local name=$1
    local port=$2
    
    if curl -s -f "http://localhost:$port/health" > /dev/null 2>&1; then
        pass_test "Servicio $name corriendo"
        return 0
    else
        fail_test "Servicio $name corriendo" "No responde en puerto $port"
        return 1
    fi
}

function validate_json_structure {
    local json_file=$1
    local field=$2
    
    if command -v jq &> /dev/null; then
        if jq -e ".$field" "$json_file" > /dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        # Alternativa básica sin jq
        if grep -q "\"$field\"" "$json_file"; then
            return 0
        else
            return 1
        fi
    fi
}

# 1. INICIO - Verificar sistema
write_header "1. VERIFICACIÓN DEL SISTEMA"

write_test "1.1" "Verificar Docker y servicios"
if command -v docker &> /dev/null && docker ps &> /dev/null; then
    pass_test "Docker funcionando"
else
    fail_test "Docker funcionando" "Docker no está corriendo"
fi

# 2. PRUEBAS DE INFRAESTRUCTURA
write_header "2. PRUEBAS DE INFRAESTRUCTURA"

write_test "2.1" "Servicio SELA (API Principal)"
check_service_running "SELA" 8000

write_test "2.2" "Servicio de Anonimización"
check_service_running "Anonimización" 8001

write_test "2.3" "Servicio de Auditoría"
check_service_running "Auditoría" 8002

write_test "2.4" "Service Discovery"
test_endpoint "Endpoint de infraestructura" "GET" "http://localhost:8000/api/v1/infraestructura"

# 3. PRUEBAS DE ACUERDOS (NÚCLEO DEL SISTEMA)
write_header "3. PRUEBAS DE ACUERDOS SeLA"

write_test "3.1" "Crear acuerdo básico"
ACUERDO_JSON='{
    "nombre": "Prueba TFM - Acuerdo de Investigación",
    "partes": {
        "proveedor": "Hospital General Universitario",
        "consumidor": "Instituto de Investigación Biomédica"
    },
    "tipo_datos": "datos_salud_fhir",
    "finalidad": "investigacion_cientifica",
    "base_legal": "consentimiento",
    "nivel_anonimizacion": "alto",
    "duracion_horas": 720,
    "volumen_maximo": 5000
}'

if test_endpoint "Creación de acuerdo" "POST" "http://localhost:8000/api/v1/acuerdo/crear" "$ACUERDO_JSON"; then
    # Extraer ID del acuerdo para pruebas posteriores
    if command -v jq &> /dev/null; then
        ACUERDO_ID=$(jq -r '.acuerdo.id' /tmp/response.json 2>/dev/null)
        echo -e "   ${GRAY}ID Acuerdo: $ACUERDO_ID${NC}"
    else
        ACUERDO_ID=$(grep -o '"id":"[^"]*"' /tmp/response.json | head -1 | cut -d'"' -f4)
        echo -e "   ${GRAY}ID Acuerdo: $ACUERDO_ID${NC}"
    fi
fi

write_test "3.2" "Listar acuerdos"
test_endpoint "Listado de acuerdos" "GET" "http://localhost:8000/api/v1/acuerdos"

write_test "3.3" "Consultar acuerdo específico"
if [[ -n "$ACUERDO_ID" && "$ACUERDO_ID" != "null" ]]; then
    test_endpoint "Consulta de acuerdo" "GET" "http://localhost:8000/api/v1/acuerdo/$ACUERDO_ID"
else
    fail_test "Consulta de acuerdo" "No hay ID de acuerdo disponible"
fi

write_test "3.4" "Verificar estado de acuerdo"
if [[ -n "$ACUERDO_ID" && "$ACUERDO_ID" != "null" ]]; then
    test_endpoint "Estado de acuerdo" "GET" "http://localhost:8000/api/v1/acuerdo/$ACUERDO_ID/estado"
fi

# 4. PRUEBAS DE VALIDACIÓN RGPD
write_header "4. PRUEBAS DE VALIDACIÓN RGPD"

write_test "4.1" "Validación de propósito específico"
VALIDACION_JSON='{
    "acuerdo_id": "'$ACUERDO_ID'",
    "datos_solicitados": ["historial_clinico", "analiticas"],
    "proposito": "estudio_epidemiologico",
    "consentimiento_explicito": true
}'

test_endpoint "Validación RGPD" "POST" "http://localhost:8000/api/v1/rgpd/validar" "$VALIDACION_JSON"

write_test "4.2" "Minimización de datos"
MINIMIZACION_JSON='{
    "datos_originales": ["nombre", "dni", "diagnostico", "tratamiento"],
    "finalidad": "investigacion_estadistica",
    "nivel_anonimizacion": "alto"
}'

test_endpoint "Minimización de datos" "POST" "http://localhost:8000/api/v1/rgpd/minimizacion" "$MINIMIZACION_JSON"

# 5. PRUEBAS DE ANONIMIZACIÓN
write_header "5. PRUEBAS DE ANONIMIZACIÓN"

write_test "5.1" "Anonimización de datos básica"
ANONIMIZACION_JSON='{
    "datos": [
        {
            "id": "P001",
            "nombre": "Juan Pérez",
            "edad": 45,
            "diagnostico": "Hipertensión esencial",
            "tratamiento": "Lisinopril 10mg"
        },
        {
            "id": "P002", 
            "nombre": "María García",
            "edad": 62,
            "diagnostico": "Diabetes tipo 2",
            "tratamiento": "Metformina 850mg"
        }
    ],
    "nivel": "alto",
    "campos_sensibles": ["nombre", "id"]
}'

test_endpoint "Servicio de anonimización" "POST" "http://localhost:8001/anonimizar" "$ANONIMIZACION_JSON"

write_test "5.2" "Verificación de k-anonimity"
K_ANON_JSON='{
    "datos_anonimizados": [
        {"edad_grupo": "40-49", "diagnostico": "Hipertensión", "ciudad": "Madrid"},
        {"edad_grupo": "40-49", "diagnostico": "Hipertensión", "ciudad": "Madrid"},
        {"edad_grupo": "60-69", "diagnostico": "Diabetes", "ciudad": "Barcelona"}
    ],
    "k": 2
}'

test_endpoint "K-anonimity" "POST" "http://localhost:8001/verificar/k-anonimity" "$K_ANON_JSON"

# 6. PRUEBAS DE AUDITORÍA Y TRAZABILIDAD
write_header "6. PRUEBAS DE AUDITORÍA Y TRAZABILIDAD"

write_test "6.1" "Registro de operación"
AUDITORIA_JSON='{
    "operacion": "consulta_datos_investigacion",
    "servicio_origen": "servicio_sela",
    "usuario": "investigador_tfm",
    "acuerdo_id": "'$ACUERDO_ID'",
    "resultado": "exito",
    "datos_procesados": 2,
    "metadatos": {
        "timestamp": "'$(date -Iseconds)'",
        "ip_origen": "192.168.1.100",
        "user_agent": "script_pruebas_tfm"
    }
}'

test_endpoint "Registro auditoría" "POST" "http://localhost:8002/registrar" "$AUDITORIA_JSON"

write_test "6.2" "Consulta de logs de auditoría"
test_endpoint "Consulta logs" "GET" "http://localhost:8002/logs?limite=5"

write_test "6.3" "Búsqueda por acuerdo"
if [[ -n "$ACUERDO_ID" && "$ACUERDO_ID" != "null" ]]; then
    test_endpoint "Auditoría por acuerdo" "GET" "http://localhost:8002/logs/acuerdo/$ACUERDO_ID"
fi

write_test "6.4" "Generación de reporte"
REPORTE_JSON='{
    "tipo_reporte": "cumplimiento_rgpd",
    "periodo": {
        "inicio": "'$(date -d "7 days ago" -Iseconds)'",
        "fin": "'$(date -Iseconds)'"
    },
    "parametros": {
        "incluir_detalles": true,
        "formato": "json"
    }
}'

test_endpoint "Generación de reporte" "POST" "http://localhost:8002/reporte/generar" "$REPORTE_JSON"

# 7. PRUEBAS DE EJECUCIÓN DE OPERACIONES
write_header "7. PRUEBAS DE OPERACIONES"

write_test "7.1" "Ejecutar operación bajo acuerdo"
if [[ -n "$ACUERDO_ID" && "$ACUERDO_ID" != "null" ]]; then
    OPERACION_JSON='{
        "operacion": "procesar_datos_investigacion",
        "datos": {
            "tipo": "historiales_clinicos",
            "cantidad": 50,
            "campos": ["diagnostico", "edad", "tratamiento"]
        },
        "parametros": {
            "prioridad": "normal",
            "destino": "servicio_anonimizacion"
        }
    }'
    
    test_endpoint "Ejecución de operación" "POST" "http://localhost:8000/api/v1/acuerdo/$ACUERDO_ID/ejecutar" "$OPERACION_JSON"
fi

write_test "7.2" "Monitoreo de operaciones"
test_endpoint "Estado de operaciones" "GET" "http://localhost:8000/api/v1/operaciones/estado"

# 8. PRUEBAS DE RESILIENCIA Y ERRORES
write_header "8. PRUEBAS DE RESILIENCIA"

write_test "8.1" "Prueba de salud completa"
test_endpoint "Health check completo" "GET" "http://localhost:8000/api/v1/health/detallado"

write_test "8.2" "Recuperación de servicio"
# Simular caída y recuperación
if command -v docker &> /dev/null; then
    echo -e "   ${GRAY}Simulando recuperación de servicio...${NC}"
    docker restart servicio-sela 2>/dev/null
    sleep 5
    if curl -s -f "http://localhost:8000/api/v1/health" > /dev/null 2>&1; then
        pass_test "Recuperación de servicio"
    else
        fail_test "Recuperación de servicio" "No se recuperó automáticamente"
    fi
else
    echo -e "   ${YELLOW}⚠ Docker no disponible para prueba de recuperación${NC}"
fi

write_test "8.3" "Manejo de errores - Acuerdo inválido"
ERROR_JSON='{
    "nombre": "",
    "partes": {},
    "tipo_datos": "invalido"
}'

test_endpoint "Error en acuerdo inválido" "POST" "http://localhost:8000/api/v1/acuerdo/crear" "$ERROR_JSON" "400"

# 9. PRUEBAS DE DEMOSTRACIÓN PARA TRIBUNAL
write_header "9. PRUEBAS DE DEMOSTRACIÓN (TRIBUNAL)"

write_test "9.1" "Endpoint de demostración"
test_endpoint "Demo para tribunal" "GET" "http://localhost:8000/api/v1/demo/tribunal"

write_test "9.2" "Estadísticas del sistema"
test_endpoint "Estadísticas" "GET" "http://localhost:8000/api/v1/estadisticas"

write_test "9.3" "Documentación API"
test_endpoint "Documentación" "GET" "http://localhost:8000/api/v1/docs"

# 10. RESUMEN Y REPORTE
write_header "10. RESUMEN FINAL DE PRUEBAS"

echo -e "\n${MAGENTA}════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}                 RESULTADOS DE LAS PRUEBAS                  ${NC}"
echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"

echo -e "\n${CYAN}Total de pruebas ejecutadas: $TOTAL_TESTS${NC}"
echo -e "${GREEN}Pruebas exitosas: $PASSED_TESTS${NC}"
if [[ $FAILED_TESTS -gt 0 ]]; then
    echo -e "${RED}Pruebas fallidas: $FAILED_TESTS${NC}"
else
    echo -e "${GREEN}Pruebas fallidas: $FAILED_TESTS${NC}"
fi

PORCENTAJE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
echo -e "\n${CYAN}Porcentaje de éxito: $PORCENTAJE%${NC}"

if [[ $PORCENTAJE -ge 90 ]]; then
    echo -e "${GREEN}✅ SISTEMA ESTABLE - LISTO PARA DEFENSA${NC}"
elif [[ $PORCENTAJE -ge 70 ]]; then
    echo -e "${YELLOW}⚠ SISTEMA FUNCIONAL - REVISAR FALLOS${NC}"
else
    echo -e "${RED}❌ SISTEMA INESTABLE - REQUIERE REPARACIONES${NC}"
fi

# Mostrar resultados detallados
if [[ $FAILED_TESTS -gt 0 ]]; then
    echo -e "\n${YELLOW}Pruebas fallidas detalladas:${NC}"
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == FAIL* ]]; then
            echo -e "  ${RED}$result${NC}"
        fi
    done
fi

# Generar reporte en archivo
REPORT_FILE="reporte_pruebas_tfm_$(date +%Y%m%d_%H%M%S).txt"
echo -e "\n${CYAN}Generando reporte en: $REPORT_FILE${NC}"

{
    echo "======================================================"
    echo "   REPORTE DE PRUEBAS - SISTEMA SeLA TFM"
    echo "   Fecha: $(date)"
    echo "======================================================"
    echo ""
    echo "RESUMEN:"
    echo "  Total pruebas: $TOTAL_TESTS"
    echo "  Pruebas exitosas: $PASSED_TESTS"
    echo "  Pruebas fallidas: $FAILED_TESTS"
    echo "  Porcentaje éxito: $PORCENTAJE%"
    echo ""
    echo "DETALLE DE PRUEBAS:"
    for result in "${TEST_RESULTS[@]}"; do
        echo "  $result"
    done
    echo ""
    echo "ENDPOINTS VERIFICADOS:"
    echo "  - SELA API: http://localhost:8000"
    echo "  - Anonimización: http://localhost:8001"
    echo "  - Auditoría: http://localhost:8002"
    echo ""
    echo "RECOMENDACIONES:"
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo "  ✅ Todos los componentes funcionan correctamente"
        echo "  ✅ El sistema está listo para la defensa del TFM"
    else
        echo "  ⚠ Revisar los componentes que fallaron"
        echo "  ⚠ Verificar logs de error"
        echo "  ⚠ Realizar pruebas manuales adicionales"
    fi
} > "$REPORT_FILE"

echo -e "\n${GREEN}📋 REPORTE GUARDADO EN: $REPORT_FILE${NC}"

# Información para el tribunal
echo -e "\n${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}               PARA LA DEFENSA DEL TFM                       ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}Puntos a destacar en tu defensa:${NC}"
echo -e "1. ${GRAY}Sistema multi-servicio con Docker Compose${NC}"
echo -e "2. ${GRAY}Validación automática RGPD en acuerdos${NC}"
echo -e "3. ${GRAY}Anonimización con diferentes niveles de protección${NC}"
echo -e "4. ${GRAY}Auditoría completa y trazabilidad${NC}"
echo -e "5. ${GRAY}Resiliencia y manejo de errores${NC}"
echo -e "6. ${GRAY}Documentación API automática${NC}"

echo -e "\n${YELLOW}Enlaces para mostrar en la presentación:${NC}"
echo -e "  ${GRAY}• Demo Tribunal: http://localhost:8000/api/v1/demo/tribunal${NC}"
echo -e "  ${GRAY}• Documentación: http://localhost:8000/api/v1/docs${NC}"
echo -e "  ${GRAY}• Estadísticas: http://localhost:8000/api/v1/estadisticas${NC}"

echo -e "\n${GREEN}✅ Script de pruebas completado${NC}"
echo -e "${GRAY}Presiona Enter para finalizar...${NC}"
read -r