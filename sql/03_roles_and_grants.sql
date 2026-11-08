-- =====================================================================
-- 03_roles_and_grants.sql
-- Role-based access control INSIDE MySQL.
-- Run as root, after 01_HFT.sql and 02_schema_additions.sql:
--     mysql -u root -p < sql/03_roles_and_grants.sql
-- Safe to re-run (CREATE ... IF NOT EXISTS, GRANTs are idempotent).
--
-- The web app connects as the MySQL user that matches the logged-in
-- person's role, so MySQL itself refuses anything the role may not do.
--
-- DEV PASSWORDS BELOW MUST MATCH YOUR .env FILE. Change both for real use.
-- =====================================================================

USE HFT;

-- ---------------------------------------------------------------------
-- 1. Roles
-- ---------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'hft_admin', 'hft_trader', 'hft_auditor';

-- ---------------------------------------------------------------------
-- 2. ADMIN: everything in the HFT database
-- ---------------------------------------------------------------------
GRANT ALL PRIVILEGES ON HFT.* TO 'hft_admin';

-- ---------------------------------------------------------------------
-- 3. TRADER: read business data, create/modify orders, routes and trades,
--    and run stored procedures. NO access to app_users (password hashes)
--    and NO direct access to audit_log. No DELETE, no DDL.
-- ---------------------------------------------------------------------
GRANT SELECT ON HFT.traders                  TO 'hft_trader';
GRANT SELECT ON HFT.algorithms               TO 'hft_trader';
GRANT SELECT ON HFT.portfolios               TO 'hft_trader';
GRANT SELECT ON HFT.securities               TO 'hft_trader';
GRANT SELECT ON HFT.exchanges                TO 'hft_trader';
GRANT SELECT ON HFT.market_feed_data         TO 'hft_trader';
GRANT SELECT ON HFT.algorithm_developers     TO 'hft_trader';
GRANT SELECT ON HFT.portfolio_owners         TO 'hft_trader';
GRANT SELECT ON HFT.portfolio_holdings       TO 'hft_trader';
GRANT SELECT ON HFT.security_listings        TO 'hft_trader';
GRANT SELECT ON HFT.algorithm_training_data  TO 'hft_trader';
GRANT SELECT ON HFT.v_portfolio_ownership_check TO 'hft_trader';
GRANT SELECT ON HFT.v_order_execution_summary   TO 'hft_trader';
GRANT SELECT, INSERT, UPDATE ON HFT.orders       TO 'hft_trader';
GRANT SELECT, INSERT, UPDATE ON HFT.order_routes TO 'hft_trader';
GRANT SELECT, INSERT, UPDATE ON HFT.trades       TO 'hft_trader';
GRANT EXECUTE ON HFT.* TO 'hft_trader';

-- ---------------------------------------------------------------------
-- 4. AUDITOR: strictly read-only, including the audit trail.
--    Still no access to app_users.
-- ---------------------------------------------------------------------
GRANT SELECT ON HFT.traders                  TO 'hft_auditor';
GRANT SELECT ON HFT.algorithms               TO 'hft_auditor';
GRANT SELECT ON HFT.portfolios               TO 'hft_auditor';
GRANT SELECT ON HFT.securities               TO 'hft_auditor';
GRANT SELECT ON HFT.exchanges                TO 'hft_auditor';
GRANT SELECT ON HFT.orders                   TO 'hft_auditor';
GRANT SELECT ON HFT.order_routes             TO 'hft_auditor';
GRANT SELECT ON HFT.trades                   TO 'hft_auditor';
GRANT SELECT ON HFT.market_feed_data         TO 'hft_auditor';
GRANT SELECT ON HFT.algorithm_developers     TO 'hft_auditor';
GRANT SELECT ON HFT.portfolio_owners         TO 'hft_auditor';
GRANT SELECT ON HFT.portfolio_holdings       TO 'hft_auditor';
GRANT SELECT ON HFT.security_listings        TO 'hft_auditor';
GRANT SELECT ON HFT.algorithm_training_data  TO 'hft_auditor';
GRANT SELECT ON HFT.audit_log                TO 'hft_auditor';
GRANT SELECT ON HFT.v_portfolio_ownership_check TO 'hft_auditor';
GRANT SELECT ON HFT.v_order_execution_summary   TO 'hft_auditor';

-- ---------------------------------------------------------------------
-- 3. Login accounts the Next.js API connects with (one per role)
-- ---------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'hft_admin_user'@'localhost'   IDENTIFIED BY 'AdminPass#2026';
CREATE USER IF NOT EXISTS 'hft_trader_user'@'localhost'  IDENTIFIED BY 'TraderPass#2026';
CREATE USER IF NOT EXISTS 'hft_auditor_user'@'localhost' IDENTIFIED BY 'AuditorPass#2026';

GRANT 'hft_admin'   TO 'hft_admin_user'@'localhost';
GRANT 'hft_trader'  TO 'hft_trader_user'@'localhost';
GRANT 'hft_auditor' TO 'hft_auditor_user'@'localhost';

-- Without this, roles are NOT active automatically after login.
SET DEFAULT ROLE 'hft_admin'   TO 'hft_admin_user'@'localhost';
SET DEFAULT ROLE 'hft_trader'  TO 'hft_trader_user'@'localhost';
SET DEFAULT ROLE 'hft_auditor' TO 'hft_auditor_user'@'localhost';

FLUSH PRIVILEGES;

-- ---------------------------------------------------------------------
-- Verify: show what each role may do
-- ---------------------------------------------------------------------
SHOW GRANTS FOR 'hft_trader_user'@'localhost'  USING 'hft_trader';
SHOW GRANTS FOR 'hft_auditor_user'@'localhost' USING 'hft_auditor';
