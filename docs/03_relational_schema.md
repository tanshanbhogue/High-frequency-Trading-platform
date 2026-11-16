# Relational schema

_Generated from the live MySQL database (`information_schema`), so it always matches `sql/01_HFT.sql` + `sql/02_schema_additions.sql`._

Notation: **PK** primary key, **FK** foreign key (`ON DELETE` / `ON UPDATE` action), **UQ** unique key, **CK** check constraint.

## Summary

| Table | Kind | Columns | Primary key |
|---|---|---|---|
| `algorithm_developers` | Junction (Trader ↔ Algorithm, M:N) | 4 | trader_id, algorithm_id |
| `algorithm_training_data` | Junction (Algorithm ↔ Market feed, M:N) | 4 | algorithm_id, feed_id |
| `algorithms` | Entity | 8 | algorithm_id |
| `app_users` | Supporting (web-app logins) | 8 | user_id |
| `audit_log` | Supporting (written by triggers) | 8 | audit_id |
| `exchanges` | Entity | 6 | exchange_id |
| `market_feed_data` | Entity | 10 | feed_id |
| `order_routes` | Junction (Order ↔ Exchange, M:N) | 6 | order_id, exchange_id |
| `orders` | Entity | 13 | order_id |
| `portfolio_holdings` | Junction (Portfolio ↔ Security, M:N) | 5 | portfolio_id, security_id |
| `portfolio_owners` | Junction (Trader ↔ Portfolio, M:N) | 4 | trader_id, portfolio_id |
| `portfolios` | Entity | 6 | portfolio_id |
| `securities` | Entity | 7 | security_id |
| `security_listings` | Junction (Security ↔ Exchange, M:N) | 7 | listing_id |
| `traders` | Entity | 8 | trader_id |
| `trades` | Entity | 9 | trade_id |

## `algorithm_developers`

_Junction (Trader ↔ Algorithm, M:N)_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| trader_id | int | NOT NULL |  | PK |
| algorithm_id | int | NOT NULL |  | PK |
| contribution_role | varchar(30) | NOT NULL |  |  |
| developed_at | date | NOT NULL |  |  |

**PK:** (trader_id, algorithm_id) — composite key

**Foreign keys**

- `fk_ad_algorithm`: (algorithm_id) → `algorithms` (algorithm_id) — ON DELETE CASCADE, ON UPDATE CASCADE
- `fk_ad_trader`: (trader_id) → `traders` (trader_id) — ON DELETE RESTRICT, ON UPDATE CASCADE

## `algorithm_training_data`

_Junction (Algorithm ↔ Market feed, M:N)_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| algorithm_id | int | NOT NULL |  | PK |
| feed_id | bigint | NOT NULL |  | PK |
| data_split | varchar(10) | NOT NULL |  |  |
| added_at | datetime | NOT NULL | CURRENT_TIMESTAMP DEFAULT_GENERATED |  |

**PK:** (algorithm_id, feed_id) — composite key

**Foreign keys**

- `fk_atd_algorithm`: (algorithm_id) → `algorithms` (algorithm_id) — ON DELETE CASCADE, ON UPDATE CASCADE
- `fk_atd_feed`: (feed_id) → `market_feed_data` (feed_id) — ON DELETE CASCADE, ON UPDATE CASCADE

**Check constraints**

- `chk_atd_split`: `(`data_split` in ('TRAINING','VALIDATION','TESTING'))`

## `algorithms`

_Entity_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| algorithm_id | int | NOT NULL | auto_increment | PK |
| algorithm_name | varchar(80) | NOT NULL |  |  |
| version | varchar(20) | NOT NULL |  |  |
| strategy_type | varchar(50) | NOT NULL |  |  |
| programming_language | varchar(30) | NOT NULL |  |  |
| status | varchar(12) | NOT NULL | DEVELOPMENT |  |
| description | varchar(500) | yes |  |  |
| created_at | datetime | NOT NULL | CURRENT_TIMESTAMP DEFAULT_GENERATED |  |

**PK:** (algorithm_id)

**Unique keys**

- `uq_algorithms_name_version`: (algorithm_name,version)

**Check constraints**

- `chk_algorithms_status`: `(`status` in ('DEVELOPMENT','TESTING','ACTIVE','RETIRED'))`

