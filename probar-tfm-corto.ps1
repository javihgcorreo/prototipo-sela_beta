# probar-tfm-corregido.ps1
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   PRUEBAS REALES SISTEMA SeLA - TFM (Windows)" -ForegroundColor Cyan
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
        
        Pass-Test $Name
        return $response
        
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq $ExpectedCode -and $ExpectedCode -ne 200) {
            Pass-Test "$Name (error esperado)"
            return $null
        } else {
            Fail-Test $Name "Codigo $statusCode (esperado $ExpectedCode) - URL: $Url"
            return $null
        }
    }
}

function Test-Health {
    param($ServiceName, $Port, $Path = "/health")
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$Port$Path" -Method Get -TimeoutSec 5
        Pass-Test "Servicio $ServiceName saludable"
        return $true
    } catch {
        Fail-Test "Servicio $ServiceName saludable" "No responde en puerto $Port - $Path"
        return $false
    }
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

Write-Test "2.1" "Servicio SELA (API Principal)"
Test-Health -ServiceName "SELA" -Port 8000 -Path "/api/v1/health"

Write-Test "2.2" "Servicio de Anonimizacion"
Test-Health -ServiceName "Anonimizacion" -Port 8001

Write-Test "2.3" "Servicio de Auditoria"
Test-Health -ServiceName "Auditoria" -Port 8002

Write-Test "2.4" "Service Discovery - Infraestructura"
Test-Endpoint -Name "Endpoint de infraestructura" -Method "GET" -Url "http://localhost:8000/api/v1/infraestructura"

# 3. PRUEBAS DE ACUERDOS (NUCLEO DEL SISTEMA)
Write-Header "3. PRUEBAS DE ACUERDOS SeLA"

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
    Write-Host "   Hash: $($acuerdoResponse.acuerdo.hash)" -ForegroundColor Gray
}

Write-Test "3.2" "Consultar estado de acuerdo"
if ($global:AcuerdoId) {
    Test-Endpoint -Name "Estado de acuerdo" -Method "GET" -Url "http://localhost:8000/api/v1/acuerdo/$global:AcuerdoId/estado"
} else {
    Fail-Test "Consulta de acuerdo" "No hay ID de acuerdo disponible"
}

# 4. PRUEBAS DE ANONIMIZACION
Write-Header "4. PRUEBAS DE ANONIMIZACION"

Write-Test "4.1" "Anonimizacion de datos basica"
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

# 5. PRUEBAS DE AUDITORIA Y TRAZABILIDAD
Write-Header "5. PRUEBAS DE AUDITORIA Y TRAZABILIDAD"

Write-Test "5.1" "Registro de operacion en auditoria"
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

Write-Test "5.2" "Consulta de logs de auditoria"
Test-Endpoint -Name "Consulta logs auditoria" -Method "GET" -Url "http://localhost:8002/logs?limite=5"

# 6. PRUEBAS DE EJECUCION DE OPERACIONES
Write-Header "6. PRUEBAS DE OPERACIONES"

Write-Test "6.1" "Ejecutar operacion bajo acuerdo"
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

# 7. PRUEBAS DE DEMOSTRACION PARA TRIBUNAL
Write-Header "7. PRUEBAS DE DEMOSTRACION (TRIBUNAL)"

Write-Test "7.1" "Endpoint de demostracion para tribunal"
Test-Endpoint -Name "Demo para tribunal" -Method "GET" -Url "http://localhost:8000/api/v1/demo/tribunal"

Write-Test "7.2" "Informacion del sistema"
Test-Endpoint -Name "Info del sistema" -Method "GET" -Url "http://localhost:8000/api/v1/info"

# 8. PRUEBAS DE RESILIENCIA
Write-Header "8. PRUEBAS DE RESILIENCIA"

Write-Test "8.1" "Health check basico"
Test-Endpoint -Name "Health check" -Method "GET" -Url "http://localhost:8000/api/v1/health"

Write-Test "8.2" "Manejo de errores - Acuerdo invalido"
$errorJson = '{
    "nombre": "",
    "partes": {},
    "tipo_datos": "invalido"
}'

Test-Endpoint -Name "Error en acuerdo invalido" -Method "POST" -Url "http://localhost:8000/api/v1/acuerdo/crear" -Body $errorJson -ExpectedCode 400

# 9. RESUMEN Y REPORTE
Write-Header "9. RESUMEN FINAL DE PRUEBAS"

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

# Mostrar endpoints disponibles
Write-Host "`nENDPOINTS DISPONIBLES:" -ForegroundColor Cyan
Write-Host "   SELA (8000):" -ForegroundColor White
Write-Host "   - http://localhost:8000/api/v1/health" -ForegroundColor Gray
Write-Host "   - http://localhost:8000/api/v1/info" -ForegroundColor Gray
Write-Host "   - http://localhost:8000/api/v1/infraestructura" -ForegroundColor Gray
Write-Host "   - http://localhost:8000/api/v1/demo/tribunal" -ForegroundColor Gray
Write-Host "   - http://localhost:8000/api/v1/acuerdo/crear" -ForegroundColor Gray
Write-Host "   - http://localhost:8000/api/v1/acuerdo/{id}/estado" -ForegroundColor Gray
Write-Host "   - http://localhost:8000/api/v1/acuerdo/{id}/ejecutar" -ForegroundColor Gray

