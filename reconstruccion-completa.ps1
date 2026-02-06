# reconstruir-completo-corregido.ps1
Write-Host "RECONSTRUCCION COMPLETA DEL SISTEMA SeLA (CORREGIDO)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# Detectar directorio del script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Directorio del script: $ScriptDir" -ForegroundColor Gray

# 1. VERIFICAR ARCHIVOS CRÍTICOS
Write-Host "`n1. VERIFICANDO ARCHIVOS NECESARIOS:" -ForegroundColor Yellow

$criticalFiles = @(
    "docker-compose.yml",
    "servicio-sela/Dockerfile",
    "servicio-sela/requirements.txt",
    "servicio-sela/app.py",
    "servicio-anonimizacion/Dockerfile", 
    "servicio-anonimizacion/requirements.txt",
    "servicio-anonimizacion/app.py",
    "servicio-auditoria/Dockerfile",
    "servicio-auditoria/requirements.txt",
    "servicio-auditoria/app.py"
)

foreach ($file in $criticalFiles) {
    $fullPath = Join-Path $ScriptDir $file
    if (Test-Path $fullPath) {
        $size = (Get-Item $fullPath).Length
        Write-Host "   [OK] $file ($size bytes)" -ForegroundColor Green
    } else {
        Write-Host "   [ERROR] $file NO ENCONTRADO" -ForegroundColor Red
        exit 1
    }
}

# 2. CREAR REQUIREMENTS.TXT SI NO EXISTEN
Write-Host "`n2. ASEGURANDO REQUIREMENTS:" -ForegroundColor Yellow

# Requirements para servicio-sela
$selaRequirements = Join-Path $ScriptDir "servicio-sela\requirements.txt"
if (-not (Test-Path $selaRequirements) -or (Get-Content $selaRequirements).Length -eq 0) {
    Write-Host "   Creando requirements.txt para servicio-sela..." -ForegroundColor Gray
    Set-Content -Path $selaRequirements -Value @"
fastapi==0.104.1
uvicorn[standard]==0.24.0
httpx==0.25.1
pydantic==2.5.0
"@
    Write-Host "   [OK] requirements.txt creado para servicio-sela" -ForegroundColor Green
}

# 3. DETENER Y LIMPIAR
Write-Host "`n3. LIMPIANDO SISTEMA PREVIO:" -ForegroundColor Yellow
docker-compose down 2>$null
docker-compose down -v 2>$null
docker system prune -f 2>$null
Write-Host "   [OK] Sistema limpiado" -ForegroundColor Green

# 4. CONSTRUIR CON LOGS DETALLADOS
Write-Host "`n4. CONSTRUYENDO IMAGENES:" -ForegroundColor Yellow
Write-Host "   Esto puede tomar varios minutos..." -ForegroundColor Gray

# Construir cada servicio por separado para ver errores
Write-Host "`n   Construyendo servicio-sela..." -ForegroundColor Gray
docker-compose build servicio-sela

Write-Host "`n   Construyendo servicio-anonimizacion..." -ForegroundColor Gray  
docker-compose build servicio-anonimizacion

Write-Host "`n   Construyendo servicio-auditoria..." -ForegroundColor Gray
docker-compose build servicio-auditoria

Write-Host "`n   [OK] Todas las imagenes construidas" -ForegroundColor Green

# 5. INICIAR SISTEMA
Write-Host "`n5. INICIANDO SISTEMA:" -ForegroundColor Yellow
docker-compose up -d

Write-Host "   Esperando inicializacion (60 segundos)..." -ForegroundColor Gray
Start-Sleep -Seconds 60

# 6. VERIFICAR ESTADO
Write-Host "`n6. ESTADO DE CONTENEDORES:" -ForegroundColor Yellow
docker-compose ps

# 7. VERIFICAR LOGS DE ERRORES
Write-Host "`n7. VERIFICANDO LOGS DE ERROR:" -ForegroundColor Yellow
$logs = docker-compose logs --tail=20 2>$null