## `app_users`

_Supporting (web-app logins)_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| user_id | int | NOT NULL | auto_increment | PK |
| username | varchar(50) | NOT NULL |  |  |
| password_hash | varchar(100) | NOT NULL |  |  |
| role | varchar(10) | NOT NULL |  |  |
| trader_id | int | yes |  |  |
| is_active | tinyint(1) | NOT NULL | 1 |  |
| created_at | datetime | NOT NULL | CURRENT_TIMESTAMP DEFAULT_GENERATED |  |
| last_login | datetime | yes |  |  |

**PK:** (user_id)

**Foreign keys**

- `fk_app_users_trader`: (trader_id) → `traders` (trader_id) — ON DELETE RESTRICT, ON UPDATE CASCADE

**Unique keys**

- `uq_app_users_username`: (username)

**Check constraints**

- `chk_app_users_role`: `(`role` in ('ADMIN','TRADER','AUDITOR'))`

## `audit_log`

_Supporting (written by triggers)_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| audit_id | bigint | NOT NULL | auto_increment | PK |
| table_name | varchar(40) | NOT NULL |  |  |
| action | varchar(6) | NOT NULL |  |  |
| row_key | varchar(60) | NOT NULL |  |  |
| old_values | json | yes |  |  |
| new_values | json | yes |  |  |
| changed_by | varchar(100) | NOT NULL |  |  |
| changed_at | datetime(3) | NOT NULL | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

**PK:** (audit_id)

**Check constraints**

- `chk_audit_action`: `(`action` in ('INSERT','UPDATE','DELETE'))`

## `exchanges`

_Entity_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| exchange_id | int | NOT NULL | auto_increment | PK |
| exchange_name | varchar(100) | NOT NULL |  |  |
| mic_code | char(4) | NOT NULL |  |  |
| country | varchar(60) | NOT NULL |  |  |
| timezone | varchar(40) | NOT NULL |  |  |
| status | varchar(10) | NOT NULL | ACTIVE |  |

**PK:** (exchange_id)

**Unique keys**

- `uq_exchanges_mic`: (mic_code)

**Check constraints**

- `chk_exchanges_status`: `(`status` in ('ACTIVE','SUSPENDED','CLOSED'))`

## `market_feed_data`

_Entity_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| feed_id | bigint | NOT NULL | auto_increment | PK |
| listing_id | int | NOT NULL |  |  |
| feed_timestamp | datetime(3) | NOT NULL |  |  |
| bid_price | decimal(18,4) | NOT NULL |  |  |
| ask_price | decimal(18,4) | NOT NULL |  |  |
| last_price | decimal(18,4) | NOT NULL |  |  |
| bid_size | int | NOT NULL |  |  |
| ask_size | int | NOT NULL |  |  |
| traded_volume | bigint | NOT NULL |  |  |
| source | varchar(30) | NOT NULL |  |  |

**PK:** (feed_id)

**Foreign keys**

- `fk_feed_listing`: (listing_id) → `security_listings` (listing_id) — ON DELETE RESTRICT, ON UPDATE CASCADE

**Unique keys**

- `uq_feed_listing_time`: (listing_id,feed_timestamp)

**Check constraints**

- `chk_feed_prices`: `((`bid_price` > 0) and (`ask_price` > 0) and (`last_price` > 0) and (`bid_price` <= `ask_price`))`
- `chk_feed_sizes`: `((`bid_size` >= 0) and (`ask_size` >= 0) and (`traded_volume` >= 0))`

## `order_routes`

_Junction (Order ↔ Exchange, M:N)_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| order_id | bigint | NOT NULL |  | PK |
| exchange_id | int | NOT NULL |  | PK |
| routed_quantity | decimal(18,4) | NOT NULL |  |  |
| routed_at | datetime(3) | NOT NULL |  |  |
| route_status | varchar(16) | NOT NULL | PENDING |  |
| routing_reason | varchar(150) | yes |  |  |

**PK:** (order_id, exchange_id) — composite key

**Foreign keys**

- `fk_routes_exchange`: (exchange_id) → `exchanges` (exchange_id) — ON DELETE RESTRICT, ON UPDATE CASCADE
- `fk_routes_order`: (order_id) → `orders` (order_id) — ON DELETE CASCADE, ON UPDATE CASCADE

