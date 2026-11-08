# HFT (High Frequency Trading) System

A DBMS course project: a trading database (orders, routes, trades, portfolios,
securities, exchanges, market feed, algorithms) with a MySQL core, a MongoDB
document store, role-based access control inside the database, and a Next.js
web interface.

- **Author:** PES1UG24CS637
- **Repository:** https://github.com/tanshanbhogue/High-frequency-Trading-platform

## Tech stack

| Layer | Technology | Used for |
|---|---|---|
| Relational DB | MySQL 8.0.16+ | Traders, portfolios, securities, exchanges, orders, routes, trades, market feed, users, audit log |
| Document DB | MongoDB (local) | Algorithm backtest results, order event log |
| Web app + API | Next.js (route handlers) | UI, login, REST API to both databases |

## Project status

- [x] Schema, constraints, triggers and dummy data (`sql/01_HFT.sql`)
- [x] Schema additions: desk hierarchy, app users, audit table (`sql/02`)
- [x] Roles and privileges in MySQL (`sql/03`)
- [ ] App user seed, DML, queries, CTEs (`sql/04` to `sql/07`)
- [ ] Procedures, functions, new triggers (`sql/08` to `sql/10`)
- [ ] MongoDB collections and RUD operations (`mongo/`)
- [ ] Next.js interface, login and role enforcement (`app/`)
- [ ] Final documentation, testing evidence and demo (`docs/`)

## Folder structure

```
README.md
.env.example        template for configuration (copy to .env)
docs/               design, ER diagram, schema, justification, testing, demo script
sql/                numbered MySQL scripts (run in order) + demo/ scripts
mongo/              MongoDB scripts (collections, seed, read/update/delete)
app/                Next.js application (see app/SETUP.md)
```

## Prerequisites

- MySQL Server 8.0.16 or later (CHECK constraints are only enforced from 8.0.16)
- MongoDB Community Server (needed from the MongoDB step onwards)
- Node.js 18+ (needed for the web app)

## Setup: MySQL

Run the scripts from the repository root, **in this order**, as the MySQL
`root` user. Each prompts for the root password.

```bash
mysql -u root -p < sql/01_HFT.sql                 # database, tables, triggers, dummy data
mysql -u root -p < sql/02_schema_additions.sql    # reports_to, app_users, audit_log  (run once)
mysql -u root -p < sql/03_roles_and_grants.sql    # roles + 3 login users             (re-runnable)
```

Check that it worked:

```sql
SHOW DATABASES;                 -- HFT is listed
USE HFT;
SHOW FULL TABLES;               -- 16 tables + 2 views
SELECT COUNT(*) FROM orders;    -- 17
```

To start again from scratch (**deletes the whole database**):

```sql
DROP DATABASE IF EXISTS HFT;
```
then re-run the three scripts above. (Re-running `01` on an existing database
fails with "table already exists" and changes nothing.)

## Database roles

The web app connects to MySQL as the account that matches the logged-in
person's role, so MySQL itself refuses anything that role may not do.

| MySQL role | Login account | May do |
|---|---|---|
| `hft_admin` | `hft_admin_user` | Everything in the `HFT` database |
| `hft_trader` | `hft_trader_user` | Read business data; insert/update orders, order routes and trades; run stored procedures. No delete, no DDL, cannot see `app_users` or `audit_log` |
| `hft_auditor` | `hft_auditor_user` | Read-only, including `audit_log`. Cannot see `app_users` |

The three passwords are development defaults defined in
`sql/03_roles_and_grants.sql` and mirrored in `.env.example`. Change both if
you ever use this outside your own machine.

## Configuration (`.env`)

```bash
cp .env.example .env
```

Then edit `.env` if you changed any password in `sql/03_roles_and_grants.sql`,
and replace `JWT_SECRET` with a long random string. **Never commit `.env`**
(it is in `.gitignore`).

## Setup: MongoDB and the web app

Coming with the next steps. See `mongo/` for the collection scripts and
`app/SETUP.md` for how to scaffold and run the Next.js app.

## Demo logins

To be added once `sql/04_seed_app_users.sql` exists (one user per role).

## Key integrity rules

- An order can only be placed by a trader who owns the portfolio
  (composite foreign key `orders` to `portfolio_owners`).
- A trade can only happen on an exchange the order was routed to
  (composite foreign key `trades` to `order_routes`).
- Total ownership of a portfolio can never exceed 100% (trigger), and the view
  `v_portfolio_ownership_check` confirms it equals exactly 100%.
- An order can only be routed to an exchange where its security is listed, and
  routed/executed quantities can never exceed the order quantity (triggers).
- Quotes must have bid <= ask; prices and quantities cannot be negative (CHECK).

## Documentation

See the `docs/` folder: design overview, ER diagram, relational schema,
technology justification, design changes, authentication and roles, testing,
demo script and contribution log.
