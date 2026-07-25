-- Ouro Fino RP - painel ESC, codigos de planos e checkout Premium manual.
-- O runtime dos resources tambem prepara estas estruturas de forma idempotente.

CREATE TABLE IF NOT EXISTS ouro_fino_plans (
    Passport INT NOT NULL,
    Plan VARCHAR(20) NOT NULL,
    AssignedBy INT NOT NULL DEFAULT 1,
    AssignedAt INT NOT NULL DEFAULT 0,
    ExpiresAt INT NOT NULL DEFAULT 0,
    PRIMARY KEY (Passport)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE ouro_fino_plans
    ADD COLUMN IF NOT EXISTS ExpiresAt INT NOT NULL DEFAULT 0 AFTER AssignedAt;

CREATE TABLE IF NOT EXISTS ouro_fino_redeem_codes (
    Code VARCHAR(64) NOT NULL,
    Passport INT NOT NULL,
    Plan VARCHAR(20) NOT NULL,
    DurationSeconds INT NOT NULL DEFAULT 0,
    Status VARCHAR(20) NOT NULL DEFAULT 'processing',
    RedeemedAt INT NOT NULL DEFAULT 0,
    PRIMARY KEY (Code,Passport),
    KEY idx_redeem_status (Code,Status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ouro_fino_premium_orders (
    OrderId VARCHAR(64) NOT NULL,
    Passport INT NOT NULL,
    Plan VARCHAR(20) NOT NULL,
    ExpectedAmountCents INT UNSIGNED NOT NULL,
    DurationSeconds INT UNSIGNED NOT NULL DEFAULT 2592000,
    Status VARCHAR(24) NOT NULL DEFAULT 'pending',
    CreatedAt INT NOT NULL,
    UpdatedAt INT NOT NULL,
    ExpiresAt INT NOT NULL,
    ApprovedBy INT NOT NULL DEFAULT 0,
    ProcessedAt INT NOT NULL DEFAULT 0,
    LastError VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (OrderId),
    KEY idx_premium_passport (Passport,Status),
    KEY idx_premium_status (Status,CreatedAt)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE ouro_fino_premium_orders
    ADD COLUMN IF NOT EXISTS DurationSeconds INT UNSIGNED NOT NULL DEFAULT 2592000 AFTER ExpectedAmountCents;