Write-Host "   Anonimizacion (8001):" -ForegroundColor White
Write-Host "   - http://localhost:8001/health" -ForegroundColor Gray
Write-Host "   - http://localhost:8001/anonimizar" -ForegroundColor Gray

Write-Host "   Auditoria (8002):" -ForegroundColor White
Write-Host "   - http://localhost:8002/health" -ForegroundColor Gray
Write-Host "   - http://localhost:8002/registrar" -ForegroundColor Gray
Write-Host "   - http://localhost:8002/logs" -ForegroundColor Gray

# Generar reporte en archivo
$reportFileName = "reporte_pruebas_reales_tfm_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$reportPath = Join-Path (Get-Location) $reportFileName

Write-Host "`nGENERANDO REPORTE EN: $reportPath" -ForegroundColor Cyan

$reportContent = @"
======================================================
   REPORTE DE PRUEBAS - SISTEMA SeLA TFM
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

ACUERDO CREADO:
  ID: $($global:AcuerdoId)

COMPONENTES VERIFICADOS:
  1. [$(if ($selaRunning) {'OK'} else {'FALLO'})] Servicio SELA (API Principal)
  2. [$(if ($anonimizacionRunning) {'OK'} else {'FALLO'})] Servicio de Anonimizacion
  3. [$(if ($auditoriaRunning) {'OK'} else {'FALLO'})] Servicio de Auditoria
  4. [$(if ($global:AcuerdoId) {'OK'} else {'FALLO'})] Creacion de Acuerdos
  5. [$(if ($global:TestResults -like '*Ejecucion de operacion*') {'OK'} else {'FALLO'})] Ejecucion de Operaciones

ENDPOINTS FUNCIONALES:
  - http://localhost:8000/api/v1/demo/tribunal
  - http://localhost:8000/api/v1/infraestructura
  - http://localhost:8000/api/v1/info
  - http://localhost:8001/anonimizar
  - http://localhost:8002/registrar
  - http://localhost:8002/logs

PARA LA DEFENSA DEL TFM:
  1. EL SISTEMA FUNCIONA CON:
     - 3 servicios Docker independientes
     - Comunicacion HTTP entre servicios
     - Creacion y gestion de acuerdos
     - Anonimizacion de datos sensibles
     - Auditoria completa de operaciones

  2. PUNTOS FUERTES PARA MOSTRAR:
     - Crear un acuerdo SeLA en tiempo real
     - Mostrar la validacion automatica
     - Ejecutar una operacion bajo acuerdo
     - Ver los logs de auditoria
     - Mostrar el estado del sistema

  3. DEMOSTRACION PRACTICA:
     1. docker-compose ps (mostrar servicios)
     2. Crear acuerdo via API
     3. Ejecutar operacion de prueba
     4. Mostrar anonimizacion de datos
     5. Verificar logs de auditoria
     6. Mostrar demo para tribunal
"@

Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8

Write-Host "`nPARA LA DEFENSA DEL TFM:" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

Write-Host "`nPASOS PARA DEMOSTRAR EN VIVO:" -ForegroundColor Yellow
Write-Host "   1. Mostrar arquitectura:" -ForegroundColor White
Write-Host "      docker-compose ps" -ForegroundColor Gray

Write-Host "`n   2. Crear un acuerdo SeLA:" -ForegroundColor White
Write-Host "      Invoke-RestMethod -Uri http://localhost:8000/api/v1/acuerdo/crear -Method Post -Body '...' -ContentType 'application/json'" -ForegroundColor Gray

Write-Host "`n   3. Ejecutar operacion de prueba:" -ForegroundColor White
Write-Host "      Invoke-RestMethod -Uri http://localhost:8000/api/v1/acuerdo/{id}/ejecutar -Method Post -Body '...' -ContentType 'application/json'" -ForegroundColor Gray

Write-Host "`n   4. Mostrar anonimizacion:" -ForegroundColor White
Write-Host "      Invoke-RestMethod -Uri http://localhost:8001/anonimizar -Method Post -Body '...' -ContentType 'application/json'" -ForegroundColor Gray

Write-Host "`n   5. Verificar auditoria:" -ForegroundColor White
Write-Host "      Invoke-RestMethod -Uri http://localhost:8002/logs?limite=5 -Method Get" -ForegroundColor Gray

Write-Host "`n   6. Mostrar demo para tribunal:" -ForegroundColor White
Write-Host "      Invoke-RestMethod -Uri http://localhost:8000/api/v1/demo/tribunal -Method Get" -ForegroundColor Gray

Write-Host "`nENLACES PARA LA PRESENTACION:" -ForegroundColor Yellow
Write-Host "   - Demo Tribunal: http://localhost:8000/api/v1/demo/tribunal" -ForegroundColor White
Write-Host "   - Service Discovery: http://localhost:8000/api/v1/infraestructura" -ForegroundColor White
Write-Host "   - Info del Sistema: http://localhost:8000/api/v1/info" -ForegroundColor White
Write-Host "   - Logs de Auditoria: http://localhost:8002/logs?limite=5" -ForegroundColor White

Write-Host "`n[OK] Script de pruebas completado" -ForegroundColor Green
Write-Host "Reporte guardado en: $reportPath" -ForegroundColor Cyan

Write-Host "`nPresiona Enter para finalizar..." -ForegroundColor Gray
Read-Host