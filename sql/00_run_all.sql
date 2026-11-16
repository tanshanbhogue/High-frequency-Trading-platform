-- =====================================================================
-- 00_run_all.sql  -  ONE-COMMAND SETUP of the whole MySQL side
-- Run from the REPOSITORY ROOT (paths below are relative to it):
--     mysql -u root -p < sql/00_run_all.sql
-- Fails with "table already exists" if HFT is already installed. To start
-- over first run:  mysql -u root -p -e "DROP DATABASE IF EXISTS HFT;"
-- =====================================================================
SOURCE sql/01_HFT.sql;
SOURCE sql/02_schema_additions.sql;
SOURCE sql/03_roles_and_grants.sql;
SOURCE sql/04_seed_app_users.sql;
SOURCE sql/08_procedures.sql;
SOURCE sql/09_functions.sql;
SOURCE sql/10_triggers.sql;
