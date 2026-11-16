# Testing

How to re-run everything yourself is in the right-hand column. Results below were recorded during development on MySQL 8.0.46 and Node 22.

## 1. Database constraints (rubric 2) — `sql/demo/HFT_demo.txt`, Section C
Run: `mysql -u root -p --force < sql/demo/HFT_demo.txt` — every statement in Section C must fail with the error shown.

| # | Attempt | Expected rejection | Result |
|---|---|---|---|
| 31 | Order by a trader who does not own the portfolio | FK `fk_orders_owner` (1452) | PASS |
| 32/33 | Ownership above 100 % | trigger message | PASS |
| 34 | Execute more than the order quantity | trigger message | PASS |
| 35 | Trade on an exchange the order was never routed to | FK `fk_trades_route` (1452) | PASS |
| 36 | Route a security to an exchange that does not list it | trigger message | PASS |
| 37 | Crossed quote (bid > ask) | `chk_feed_prices` (3819) | PASS |
| 38 | Negative holding quantity | `chk_ph_qty` (3819) | PASS |
| 39 | MARKET order that carries a price | `chk_orders_price` (3819) | PASS |
| 40 | Duplicate trader email | UNIQUE (1062) | PASS |
| 41 | Delete a trader who owns portfolios | `ON DELETE RESTRICT` (1451) | PASS |
| 42 | Duplicate algorithm name + version | UNIQUE (1062) | PASS |

## 2. Procedures, functions and triggers (rubric 4) — `sql/demo/advanced_demo.txt`
Run: `mysql -u root -p --force < sql/demo/advanced_demo.txt` — exactly **7** errors are expected (marked "EXPECTED ERROR").

| Demo | What is checked | Result |
|---|---|---|
| 8 | place → route → partial fill → full fill with procedures | PASS (status PENDING → PARTIALLY_FILLED → FILLED) |
| 9, 10, 11 | procedure validation: non-owner, retired algorithm, price above BUY limit | PASS (rejected) |
| 13 | status-sync trigger + audit triggers write rows with `@app_user` | PASS |
| 14, 15, 16, 17 | ownership, routing, quantity and app_users triggers | PASS (rejected) |
| 18–24 | CTE, recursive CTEs, window function, correlated / nested queries | PASS (return rows) |
| 25 | DML script (insert/update/delete/savepoint/rollback) | PASS (data unchanged afterwards) |

## 3. Role-based access control (rubric 6) — `cd app && npm run test:roles`
**26 / 26 PASS.** Trader: 11 checks (read allowed; `app_users`, `audit_log`, direct writes, `DROP`, internal procedure denied; owned-portfolio procedure call allowed; non-owner call rejected; function allowed). Auditor: 9 checks (read allowed; every write and procedure call denied). Auth account: 4 checks. Admin: 3 checks.

## 4. API end-to-end (rubric 5, 6) — start the app, then `cd app && npm run test:api`
**44 / 44 PASS** — authentication (6), role restrictions (6), trading workflow (13: order, wrong portfolio, wrong exchange, over-routing, other trader blocked, price above limit, partial fill, over-execution, full fill, route status sync, cancel a filled order), cancel workflow (3), audit trail (1), 13 SQL reports run as the read-only auditor (2), admin user management (5), MongoDB (8).

> This test creates a few test orders and trades. To get a pristine database again, follow *Reset* in the README.

## 5. MongoDB (rubric 2, 4) — `mongo/*.js`, `mongo/mongo_demo.txt`
| Script | Checks | Result in development |
|---|---|---|
| `01_create_collections.js`, `02_seed_data.js` | 2 collections, indexes, 16 backtest runs, 77 events | PASS |
| `03_read_queries.js` | R1–R11: filters, projection, array/nested queries, `$unwind`, aggregation | R1–R6, R8, R10, R11 verified; **R7, R9 (`$avg`, `$push` aggregation) should be confirmed on your MongoDB** |
| `04_update_operations.js` | `$set`, `$inc`, `$addToSet`, `$push`, `$pull`, `$rename`, upsert | PASS |
| `05_delete_operations.js` | `deleteOne`, `deleteMany`, event-log delete | D1–D4 PASS; **D5 (TTL index) should be confirmed on your MongoDB** |

The development machine had no MongoDB server, so these scripts were run against a MongoDB-compatible server that does not implement a few operators (`$avg`, `$size`, TTL indexes, `$jsonSchema` validators). The syntax used is standard MongoDB. **Please run the scripts once on your real MongoDB and record the outcome here.**

## 6. Web pages
Verified in development: production build compiles; every page returns 200 / the correct redirect for each role (e.g. the auditor is redirected away from `/orders/new` and `/admin/users`, a trader away from `/audit`); every page component renders with real API data.
**Not automated** (no browser in the development environment) — tick these by hand:

| ✔ | Check |
|---|---|
| ☐ | Login with wrong password shows an error; correct login lands on the dashboard |
| ☐ | Dashboard shows counts, status badges, volume bars, latest trades |
| ☐ | **aarav**: New order → portfolio list shows only portfolios 1, 9, 10 → order created |
| ☐ | Order detail: route to NSE, then record two trades → status PARTIALLY_FILLED → FILLED |
| ☐ | Order detail: the event log (MongoDB) lists the new events |
| ☐ | **aarav** menu has no *Audit log* / *Users*; typing `/audit` redirects to the dashboard |
| ☐ | **auditor**: no *New order*; order detail shows "read-only" |
| ☐ | **admin**: Users → create a user, disable it, reset its password |
| ☐ | Algorithms: *Mark reviewed*, *+ tag* (trader/admin); *Delete* only for admin |
| ☐ | SQL reports: all 13 run; recursive CTE shows the org chart |
| ☐ | Audit log lists the actions you just did, with your username |