**Check constraints**

- `chk_routes_qty`: `(`routed_quantity` > 0)`
- `chk_routes_status`: `(`route_status` in ('PENDING','SENT','PARTIALLY_FILLED','FILLED','CANCELLED','REJECTED'))`

## `orders`

_Entity_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| order_id | bigint | NOT NULL | auto_increment | PK |
| trader_id | int | NOT NULL |  |  |
| portfolio_id | int | NOT NULL |  |  |
| security_id | int | NOT NULL |  |  |
| algorithm_id | int | yes |  |  |
| side | varchar(4) | NOT NULL |  |  |
| order_type | varchar(6) | NOT NULL |  |  |
| quantity | decimal(18,4) | NOT NULL |  |  |
| limit_price | decimal(18,4) | yes |  |  |
| time_in_force | varchar(3) | NOT NULL | DAY |  |
| status | varchar(16) | NOT NULL | NEW |  |
| created_at | datetime | NOT NULL | CURRENT_TIMESTAMP DEFAULT_GENERATED |  |
| updated_at | datetime | NOT NULL | CURRENT_TIMESTAMP DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

**PK:** (order_id)

**Foreign keys**

- `fk_orders_algorithm`: (algorithm_id) → `algorithms` (algorithm_id) — ON DELETE SET NULL, ON UPDATE CASCADE
- `fk_orders_owner`: (trader_id,portfolio_id) → `portfolio_owners` (trader_id,portfolio_id) — ON DELETE RESTRICT, ON UPDATE CASCADE — **composite**
- `fk_orders_portfolio`: (portfolio_id) → `portfolios` (portfolio_id) — ON DELETE RESTRICT, ON UPDATE CASCADE
- `fk_orders_security`: (security_id) → `securities` (security_id) — ON DELETE RESTRICT, ON UPDATE CASCADE
- `fk_orders_trader`: (trader_id) → `traders` (trader_id) — ON DELETE RESTRICT, ON UPDATE CASCADE

**Check constraints**

- `chk_orders_price`: `(((`order_type` = 'MARKET') and (`limit_price` is null)) or ((`order_type` in ('LIMIT','STOP')) and (`limit_price` is not null) and (`limit_price` > 0)))`
- `chk_orders_qty`: `(`quantity` > 0)`
- `chk_orders_side`: `(`side` in ('BUY','SELL'))`
- `chk_orders_status`: `(`status` in ('NEW','PENDING','PARTIALLY_FILLED','FILLED','CANCELLED','REJECTED'))`
- `chk_orders_tif`: `(`time_in_force` in ('DAY','IOC','FOK','GTC'))`
- `chk_orders_times`: `(`updated_at` >= `created_at`)`
- `chk_orders_type`: `(`order_type` in ('MARKET','LIMIT','STOP'))`

## `portfolio_holdings`

_Junction (Portfolio ↔ Security, M:N)_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| portfolio_id | int | NOT NULL |  | PK |
| security_id | int | NOT NULL |  | PK |
| quantity_held | decimal(18,4) | NOT NULL |  |  |
| avg_price | decimal(18,4) | NOT NULL |  |  |
| last_updated | datetime | NOT NULL | CURRENT_TIMESTAMP DEFAULT_GENERATED |  |

**PK:** (portfolio_id, security_id) — composite key

**Foreign keys**

- `fk_ph_portfolio`: (portfolio_id) → `portfolios` (portfolio_id) — ON DELETE CASCADE, ON UPDATE CASCADE
- `fk_ph_security`: (security_id) → `securities` (security_id) — ON DELETE RESTRICT, ON UPDATE CASCADE

**Check constraints**

- `chk_ph_price`: `(`avg_price` > 0)`
- `chk_ph_qty`: `(`quantity_held` >= 0)`

## `portfolio_owners`

_Junction (Trader ↔ Portfolio, M:N)_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| trader_id | int | NOT NULL |  | PK |
| portfolio_id | int | NOT NULL |  | PK |
| ownership_percentage | decimal(5,2) | NOT NULL |  |  |
| ownership_start_date | date | NOT NULL |  |  |

