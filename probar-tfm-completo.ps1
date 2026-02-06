# probar-tfm-completo-windows.ps1
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   PRUEBAS COMPLETAS SISTEMA SeLA - TFM (Windows)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# Variables globales
$global:TestResults = @()
$global:TotalTests = 0
$global:PassedTests = 0
$global:FailedTests = 0
$global:AcuerdoId = $null
$global:StartTime = Get-Date

# Funciones auxiliares
function Write-Header {
    param($Title)
    Write-Host "`n=== $Title ===" -ForegroundColor Cyan
}

function Write-Test {
    param($Number, $Description)
    Write-Host "`nPrueba $($Number): $Description" -ForegroundColor Blue
    $global:TotalTests++
}

function Pass-Test {
    param($Message)
    Write-Host "   [OK] $Message" -ForegroundColor Green
    $global:TestResults += "PASS: $Message"
    $global:PassedTests++
}

function Fail-Test {
    param($Message, $ErrorDetail)
    Write-Host "   [ERROR] $Message" -ForegroundColor Red
    if ($ErrorDetail) {
        Write-Host "   Detalle: $ErrorDetail" -ForegroundColor Gray
    }
    $global:TestResults += "FAIL: $Message - $ErrorDetail"
    $global:FailedTests++
}

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Url,
        [string]$Body = $null,
        [int]$ExpectedCode = 200
    )
    
    try {
        if ($Method -eq "GET") {
            $response = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 10
        }
        elseif ($Method -eq "POST") {
            $response = Invoke-RestMethod -Uri $Url -Method Post -Body $Body -ContentType "application/json" -TimeoutSec 10
        }
        elseif ($Method -eq "PUT") {
            $response = Invoke-RestMethod -Uri $Url -Method Put -Body $Body -ContentType "application/json" -TimeoutSec 10
        }
        
        Pass-Test $Name
        return $response
        
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq $ExpectedCode -and $ExpectedCode -ne 200) {
            Pass-Test "$Name (error esperado)"
            return $null
        } else {
            Fail-Test $Name "Codigo $statusCode (esperado $ExpectedCode)"
            return $null
        }
    }
}

function Test-ServiceRunning {
    param($ServiceName, $Port)
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$Port/health" -Method Get -TimeoutSec 5
        Pass-Test "Servicio $ServiceName corriendo"
        return $true
    } catch {
        Fail-Test "Servicio $ServiceName corriendo" "No responde en puerto $Port"
        return $false
    }
}

function Show-Progress {
    param($Current, $Total, $Message)
    
    $percent = [math]::Round(($Current / $Total) * 100)
    Write-Host "   [$Current/$Total] $Message ($percent`%)" -ForegroundColor Gray
}

# 1. INICIO - Verificar sistema
Write-Header "1. VERIFICACION DEL SISTEMA"

Write-Test "1.1" "Verificar Docker y servicios"
try {
    docker ps | Out-Null
    Pass-Test "Docker funcionando"
} catch {
    Fail-Test "Docker funcionando" "Docker no esta corriendo o no esta instalado"
}

# 2. PRUEBAS DE INFRAESTRUCTURA
Write-Header "2. PRUEBAS DE INFRAESTRUCTURA"
Show-Progress 1 25 "Iniciando pruebas de infraestructura"

Write-Test "2.1" "Servicio SELA (API Principal)"
$selaRunning = Test-ServiceRunning "SELA" 8000

Write-Test "2.2" "Servicio de Anonimizacion"
$anonimizacionRunning = Test-ServiceRunning "Anonimizacion" 8001

Write-Test "2.3" "Servicio de Auditoria"
$auditoriaRunning = Test-ServiceRunning "Auditoria" 8002

Write-Test "2.4" "Service Discovery"
Test-Endpoint -Name "Endpoint de infraestructura" -Method "GET" -Url "http://localhost:8000/api/v1/infraestructura"

