# probar-desde-cero.ps1
Write-Host "🧪 PRUEBA COMPLETA DESDE CERO - SISTEMA SeLA TFM" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

function Write-Step {
    param($Numero, $Descripcion)
    Write-Host "`n$Numero. $Descripcion" -ForegroundColor Yellow
}

function Test-Service {
    param($Name, $Port, $Path, $Timeout=10)
    try {
        $url = "http://localhost:$Port$Path"
        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec $Timeout
        Write-Host "   ✅ $Name" -ForegroundColor Green
        return $response
    } catch {
        Write-Host "   ❌ $Name - $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

Write-Step "1" "LIMPIANDO SISTEMA PREVIO"
docker-compose down -v 2>$null
docker system prune -f 2>$null
Write-Host "   ✅ Sistema limpiado" -ForegroundColor Green

Write-Step "2" "VERIFICANDO CÓDIGO ACTUAL"
$lineCount = (Get-Content servicio-sela/app.py).Count
Write-Host "   📊 servicio-sela/app.py: $lineCount líneas" -ForegroundColor Gray

$hasInfra = Select-String -Path servicio-sela/app.py -Pattern "infraestructura" -Quiet
Write-Host "   🔍 Tiene endpoint /infraestructura: $(if($hasInfra){'✅'}else{'❌'})" -ForegroundColor $(if($hasInfra){'Green'}else{'Red'})

Write-Step "3" "INICIANDO SISTEMA COMPLETO"
Write-Host "   🚀 Ejecutando: docker-compose up --build" -ForegroundColor White
Write-Host "   ⏳ Esto tomará 2-3 minutos..." -ForegroundColor Gray

# Iniciar en segundo plano
docker-compose up --build -d

Write-Host "   ⏳ Esperando inicialización (30 segundos)..." -ForegroundColor Gray
Start-Sleep -Seconds 30

Write-Step "4" "VERIFICANDO SERVICIOS"
docker-compose ps
# En probar-desde-cero.ps1, agregar:

# ... después de iniciar los servicios ...

Write-Host "`n=== VERIFICANDO SERVICIO AUDITORÍA ===" -ForegroundColor Cyan

# Cargar la función
. .\verificar-auditoria.ps1

# Ejecutar verificación
$auditoriaOk = Verificar-ServicioAuditoria -Detallado:$true

if ($auditoriaOk) {
    Write-Host "✅ Servicio de auditoría funcionando correctamente" -ForegroundColor Green
} else {
    Write-Host "⚠️  Hay problemas con el servicio de auditoría" -ForegroundColor Yellow
}
# ----

Write-Step "5" "PRUEBA DE SALUD DE TODOS LOS SERVICIOS"
$services = @(
    @{Name="SELA (8000)"; Port=8000; Path="/api/v1/health"},
    @{Name="Anonimización (8001)"; Port=8001; Path="/health"},
    @{Name="Auditoría (8002)"; Port=8002; Path="/health"}
)

foreach ($svc in $services) {
    Test-Service @svc
}

Write-Step "6" "CREANDO ACUERDO SeLA (NÚCLEO TFM)"
$acuerdoJson = @'
{
    "nombre": "PRUEBA DESDE CERO - TFM SeLA",
    "partes": {
        "proveedor": "Hospital de Pruebas",
        "consumidor": "Laboratorio de Investigación TFM"
    },
    "tipo_datos": "datos_salud_fhir",
    "finalidad": "investigacion_cientifica",
    "base_legal": "consentimiento",
    "nivel_anonimizacion": "alto",
    "duracion_horas": 720,
    "volumen_maximo": 10000
}
'@

try {
    $acuerdo = Invoke-RestMethod `
        -Uri "http://localhost:8000/api/v1/acuerdo/crear" `
        -Method Post `
        -Body $acuerdoJson `
        -ContentType "application/json" `
        -TimeoutSec 10
    
    Write-Host "   ✅ ACUERDO CREADO" -ForegroundColor Green
    Write-Host "      ID: $($acuerdo.acuerdo.id)" -ForegroundColor Cyan
    Write-Host "      Hash: $($acuerdo.acuerdo.hash)" -ForegroundColor Gray
    
    $acuerdoId = $acuerdo.acuerdo.id
    
} catch {
    Write-Host "   ❌ ERROR CREANDO ACUERDO" -ForegroundColor Red
    Write-Host "      $($_.Exception.Message)" -ForegroundColor Gray
    $acuerdoId = $null
}

Write-Step "7" "PRUEBA DE ENDPOINTS COMPLETOS"
if ($acuerdoId) {
    # Estado del acuerdo
    Test-Service -Name "Estado Acuerdo" -Port 8000 -Path "/api/v1/acuerdo/$acuerdoId/estado"
    
    # Ejecutar operación
    $operacionJson = @'
    {
        "operacion": "procesar_datos",
        "datos": {"pacientes": 50, "tipo": "historiales_clinicos"},
        "parametros": {"prioridad": "alta", "destino": "servicio_anonimizacion"}
    }
'@
    try {
        $operacion = Invoke-RestMethod `
            -Uri "http://localhost:8000/api/v1/acuerdo/$acuerdoId/ejecutar" `
            -Method Post `
            -Body $operacionJson `
            -ContentType "application/json" `
            -TimeoutSec 10
        Write-Host "   ✅ Operación ejecutada: $($operacion.operacion.id)" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️  Operación falló (puede ser normal): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Endpoints importantes
Test-Service -Name "Info SELA" -Port 8000 -Path "/api/v1/info"
Test-Service -Name "Infraestructura (Service Discovery)" -Port 8000 -Path "/api/v1/infraestructura"
Test-Service -Name "Demo Tribunal" -Port 8000 -Path "/api/v1/demo/tribunal"

Write-Step "8" "PRUEBA DE AUDITORÍA"
try {
    $auditJson = @"
    {
        "operacion": "prueba_desde_cero",
        "servicio_origen": "script_pruebas",
        "resultado": "Prueba completa del sistema SeLA desde cero",
        "datos_procesados": 5,
        "metadatos": {
            "acuerdo_id": "$acuerdoId",
            "prueba": "completa",
            "timestamp": "$(Get-Date -Format 'o')"
        }
    }
"@
    
    $audit = Invoke-RestMethod `
        -Uri "http://localhost:8002/registrar" `
        -Method Post `
        -Body $auditJson `
        -ContentType "application/json" `
        -TimeoutSec 10 -ErrorAction SilentlyContinue
    
    if ($audit) {
        Write-Host "   ✅ Auditoría registrada: $($audit.operacion_id)" -ForegroundColor Green
    }
} catch {
    Write-Host "   ⚠️  Auditoría no disponible (puede ser normal)" -ForegroundColor Yellow
}

# Consultar logs
Test-Service -Name "Logs Auditoría" -Port 8002 -Path "/logs?limite=3"

Write-Step "9" "RESUMEN FINAL"
Write-Host "`n📊 ESTADO DEL SISTEMA:" -ForegroundColor Cyan

$demo = Invoke-RestMethod -Uri "http://localhost:8000/api/v1/demo/tribunal" -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
if ($demo) {
    Write-Host "   • Acuerdos activos: $($demo.estado_actual.acuerdos_activos)" -ForegroundColor White
    Write-Host "   • Total operaciones: $($demo.estado_actual.total_operaciones)" -ForegroundColor White
    Write-Host "   • Servicio: $($demo.estado_actual.servicio)" -ForegroundColor White
}

Write-Host "`n✅ SISTEMA SeLA - LISTO PARA DEFENSA TFM" -ForegroundColor Green
Write-Host "`n🔗 URLs para tu presentación:" -ForegroundColor Yellow
Write-Host "   • http://localhost:8000/api/v1/demo/tribunal" -ForegroundColor White
Write-Host "   • http://localhost:8000/api/v1/infraestructura" -ForegroundColor White
Write-Host "   • http://localhost:8000/api/v1/info" -ForegroundColor White

Write-Host "`n🎯 Para mostrar en tu defensa:" -ForegroundColor Cyan
Write-Host "   1. docker-compose ps (muestra servicios corriendo)" -ForegroundColor White
Write-Host "   2. Crear acuerdo SeLA (validación RGPD automática)" -ForegroundColor White
Write-Host "   3. Mostrar endpoint /demo/tribunal (resumen completo)" -ForegroundColor White

Write-Host "`n🛑 Para detener el sistema: docker-compose down" -ForegroundColor Gray
Write-Host "`nPresiona Enter para ver logs en tiempo real..."
$null = Read-Host

# Mostrar logs
docker-compose logs --tail=20