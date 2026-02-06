# test-inmediato.ps1 - Prueba RÁPIDA
Write-Host "=== PRUEBA INMEDIATA POST-RECONSTRUCCIÓN ===" -ForegroundColor Cyan

# PRUEBA 1: Formato que SABEMOS funciona (usuario, accion, detalles, origen)
$test1 = @{
    usuario = "admin"
    accion = "TEST_RECONSTRUCCION"
    detalles = "Prueba después de reconstrucción completa"
    origen = "powershell_test"
} | ConvertTo-Json

Write-Host "Prueba 1 - Formato conocido..." -ForegroundColor Gray

try {
    $response = Invoke-RestMethod -Uri "http://localhost:8002/registrar" `
        -Method POST `
        -Body $test1 `
        -ContentType "application/json" `
        -TimeoutSec 10
    
    Write-Host "✅ ÉXITO - Formato aceptado" -ForegroundColor Green
    Write-Host "   Operación ID: $($response.operacion_id)" -ForegroundColor Gray
    Write-Host "   Formato: $($response.formato_detectado)" -ForegroundColor Gray
    Write-Host "   Blockchain: $($response.blockchain_enabled)" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    
    # Mostrar error completo
    if ($_.Exception.Response) {
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $errorBody = $reader.ReadToEnd()
            Write-Host "   Error detallado: $errorBody" -ForegroundColor Yellow
        } catch {
            Write-Host "   No se pudo obtener detalles del error" -ForegroundColor DarkGray
        }
    }
}

# PRUEBA 2: Verificar que el servicio responde
Write-Host "`nPrueba 2 - Health check..." -ForegroundColor Gray
try {
    $health = Invoke-RestMethod "http://localhost:8002/health" -TimeoutSec 5
    Write-Host "✅ Health OK: $($health.service) v$($health.version)" -ForegroundColor Green
    Write-Host "   DB Status: $($health.database_status)" -ForegroundColor Gray
    Write-Host "   Blockchain: $($health.blockchain_enabled)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Health check falló: $_" -ForegroundColor Red
}

# PRUEBA 3: Ver logs
Write-Host "`nPrueba 3 - Ver logs..." -ForegroundColor Gray
try {
    $logs = Invoke-RestMethod "http://localhost:8002/logs?limite=3" -TimeoutSec 5
    Write-Host "✅ Logs obtenidos: $($logs.total_logs) registros" -ForegroundColor Green
} catch {
    Write-Host "⚠️  No se pudieron obtener logs: $_" -ForegroundColor Yellow
}