# 3. PRUEBAS DE ACUERDOS (NUCLEO DEL SISTEMA)
Write-Header "3. PRUEBAS DE ACUERDOS SeLA"
Show-Progress 5 25 "Probando gestion de acuerdos"

Write-Test "3.1" "Crear acuerdo basico"
$acuerdoJson = '{
    "nombre": "Prueba TFM - Acuerdo de Investigacion",
    "partes": {
        "proveedor": "Hospital General Universitario",
        "consumidor": "Instituto de Investigacion Biomedica"
    },
    "tipo_datos": "datos_salud_fhir",
    "finalidad": "investigacion_cientifica",
    "base_legal": "consentimiento",
    "nivel_anonimizacion": "alto",
    "duracion_horas": 720,
    "volumen_maximo": 5000
}'

$acuerdoResponse = Test-Endpoint -Name "Creacion de acuerdo" -Method "POST" -Url "http://localhost:8000/api/v1/acuerdo/crear" -Body $acuerdoJson
if ($acuerdoResponse) {
    $global:AcuerdoId = $acuerdoResponse.acuerdo.id
    Write-Host "   ID Acuerdo: $($global:AcuerdoId)" -ForegroundColor Gray
}

Write-Test "3.2" "Listar acuerdos"
Test-Endpoint -Name "Listado de acuerdos" -Method "GET" -Url "http://localhost:8000/api/v1/acuerdos"

Write-Test "3.3" "Consultar acuerdo especifico"
if ($global:AcuerdoId) {
    Test-Endpoint -Name "Consulta de acuerdo" -Method "GET" -Url "http://localhost:8000/api/v1/acuerdo/$global:AcuerdoId"
} else {
    Fail-Test "Consulta de acuerdo" "No hay ID de acuerdo disponible"
}

Write-Test "3.4" "Verificar estado de acuerdo"
if ($global:AcuerdoId) {
    Test-Endpoint -Name "Estado de acuerdo" -Method "GET" -Url "http://localhost:8000/api/v1/acuerdo/$global:AcuerdoId/estado"
}

# 4. PRUEBAS DE VALIDACION RGPD
Write-Header "4. PRUEBAS DE VALIDACION RGPD"
Show-Progress 10 25 "Probando cumplimiento RGPD"

Write-Test "4.1" "Validacion de proposito especifico"
if ($global:AcuerdoId) {
    $validacionJson = '{
        "acuerdo_id": "' + $global:AcuerdoId + '",
        "datos_solicitados": ["historial_clinico", "analiticas"],
        "proposito": "estudio_epidemiologico",
        "consentimiento_explicito": true
    }'
    
    Test-Endpoint -Name "Validacion RGPD" -Method "POST" -Url "http://localhost:8000/api/v1/rgpd/validar" -Body $validacionJson
} else {
    Fail-Test "Validacion RGPD" "No hay acuerdo para validar"
}

Write-Test "4.2" "Minimizacion de datos"
$minimizacionJson = '{
    "datos_originales": ["nombre", "dni", "diagnostico", "tratamiento"],
    "finalidad": "investigacion_estadistica",
    "nivel_anonimizacion": "alto"
}'

Test-Endpoint -Name "Minimizacion de datos" -Method "POST" -Url "http://localhost:8000/api/v1/rgpd/minimizacion" -Body $minimizacionJson

# 5. PRUEBAS DE ANONIMIZACION
Write-Header "5. PRUEBAS DE ANONIMIZACION"
Show-Progress 12 25 "Probando anonimizacion"

Write-Test "5.1" "Anonimizacion de datos basica"
$anonimizacionJson = '{
    "datos": [
        {
            "id": "P001",
            "nombre": "Juan Perez",
            "edad": 45,
            "diagnostico": "Hipertension esencial",
            "tratamiento": "Lisinopril 10mg"
        },
        {
            "id": "P002", 
            "nombre": "Maria Garcia",
            "edad": 62,
            "diagnostico": "Diabetes tipo 2",
            "tratamiento": "Metformina 850mg"
        }
    ],
    "nivel": "alto",
    "campos_sensibles": ["nombre", "id"]
}'

