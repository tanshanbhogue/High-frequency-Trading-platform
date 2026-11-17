
-- mysql -u root -p -e "DROP DATABASE IF EXISTS HFT;"
-- mysql -u root -p < sql/00_run_all.sql


SOURCE sql/01_HFT.sql;
SOURCE sql/02_schema_additions.sql;
SOURCE sql/03_roles_and_grants.sql;
SOURCE sql/04_seed_app_users.sql;
SOURCE sql/08_procedures.sql;
SOURCE sql/09_functions.sql;
SOURCE sql/10_triggers.sql;