**PK:** (trader_id, portfolio_id) — composite key

**Foreign keys**

- `fk_po_portfolio`: (portfolio_id) → `portfolios` (portfolio_id) — ON DELETE CASCADE, ON UPDATE CASCADE
- `fk_po_trader`: (trader_id) → `traders` (trader_id) — ON DELETE RESTRICT, ON UPDATE CASCADE

**Check constraints**

- `chk_po_pct`: `((`ownership_percentage` > 0) and (`ownership_percentage` <= 100))`

## `portfolios`

_Entity_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| portfolio_id | int | NOT NULL | auto_increment | PK |
| portfolio_name | varchar(100) | NOT NULL |  |  |
| base_currency | char(3) | NOT NULL |  |  |
| risk_profile | varchar(15) | NOT NULL |  |  |
| status | varchar(10) | NOT NULL | ACTIVE |  |
| created_at | datetime | NOT NULL | CURRENT_TIMESTAMP DEFAULT_GENERATED |  |

**PK:** (portfolio_id)

**Unique keys**

- `uq_portfolios_name`: (portfolio_name)

**Check constraints**

- `chk_portfolios_risk`: `(`risk_profile` in ('CONSERVATIVE','MODERATE','AGGRESSIVE'))`
- `chk_portfolios_status`: `(`status` in ('ACTIVE','SUSPENDED','CLOSED'))`

## `securities`

_Entity_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| security_id | int | NOT NULL | auto_increment | PK |
| isin | char(12) | NOT NULL |  |  |
| security_name | varchar(120) | NOT NULL |  |  |
| asset_type | varchar(15) | NOT NULL |  |  |
| currency | char(3) | NOT NULL |  |  |
| country | varchar(60) | NOT NULL |  |  |
| status | varchar(10) | NOT NULL | ACTIVE |  |

**PK:** (security_id)

**Unique keys**

- `uq_securities_isin`: (isin)

**Check constraints**

- `chk_securities_asset`: `(`asset_type` in ('EQUITY','ETF','ADR','BOND','FUTURE'))`
- `chk_securities_status`: `(`status` in ('ACTIVE','SUSPENDED','DELISTED'))`

## `security_listings`

_Junction (Security ↔ Exchange, M:N)_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| listing_id | int | NOT NULL | auto_increment | PK |
| security_id | int | NOT NULL |  |  |
| exchange_id | int | NOT NULL |  |  |
| ticker_symbol | varchar(20) | NOT NULL |  |  |
| listing_date | date | NOT NULL |  |  |
| currency | char(3) | NOT NULL |  |  |
| is_active | tinyint(1) | NOT NULL | 1 |  |

**PK:** (listing_id)

**Foreign keys**

- `fk_sl_exchange`: (exchange_id) → `exchanges` (exchange_id) — ON DELETE RESTRICT, ON UPDATE CASCADE
- `fk_sl_security`: (security_id) → `securities` (security_id) — ON DELETE RESTRICT, ON UPDATE CASCADE

**Unique keys**

- `uq_listing_exchange_ticker`: (exchange_id,ticker_symbol)
- `uq_listing_security_exchange`: (security_id,exchange_id)

## `traders`

_Entity_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| trader_id | int | NOT NULL | auto_increment | PK |
| full_name | varchar(100) | NOT NULL |  |  |
| email | varchar(150) | NOT NULL |  |  |
| desk | varchar(60) | NOT NULL |  |  |
| role | varchar(50) | NOT NULL |  |  |
| reports_to | int | yes |  |  |
| status | varchar(10) | NOT NULL | ACTIVE |  |
| created_at | datetime | NOT NULL | CURRENT_TIMESTAMP DEFAULT_GENERATED |  |

**PK:** (trader_id)

**Foreign keys**

- `fk_traders_reports_to`: (reports_to) → `traders` (trader_id) — ON DELETE SET NULL, ON UPDATE CASCADE

**Unique keys**

- `uq_traders_email`: (email)

**Check constraints**

- `chk_traders_status`: `(`status` in ('ACTIVE','INACTIVE','SUSPENDED'))`

## `trades`

_Entity_

