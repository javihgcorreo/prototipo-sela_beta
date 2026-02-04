# actualizar-sela.ps1
Write-Host "🔄 ACTUALIZANDO SERVICIO SELA" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

# 1. Verificar archivo actual
Write-Host "`n1. Verificando archivo actual..." -ForegroundColor Yellow
if (Test-Path "servicio-sela/app.py") {
    $lineas = (Get-Content "servicio-sela/app.py").Count
    Write-Host "   ✅ app.py existe ($lineas líneas)" -ForegroundColor Green
    
    # Verificar si ya tiene el endpoint /infraestructura
    $tieneInfraestructura = Select-String -Path "servicio-sela/app.py" -Pattern "infraestructura" -Quiet
    if ($tieneInfraestructura) {
        Write-Host "   ⚠️  Ya tiene endpoint /infraestructura (¿ya actualizado?)" -ForegroundColor Yellow
    } else {
        Write-Host "   ❌ No tiene endpoint /infraestructura (necesita actualización)" -ForegroundColor Red
    }
} else {
    Write-Host "   ❌ app.py no encontrado" -ForegroundColor Red
    exit 1
}

# 2. Verificar requirements.txt
Write-Host "`n2. Verificando dependencias..." -ForegroundColor Yellow
if (Test-Path "servicio-sela/requirements.txt") {
    $tieneRequests = Select-String -Path "servicio-sela/requirements.txt" -Pattern "requests" -Quiet
    if ($tieneRequests) {
        Write-Host "   ✅ requests instalado" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Falta requests en requirements.txt" -ForegroundColor Red
    }
}

# 3. Preguntar si continuar
Write-Host "`n3. ¿Quieres actualizar el código? (S/N)" -ForegroundColor Cyan
$respuesta = Read-Host "   "
if ($respuesta -notmatch "^[Ss]") {
    Write-Host "   ❌ Actualización cancelada" -ForegroundColor Red
    exit 0
}

# 4. Parar Docker
Write-Host "`n4. Parando servicios Docker..." -ForegroundColor Yellow
docker-compose down 2>$null

# 5. Mensaje final
Write-Host "`n📋 MANUALMENTE EN VS CODE:" -ForegroundColor Cyan
Write-Host "   1. Abre 'servicio-sela/app.py' en editor" -ForegroundColor White
Write-Host "   2. Reemplaza TODO el contenido con el nuevo código" -ForegroundColor White
Write-Host "   3. Guarda (Ctrl+S)" -ForegroundColor White
Write-Host "   4. Luego ejecuta: docker-compose up --build -d" -ForegroundColor White

Write-Host "`n🎯 Después de actualizar, prueba:" -ForegroundColor Cyan
Write-Host "   • http://localhost:8000/api/v1/infraestructura" -ForegroundColor White
Write-Host "   • http://localhost:8000/api/v1/demo/tribunal" -ForegroundColor White

Write-Host "`nPresiona Enter cuando hayas actualizado el archivo..."
$null = Read-Host

# 6. Iniciar después de actualizar
Write-Host "`n5. Iniciando servicios..." -ForegroundColor Yellow
docker-compose up --build -d

Write-Host "`n6. Esperando inicialización..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

Write-Host "`n7. Probando nuevos endpoints..." -ForegroundColor Yellow

$tests = @(
    @{Name="Health"; URL="http://localhost:8000/api/v1/health"},
    @{Name="Infraestructura (NUEVO)"; URL="http://localhost:8000/api/v1/infraestructura"},
    @{Name="Demo Tribunal"; URL="http://localhost:8000/api/v1/demo/tribunal"},
    @{Name="Info"; URL="http://localhost:8000/api/v1/info"}
)

foreach ($test in $tests) {
    try {
        $response = Invoke-RestMethod -Uri $test.URL -Method Get -TimeoutSec 5
        Write-Host "   ✅ $($test.Name)" -ForegroundColor Green
        
        if ($test.Name -eq "Infraestructura (NUEVO)" -and $response.infraestructura) {
            Write-Host "      Service Discovery: $($response.service_discovery)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   ❌ $($test.Name)" -ForegroundColor Red
        Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

Write-Host "`n🎉 ACTUALIZACIÓN COMPLETADA" -ForegroundColor Green