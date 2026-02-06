# verificar-auditoria.ps1
# Script de verificacion del servicio de auditoria con blockchain

function Verificar-ServicioAuditoria {
    param(
        [string]$BaseUrl = "http://localhost:8002",
        [switch]$Detallado = $false
    )
    
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "VERIFICACION SERVICIO AUDITORIA CON BLOCKCHAIN" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    # 1. Estado de contenedores
    Write-Host ""
    Write-Host "1. ESTADO DE CONTENEDORES" -ForegroundColor Yellow
    Write-Host "   CONTENEDORES SELA ACTIVOS:" -ForegroundColor White
    
    try {
        $containerOutput = docker ps --filter "name=sela" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" 2>$null
        if ($containerOutput) {
            Write-Host $containerOutput -ForegroundColor Green
        } else {
            Write-Host "   AVISO: No se encontraron contenedores SELA" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   AVISO: Error al consultar contenedores" -ForegroundColor Yellow
    }
    
    # 2. Verificar conectividad basica
    Write-Host ""
    Write-Host "2. CONECTIVIDAD BASICA" -ForegroundColor Yellow
    
    # Health check
    $healthOk = $false
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/health" -Method GET -TimeoutSec 10
        Write-Host "   OK HEALTH: Conectado" -ForegroundColor Green
        Write-Host "      Servicio: $($response.service)" -ForegroundColor Gray
        Write-Host "      Version: $($response.version)" -ForegroundColor Gray
        Write-Host "      DB Status: $($response.db_status)" -ForegroundColor Gray
        Write-Host "      Blockchain: $($response.blockchain_enabled)" -ForegroundColor Gray
        $healthOk = $true
    } catch {
        Write-Host "   ERROR HEALTH: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Info
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/info" -Method GET -TimeoutSec 5
        Write-Host "   OK INFO: Conectado" -ForegroundColor Green
        Write-Host "      Descripcion: $($response.description)" -ForegroundColor Gray
        Write-Host "      Blockchain habilitado: $($response.blockchain_enabled)" -ForegroundColor Gray
    } catch {
        Write-Host "   AVISO INFO: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # 3. Verificar base de datos
    Write-Host ""
    Write-Host "3. VERIFICACION BASE DE DATOS" -ForegroundColor Yellow
    
    $dbReady = $false
    try {
        # Probar conexion a PostgreSQL
        $testResult = docker exec sela-postgres pg_isready -U auditoria_user -d auditoria_db 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   OK PostgreSQL conectado y listo" -ForegroundColor Green
            $dbReady = $true
            
            # Verificar tablas
            Write-Host "   Tablas encontradas:" -ForegroundColor Gray
            
            $tablesQuery = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"
            $tables = docker exec sela-postgres psql -U auditoria_user -d auditoria_db -t -c $tablesQuery 2>$null
            
            if ($tables -and ($tables -match '\S')) {
                $tableList = $tables.Trim() -split "[\r\n]+" | Where-Object { $_ -match '\S' }
                foreach ($table in $tableList) {
                    Write-Host "      - $table" -ForegroundColor Gray
                }
            } else {
                Write-Host "      (ninguna tabla encontrada)" -ForegroundColor DarkGray
            }
            
            # Verificar columnas blockchain especificas
            Write-Host "   Columnas blockchain:" -ForegroundColor Gray
            
            $blockchainQuery = "SELECT table_name, column_name, data_type FROM information_schema.columns WHERE column_name LIKE '%hash%' OR column_name LIKE '%block%' OR table_name LIKE '%block%' ORDER BY table_name, ordinal_position;"
            $blockchainColumns = docker exec sela-postgres psql -U auditoria_user -d auditoria_db -t -c $blockchainQuery 2>$null
            
            if ($blockchainColumns -and ($blockchainColumns -match '\S')) {
                $columnList = $blockchainColumns.Trim() -split "[\r\n]+" | Where-Object { $_ -match '\S' }
                foreach ($col in $columnList) {
                    Write-Host "      $col" -ForegroundColor Gray
                }
            } else {
                Write-Host "      (ninguna columna blockchain encontrada)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "   AVISO PostgreSQL no esta listo" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   AVISO: No se pudo verificar PostgreSQL" -ForegroundColor Yellow
    }
    
    # 4. Prueba de endpoints
    Write-Host ""
    Write-Host "4. PRUEBA DE ENDPOINTS" -ForegroundColor Yellow
    
    $endpoints = @(
        @{Name="HEALTH"; Path="/health"; Method="GET"},
        @{Name="INFO"; Path="/info"; Method="GET"},
        @{Name="BLOCKCHAIN ESTADO"; Path="/blockchain/estado"; Method="GET"},
        @{Name="BLOCKCHAIN VERIFICAR"; Path="/blockchain/verificar"; Method="GET"},
        @{Name="LOGS"; Path="/logs?limite=3"; Method="GET"}
    )
    
    foreach ($endpoint in $endpoints) {
        $url = "$BaseUrl$($endpoint.Path)"
        Write-Host "   $($endpoint.Name)" -NoNewline
        Write-Host ""
        Write-Host "   URL: $url" -ForegroundColor DarkGray
        
        try {
            $response = Invoke-RestMethod -Uri $url -Method $endpoint.Method -TimeoutSec 10
            Write-Host "   OK Conectado" -ForegroundColor Green
        } catch {
            $statusCode = 0
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__
            }
            $message = $_.Exception.Message
            
            # Manejar codigos de error especificos
            if ($statusCode -eq 400 -and $endpoint.Name -eq "BLOCKCHAIN VERIFICAR") {
                Write-Host "   AVISO Error 400 (normal con cadena vacia o solo bloque genesis)" -ForegroundColor Yellow
            } elseif ($statusCode -eq 500) {
                Write-Host "   ERROR en el servidor remoto: ($statusCode) Error interno del servidor." -ForegroundColor Red
            } else {
                Write-Host "   ERROR: $message" -ForegroundColor Red
            }
        }
        Start-Sleep -Milliseconds 200
    }
    
    # 5. Prueba de registro con blockchain
    Write-Host ""
    Write-Host "5. PRUEBA DE REGISTRO CON BLOCKCHAIN" -ForegroundColor Yellow
    Write-Host "   Enviando registro de prueba..." -ForegroundColor Gray
    
    $testPayload = @{
        usuario = "verificacion_script"
        accion = "PRUEBA_VERIFICACION"
        detalles = "Registro de prueba desde script de verificacion"
        origen = "verificar-auditoria.ps1"
        metadata = @{
            timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            script = "verificar-auditoria"
            host = $env:COMPUTERNAME
        }
    }
    
    try {
        $jsonBody = $testPayload | ConvertTo-Json
        $registro = Invoke-RestMethod -Uri "$BaseUrl/registrar" -Method POST `
            -Body $jsonBody `
            -ContentType "application/json" `
            -TimeoutSec 10
        
        Write-Host "   OK Registro exitoso" -ForegroundColor Green
        Write-Host "      ID: $($registro.id)" -ForegroundColor Gray
        if ($registro.hash) {
            Write-Host "      Hash: $($registro.hash)" -ForegroundColor Gray
        }
        Write-Host "      Timestamp: $($registro.timestamp)" -ForegroundColor Gray
        
        if ($registro.block_hash) {
            Write-Host "      Hash del bloque: $($registro.block_hash)" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "   ERROR en registro: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # 6. Verificacion de registro en BD
    if ($dbReady) {
        Write-Host ""
        Write-Host "6. VERIFICACION DE REGISTRO EN BD" -ForegroundColor Yellow
        
        try {
            $ultimoRegistroQuery = "SELECT id, usuario, accion, timestamp, hash FROM log_entries ORDER BY timestamp DESC LIMIT 1;"
            $ultimoRegistro = docker exec sela-postgres psql -U auditoria_user -d auditoria_db -t -c $ultimoRegistroQuery 2>$null
            
            if ($ultimoRegistro -and ($ultimoRegistro -match '\S')) {
                Write-Host "   Ultimo registro en BD:" -ForegroundColor Green
                $lines = $ultimoRegistro.Trim() -split "[\r\n]+" | Where-Object { $_ -match '\S' }
                foreach ($line in $lines) {
                    Write-Host "      $line" -ForegroundColor Gray
                }
            } else {
                Write-Host "   INFO: No hay registros en la BD" -ForegroundColor Gray
            }
        } catch {
            Write-Host "   AVISO: No se pudo consultar registros" -ForegroundColor Yellow
        }
    }
    
    # 7. Verificacion cadena de bloques
    Write-Host ""
    Write-Host "7. VERIFICACION CADENA DE BLOQUES" -ForegroundColor Yellow
    
    if ($dbReady) {
        try {
            # Consulta simplificada
            $bloquesQuery = "SELECT index, hash, previous_hash FROM blocks ORDER BY index;"
            $bloques = docker exec sela-postgres psql -U auditoria_user -d auditoria_db -t -c $bloquesQuery 2>$null
            
            if ($bloques -and ($bloques -match '\S')) {
                Write-Host "   Bloques encontrados:" -ForegroundColor Green
                $lines = $bloques.Trim() -split "[\r\n]+" | Where-Object { $_ -match '\S' }
                
                if ($lines.Count -eq 1 -and $lines[0] -match '^\s*0\s*\|') {
                    Write-Host "      Solo bloque genesis presente" -ForegroundColor Yellow
                } else {
                    foreach ($line in $lines) {
                        # Formatear la salida
                        $parts = $line -split '\|' | ForEach-Object { $_.Trim() }
                        if ($parts.Count -ge 3) {
                            $index = $parts[0]
                            $hash = if ($parts[1].Length -gt 12) { $parts[1].Substring(0,12) + "..." } else { $parts[1] }
                            $prev = if ($parts[2]) { $parts[2].Substring(0,8) } else { "GENESIS" }
                            Write-Host "      Bloque $index : $hash (Prev: $prev)" -ForegroundColor Gray
                        }
                    }
                }
                
                # Contar bloques
                $numBloquesQuery = "SELECT COUNT(*) FROM blocks;"
                $numBloques = docker exec sela-postgres psql -U auditoria_user -d auditoria_db -t -c $numBloquesQuery 2>$null
                
                if ($numBloques -match '\d+') {
                    $numBloques = $numBloques.Trim()
                    Write-Host "   Cantidad de bloques: $numBloques" -ForegroundColor Cyan
                }
            } else {
                Write-Host "   INFO: No hay bloques en la cadena (solo genesis o vacia)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "   AVISO: No se pudo consultar la cadena de bloques" -ForegroundColor Yellow
        }
    }
    
    # 8. Resumen
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "RESUMEN DE VERIFICACION" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    Write-Host "   Servicio auditoria: " -NoNewline
    if ($healthOk) {
        Write-Host "OK ACTIVO" -ForegroundColor Green
    } else {
        Write-Host "ERROR INACTIVO" -ForegroundColor Red
    }
    
    Write-Host "   Base de datos: " -NoNewline
    if ($dbReady) {
        Write-Host "OK CONECTADA" -ForegroundColor Green
    } else {
        Write-Host "ERROR NO CONECTADA" -ForegroundColor Red
    }
    
    # Determinar estado blockchain
    $blockchainStatus = "DESCONOCIDO"
    try {
        $estado = Invoke-RestMethod -Uri "$BaseUrl/blockchain/estado" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($estado -and $estado.enabled -eq $true) {
            $blockchainStatus = "OK HABILITADO"
            if ($estado.blocks -and $estado.blocks -gt 1) {
                $blockchainStatus += " ($($estado.blocks) bloques)"
            }
        } else {
            $blockchainStatus = "AVISO DESHABILITADO/PARCIAL"
        }
    } catch {
        $blockchainStatus = "ERROR NO RESPONDE"
    }
    
    Write-Host "   Blockchain: $blockchainStatus"
    
    Write-Host ""
    Write-Host "COMANDOS UTILES:" -ForegroundColor Yellow
    Write-Host "   Ver logs servicio: docker-compose logs servicio-auditoria" -ForegroundColor Gray
    Write-Host "   Ver logs PostgreSQL: docker-compose logs sela-postgres" -ForegroundColor Gray
    Write-Host "   Conectar a PostgreSQL: docker exec -it sela-postgres psql -U auditoria_user -d auditoria_db" -ForegroundColor Gray
    Write-Host "   Reiniciar servicio: docker-compose restart servicio-auditoria" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "URLS DEL SERVICIO:" -ForegroundColor Yellow
    Write-Host "   Health: http://localhost:8002/health" -ForegroundColor Gray
    Write-Host "   Info: http://localhost:8002/info" -ForegroundColor Gray
    Write-Host "   Blockchain: http://localhost:8002/blockchain/verificar" -ForegroundColor Gray
    Write-Host "   Registrar: POST http://localhost:8002/registrar" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "VERIFICACION COMPLETADA" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    return $healthOk -and $dbReady
}

# Ejecutar si se llama directamente
if ($MyInvocation.InvocationName -eq '.' -or $PSCommandPath -eq $MyInvocation.MyCommand.Path) {
    Verificar-ServicioAuditoria
}