| Column | Type | Null | Default / extra | Key |
|---|---|---|---|---|
| trade_id | bigint | NOT NULL | auto_increment | PK |
| order_id | bigint | NOT NULL |  |  |
| exchange_id | int | NOT NULL |  |  |
| execution_reference | varchar(40) | NOT NULL |  |  |
| executed_quantity | decimal(18,4) | NOT NULL |  |  |
| execution_price | decimal(18,4) | NOT NULL |  |  |
| executed_at | datetime(3) | NOT NULL |  |  |
| commission | decimal(14,4) | NOT NULL | 0.0000 |  |
| settlement_status | varchar(10) | NOT NULL | PENDING |  |

**PK:** (trade_id)

**Foreign keys**

- `fk_trades_exchange`: (exchange_id) → `exchanges` (exchange_id) — ON DELETE RESTRICT, ON UPDATE CASCADE
- `fk_trades_order`: (order_id) → `orders` (order_id) — ON DELETE RESTRICT, ON UPDATE CASCADE
- `fk_trades_route`: (order_id,exchange_id) → `order_routes` (order_id,exchange_id) — ON DELETE RESTRICT, ON UPDATE CASCADE — **composite**

**Unique keys**

- `uq_trades_execref`: (execution_reference)

**Check constraints**

- `chk_trades_commission`: `(`commission` >= 0)`
- `chk_trades_price`: `(`execution_price` > 0)`
- `chk_trades_qty`: `(`executed_quantity` > 0)`
- `chk_trades_settlement`: `(`settlement_status` in ('PENDING','SETTLED','FAILED'))`

## Rules enforced by triggers (cannot be expressed as plain constraints)

| Trigger | Table | When | Rule |
|---|---|---|---|
| `trg_app_users_before_insert` | app_users | BEFORE INSERT | A TRADER login must have a trader_id |
| `trg_app_users_before_update` | app_users | BEFORE UPDATE | Same as insert |
| `trg_routes_before_insert` | order_routes | BEFORE INSERT | Security must be actively listed on the exchange; routed quantities ≤ order quantity |
| `trg_routes_before_update` | order_routes | BEFORE UPDATE | Same as insert |
| `trg_orders_audit_ai` | orders | AFTER INSERT | Writes an audit_log row (who, before/after as JSON) |
| `trg_orders_audit_au` | orders | AFTER UPDATE | Writes an audit_log row (who, before/after as JSON) |
| `trg_orders_audit_ad` | orders | AFTER DELETE | Writes an audit_log row (who, before/after as JSON) |
| `trg_po_before_insert` | portfolio_owners | BEFORE INSERT | Total ownership of a portfolio cannot exceed 100 % |
| `trg_po_before_update` | portfolio_owners | BEFORE UPDATE | Total ownership of a portfolio cannot exceed 100 % |
| `trg_trades_audit_ai` | trades | AFTER INSERT | Writes an audit_log row (who, before/after as JSON) |
| `trg_trades_sync_status` | trades | AFTER INSERT | Moves the order to PARTIALLY_FILLED / FILLED and updates the route status |
| `trg_trades_audit_au` | trades | AFTER UPDATE | Writes an audit_log row (who, before/after as JSON) |
| `trg_trades_audit_ad` | trades | AFTER DELETE | Writes an audit_log row (who, before/after as JSON) |
| `trg_trades_before_insert` | trades | BEFORE INSERT | Executed quantity ≤ order quantity and ≤ quantity routed to that exchange |
| `trg_trades_before_update` | trades | BEFORE UPDATE | Same as insert |

## Normalization (3NF)

Every non-key column depends on the key, the whole key and nothing but the key:

- Facts are stored once: a security's name/ISIN live in `securities`; where it trades lives in `security_listings`; quotes reference a **listing** instead of repeating security and exchange.
- Many-to-many relationships are resolved into junction tables whose extra columns describe the relationship itself (`ownership_percentage`, `quantity_held`/`avg_price`, `ticker_symbol`, `routed_quantity`, `data_split`).
- Derived values (executed quantity, remaining quantity, VWAP, portfolio value) are **calculated** by functions/views, not stored.
- The only stored/derived pair is `orders.status`, which is kept consistent by trigger `trg_trades_sync_status` and checked by view `v_order_execution_summary`.
