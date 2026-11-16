-- =====================================================================
-- 11_role_access_tests.sql  -  PROOF OF ROLE-BASED ACCESS CONTROL
-- (rubric 6/7). MySQL cannot switch login accounts inside one script, so
-- each block below is run in its OWN mysql session. Easiest way:
--     cd app && npm run test:roles        (runs every check below automatically)
-- or by hand, e.g.   mysql -u hft_trader_user -p HFT
-- Passwords are in sql/03_roles_and_grants.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A) hft_trader_user   (read everything except app_users/audit_log;
--                       write ONLY through the four stored procedures)
-- ---------------------------------------------------------------------
-- SELECT COUNT(*) FROM orders;                         -- OK  (17)
-- SELECT * FROM app_users;                             -- DENIED: SELECT command denied ... 'app_users'
-- SELECT * FROM audit_log;                             -- DENIED
-- INSERT INTO orders (...) VALUES (...);               -- DENIED: INSERT command denied ... 'orders'
-- UPDATE orders SET status='NEW' WHERE order_id=1;     -- DENIED
-- DELETE FROM trades WHERE trade_id=1;                 -- DENIED
-- DROP TABLE trades;                                   -- DENIED
-- CALL sp_validate_trade(1,1,1,NULL);                  -- DENIED: internal helper, not granted
-- CALL sp_place_order(3,3,4,NULL,'BUY','LIMIT',10,1440,'DAY',@o);   -- OK
-- CALL sp_place_order(2,3,4,NULL,'BUY','LIMIT',10,1440,'DAY',@o);   -- Trader is not an owner of this portfolio

-- ---------------------------------------------------------------------
-- B) hft_auditor_user  (strictly read-only, may read audit_log)
-- ---------------------------------------------------------------------
-- SELECT COUNT(*) FROM trades;                         -- OK
-- SELECT * FROM audit_log LIMIT 5;                     -- OK
-- SELECT fn_remaining_quantity(2);                     -- OK (read-only function)
-- SELECT * FROM app_users;                             -- DENIED
-- INSERT INTO exchanges (...) VALUES (...);            -- DENIED
-- UPDATE orders SET status='NEW' WHERE order_id=1;     -- DENIED
-- CALL sp_place_order(3,3,4,NULL,'BUY','LIMIT',10,1440,'DAY',@o);   -- DENIED: EXECUTE command denied

-- ---------------------------------------------------------------------
-- C) hft_auth_user  (login lookup only)
-- ---------------------------------------------------------------------
-- SELECT username, role FROM app_users;                -- OK
-- UPDATE app_users SET last_login = NOW() WHERE user_id=1;   -- OK (only this column)
-- UPDATE app_users SET role='ADMIN' WHERE user_id=2;   -- DENIED
-- SELECT * FROM orders;                                -- DENIED

-- ---------------------------------------------------------------------
-- D) hft_admin_user (everything)
-- ---------------------------------------------------------------------
-- SELECT COUNT(*) FROM app_users;                      -- OK
-- SELECT * FROM audit_log;                             -- OK
-- INSERT INTO exchanges (exchange_name, mic_code, country, timezone) VALUES ('X','XXXX','X','UTC');  -- OK
--   (then clean up: DELETE FROM exchanges WHERE mic_code='XXXX';)

-- ---------------------------------------------------------------------
-- Show what each role is granted (run as root)
-- ---------------------------------------------------------------------
SHOW GRANTS FOR 'hft_trader_user'@'localhost'  USING 'hft_trader';
SHOW GRANTS FOR 'hft_auditor_user'@'localhost' USING 'hft_auditor';
SHOW GRANTS FOR 'hft_auth_user'@'localhost'    USING 'hft_auth';
