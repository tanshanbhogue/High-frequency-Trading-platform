-- =====================================================================
-- 02_schema_additions.sql
-- Schema additions on top of 01_HFT.sql
--   1. traders.reports_to   -> desk hierarchy (used by the recursive CTE)
--   2. app_users            -> web-app logins (authentication)
--   3. audit_log            -> filled by triggers (see 10_triggers.sql)
-- Run ONCE, after 01_HFT.sql:   mysql -u root -p < sql/02_schema_additions.sql
-- (ALTER TABLE ... ADD COLUMN fails if run a second time.)
-- =====================================================================

USE HFT;

-- ---------------------------------------------------------------------
-- 1. Desk hierarchy: every trader may report to exactly one other trader.
--    NULL = top of the hierarchy. Deleting a manager keeps their reports.
--    (Rule "a trader cannot report to themselves" is NOT a CHECK, because
--     MySQL forbids CHECK on columns that have FK referential actions.
--     The data below respects it; the app/procedures must as well.)
-- ---------------------------------------------------------------------
ALTER TABLE traders
    ADD COLUMN reports_to INT NULL AFTER role,
    ADD KEY idx_traders_reports_to (reports_to),
    ADD CONSTRAINT fk_traders_reports_to FOREIGN KEY (reports_to)
        REFERENCES traders (trader_id) ON DELETE SET NULL ON UPDATE CASCADE;

-- Two heads (3 and 8), four levels deep: 12 -> 5 -> 1 -> 3
UPDATE traders SET reports_to = NULL WHERE trader_id IN (3, 8);
UPDATE traders SET reports_to = 3  WHERE trader_id IN (1, 2, 9);
UPDATE traders SET reports_to = 1  WHERE trader_id = 5;
UPDATE traders SET reports_to = 2  WHERE trader_id IN (4, 10);
UPDATE traders SET reports_to = 5  WHERE trader_id = 12;
UPDATE traders SET reports_to = 8  WHERE trader_id IN (6, 7, 11);

-- ---------------------------------------------------------------------
-- 2. Application users (web login). Passwords are stored ONLY as bcrypt
--    hashes (never plain text). Rows are inserted by 04_seed_app_users.sql.
--    A TRADER login is linked to a real trader row; ADMIN/AUDITOR need not be.
-- ---------------------------------------------------------------------
CREATE TABLE app_users (
    user_id       INT          NOT NULL AUTO_INCREMENT,
    username      VARCHAR(50)  NOT NULL,
    password_hash VARCHAR(100) NOT NULL,
    role          VARCHAR(10)  NOT NULL,
    trader_id     INT          NULL,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login    DATETIME     NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_app_users_username (username),
    KEY idx_app_users_trader (trader_id),
    CONSTRAINT fk_app_users_trader FOREIGN KEY (trader_id)
        REFERENCES traders (trader_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_app_users_role CHECK (role IN ('ADMIN', 'TRADER', 'AUDITOR'))
) ENGINE=InnoDB;

-- Rule "a TRADER login must be linked to a trader row" cannot be a CHECK
-- (trader_id has a foreign-key action), so a trigger enforces it.
DELIMITER $$
CREATE TRIGGER trg_app_users_before_insert BEFORE INSERT ON app_users
FOR EACH ROW
BEGIN
    IF NEW.role = 'TRADER' AND NEW.trader_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A TRADER login must be linked to a trader_id';
    END IF;
END$$
CREATE TRIGGER trg_app_users_before_update BEFORE UPDATE ON app_users
FOR EACH ROW
BEGIN
    IF NEW.role = 'TRADER' AND NEW.trader_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A TRADER login must be linked to a trader_id';
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- 3. Audit trail. old_values / new_values hold the row as JSON.
--    Only triggers write here; no application role gets INSERT on it.
-- ---------------------------------------------------------------------
CREATE TABLE audit_log (
    audit_id    BIGINT       NOT NULL AUTO_INCREMENT,
    table_name  VARCHAR(40)  NOT NULL,
    action      VARCHAR(6)   NOT NULL,
    row_key     VARCHAR(60)  NOT NULL,
    old_values  JSON         NULL,
    new_values  JSON         NULL,
    changed_by  VARCHAR(100) NOT NULL,
    changed_at  DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (audit_id),
    KEY idx_audit_table_key (table_name, row_key),
    KEY idx_audit_changed_at (changed_at),
    CONSTRAINT chk_audit_action CHECK (action IN ('INSERT', 'UPDATE', 'DELETE'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Quick check
-- ---------------------------------------------------------------------
SELECT trader_id, full_name, role, reports_to FROM traders ORDER BY trader_id;
SHOW TABLES LIKE 'app_users';
SHOW TABLES LIKE 'audit_log';
