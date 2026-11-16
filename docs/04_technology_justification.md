# Technology justification

| Layer | Choice | Why |
|---|---|---|
| Core data | **MySQL 8** | Trading data is highly structured and must be correct: orders, routes and trades are tightly related, so we need foreign keys (including composite ones), `CHECK` constraints, transactions and triggers. MySQL 8 adds enforced `CHECK`, CTEs/recursive CTEs, window functions, roles (`CREATE ROLE`) and stored routines — everything this project demonstrates. |
| Flexible data | **MongoDB** | Backtest results and order event logs are *documents*: nested parameters/metrics, arrays (equity curve, tags) and event payloads whose fields differ by event type. Forcing that into tables would mean many sparse columns or JSON blobs. Documents can be stored, queried (`$gt`, `$unwind`, aggregation) and updated in place (`$set`, `$push`, `$pull`) without schema migrations. |
| Web app | **Next.js (App Router)** | One project for both the React user interface and the API (route handlers), so there is no separate backend server to deploy. Server-side code keeps database credentials out of the browser. |
| Auth | **bcrypt + signed JWT in an httpOnly cookie** | Passwords are never stored in clear; the session cookie cannot be read by page scripts. |
| Access control | **MySQL roles and accounts** | Authorization is enforced by the database itself, not only by the UI, so a bug or a crafted request cannot exceed a role's privileges. |

## How the two databases fit together
MySQL is the **system of record**. MongoDB stores supplementary documents that point at MySQL rows by id (`algorithm_id`, `order_id`). The application writes the order event log best-effort: if MongoDB is down, trading in MySQL still works.

## Why not one database for everything?
- Only-MySQL: the backtest and event data would need awkward JSON columns or many nullable columns, and aggregations over nested arrays are clumsy.
- Only-MongoDB: we would lose foreign keys, `CHECK` constraints, multi-row triggers and `GRANT`-level role control, which are the core of the correctness story for trades and ownership.
