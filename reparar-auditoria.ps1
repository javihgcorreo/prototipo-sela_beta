Write-Host "=== REPARANDO SERVICIO AUDITORIA ===" -ForegroundColor Cyan

# 1. Detener servicio
Write-Host "`n1. DETENIENDO SERVICIO..." -ForegroundColor Yellow
docker-compose stop servicio-auditoria

# 2. Actualizar docker-compose.yml con nuevas variables
Write-Host "`n2. ACTUALIZANDO CONFIGURACION..." -ForegroundColor Yellow

# Crear backup
Copy-Item docker-compose.yml docker-compose.yml.backup -Force

# Leer y actualizar el archivo
$content = Get-Content docker-compose.yml -Raw

# Buscar la seccion de servicio-auditoria y agregar variables
if ($content -match 'servicio-auditoria:') {
    $newContent = $content -replace '(servicio-auditoria:\s*\n\s*build:.*?\n\s*container_name:.*?\n\s*ports:.*?\n\s*environment:\s*\n\s*-\s*DATABASE_URL=.*?\n\s*-\s*FLASK_HOST=.*?\n\s*-\s*FLASK_PORT=.*?\n\s*-\s*FLASK_DEBUG=.*?\n)', "`$1      - BLOCKCHAIN_ENABLED=true`n      - BLOCKCHAIN_DIFFICULTY=4`n      - BLOCKCHAIN_REWARD=1`n      - APP_NAME=Servicio de Auditoría`n      - APP_VERSION=2.0.0`n      - APP_DESCRIPTION=Microservicio para auditoría y logging de operaciones con integración blockchain`n"
    
    Set-Content docker-compose.yml $newContent -Encoding UTF8
    Write-Host "✅ docker-compose.yml actualizado" -ForegroundColor Green
} else {
    Write-Host "⚠️  No se pudo actualizar automáticamente" -ForegroundColor Yellow
    Write-Host "Agrega manualmente estas variables a servicio-auditoria:" -ForegroundColor White
    Write-Host "      - BLOCKCHAIN_ENABLED=true" -ForegroundColor Gray
    Write-Host "      - BLOCKCHAIN_DIFFICULTY=4" -ForegroundColor Gray
    Write-Host "      - BLOCKCHAIN_REWARD=1" -ForegroundColor Gray
    Write-Host "      - APP_NAME=Servicio de Auditoría" -ForegroundColor Gray
    Write-Host "      - APP_VERSION=2.0.0" -ForegroundColor Gray
    Write-Host "      - APP_DESCRIPTION=Microservicio para auditoría y logging de operaciones con integración blockchain" -ForegroundColor Gray
}

# 3. Reconstruir servicio
Write-Host "`n3. RECONSTRUYENDO SERVICIO..." -ForegroundColor Yellow
docker-compose build --no-cache servicio-auditoria

# 4. Iniciar servicios
Write-Host "`n4. INICIANDO SERVICIOS..." -ForegroundColor Yellow
docker-compose up -d

# 5. Esperar inicialización
Write-Host "`n5. ESPERANDO INICIALIZACION (30 segundos)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# 6. Verificar variables actualizadas
Write-Host "`n6. VERIFICANDO VARIABLES DE ENTORNO..." -ForegroundColor Yellow
docker-compose exec servicio-auditoria printenv | Select-String -Pattern "BLOCKCHAIN|APP_"

# 7. Probar endpoints básicos
Write-Host "`n7. PROBANDO ENDPOINTS..." -ForegroundColor Yellow

$testEndpoints = @(
    "/health",
    "/info",
    "/blockchain/estado"
)

foreach ($endpoint in $testEndpoints) {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8002$endpoint" -TimeoutSec 5
        Write-Host "✅ $endpoint : OK" -ForegroundColor Green
        if ($endpoint -eq "/info") {
            Write-Host "   Descripción: $($response.description)" -ForegroundColor Gray
            Write-Host "   Blockchain: $($response.blockchain_enabled)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "❌ $endpoint : Error - $_" -ForegroundColor Red
    }
}

# 8. Probar registro con datos simples
Write-Host "`n8. PROBANDO REGISTRO SIMPLE..." -ForegroundColor Yellow

$simpleData = '{"usuario":"admin","accion":"LOGIN","detalles":"Inicio de sesion","origen":"sistema"}'

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8002/registrar" `
        -Method POST `
        -Body $simpleData `
        -ContentType "application/json" `
        -TimeoutSec 10
    
    Write-Host "✅ POST /registrar: $($response.StatusCode)" -ForegroundColor Green
    $content = $response.Content | ConvertFrom-Json
    Write-Host "   ID: $($content.id)" -ForegroundColor Gray
    Write-Host "   Hash: $($content.hash)" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ POST /registrar falló: $($_.Exception.Message)" -ForegroundColor Red
    
    # Mostrar más detalles del error
    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $errorBody = $reader.ReadToEnd()
            Write-Host "   Error detallado: $errorBody" -ForegroundColor DarkYellow
        } catch {
            Write-Host "   No se pudo obtener detalles del error" -ForegroundColor DarkGray
        }
    }
}

# 9. Verificar base de datos
Write-Host "`n9. VERIFICANDO BASE DE DATOS..." -ForegroundColor Yellow

$queries = @(
    "SELECT COUNT(*) as total_logs FROM auditoria_logs;",
    "SELECT COUNT(*) as total_blocks FROM blockchain_hashes;",
    "SELECT id, usuario, accion, timestamp FROM auditoria_logs ORDER BY id DESC LIMIT 3;",
    "SELECT block_id, block_hash, previous_hash, timestamp FROM blockchain_hashes ORDER BY block_id DESC LIMIT 3;"
)

foreach ($query in $queries) {
    try {
        $result = docker exec sela-postgres psql -U auditoria_user -d auditoria_db -t -c $query 2>$null
        if ($result -and $result.Trim()) {
            Write-Host "✅ Consulta ejecutada:" -ForegroundColor Green
            Write-Host $result.Trim() -ForegroundColor Gray
        }
    } catch {
        Write-Host "⚠️  Error en consulta" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "=== REPARACION COMPLETADA ===" -ForegroundColor Cyan