Test-Endpoint -Name "Servicio de anonimizacion" -Method "POST" -Url "http://localhost:8001/anonimizar" -Body $anonimizacionJson

Write-Test "5.2" "Verificacion de k-anonimity"
$kAnonJson = '{
    "datos_anonimizados": [
        {"edad_grupo": "40-49", "diagnostico": "Hipertension", "ciudad": "Madrid"},
        {"edad_grupo": "40-49", "diagnostico": "Hipertension", "ciudad": "Madrid"},
        {"edad_grupo": "60-69", "diagnostico": "Diabetes", "ciudad": "Barcelona"}
    ],
    "k": 2
}'

Test-Endpoint -Name "K-anonimity" -Method "POST" -Url "http://localhost:8001/verificar/k-anonimity" -Body $kAnonJson

# 6. PRUEBAS DE AUDITORIA Y TRAZABILIDAD
Write-Header "6. PRUEBAS DE AUDITORIA Y TRAZABILIDAD"
Show-Progress 15 25 "Probando auditoria"

Write-Test "6.1" "Registro de operacion"
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
if ($global:AcuerdoId) {
    $auditoriaJson = '{
        "operacion": "consulta_datos_investigacion",
        "servicio_origen": "servicio_sela",
        "usuario": "investigador_tfm",
        "acuerdo_id": "' + $global:AcuerdoId + '",
        "resultado": "exito",
        "datos_procesados": 2,
        "metadatos": {
            "timestamp": "' + $timestamp + '",
            "ip_origen": "192.168.1.100",
            "user_agent": "script_pruebas_tfm_windows"
        }
    }'
    
    Test-Endpoint -Name "Registro auditoria" -Method "POST" -Url "http://localhost:8002/registrar" -Body $auditoriaJson
} else {
    Fail-Test "Registro auditoria" "No hay acuerdo para auditoria"
}

Write-Test "6.2" "Consulta de logs de auditoria"
Test-Endpoint -Name "Consulta logs" -Method "GET" -Url "http://localhost:8002/logs?limite=5"

Write-Test "6.3" "Busqueda por acuerdo"
if ($global:AcuerdoId) {
    Test-Endpoint -Name "Auditoria por acuerdo" -Method "GET" -Url "http://localhost:8002/logs/acuerdo/$global:AcuerdoId"
}

Write-Test "6.4" "Generacion de reporte"
$timestampInicio = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ss")
$timestampFin = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"

$reporteJson = '{
    "tipo_reporte": "cumplimiento_rgpd",
    "periodo": {
        "inicio": "' + $timestampInicio + '",
        "fin": "' + $timestampFin + '"
    },
    "parametros": {
        "incluir_detalles": true,
        "formato": "json"
    }
}'

Test-Endpoint -Name "Generacion de reporte" -Method "POST" -Url "http://localhost:8002/reporte/generar" -Body $reporteJson

# 7. PRUEBAS DE EJECUCION DE OPERACIONES
Write-Header "7. PRUEBAS DE OPERACIONES"
Show-Progress 20 25 "Probando ejecucion de operaciones"

Write-Test "7.1" "Ejecutar operacion bajo acuerdo"
if ($global:AcuerdoId) {
    $operacionJson = '{
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
    
    Test-Endpoint -Name "Ejecucion de operacion" -Method "POST" -Url "http://localhost:8000/api/v1/acuerdo/$global:AcuerdoId/ejecutar" -Body $operacionJson
}

Write-Test "7.2" "Monitoreo de operaciones"
Test-Endpoint -Name "Estado de operaciones" -Method "GET" -Url "http://localhost:8000/api/v1/operaciones/estado"

# 8. PRUEBAS DE RESILIENCIA Y ERRORES
Write-Header "8. PRUEBAS DE RESILIENCIA"
Show-Progress 22 25 "Probando resiliencia"

Write-Test "8.1" "Prueba de salud completa"
Test-Endpoint -Name "Health check completo" -Method "GET" -Url "http://localhost:8000/api/v1/health/detallado"