if ($logs -match "ModuleNotFoundError|ImportError|No module named") {
    Write-Host "   [ERROR] Hay problemas de dependencias en los logs" -ForegroundColor Red
    Write-Host "   Mostrando logs relevantes:" -ForegroundColor Gray
    $logs | Select-String -Pattern "ModuleNotFoundError|ImportError|No module named|Traceback" -Context 5
} else {
    Write-Host "   [OK] No se encontraron errores de dependencias en logs" -ForegroundColor Green
}

# 8. PRUEBA DE CONECTIVIDAD
Write-Host "`n8. PRUEBA DE CONECTIVIDAD:" -ForegroundColor Yellow

$services = @(
    @{Name="SELA - Puerto 8000"; Port=8000; Path="/api/v1/health"},
    @{Name="Anonimizacion - Puerto 8001"; Port=8001; Path="/health"},
    @{Name="Auditoria - Puerto 8002"; Port=8002; Path="/health"}
)

foreach ($svc in $services) {
    try {
        $url = "http://localhost:$($svc.Port)$($svc.Path)"
        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10
        Write-Host "   [OK] $($svc.Name)" -ForegroundColor Green
    } catch {
        Write-Host "   [ERROR] $($svc.Name) - $($_.Exception.Message)" -ForegroundColor Red
        
        # Mostrar logs específicos del servicio que falla
        if ($svc.Name -like "*SELA*") {
            Write-Host "   Mostrando logs de sela-main:" -ForegroundColor Gray
            docker-compose logs servicio-sela --tail=10 2>$null
        }
    }
}

# 9. RESOLVER PROBLEMAS COMUNES
Write-Host "`n9. SOLUCIONANDO PROBLEMAS COMUNES:" -ForegroundColor Yellow

# Si SELA sigue fallando, intentar reinstalar dependencias
try {
    Invoke-RestMethod -Uri "http://localhost:8000/api/v1/health" -Method Get -TimeoutSec 5 -ErrorAction Stop | Out-Null
} catch {
    Write-Host "   SELA sigue fallando. Intentando reinstalacion de dependencias..." -ForegroundColor Yellow
    
    # Ejecutar pip install dentro del contenedor
    Write-Host "   Instalando dependencias en contenedor sela-main..." -ForegroundColor Gray
    docker exec sela-main pip install fastapi uvicorn httpx pydantic 2>$null
    
    Write-Host "   Reiniciando servicio..." -ForegroundColor Gray
    docker-compose restart servicio-sela
    
    Write-Host "   Esperando 30 segundos..." -ForegroundColor Gray
    Start-Sleep -Seconds 30
    
    # Verificar nuevamente
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8000/api/v1/health" -Method Get -TimeoutSec 10
        Write-Host "   [OK] SELA ahora funciona correctamente" -ForegroundColor Green
    } catch {
        Write-Host "   [ERROR] SELA sigue sin funcionar" -ForegroundColor Red
        Write-Host "   Verifica manualmente con: docker-compose logs servicio-sela" -ForegroundColor Gray
    }
}

# 10. RESUMEN FINAL
Write-Host "`n10. RESUMEN FINAL:" -ForegroundColor Cyan

Write-Host "`nCOMANDOS UTILES PARA DIAGNOSTICO:" -ForegroundColor Yellow
Write-Host "   - Ver todos los logs: docker-compose logs" -ForegroundColor Gray
Write-Host "   - Logs de SELA: docker-compose logs servicio-sela" -ForegroundColor Gray
Write-Host "   - Entrar al contenedor: docker exec -it sela-main bash" -ForegroundColor Gray
Write-Host "   - Ver pip list: docker exec sela-main pip list" -ForegroundColor Gray
Write-Host "   - Reconstruir solo SELA: docker-compose build servicio-sela" -ForegroundColor Gray

Write-Host "`nSI EL PROBLEMA PERSISTE:" -ForegroundColor Red
Write-Host "   1. Verifica que servicio-sela/requirements.txt existe" -ForegroundColor Gray
Write-Host "   2. Verifica que el Dockerfile copia requirements.txt" -ForegroundColor Gray
Write-Host "   3. Revisa el archivo app.py linea 1" -ForegroundColor Gray
Write-Host "   4. Prueba: docker-compose build --no-cache servicio-sela" -ForegroundColor Gray

Write-Host "`nPresiona Enter para finalizar..." -ForegroundColor Gray
Read-Host