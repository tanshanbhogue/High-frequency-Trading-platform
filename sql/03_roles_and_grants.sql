-- =====================================================================
-- 03_roles_and_grants.sql
-- Role-based access control INSIDE MySQL.
-- Run as root, after 01_HFT.sql and 02_schema_additions.sql:
--     mysql -u root -p < sql/03_roles_and_grants.sql
-- Safe to re-run (CREATE ... IF NOT EXISTS; GRANTs are idempotent).
--
-- The web app connects as the MySQL account that matches the logged-in
-- person's role, so MySQL itself refuses anything that role may not do.
--
--   hft_admin   : everything in HFT
--   hft_trader  : READ business data. All WRITES go through stored
--                 procedures (granted in 08_procedures.sql) so business
--                 rules and the audit trail cannot be bypassed.
--   hft_auditor : strictly READ-ONLY, including the audit trail
--   hft_auth    : login lookup only (reads app_users, stamps last_login)
--
-- Routine (procedure/function) grants are made at the end of
-- 08_procedures.sql and 09_functions.sql, because the routines must exist
-- before they can be granted.
--
-- DEV PASSWORDS BELOW MUST MATCH YOUR .env FILE. Change both for real use.
-- =====================================================================

USE HFT;

-- ---------------------------------------------------------------------
-- 1. Roles
-- ---------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'hft_admin', 'hft_trader', 'hft_auditor', 'hft_auth';

-- ---------------------------------------------------------------------
-- 2. ADMIN: everything in the HFT database
-- ---------------------------------------------------------------------
GRANT ALL PRIVILEGES ON HFT.* TO 'hft_admin';

-- ---------------------------------------------------------------------
-- 3. TRADER: read-only on business data. No access to app_users
--    (password hashes) or audit_log. No direct INSERT/UPDATE/DELETE:
--    writes happen only via sp_place_order, sp_route_order, sp_add_trade
--    and sp_cancel_order.
-- ---------------------------------------------------------------------
GRANT SELECT ON HFT.traders                     TO 'hft_trader';
GRANT SELECT ON HFT.algorithms                  TO 'hft_trader';
GRANT SELECT ON HFT.portfolios                  TO 'hft_trader';
GRANT SELECT ON HFT.securities                  TO 'hft_trader';
GRANT SELECT ON HFT.exchanges                   TO 'hft_trader';
GRANT SELECT ON HFT.orders                      TO 'hft_trader';
GRANT SELECT ON HFT.order_routes                TO 'hft_trader';
GRANT SELECT ON HFT.trades                      TO 'hft_trader';
GRANT SELECT ON HFT.market_feed_data            TO 'hft_trader';
GRANT SELECT ON HFT.algorithm_developers        TO 'hft_trader';
GRANT SELECT ON HFT.portfolio_owners            TO 'hft_trader';
GRANT SELECT ON HFT.portfolio_holdings          TO 'hft_trader';
GRANT SELECT ON HFT.security_listings           TO 'hft_trader';
GRANT SELECT ON HFT.algorithm_training_data     TO 'hft_trader';
GRANT SELECT ON HFT.v_portfolio_ownership_check TO 'hft_trader';
GRANT SELECT ON HFT.v_order_execution_summary   TO 'hft_trader';

-- ---------------------------------------------------------------------
-- 4. AUDITOR: strictly read-only, including the audit trail.
--    Still no access to app_users.
-- ---------------------------------------------------------------------
GRANT SELECT ON HFT.traders                     TO 'hft_auditor';
GRANT SELECT ON HFT.algorithms                  TO 'hft_auditor';
GRANT SELECT ON HFT.portfolios                  TO 'hft_auditor';
GRANT SELECT ON HFT.securities                  TO 'hft_auditor';
GRANT SELECT ON HFT.exchanges                   TO 'hft_auditor';
GRANT SELECT ON HFT.orders                      TO 'hft_auditor';
GRANT SELECT ON HFT.order_routes                TO 'hft_auditor';
GRANT SELECT ON HFT.trades                      TO 'hft_auditor';
GRANT SELECT ON HFT.market_feed_data            TO 'hft_auditor';
GRANT SELECT ON HFT.algorithm_developers        TO 'hft_auditor';
GRANT SELECT ON HFT.portfolio_owners            TO 'hft_auditor';
GRANT SELECT ON HFT.portfolio_holdings          TO 'hft_auditor';
GRANT SELECT ON HFT.security_listings           TO 'hft_auditor';
GRANT SELECT ON HFT.algorithm_training_data     TO 'hft_auditor';
GRANT SELECT ON HFT.audit_log                   TO 'hft_auditor';
GRANT SELECT ON HFT.v_portfolio_ownership_check TO 'hft_auditor';
GRANT SELECT ON HFT.v_order_execution_summary   TO 'hft_auditor';

