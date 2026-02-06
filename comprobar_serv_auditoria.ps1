# comprobar_serv_auditoria.ps1
Write-Host "VERIFICACION SERVICIO AUDITORIA CON BLOCKCHAIN" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# 1. Verificar estado de contenedores
Write-Host "`n1. ESTADO DE CONTENEDORES" -ForegroundColor Yellow

$contenedores = docker ps --filter "name=sela" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
if ($contenedores) {
    Write-Host "   CONTENEDORES SELA ACTIVOS:" -ForegroundColor Green
    $contenedores
} else {
    Write-Host "   NO hay contenedores SELA activos" -ForegroundColor Red
    exit 1
}

# 2. Verificar conexion a PostgreSQL
Write-Host "`n2. VERIFICACION BASE DE DATOS" -ForegroundColor Yellow

try {
    $dbCheck = docker exec sela-postgres pg_isready -U auditoria_user -d auditoria_db 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   PostgreSQL conectado y listo" -ForegroundColor Green
        
        # Verificar tablas blockchain
        $tablas = docker exec sela-postgres psql -U auditoria_user -d auditoria_db -t -c "
        SELECT 'Tablas:' as info;
        SELECT table_name FROM information_schema.tables 
        WHERE table_schema='public' AND table_name IN ('auditoria_logs', 'blockchain_hashes');
        
        SELECT 'Columnas blockchain:' as info;
        SELECT column_name FROM information_schema.columns 
        WHERE table_name='auditoria_logs' AND column_name LIKE 'blockchain%';
        " 2>$null
        
        if ($tablas) {
            Write-Host "   Tablas/Columnas blockchain:" -ForegroundColor Green
            $tablas | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
        }
    } else {
        Write-Host "   PostgreSQL no disponible" -ForegroundColor Red
    }
} catch {
    Write-Host "   Error verificando PostgreSQL: $_" -ForegroundColor Red
}

# 3. Probar endpoints del servicio
Write-Host "`n3. PRUEBA DE ENDPOINTS" -ForegroundColor Yellow

$endpoints = @(
    @{Nombre="HEALTH"; URL="http://localhost:8002/health"; Metodo="GET"},
    @{Nombre="INFO"; URL="http://localhost:8002/info"; Metodo="GET"},
    @{Nombre="BLOCKCHAIN ESTADO"; URL="http://localhost:8002/blockchain/estado"; Metodo="GET"},
    @{Nombre="BLOCKCHAIN VERIFICAR"; URL="http://localhost:8002/blockchain/verificar"; Metodo="GET"},
    @{Nombre="LOGS"; URL="http://localhost:8002/logs?limite=3"; Metodo="GET"}
)

