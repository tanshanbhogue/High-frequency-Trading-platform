# Authentication and role-based access control

## Roles
| Role | Web login | MySQL role / account | May do |
|---|---|---|---|
| **ADMIN** | `admin` | `hft_admin` / `hft_admin_user` | Everything, including user management and deleting backtests |
| **TRADER** | `aarav`, `rohan` | `hft_trader` / `hft_trader_user` | Read all business data; place/route/trade/cancel **their own** orders (only through stored procedures); edit backtests |
| **AUDITOR** | `auditor` | `hft_auditor` / `hft_auditor_user` | Read-only everywhere, including the audit log |
| (system) | — | `hft_auth` / `hft_auth_user` | Used only by the login endpoint: read `app_users`, update `last_login` |

## Login flow
1. Browser posts username + password to `POST /api/auth/login`.
2. The API looks the user up with the **restricted** `hft_auth_user` account, checks `is_active`, and compares the password with the stored **bcrypt** hash.
3. On success it signs a **JWT** (`username`, `role`, `traderId`, 8 h) and sets it in an **httpOnly** cookie.
4. `src/middleware.js` verifies the cookie for every page and API call: no valid session → redirect to `/login` (pages) or `401` (API). Pages restricted to some roles redirect others to the dashboard.
5. Each API handler calls `requireRole([...])` and returns `403` if the role is not allowed.

## Where access is really enforced (three layers)
1. **UI** hides links and buttons a role cannot use (convenience only).
2. **API** checks the role and, for traders, that the order belongs to them.
3. **MySQL** is the final authority: the API connects with the account that matches the role, so even a bug in layers 1–2 cannot exceed the role's privileges.

## Proof that MySQL itself refuses forbidden actions
`cd app && npm run test:roles` connects as each account and checks 26 statements, for example:

| Account | Statement | Result |
|---|---|---|
| trader | `SELECT * FROM app_users` | denied |
| trader | `INSERT INTO orders …` (direct) | denied |
| trader | `CALL sp_place_order(…)` on a portfolio they own | allowed |
| trader | `CALL sp_place_order(…)` on a portfolio they do not own | rejected by the procedure |
| auditor | `UPDATE orders …`, `DELETE`, `INSERT` | denied |
| auditor | `CALL sp_place_order(…)` | denied (`EXECUTE`) |
| auditor | `SELECT * FROM audit_log` | allowed |
| auth | `UPDATE app_users SET role='ADMIN'` | denied (only `last_login` is updatable) |

The grants are in `sql/03_roles_and_grants.sql` (tables) and the ends of `sql/08_procedures.sql` / `sql/09_functions.sql` (routines).

## Password handling
bcrypt (cost 10) via `bcryptjs`; hashes only in `app_users.password_hash`; the demo hashes in `sql/04_seed_app_users.sql` were produced with `node app/scripts/hash-password.js <password>`.
