# ER diagram

GitHub renders the diagram below automatically (Mermaid). **For the submission**, paste the code block into <https://mermaid.live>, export a PNG/SVG, save it as `docs/er_diagram.png` and embed it here.

```mermaid
erDiagram
    TRADERS ||--o{ ALGORITHM_DEVELOPERS : develops
    ALGORITHMS ||--o{ ALGORITHM_DEVELOPERS : "developed by"
    TRADERS ||--o{ PORTFOLIO_OWNERS : "OWNS (ownership_percentage)"
    PORTFOLIOS ||--o{ PORTFOLIO_OWNERS : "owned by"
    PORTFOLIOS ||--o{ PORTFOLIO_HOLDINGS : holds
    SECURITIES ||--o{ PORTFOLIO_HOLDINGS : "held in"
    SECURITIES ||--o{ SECURITY_LISTINGS : "LISTED ON (ticker_symbol)"
    EXCHANGES ||--o{ SECURITY_LISTINGS : lists
    SECURITY_LISTINGS ||--o{ MARKET_FEED_DATA : "QUOTES (feed_timestamp)"
    ALGORITHMS ||--o{ ALGORITHM_TRAINING_DATA : "trains on"
    MARKET_FEED_DATA ||--o{ ALGORITHM_TRAINING_DATA : "used by"
    PORTFOLIO_OWNERS ||--o{ ORDERS : "places (owner of portfolio)"
    SECURITIES ||--o{ ORDERS : "traded in"
    ALGORITHMS |o--o{ ORDERS : "generates (optional)"
    ORDERS ||--o{ ORDER_ROUTES : "routed to"
    EXCHANGES ||--o{ ORDER_ROUTES : receives
    ORDER_ROUTES ||--o{ TRADES : "EXECUTES AS / EXECUTED_ON"
    TRADERS |o--o{ TRADERS : "manages (reports_to)"
    TRADERS |o--o{ APP_USERS : "login for"

    TRADERS { int trader_id PK
        string full_name
        string email UK
        string desk
        string role
        string status
        int reports_to FK }
    ALGORITHMS { int algorithm_id PK
        string algorithm_name
        string version
        string strategy_type
        string programming_language
        string status }
    PORTFOLIOS { int portfolio_id PK
        string portfolio_name
        string base_currency
        string risk_profile
        string status }
    SECURITIES { int security_id PK
        string isin UK
        string security_name
        string asset_type
        string currency }
    EXCHANGES { int exchange_id PK
        string exchange_name
        string mic_code UK
        string country
        string timezone }
    ORDERS { bigint order_id PK
        int trader_id FK
        int portfolio_id FK
        int security_id FK
        int algorithm_id FK
        string side
        string order_type
        decimal quantity
        decimal limit_price
        string time_in_force
        string status }
    TRADES { bigint trade_id PK
        bigint order_id FK
        int exchange_id FK
        string execution_reference UK
        decimal executed_quantity
        decimal execution_price
        decimal commission
        string settlement_status }
    MARKET_FEED_DATA { bigint feed_id PK
        int listing_id FK
        datetime feed_timestamp
        decimal bid_price
        decimal ask_price
        decimal last_price }
    PORTFOLIO_OWNERS { int trader_id PK
        int portfolio_id PK
        decimal ownership_percentage }
    PORTFOLIO_HOLDINGS { int portfolio_id PK
        int security_id PK
        decimal quantity_held
        decimal avg_price }
    SECURITY_LISTINGS { int listing_id PK
        int security_id FK
        int exchange_id FK
        string ticker_symbol }
    ORDER_ROUTES { bigint order_id PK
        int exchange_id PK
        decimal routed_quantity
        string route_status }
    ALGORITHM_DEVELOPERS { int trader_id PK
        int algorithm_id PK
        string contribution_role }
    ALGORITHM_TRAINING_DATA { int algorithm_id PK
        bigint feed_id PK
        string data_split }
    APP_USERS { int user_id PK
        string username UK
        string password_hash
        string role
        int trader_id FK }
    AUDIT_LOG { bigint audit_id PK
        string table_name
        string action
        json old_values
        json new_values
        string changed_by }
```

`AUDIT_LOG` has no foreign keys on purpose: it is a history table written by triggers and must survive deletions.

## MongoDB side (linked by id, not by foreign key)

| Collection | Key fields | Links to MySQL |
|---|---|---|
| `backtest_results` | `algorithm_id`, `run_label`, `metrics{}`, `parameters{}`, `equity_curve[]`, `tags[]`, `status` | `algorithms.algorithm_id` |
| `order_events` | `order_id`, `event_type`, `ts`, `source`, `payload{}` | `orders.order_id` |
