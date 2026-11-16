# Demo script (about 7 minutes, follows the marking scheme)

**Before you start:** MySQL and MongoDB running, `cd app && npm run dev`, browser on <http://localhost:3000>, a terminal in the repository root with `mysql` and `mongosh` available.

| Min | Rubric item | What to do / say |
|---|---|---|
| 0:00 | 1 Design | Show `docs/02_er_diagram.md` (Mermaid renders on GitHub). Point at the two composite foreign keys: orders→portfolio_owners and trades→order_routes. Mention 8 entities, 6 junctions, 3NF. |
| 1:00 | 2 SQL creation | Terminal: `mysql -u root -p` → `prompt PES1UG24CS637_HFT>\_` → `USE HFT;` → `SHOW FULL TABLES;`. Show a rejected insert (demo 31 or 35 in `sql/demo/HFT_demo.txt`). |
| 2:00 | 3 SQL queries | Run demos from `sql/demo/advanced_demo.txt`: a correlated subquery (22), the recursive CTE (19), a window function (21). |
| 3:00 | 4 Advanced | Demo 8 (procedures: place → route → partial fill → filled), demo 13 (status-sync + audit trigger), demo 5 (functions). |
| 4:00 | 4 NoSQL | `mongosh` → `use HFT_docs` → demos 5, 8 (read + aggregation), 11–13 (update), 17 (delete) from `mongo/mongo_demo.txt`. Restore with `load('mongo/02_seed_data.js')`. |
| 5:00 | 5 + 6 Web, auth | Browser: log in as **aarav** (trader): place an order, route it, add two trades → watch status go PARTIALLY_FILLED → FILLED; open the event log (MongoDB). Show that **Audit log** and **Users** are not in his menu. |
| 6:00 | 6 RBAC | Log in as **auditor**: orders visible, no "New order", no buttons. Terminal: `cd app && npm run test:roles` (26 PASS) — "MySQL itself refuses, not just the UI". |
| 6:45 | 7 | Show the GitHub commit history and `docs/07_testing.md`. |

## If something goes wrong
- MongoDB down → the app still works; backtests / event log show an info message. Say so, continue.
- Need a clean database → `sql/00_run_all.sql` (see README, "Reset").
- Forgot a password → log in as `admin` → **Users** → *Reset password*.
