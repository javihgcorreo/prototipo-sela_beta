# comprobarservicios-sela.ps1
Write-Host "=== VERIFICANDO SERVICIO SELA ===" -ForegroundColor Cyan

# 1. Verificar estado de Docker
Write-Host "`n1. Verificando estado Docker..." -ForegroundColor Yellow

# Comprobar si Docker está corriendo
try {
    docker version 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   OK - Docker esta corriendo" -ForegroundColor Green
        
        # Verificar contenedores del servicio
        $containers = docker ps --filter "name=sela" --quiet
        if ($containers) {
            Write-Host "   Contenedores SELA encontrados:" -ForegroundColor Green
            docker ps --filter "name=sela" --format "{{.Names}} - {{.Status}} - {{.Ports}}"
        } else {
            Write-Host "   ADVERTENCIA - No hay contenedores SELA corriendo" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ERROR - Docker no esta disponible" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   ERROR - No se pudo verificar Docker: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. Verificar archivo de configuración
Write-Host "`n2. Verificando configuracion..." -ForegroundColor Yellow
if (Test-Path "docker-compose.yml") {
    Write-Host "   OK - docker-compose.yml encontrado" -ForegroundColor Green
} else {
    Write-Host "   ADVERTENCIA - docker-compose.yml no encontrado" -ForegroundColor Yellow
}

# 3. Comprobar si el servicio esta corriendo
Write-Host "`n3. Comprobando estado del servicio..." -ForegroundColor Yellow
Write-Host "   Probando endpoints..." -ForegroundColor White

$services = @(
    @{Name="Health Check"; URL="http://localhost:8000/api/v1/health"},
    @{Name="Info del Servicio"; URL="http://localhost:8000/api/v1/info"},
    @{Name="Demo Tribunal"; URL="http://localhost:8000/api/v1/demo/tribunal"},
    @{Name="Infraestructura"; URL="http://localhost:8000/api/v1/infraestructura"}
)

foreach ($service in $services) {
    try {
        $response = Invoke-RestMethod -Uri $service.URL -Method Get -TimeoutSec 3
        Write-Host "   OK - $($service.Name)" -ForegroundColor Green
        
        if ($service.Name -eq "Health Check") {
            Write-Host "      Estado: $($response.status)" -ForegroundColor Gray
        }
        elseif ($service.Name -eq "Info del Servicio") {
            Write-Host "      Nombre: $($response.name)" -ForegroundColor Gray
            Write-Host "      Version: $($response.version)" -ForegroundColor Gray
        }
        elseif ($service.Name -eq "Infraestructura" -and $response.service_discovery) {
            Write-Host "      Service Discovery: $($response.service_discovery)" -ForegroundColor Gray
        }
    } catch {
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "   ERROR - $($service.Name) (HTTP $statusCode)" -ForegroundColor Red
        } else {
            Write-Host "   ERROR - $($service.Name) (Sin conexion)" -ForegroundColor Red
        }
    }
}

# 4. Verificar logs recientes
Write-Host "`n4. Verificando logs recientes..." -ForegroundColor Yellow
try {
    $logs = docker logs --tail 5 servicio-sela 2>$null
    if ($logs) {
        Write-Host "   Ultimas 5 lineas de logs:" -ForegroundColor Green
        $logs | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "   No se pudieron obtener logs" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   No se pudieron obtener logs del contenedor" -ForegroundColor Yellow
}

# 5. Resumen del estado
Write-Host "`n=== RESUMEN DEL ESTADO ===" -ForegroundColor Cyan

$successCount = 0
foreach ($service in $services) {
    try {
        $null = Invoke-RestMethod -Uri $service.URL -Method Get -TimeoutSec 2
        $successCount++
    } catch {
        # Ignorar errores
    }
}

if ($successCount -eq $services.Count) {
    Write-Host "   TODOS los endpoints funcionan ($successCount/$($services.Count))" -ForegroundColor Green
} elseif ($successCount -gt 0) {
    Write-Host "   Algunos endpoints funcionan ($successCount/$($services.Count))" -ForegroundColor Yellow
} else {
    Write-Host "   NINGUN endpoint responde (0/$($services.Count))" -ForegroundColor Red
}

Write-Host "`n=== ACCIONES RECOMENDADAS ===" -ForegroundColor Cyan
if ($successCount -lt $services.Count) {
    Write-Host "   1. Verificar que el servicio este corriendo: docker-compose ps" -ForegroundColor White
    Write-Host "   2. Revisar logs del servicio: docker-compose logs servicio-sela" -ForegroundColor White
    Write-Host "   3. Reiniciar el servicio: docker-compose restart" -ForegroundColor White
} else {
    Write-Host "   El servicio funciona correctamente" -ForegroundColor Green
}

Write-Host "`n=== COMANDOS UTILES ===" -ForegroundColor Cyan
Write-Host "   - Ver estado: docker-compose ps" -ForegroundColor White
Write-Host "   - Ver logs: docker-compose logs -f" -ForegroundColor White
Write-Host "   - Reiniciar: docker-compose restart" -ForegroundColor White
Write-Host "   - Detener: docker-compose down" -ForegroundColor White
Write-Host "   - Iniciar: docker-compose up -d" -ForegroundColor White