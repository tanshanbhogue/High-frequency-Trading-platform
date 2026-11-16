# HFT (High Frequency Trading) System

A DBMS course project: a trading database (orders, routes, trades, portfolios, securities, exchanges, market feed, algorithms) with a **MySQL** core, a **MongoDB** document store, **role-based access control inside the database**, and a **Next.js** web interface.

- **Author:** PES1UG24CS637
- **Repository:** https://github.com/tanshanbhogue/High-frequency-Trading-platform

## What is in the project

| Marking-scheme item | Where |
|---|---|
| ER diagram, relational schema | `docs/02_er_diagram.md`, `docs/03_relational_schema.md` |
| SQL DDL with constraints | `sql/01_HFT.sql`, `sql/02_schema_additions.sql` |
| NoSQL database + justification | `mongo/`, `docs/04_technology_justification.md` |
| DML, joins, nested / correlated / recursive queries | `sql/05_…`, `sql/06_…`, `sql/07_…` |
| Procedures, functions, triggers, CTEs | `sql/08_procedures.sql`, `sql/09_functions.sql`, `sql/10_triggers.sql`, `sql/07_…` |
| NoSQL Read / Update / Delete | `mongo/03_…`, `mongo/04_…`, `mongo/05_…` |
| Next.js interface + API | `app/` |
| Authentication + roles in the database | `app/src/lib/auth.js`, `app/src/middleware.js`, `sql/03_roles_and_grants.sql`, `docs/06_auth_and_roles.md` |
| Documentation, testing, demo | `docs/` (including `07_testing.md`, `08_demo_script.md`) |

## Prerequisites

| Software | Version | Needed for |
|---|---|---|
| MySQL Server | 8.0.16 or later | the database (CHECK constraints are only enforced from 8.0.16) |
| Node.js | 18 or later | the web app and test scripts |
| MongoDB Community Server + `mongosh` | 6.0 or later | the NoSQL part (the app still runs without it; only backtests and the event log are unavailable) |

## Quick start

Run everything from the **repository root**.

**1. MySQL** — creates the database, tables, data, roles, users, procedures, functions and triggers:
```bash
mysql -u root -p < sql/00_run_all.sql
```
(Linux with `auth_socket`: `sudo mysql < sql/00_run_all.sql`.)

**2. MongoDB** — start `mongod`, then:
```bash
mongosh --file mongo/00_run_all.js
```

**3. Configuration:**
```bash
cp .env.example .env          # Windows (cmd):  copy .env.example .env
```
The defaults already match the accounts created in step 1. Change `JWT_SECRET` to a long random string.

**4. Web app:**
```bash
cd app
npm install
npm run dev
```
Open <http://localhost:3000>.

## Demo logins

| Username | Password | Role | Notes |
|---|---|---|---|
| `admin` | `Admin@123` | ADMIN | everything, user management |
| `aarav` | `Trader@123` | TRADER | trader 1 — owns portfolios 1, 9, 10 |
| `rohan` | `Trader@123` | TRADER | trader 3 — owns portfolios 3, 8 |
| `auditor` | `Auditor@123` | AUDITOR | read-only, can see the audit log |

## Checking that it works

```bash
mysql -u root -p -e "USE HFT; SHOW FULL TABLES;"            # 16 tables + 2 views
mysql -u root -p -e "SELECT COUNT(*) FROM HFT.orders;"       # 17
cd app && npm run test:roles                                 # 26 database-permission checks
cd app && npm run test:api                                   # 44 end-to-end checks (app must be running)
```

## Demo scripts

| File | Run with |
|---|---|
| `sql/demo/HFT_demo.txt` — schema, queries, integrity rules | `mysql -u root -p --force < sql/demo/HFT_demo.txt` |
| `sql/demo/advanced_demo.txt` — roles, functions, procedures, triggers, CTEs, DML | `mysql -u root -p --force < sql/demo/advanced_demo.txt` |
| `mongo/mongo_demo.txt` — read / update / delete in MongoDB | paste the commands into `mongosh` |
| `docs/08_demo_script.md` | the 7-minute presentation plan |

Both SQL demo files start with `prompt PES1UG24CS637_HFT>\_` and `USE HFT;`. The `--force` flag lets them continue past the errors that are shown on purpose. Paste the commands one at a time in an interactive `mysql` session to present them.

## Reset

The test scripts create real rows. For a pristine database (**this deletes the whole HFT database**):
```bash
mysql -u root -p -e "DROP DATABASE IF EXISTS HFT;"
mysql -u root -p < sql/00_run_all.sql
mongosh --file mongo/00_run_all.js
```
Restart `npm run dev` afterwards.

## Folder structure
```
sql/      00_run_all.sql and numbered scripts 01–11, demo/
mongo/    00_run_all.js, 01–05 scripts, mongo_demo.txt
app/      Next.js app (src/app pages and API routes, src/lib, scripts/)
docs/     design, ER diagram, schema, justification, auth, testing, demo script
```
Run order of the SQL files: `01 → 02 → 03 → 04 → 08 → 09 → 10` (that is what `00_run_all.sql` does). `05`, `06`, `07` and `11` are demonstration files you can run at any time.

## Database roles

| MySQL role | Account | May do |
|---|---|---|
| `hft_admin` | `hft_admin_user` | everything in `HFT` |
| `hft_trader` | `hft_trader_user` | read business data; **write only through stored procedures**; no `app_users` / `audit_log` |
| `hft_auditor` | `hft_auditor_user` | read-only, including `audit_log` |
| `hft_auth` | `hft_auth_user` | login lookup only |

The passwords are development defaults in `sql/03_roles_and_grants.sql`, mirrored in `.env.example`. Change both for anything beyond your own machine.

## Key integrity rules

- An order can only be placed by a trader who owns the portfolio (composite FK `orders` → `portfolio_owners`).
- A trade can only happen on an exchange the order was routed to (composite FK `trades` → `order_routes`).
- Ownership of a portfolio can never exceed 100 % (trigger); the view `v_portfolio_ownership_check` confirms it equals 100 %.
- An order can only be routed where its security is listed; routed and executed quantities can never exceed the order quantity (triggers).
- Quotes need bid ≤ ask; prices and quantities cannot be negative (CHECK).
- Order and route status follow the trades automatically (trigger); every change to orders and trades is audited.

## Troubleshooting

| Problem | Fix |
|---|---|
| `ERROR 3819 / CHECK constraints ignored` | MySQL older than 8.0.16 — upgrade |
| `Table … already exists` when running `00_run_all.sql` | The database is already installed — see *Reset* |
| App shows `connect ECONNREFUSED 127.0.0.1:3306` | MySQL is not running |
| App shows `Access denied for user 'hft_…'` | `.env` passwords differ from `sql/03_roles_and_grants.sql`, or step 1 was not run |
| Login always fails with “Invalid username or password” | `sql/04_seed_app_users.sql` did not run (use `00_run_all.sql`), or the user was disabled |
| Backtests / event log say “MongoDB error” | `mongod` is not running or `MONGODB_URI` is wrong; the rest of the app is unaffected |
| `mongosh` command not found | Install MongoDB Shell from mongodb.com/try/download/shell |
| Port 3000 busy | `npm run dev -- -p 3001` |