Write-Test "8.2" "Manejo de errores - Acuerdo invalido"
$errorJson = '{
    "nombre": "",
    "partes": {},
    "tipo_datos": "invalido"
}'

Test-Endpoint -Name "Error en acuerdo invalido" -Method "POST" -Url "http://localhost:8000/api/v1/acuerdo/crear" -Body $errorJson -ExpectedCode 422

# 9. PRUEBAS DE DEMOSTRACION PARA TRIBUNAL
Write-Header "9. PRUEBAS DE DEMOSTRACION (TRIBUNAL)"
Show-Progress 24 25 "Preparando demostracion para tribunal"

Write-Test "9.1" "Endpoint de demostracion"
Test-Endpoint -Name "Demo para tribunal" -Method "GET" -Url "http://localhost:8000/api/v1/demo/tribunal"

Write-Test "9.2" "Estadisticas del sistema"
Test-Endpoint -Name "Estadisticas" -Method "GET" -Url "http://localhost:8000/api/v1/estadisticas"

Write-Test "9.3" "Documentacion API"
Test-Endpoint -Name "Documentacion" -Method "GET" -Url "http://localhost:8000/api/v1/docs"

# 10. RESUMEN Y REPORTE
Write-Header "10. RESUMEN FINAL DE PRUEBAS"

Write-Host "`n======================================================" -ForegroundColor Magenta
Write-Host "                 RESULTADOS DE LAS PRUEBAS                  " -ForegroundColor Magenta
Write-Host "======================================================" -ForegroundColor Magenta

$porcentaje = if ($global:TotalTests -gt 0) { [math]::Round(($global:PassedTests / $global:TotalTests) * 100) } else { 0 }
$tiempoEjecucion = (Get-Date) - $global:StartTime

Write-Host "`nESTADISTICAS:" -ForegroundColor Cyan
Write-Host "   Total de pruebas ejecutadas: $($global:TotalTests)" -ForegroundColor White
Write-Host "   Pruebas exitosas: $($global:PassedTests)" -ForegroundColor Green
if ($global:FailedTests -gt 0) {
    Write-Host "   Pruebas fallidas: $($global:FailedTests)" -ForegroundColor Red
} else {
    Write-Host "   Pruebas fallidas: $($global:FailedTests)" -ForegroundColor Green
}
Write-Host "   Porcentaje de exito: $porcentaje%" -ForegroundColor Cyan
Write-Host "   Tiempo de ejecucion: $($tiempoEjecucion.TotalSeconds.ToString('0.00')) segundos" -ForegroundColor Gray

Write-Host "`nEVALUACION:" -ForegroundColor Cyan
if ($porcentaje -ge 90) {
    Write-Host "   [OK] SISTEMA ESTABLE - LISTO PARA DEFENSA" -ForegroundColor Green
} elseif ($porcentaje -ge 70) {
    Write-Host "   [ADVERTENCIA] SISTEMA FUNCIONAL - REVISAR FALLOS" -ForegroundColor Yellow
} else {
    Write-Host "   [ERROR] SISTEMA INESTABLE - REQUIERE REPARACIONES" -ForegroundColor Red
}

# Mostrar pruebas fallidas
if ($global:FailedTests -gt 0) {
    Write-Host "`nPRUEBAS FALLIDAS DETALLADAS:" -ForegroundColor Yellow
    foreach ($result in $global:TestResults) {
        if ($result -like "FAIL:*") {
            Write-Host "   $result" -ForegroundColor Red
        }
    }
}

# Generar reporte en archivo
$reportFileName = "reporte_pruebas_tfm_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$reportPath = Join-Path (Get-Location) $reportFileName

Write-Host "`nGENERANDO REPORTE EN: $reportPath" -ForegroundColor Cyan

$reportContent = @"
======================================================
   REPORTE DE PRUEBAS - SISTEMA SeLA TFM (Windows)
   Fecha: $(Get-Date)
   Tiempo ejecucion: $($tiempoEjecucion.TotalSeconds.ToString('0.00')) segundos
