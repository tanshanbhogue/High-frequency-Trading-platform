# Design decisions and changes from the original ER diagram

The original eight entities and six junction tables, their attributes and relationships were all kept. These additions and interpretation choices were made:

| # | Change | Why | Effect |
|---|---|---|---|
| 1 | Redundant single-column FKs kept next to the composite ones (`orders.trader_id`, `orders.portfolio_id`, `trades.order_id`, `trades.exchange_id`) | The specification lists both forms; makes each relationship explicit | No extra data; a few extra constraints |
| 2 | Ownership: `CHECK 0 < pct ≤ 100` per row + trigger "sum ≤ 100" + view `v_portfolio_ownership_check` for "= 100" | A row-level trigger cannot require "= 100" while owners are inserted one by one | Over-allocation is impossible; incomplete portfolios are visible in the view |
| 3 | Routing triggers (security must be listed on the exchange; Σ routed ≤ order qty) | A foreign key cannot express "this exchange lists this order's security" without duplicating `security_id` (a 3NF violation) | Prevents routing Infosys to NASDAQ |
| 4 | Trade triggers (Σ executed ≤ order qty and ≤ routed qty on that exchange) | A `CHECK` cannot sum other rows | Over-execution impossible |
| 5 | `limit_price` doubles as the stop trigger price for `STOP` orders | Keeps the original column list | A separate `stop_price` would be cleaner in a larger system |
| 6 | `security_listings` has its own surrogate key `listing_id` | `market_feed_data` references one specific listing | Quote rows do not repeat security + exchange |
| 7 | `DATETIME(3)` for feed / route / execution times; all times in UTC | Millisecond precision suits HFT; avoids time-zone confusion | — |
| 8 | **NEW** `traders.reports_to` (self-FK) | Gives the recursive CTE a real hierarchy (desk structure) | Nullable; manager deletion sets reports to NULL |
| 9 | **NEW** `app_users` | Web login with bcrypt hashes and a role | A trigger requires TRADER users to link to a trader |
| 10 | **NEW** `audit_log` + triggers on `orders` and `trades` | Who changed what and when | Written only by triggers; no application account may insert into it |
| 11 | **NEW** stored procedures `sp_place_order`, `sp_route_order`, `sp_add_trade`, `sp_cancel_order` | One place for business validation; trader accounts can write only through them | Trader role has no `INSERT`/`UPDATE` on tables |
| 12 | **NEW** trigger `trg_trades_sync_status` | Stored `orders.status` must follow the trades | Order and route status update automatically |
| 13 | **NEW** functions `fn_executed_quantity`, `fn_remaining_quantity`, `fn_order_vwap`, `fn_portfolio_value` | Derived values are calculated, not stored (3NF) | Reusable in queries and reports |
| 14 | **NEW** MongoDB `HFT_docs` (`backtest_results`, `order_events`) | Document-shaped data (rubric: NoSQL) | Linked to MySQL by id only |

## Rules that are documented, not enforced
- A trader cannot report to themselves (`reports_to <> trader_id`): MySQL forbids a `CHECK` on a column that has a foreign-key action, so the seed data respects it and procedures should too.
- Commission is in the trade's local currency; there is no FX table, so `fn_portfolio_value` adds raw numbers for a portfolio that mixes currencies.
- `sp_cancel_order` starts its own transaction, so it must not be called inside an open transaction.

## Known limitations
- Sample ISINs look realistic but their check digits were not verified.
- Seed order 6 sells NVIDIA from a portfolio that holds none; the new procedures do not check holdings before a sell (a possible extension).