foreach ($endpoint in $endpoints) {
    Write-Host "`n   $($endpoint.Nombre)" -ForegroundColor White
    Write-Host "   URL: $($endpoint.URL)" -ForegroundColor Gray
    
    try {
        if ($endpoint.Metodo -eq "GET") {
            $response = Invoke-RestMethod -Uri $endpoint.URL -Method Get -TimeoutSec 5
        }
        
        Write-Host "   Conectado" -ForegroundColor Green
        
        # Informacion especifica por endpoint
        switch ($endpoint.Nombre) {
            "HEALTH" {
                Write-Host "      Servicio: $($response.service)" -ForegroundColor Gray
                Write-Host "      Version: $($response.version)" -ForegroundColor Gray
                Write-Host "      DB Status: $($response.database_status)" -ForegroundColor $(if ($response.database_status -eq 'healthy') { 'Green' } else { 'Red' })
                Write-Host "      Blockchain: $($response.blockchain_enabled)" -ForegroundColor $(if ($response.blockchain_enabled) { 'Cyan' } else { 'Yellow' })
            }
            "INFO" {
                Write-Host "      Descripcion: $($response.descripcion)" -ForegroundColor Gray
                if ($response.blockchain) {
                    Write-Host "      Blockchain habilitado: $($response.blockchain.habilitado)" -ForegroundColor Cyan
                }
            }
            "BLOCKCHAIN ESTADO" {
                if ($response.estadisticas) {
                    Write-Host "      Total bloques: $($response.estadisticas.blockchain.total_bloques)" -ForegroundColor Cyan
                    Write-Host "      Registros con blockchain: $($response.estadisticas.auditoria.registros_con_blockchain)" -ForegroundColor Cyan
                }
            }
            "BLOCKCHAIN VERIFICAR" {
                Write-Host "      Status: $($response.status)" -ForegroundColor Cyan
                if ($response.total_bloques) {
                    Write-Host "      Bloques en cadena: $($response.total_bloques)" -ForegroundColor Gray
                }
            }
            "LOGS" {
                Write-Host "      Total logs: $($response.total_logs)" -ForegroundColor Gray
                if ($response.logs -and $response.logs.Count -gt 0) {
                    $logsConBlockchain = $response.logs | Where-Object { $_.blockchain_hash }
                    Write-Host "      Logs con blockchain: $($logsConBlockchain.Count)" -ForegroundColor Cyan
                }
            }
        }
        
    } catch {
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 4. Probar registro con blockchain
Write-Host "`n4. PRUEBA DE REGISTRO CON BLOCKCHAIN" -ForegroundColor Cyan

$testData = @{
    operacion = "verificacion_servicio"
    servicio_origen = "script_comprobacion"
    resultado = "verificacion_exitosa"
    datos_procesados = 1
    metadatos = @{
        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        script = "comprobar_serv_auditoria.ps1"
        test_type = "blockchain_integration"
    }
}

$testDataJson = $testData | ConvertTo-Json

try {
    Write-Host "   Enviando registro de prueba..." -ForegroundColor White
    
    $registroResponse = Invoke-RestMethod -Uri "http://localhost:8002/registrar" `
        -Method Post `
        -ContentType "application/json" `
        -Body $testDataJson `
        -TimeoutSec 10
    
    Write-Host "   Registro exitoso" -ForegroundColor Green
    Write-Host "      ID Operacion: $($registroResponse.operacion_id)" -ForegroundColor Gray
    
    if ($registroResponse.blockchain_enabled) {
        Write-Host "      Blockchain HABILITADO" -ForegroundColor Cyan
        
        if ($registroResponse.blockchain -and $registroResponse.blockchain.hash) {
            Write-Host "      Hash: $($registroResponse.blockchain.hash)" -ForegroundColor Gray
            Write-Host "      Bloque: $($registroResponse.blockchain.block_id)" -ForegroundColor Gray
        }
    } else {
        Write-Host "      Blockchain NO habilitado" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "   Error en registro: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Verificar el registro recien creado
Write-Host "`n5. VERIFICACION DE REGISTRO EN BD" -ForegroundColor Yellow
Start-Sleep -Seconds 2  # Esperar que se persista

try {
    $sqlQuery = @"
SELECT 'Ultimo registro:' as titulo;
SELECT 
    operacion,
    servicio_origen,
    resultado,
    CASE WHEN blockchain_hash IS NOT NULL THEN 'CON BLOCKCHAIN' ELSE 'SIN BLOCKCHAIN' END as estado_blockchain,
    blockchain_hash,
    blockchain_block_id
FROM auditoria_logs 
ORDER BY timestamp DESC 
LIMIT 1;
"@

    $ultimoRegistro = docker exec sela-postgres psql -U auditoria_user -d auditoria_db -t -c $sqlQuery 2>$null
    
    if ($ultimoRegistro) {
        Write-Host "   Ultimo registro en BD:" -ForegroundColor Green
        $ultimoRegistro | ForEach-Object { 
            if ($_ -match "CON BLOCKCHAIN") {
                Write-Host "      $_" -ForegroundColor Cyan
            } else {
                Write-Host "      $_" -ForegroundColor Gray
            }
        }
    }
} catch {
    Write-Host "   No se pudo verificar registro en BD" -ForegroundColor Yellow
}

# 6. Verificar cadena de bloques
Write-Host "`n6. VERIFICACION CADENA DE BLOQUES" -ForegroundColor Cyan

try {
    $sqlCadena = @"
SELECT 'Cadena de bloques:' as titulo;
SELECT 
    block_id,
    SUBSTRING(block_hash, 1, 16) || '...' as hash_corto,
    LENGTH(block_hash) as longitud_hash,
    timestamp,
    transactions_count
FROM blockchain_hashes 
ORDER BY block_id;
"@

    $cadenaBloques = docker exec sela-postgres psql -U auditoria_user -d auditoria_db -t -c $sqlCadena 2>$null
    
    if ($cadenaBloques) {
        Write-Host "   Bloques en la cadena:" -ForegroundColor Green
        $lineCount = 0
        $cadenaBloques | ForEach-Object {
            if ($_ -and $_.Trim() -ne "") {
                $lineCount++
                if ($lineCount -gt 1) {  # Saltar titulo
                    Write-Host "      $_" -ForegroundColor Gray
                }
            }
        }
        
        if ($lineCount -le 1) {
            Write-Host "      Solo bloque genesis presente" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "   No se pudo verificar cadena de bloques" -ForegroundColor Yellow
}

# 7. Resumen final
Write-Host "`nRESUMEN DE VERIFICACION" -ForegroundColor Cyan

$servicioUp = $false
$blockchainHabilitado = $false
$dbConectada = $false

# Verificar health
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8002/health" -TimeoutSec 3
    $servicioUp = $true
    $blockchainHabilitado = $health.blockchain_enabled
    $dbConectada = $health.database_status -eq 'healthy'
} catch {
    Write-Host "   No se pudo conectar al servicio" -ForegroundColor Red
}

Write-Host "   Servicio auditorio: $(if($servicioUp){'ACTIVO'}else{'INACTIVO'})" -ForegroundColor $(if($servicioUp){'Green'}else{'Red'})
Write-Host "   Base de datos: $(if($dbConectada){'CONECTADA'}else{'DESCONECTADA'})" -ForegroundColor $(if($dbConectada){'Green'}else{'Red'})
Write-Host "   Blockchain: $(if($blockchainHabilitado){'HABILITADO'}else{'DESHABILITADO'})" -ForegroundColor $(if($blockchainHabilitado){'Cyan'}else{'Yellow'})

Write-Host "`nCOMANDOS UTILES:" -ForegroundColor Yellow
Write-Host "   Ver logs servicio: docker-compose logs servicio-sela" -ForegroundColor White
Write-Host "   Ver logs PostgreSQL: docker-compose logs sela-postgres" -ForegroundColor White
Write-Host "   Conectar a PostgreSQL: docker exec -it sela-postgres psql -U auditoria_user -d auditoria_db" -ForegroundColor White
Write-Host "   Reiniciar servicio: docker-compose restart servicio-sela" -ForegroundColor White

Write-Host "`nURLS DEL SERVICIO:" -ForegroundColor Cyan
Write-Host "   Health: http://localhost:8002/health" -ForegroundColor White
Write-Host "   Info: http://localhost:8002/info" -ForegroundColor White
Write-Host "   Blockchain: http://localhost:8002/blockchain/verificar" -ForegroundColor White
Write-Host "   Registrar: POST http://localhost:8002/registrar" -ForegroundColor White

Write-Host "`nVERIFICACION COMPLETADA" -ForegroundColor Green