-- ---------------------------------------------------------------------
-- 5. AUTH: used only by the login endpoint. Can read app_users and
--    stamp last_login; nothing else in the database.
-- ---------------------------------------------------------------------
GRANT SELECT ON HFT.app_users TO 'hft_auth';
GRANT UPDATE (last_login) ON HFT.app_users TO 'hft_auth';

-- ---------------------------------------------------------------------
-- 6. Login accounts the Next.js API connects with (one per role).
--    Created for "localhost", "127.0.0.1" and "::1" so the app connects
--    whichever way your computer resolves "localhost".
-- ---------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'hft_admin_user'@'localhost' IDENTIFIED BY 'AdminPass#2026';
CREATE USER IF NOT EXISTS 'hft_trader_user'@'localhost' IDENTIFIED BY 'TraderPass#2026';
CREATE USER IF NOT EXISTS 'hft_auditor_user'@'localhost' IDENTIFIED BY 'AuditorPass#2026';
CREATE USER IF NOT EXISTS 'hft_auth_user'@'localhost' IDENTIFIED BY 'AuthPass#2026';
CREATE USER IF NOT EXISTS 'hft_admin_user'@'127.0.0.1' IDENTIFIED BY 'AdminPass#2026';
CREATE USER IF NOT EXISTS 'hft_trader_user'@'127.0.0.1' IDENTIFIED BY 'TraderPass#2026';
CREATE USER IF NOT EXISTS 'hft_auditor_user'@'127.0.0.1' IDENTIFIED BY 'AuditorPass#2026';
CREATE USER IF NOT EXISTS 'hft_auth_user'@'127.0.0.1' IDENTIFIED BY 'AuthPass#2026';
CREATE USER IF NOT EXISTS 'hft_admin_user'@'::1' IDENTIFIED BY 'AdminPass#2026';
CREATE USER IF NOT EXISTS 'hft_trader_user'@'::1' IDENTIFIED BY 'TraderPass#2026';
CREATE USER IF NOT EXISTS 'hft_auditor_user'@'::1' IDENTIFIED BY 'AuditorPass#2026';
CREATE USER IF NOT EXISTS 'hft_auth_user'@'::1' IDENTIFIED BY 'AuthPass#2026';

GRANT 'hft_admin' TO 'hft_admin_user'@'localhost';
GRANT 'hft_trader' TO 'hft_trader_user'@'localhost';
GRANT 'hft_auditor' TO 'hft_auditor_user'@'localhost';
GRANT 'hft_auth' TO 'hft_auth_user'@'localhost';
GRANT 'hft_admin' TO 'hft_admin_user'@'127.0.0.1';
GRANT 'hft_trader' TO 'hft_trader_user'@'127.0.0.1';
GRANT 'hft_auditor' TO 'hft_auditor_user'@'127.0.0.1';
GRANT 'hft_auth' TO 'hft_auth_user'@'127.0.0.1';
GRANT 'hft_admin' TO 'hft_admin_user'@'::1';
GRANT 'hft_trader' TO 'hft_trader_user'@'::1';
GRANT 'hft_auditor' TO 'hft_auditor_user'@'::1';
GRANT 'hft_auth' TO 'hft_auth_user'@'::1';

-- Without this, roles are NOT active automatically after login.
SET DEFAULT ROLE 'hft_admin' TO 'hft_admin_user'@'localhost';
SET DEFAULT ROLE 'hft_trader' TO 'hft_trader_user'@'localhost';
SET DEFAULT ROLE 'hft_auditor' TO 'hft_auditor_user'@'localhost';
SET DEFAULT ROLE 'hft_auth' TO 'hft_auth_user'@'localhost';
SET DEFAULT ROLE 'hft_admin' TO 'hft_admin_user'@'127.0.0.1';
SET DEFAULT ROLE 'hft_trader' TO 'hft_trader_user'@'127.0.0.1';
SET DEFAULT ROLE 'hft_auditor' TO 'hft_auditor_user'@'127.0.0.1';
SET DEFAULT ROLE 'hft_auth' TO 'hft_auth_user'@'127.0.0.1';
SET DEFAULT ROLE 'hft_admin' TO 'hft_admin_user'@'::1';
SET DEFAULT ROLE 'hft_trader' TO 'hft_trader_user'@'::1';
SET DEFAULT ROLE 'hft_auditor' TO 'hft_auditor_user'@'::1';
SET DEFAULT ROLE 'hft_auth' TO 'hft_auth_user'@'::1';

FLUSH PRIVILEGES;

-- ---------------------------------------------------------------------
-- Verify: show what each role may do (routine grants appear after 08/09)
-- ---------------------------------------------------------------------
SHOW GRANTS FOR 'hft_trader_user'@'localhost'  USING 'hft_trader';
SHOW GRANTS FOR 'hft_auditor_user'@'localhost' USING 'hft_auditor';
