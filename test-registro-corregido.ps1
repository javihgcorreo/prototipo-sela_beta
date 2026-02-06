# test-registro-corregido.ps1
Write-Host "=== PRUEBA ENDPOINT REGISTRAR CORREGIDO ===" -ForegroundColor Cyan

# Datos en el formato CORRECTO que espera tu código actual
$datosCorrectos = @{
    operacion = "admin - LOGIN"  # Combina usuario + acción
    servicio_origen = "sistema"   # Tu campo 'origen'
    resultado = "Inicio de sesión exitoso"  # Tu campo 'detalles'
    datos_procesados = 1
    metadatos = @{
        ip = "192.168.1.1"
        user_agent = "PowerShell"
        version = "2.0"
    }
} | ConvertTo-Json

Write-Host "Enviando datos en formato CORRECTO..." -ForegroundColor Yellow
Write-Host "JSON: $datosCorrectos"

try {
    $response = Invoke-RestMethod -Uri "http://localhost:8002/registrar" `
        -Method POST `
        -Body $datosCorrectos `
        -ContentType "application/json" `
        -TimeoutSec 10
    
    Write-Host "✅ ÉXITO - Registro creado" -ForegroundColor Green
    Write-Host "   Operación ID: $($response.operacion_id)" -ForegroundColor Gray
    Write-Host "   Log ID: $($response.log_id)" -ForegroundColor Gray
    Write-Host "   Blockchain: $($response.blockchain_enabled)" -ForegroundColor Gray
    
    if ($response.blockchain_enabled -eq $true) {
        Write-Host "   Blockchain Hash: $($response.blockchain.hash)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    
    # Mostrar detalles del error
    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $errorBody = $reader.ReadToEnd()
            Write-Host "   Detalles: $errorBody" -ForegroundColor Yellow
        } catch {
            Write-Host "   No se pudo obtener detalles del error" -ForegroundColor DarkGray
        }
    }
}

# También prueba con datos simples
Write-Host "`n=== PRUEBA CON DATOS MÍNIMOS ===" -ForegroundColor Cyan

$datosMinimos = @{
    operacion = "test - ACTION"
    servicio_origen = "script"
    resultado = "Prueba mínima"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "http://localhost:8002/registrar" `
        -Method POST `
        -Body $datosMinimos `
        -ContentType "application/json" `
        -TimeoutSec 10
    
    Write-Host "✅ ÉXITO con datos mínimos" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR con datos mínimos: $_" -ForegroundColor Red
}