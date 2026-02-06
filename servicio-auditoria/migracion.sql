-- 1. Añadir columnas blockchain a la tabla existente
ALTER TABLE auditoria_logs 
ADD COLUMN IF NOT EXISTS blockchain_hash VARCHAR(128),
ADD COLUMN IF NOT EXISTS blockchain_block_id INTEGER,
ADD COLUMN IF NOT EXISTS blockchain_verified BOOLEAN DEFAULT FALSE;

-- 2. Crear tabla para hashes de blockchain
CREATE TABLE IF NOT EXISTS blockchain_hashes (
    id SERIAL PRIMARY KEY,
    block_id INTEGER NOT NULL,
    block_hash VARCHAR(128) NOT NULL,
    previous_hash VARCHAR(128),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    transactions_count INTEGER DEFAULT 0,
    UNIQUE(block_id)
);