-- =====================================================================
-- 04_seed_app_users.sql
-- Demo logins for the web app. Passwords are stored as BCRYPT HASHES only.
-- (Hashes generated with: node app/scripts/hash-password.js <password>)
--
--   username   password      role     linked trader
--   admin      Admin@123     ADMIN    -
--   aarav      Trader@123    TRADER   1 Aarav Sharma  (owns portfolios 1, 9, 10)
--   rohan      Trader@123    TRADER   3 Rohan Mehta   (owns portfolios 3, 8)
--   auditor    Auditor@123   AUDITOR  -
--
-- Safe to re-run (existing usernames are left untouched).
-- =====================================================================
USE HFT;

INSERT IGNORE INTO app_users (username, password_hash, role, trader_id) VALUES
('admin',   '$2a$10$l5Yvxowp5uU/KtrgEXkfjeMxbemvbguJgLXS9rgTpLvBF4mrdfufW',   'ADMIN',   NULL),
('aarav',   '$2a$10$lNaxyNtK1qaGX7dpPeF7jOh6qbsK6Ne9dMq9q6J.DvZSEvHwDTD02',  'TRADER',  1),
('rohan',   '$2a$10$lNaxyNtK1qaGX7dpPeF7jOh6qbsK6Ne9dMq9q6J.DvZSEvHwDTD02',  'TRADER',  3),
('auditor', '$2a$10$pEcl3VD/QkdcMV2k8NwySu1ODY14WEfvfUb6GTqQr98Pbj2UjFcN6', 'AUDITOR', NULL);

SELECT user_id, username, role, trader_id, is_active, LEFT(password_hash, 7) AS hash_prefix FROM app_users;