======================================================

RESUMEN:
  Total pruebas: $($global:TotalTests)
  Pruebas exitosas: $($global:PassedTests)
  Pruebas fallidas: $($global:FailedTests)
  Porcentaje exito: $porcentaje%

DETALLE DE PRUEBAS:
$(($global:TestResults | ForEach-Object { "  $_" }) -join "`r`n")

ENDPOINTS VERIFICADOS:
  - SELA API: http://localhost:8000
  - Anonimizacion: http://localhost:8001
  - Auditoria: http://localhost:8002

COMPONENTES PROBADOS:
  1. Infraestructura (Service Discovery)
  2. Gestion de Acuerdos SeLA
  3. Validacion RGPD Automatica
  4. Servicio de Anonimizacion
  5. Sistema de Auditoria
  6. Ejecucion de Operaciones
  7. Resiliencia y Manejo de Errores
  8. Demostracion para Tribunal

RECOMENDACIONES:
$(if ($global:FailedTests -eq 0) {
    "  [OK] Todos los componentes funcionan correctamente"
    "  [OK] El sistema esta listo para la defensa del TFM"
} else {
    "  [ADVERTENCIA] Revisar los componentes que fallaron"
    "  [ADVERTENCIA] Verificar logs de error en Docker"
    "  [ADVERTENCIA] Realizar pruebas manuales adicionales"
})

PARA LA DEFENSA:
  1. Mostrar demo en: http://localhost:8000/api/v1/demo/tribunal
  2. Mostrar documentacion: http://localhost:8000/api/v1/docs
  3. Mostrar estadisticas: http://localhost:8000/api/v1/estadisticas
  4. Ejecutar prueba de anonimizacion en vivo
  5. Mostrar logs de auditoria en tiempo real
"@

Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8

Write-Host "`nINFORMACION PARA LA DEFENSA:" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

Write-Host "`nPuntos a destacar en tu defensa:" -ForegroundColor Yellow
Write-Host "   1. Sistema multi-servicio con Docker Compose" -ForegroundColor Gray
Write-Host "   2. Validacion automatica RGPD en acuerdos" -ForegroundColor Gray
Write-Host "   3. Anonimizacion con diferentes niveles de proteccion" -ForegroundColor Gray
Write-Host "   4. Auditoria completa y trazabilidad" -ForegroundColor Gray
Write-Host "   5. Resiliencia y manejo de errores" -ForegroundColor Gray
Write-Host "   6. Documentacion API automatica" -ForegroundColor Gray

Write-Host "`nEnlaces para mostrar en la presentacion:" -ForegroundColor Yellow
Write-Host "   - Demo Tribunal: http://localhost:8000/api/v1/demo/tribunal" -ForegroundColor White
Write-Host "   - Documentacion: http://localhost:8000/api/v1/docs" -ForegroundColor White
Write-Host "   - Estadisticas: http://localhost:8000/api/v1/estadisticas" -ForegroundColor White
Write-Host "   - Health Check: http://localhost:8000/api/v1/health" -ForegroundColor White

Write-Host "`nComandos para demostrar en vivo:" -ForegroundColor Yellow
Write-Host "   - Ver servicios: docker-compose ps" -ForegroundColor Gray
Write-Host "   - Ver logs: docker-compose logs --tail=10" -ForegroundColor Gray
Write-Host "   - Crear acuerdo: Invoke-RestMethod -Uri http://localhost:8000/api/v1/acuerdo/crear -Method Post -Body ..." -ForegroundColor Gray
Write-Host "   - Ver auditoria: Invoke-RestMethod -Uri http://localhost:8002/logs?limite=5 -Method Get" -ForegroundColor Gray

Write-Host "`n[OK] Script de pruebas completado" -ForegroundColor Green
Write-Host "Reporte guardado en: $reportPath" -ForegroundColor Cyan
Write-Host "`nPresiona Enter para finalizar..." -ForegroundColor Gray
Read-Host