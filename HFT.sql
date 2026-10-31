-- =====================================================================
--  HFT (High Frequency Trading) System - DBMS course project
--  Target : MySQL 8.0.16+ (CHECK constraints are enforced)
--  Run    : mysql -u root -p < HFT.sql
--  NOTE   : This script does NOT drop anything. If the tables already exist,
--           use the optional reset in Part 3 of the instructions first.
--  All timestamps (feed, orders, trades) are stored in UTC.
-- =====================================================================

SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS HFT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE HFT;

-- =====================================================================
-- SECTION 1 : MAIN ENTITY TABLES
-- =====================================================================

CREATE TABLE traders (
    trader_id   INT          NOT NULL AUTO_INCREMENT,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(150) NOT NULL,
    desk        VARCHAR(60)  NOT NULL,
    role        VARCHAR(50)  NOT NULL,
    status      VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (trader_id),
    UNIQUE KEY uq_traders_email (email),
    KEY idx_traders_desk (desk),
    CONSTRAINT chk_traders_status CHECK (status IN ('ACTIVE','INACTIVE','SUSPENDED'))
) ENGINE=InnoDB;

CREATE TABLE algorithms (
    algorithm_id         INT          NOT NULL AUTO_INCREMENT,
    algorithm_name       VARCHAR(80)  NOT NULL,
    version              VARCHAR(20)  NOT NULL,
    strategy_type        VARCHAR(50)  NOT NULL,
    programming_language VARCHAR(30)  NOT NULL,
    status               VARCHAR(12)  NOT NULL DEFAULT 'DEVELOPMENT',
    description          VARCHAR(500) NULL,
    created_at           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (algorithm_id),
    UNIQUE KEY uq_algorithms_name_version (algorithm_name, version),
    KEY idx_algorithms_strategy (strategy_type),
    CONSTRAINT chk_algorithms_status CHECK (status IN ('DEVELOPMENT','TESTING','ACTIVE','RETIRED'))
) ENGINE=InnoDB;

CREATE TABLE portfolios (
    portfolio_id   INT          NOT NULL AUTO_INCREMENT,
    portfolio_name VARCHAR(100) NOT NULL,
    base_currency  CHAR(3)      NOT NULL,
    risk_profile   VARCHAR(15)  NOT NULL,
    status         VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (portfolio_id),
    UNIQUE KEY uq_portfolios_name (portfolio_name),
    CONSTRAINT chk_portfolios_risk   CHECK (risk_profile IN ('CONSERVATIVE','MODERATE','AGGRESSIVE')),
    CONSTRAINT chk_portfolios_status CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED'))
) ENGINE=InnoDB;

CREATE TABLE securities (
    security_id   INT          NOT NULL AUTO_INCREMENT,
    isin          CHAR(12)     NOT NULL,
    security_name VARCHAR(120) NOT NULL,
    asset_type    VARCHAR(15)  NOT NULL,
    currency      CHAR(3)      NOT NULL,
    country       VARCHAR(60)  NOT NULL,
    status        VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',
    PRIMARY KEY (security_id),
    UNIQUE KEY uq_securities_isin (isin),
    KEY idx_securities_name (security_name),
    CONSTRAINT chk_securities_asset  CHECK (asset_type IN ('EQUITY','ETF','ADR','BOND','FUTURE')),
    CONSTRAINT chk_securities_status CHECK (status IN ('ACTIVE','SUSPENDED','DELISTED'))
) ENGINE=InnoDB;

CREATE TABLE exchanges (
    exchange_id   INT          NOT NULL AUTO_INCREMENT,
    exchange_name VARCHAR(100) NOT NULL,
    mic_code      CHAR(4)      NOT NULL,
    country       VARCHAR(60)  NOT NULL,
    timezone      VARCHAR(40)  NOT NULL,
    status        VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',
    PRIMARY KEY (exchange_id),
    UNIQUE KEY uq_exchanges_mic (mic_code),
    CONSTRAINT chk_exchanges_status CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Junction tables that other main tables depend on are created first.
-- ---------------------------------------------------------------------

-- portfolio_owners (Trader <-> Portfolio, M:N)
CREATE TABLE portfolio_owners (
    trader_id            INT          NOT NULL,
    portfolio_id         INT          NOT NULL,
    ownership_percentage DECIMAL(5,2) NOT NULL,
    ownership_start_date DATE         NOT NULL,
    PRIMARY KEY (trader_id, portfolio_id),
    KEY idx_po_portfolio (portfolio_id),
    CONSTRAINT fk_po_trader    FOREIGN KEY (trader_id)    REFERENCES traders (trader_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_po_portfolio FOREIGN KEY (portfolio_id) REFERENCES portfolios (portfolio_id)
        ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT chk_po_pct CHECK (ownership_percentage > 0 AND ownership_percentage <= 100)
) ENGINE=InnoDB;

-- security_listings (Security <-> Exchange, M:N, has its own surrogate key
-- because market_feed_data references one specific listing)
CREATE TABLE security_listings (
    listing_id    INT         NOT NULL AUTO_INCREMENT,
    security_id   INT         NOT NULL,
    exchange_id   INT         NOT NULL,
    ticker_symbol VARCHAR(20) NOT NULL,
    listing_date  DATE        NOT NULL,
    currency      CHAR(3)     NOT NULL,
    is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
    PRIMARY KEY (listing_id),
    UNIQUE KEY uq_listing_security_exchange (security_id, exchange_id),
    UNIQUE KEY uq_listing_exchange_ticker   (exchange_id, ticker_symbol),
    CONSTRAINT fk_sl_security FOREIGN KEY (security_id) REFERENCES securities (security_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sl_exchange FOREIGN KEY (exchange_id) REFERENCES exchanges (exchange_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- market_feed_data (Security listing 1 --- N quotes)
CREATE TABLE market_feed_data (
    feed_id        BIGINT        NOT NULL AUTO_INCREMENT,
    listing_id     INT           NOT NULL,
    feed_timestamp DATETIME(3)   NOT NULL,   -- the "quote_timestamp" of QUOTES
    bid_price      DECIMAL(18,4) NOT NULL,
    ask_price      DECIMAL(18,4) NOT NULL,
    last_price     DECIMAL(18,4) NOT NULL,
    bid_size       INT           NOT NULL,
    ask_size       INT           NOT NULL,
    traded_volume  BIGINT        NOT NULL,
    source         VARCHAR(30)   NOT NULL,
    PRIMARY KEY (feed_id),
    UNIQUE KEY uq_feed_listing_time (listing_id, feed_timestamp),
    KEY idx_feed_timestamp (feed_timestamp),
    CONSTRAINT fk_feed_listing FOREIGN KEY (listing_id) REFERENCES security_listings (listing_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_feed_prices CHECK (bid_price > 0 AND ask_price > 0 AND last_price > 0 AND bid_price <= ask_price),
    CONSTRAINT chk_feed_sizes  CHECK (bid_size >= 0 AND ask_size >= 0 AND traded_volume >= 0)
) ENGINE=InnoDB;

CREATE TABLE orders (
    order_id       BIGINT        NOT NULL AUTO_INCREMENT,
    trader_id      INT           NOT NULL,
    portfolio_id   INT           NOT NULL,
    security_id    INT           NOT NULL,
    algorithm_id   INT           NULL,                 -- NULL = manual order
    side           VARCHAR(4)    NOT NULL,
    order_type     VARCHAR(6)    NOT NULL,
    quantity       DECIMAL(18,4) NOT NULL,
    limit_price    DECIMAL(18,4) NULL,                 -- limit price (LIMIT) or trigger price (STOP)
    time_in_force  VARCHAR(3)    NOT NULL DEFAULT 'DAY',
    status         VARCHAR(16)   NOT NULL DEFAULT 'NEW',
    created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id),
    KEY idx_orders_trader_portfolio (trader_id, portfolio_id),
    KEY idx_orders_portfolio (portfolio_id),
    KEY idx_orders_security_status (security_id, status),
    KEY idx_orders_algorithm (algorithm_id),
    KEY idx_orders_status (status),
    KEY idx_orders_created (created_at),
    -- trader MUST be an owner of the portfolio:
    CONSTRAINT fk_orders_owner FOREIGN KEY (trader_id, portfolio_id)
        REFERENCES portfolio_owners (trader_id, portfolio_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_orders_trader    FOREIGN KEY (trader_id)    REFERENCES traders (trader_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_orders_portfolio FOREIGN KEY (portfolio_id) REFERENCES portfolios (portfolio_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_orders_security  FOREIGN KEY (security_id)  REFERENCES securities (security_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_orders_algorithm FOREIGN KEY (algorithm_id) REFERENCES algorithms (algorithm_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_orders_side   CHECK (side IN ('BUY','SELL')),
    CONSTRAINT chk_orders_type   CHECK (order_type IN ('MARKET','LIMIT','STOP')),
    CONSTRAINT chk_orders_tif    CHECK (time_in_force IN ('DAY','IOC','FOK','GTC')),
    CONSTRAINT chk_orders_status CHECK (status IN ('NEW','PENDING','PARTIALLY_FILLED','FILLED','CANCELLED','REJECTED')),
    CONSTRAINT chk_orders_qty    CHECK (quantity > 0),
    CONSTRAINT chk_orders_price  CHECK (
        (order_type = 'MARKET' AND limit_price IS NULL)
        OR (order_type IN ('LIMIT','STOP') AND limit_price IS NOT NULL AND limit_price > 0)),
    CONSTRAINT chk_orders_times  CHECK (updated_at >= created_at)
) ENGINE=InnoDB;

-- order_routes (Order <-> Exchange, M:N)
CREATE TABLE order_routes (
    order_id        BIGINT        NOT NULL,
    exchange_id     INT           NOT NULL,
    routed_quantity DECIMAL(18,4) NOT NULL,
    routed_at       DATETIME(3)   NOT NULL,
    route_status    VARCHAR(16)   NOT NULL DEFAULT 'PENDING',
    routing_reason  VARCHAR(150)  NULL,
    PRIMARY KEY (order_id, exchange_id),
    KEY idx_routes_exchange (exchange_id),
    CONSTRAINT fk_routes_order    FOREIGN KEY (order_id)    REFERENCES orders (order_id)
        ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_routes_exchange FOREIGN KEY (exchange_id) REFERENCES exchanges (exchange_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_routes_qty    CHECK (routed_quantity > 0),
    CONSTRAINT chk_routes_status CHECK (route_status IN ('PENDING','SENT','PARTIALLY_FILLED','FILLED','CANCELLED','REJECTED'))
) ENGINE=InnoDB;

CREATE TABLE trades (
    trade_id            BIGINT        NOT NULL AUTO_INCREMENT,
    order_id            BIGINT        NOT NULL,
    exchange_id         INT           NOT NULL,
    execution_reference VARCHAR(40)   NOT NULL,
    executed_quantity   DECIMAL(18,4) NOT NULL,
    execution_price     DECIMAL(18,4) NOT NULL,
    executed_at         DATETIME(3)   NOT NULL,
    commission          DECIMAL(14,4) NOT NULL DEFAULT 0,
    settlement_status   VARCHAR(10)   NOT NULL DEFAULT 'PENDING',
    PRIMARY KEY (trade_id),
    UNIQUE KEY uq_trades_execref (execution_reference),
    KEY idx_trades_order (order_id),
    KEY idx_trades_route (order_id, exchange_id),
    KEY idx_trades_exchange (exchange_id),
    KEY idx_trades_executed_at (executed_at),
    CONSTRAINT fk_trades_order    FOREIGN KEY (order_id)    REFERENCES orders (order_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_trades_exchange FOREIGN KEY (exchange_id) REFERENCES exchanges (exchange_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- EXECUTED_ON: the exchange must be one the order was actually routed to
    CONSTRAINT fk_trades_route FOREIGN KEY (order_id, exchange_id)
        REFERENCES order_routes (order_id, exchange_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_trades_qty        CHECK (executed_quantity > 0),
    CONSTRAINT chk_trades_price      CHECK (execution_price > 0),
    CONSTRAINT chk_trades_commission CHECK (commission >= 0),
    CONSTRAINT chk_trades_settlement CHECK (settlement_status IN ('PENDING','SETTLED','FAILED'))
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 2 : REMAINING JUNCTION TABLES
-- =====================================================================

CREATE TABLE algorithm_developers (
    trader_id         INT         NOT NULL,
    algorithm_id      INT         NOT NULL,
    contribution_role VARCHAR(30) NOT NULL,
    developed_at      DATE        NOT NULL,
    PRIMARY KEY (trader_id, algorithm_id),
    KEY idx_ad_algorithm (algorithm_id),
    CONSTRAINT fk_ad_trader    FOREIGN KEY (trader_id)    REFERENCES traders (trader_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ad_algorithm FOREIGN KEY (algorithm_id) REFERENCES algorithms (algorithm_id)
        ON DELETE CASCADE  ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE portfolio_holdings (
    portfolio_id  INT           NOT NULL,
    security_id   INT           NOT NULL,
    quantity_held DECIMAL(18,4) NOT NULL,
    avg_price     DECIMAL(18,4) NOT NULL,
    last_updated  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (portfolio_id, security_id),
    KEY idx_ph_security (security_id),
    CONSTRAINT fk_ph_portfolio FOREIGN KEY (portfolio_id) REFERENCES portfolios (portfolio_id)
        ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_ph_security  FOREIGN KEY (security_id)  REFERENCES securities (security_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_ph_qty   CHECK (quantity_held >= 0),
    CONSTRAINT chk_ph_price CHECK (avg_price > 0)
) ENGINE=InnoDB;

CREATE TABLE algorithm_training_data (
    algorithm_id INT         NOT NULL,
    feed_id      BIGINT      NOT NULL,
    data_split   VARCHAR(10) NOT NULL,
    added_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (algorithm_id, feed_id),
    KEY idx_atd_feed (feed_id),
    CONSTRAINT fk_atd_algorithm FOREIGN KEY (algorithm_id) REFERENCES algorithms (algorithm_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_atd_feed      FOREIGN KEY (feed_id)      REFERENCES market_feed_data (feed_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_atd_split CHECK (data_split IN ('TRAINING','VALIDATION','TESTING'))
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 3 : TRIGGERS, PROCEDURES AND VIEWS (rules plain CHECKs cannot express)
-- =====================================================================

DELIMITER $$

-- Rule A: ownership of one portfolio can never exceed 100 %.
CREATE TRIGGER trg_po_before_insert BEFORE INSERT ON portfolio_owners
FOR EACH ROW
BEGIN
    DECLARE v_other DECIMAL(7,2);
    SELECT COALESCE(SUM(ownership_percentage), 0) INTO v_other
      FROM portfolio_owners WHERE portfolio_id = NEW.portfolio_id;
    IF v_other + NEW.ownership_percentage > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Total ownership of a portfolio cannot exceed 100 percent';
    END IF;
END$$

CREATE TRIGGER trg_po_before_update BEFORE UPDATE ON portfolio_owners
FOR EACH ROW
BEGIN
    DECLARE v_other DECIMAL(7,2);
    SELECT COALESCE(SUM(ownership_percentage), 0) INTO v_other
      FROM portfolio_owners
     WHERE portfolio_id = NEW.portfolio_id
       AND NOT (trader_id = OLD.trader_id AND portfolio_id = OLD.portfolio_id);
    IF v_other + NEW.ownership_percentage > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Total ownership of a portfolio cannot exceed 100 percent';
    END IF;
END$$

-- Rule B: an order may only be routed to an exchange where its security is
-- actively listed, and routed quantities may not exceed the order quantity.
CREATE PROCEDURE sp_validate_order_route(
    IN p_order_id BIGINT, IN p_exchange_id INT,
    IN p_qty DECIMAL(18,4), IN p_replaced_exchange_id INT)
BEGIN
    DECLARE v_security_id INT;
    DECLARE v_order_qty   DECIMAL(18,4);
    DECLARE v_other       DECIMAL(18,4);
    DECLARE v_listed      INT;

    SELECT security_id, quantity INTO v_security_id, v_order_qty
      FROM orders WHERE order_id = p_order_id;

    SELECT COUNT(*) INTO v_listed FROM security_listings
     WHERE security_id = v_security_id AND exchange_id = p_exchange_id AND is_active = TRUE;
    IF v_listed = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Security is not actively listed on the exchange being routed to';
    END IF;

    SELECT COALESCE(SUM(routed_quantity), 0) INTO v_other FROM order_routes
     WHERE order_id = p_order_id AND exchange_id <> COALESCE(p_replaced_exchange_id, -1);
    IF v_other + p_qty > v_order_qty THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Total routed quantity exceeds the order quantity';
    END IF;
END$$

CREATE TRIGGER trg_routes_before_insert BEFORE INSERT ON order_routes
FOR EACH ROW
BEGIN
    CALL sp_validate_order_route(NEW.order_id, NEW.exchange_id, NEW.routed_quantity, NULL);
END$$

CREATE TRIGGER trg_routes_before_update BEFORE UPDATE ON order_routes
FOR EACH ROW
BEGIN
    CALL sp_validate_order_route(NEW.order_id, NEW.exchange_id, NEW.routed_quantity, OLD.exchange_id);
END$$

-- Rule C: executions of an order may not exceed the order quantity, and
-- executions on one route may not exceed that route's routed quantity.
CREATE PROCEDURE sp_validate_trade(
    IN p_order_id BIGINT, IN p_exchange_id INT,
    IN p_qty DECIMAL(18,4), IN p_replaced_trade_id BIGINT)
BEGIN
    DECLARE v_order_qty  DECIMAL(18,4);
    DECLARE v_routed_qty DECIMAL(18,4);
    DECLARE v_done_order DECIMAL(18,4);
    DECLARE v_done_route DECIMAL(18,4);

    SELECT quantity INTO v_order_qty FROM orders WHERE order_id = p_order_id;
    SELECT routed_quantity INTO v_routed_qty FROM order_routes
     WHERE order_id = p_order_id AND exchange_id = p_exchange_id;

    SELECT COALESCE(SUM(executed_quantity), 0) INTO v_done_order FROM trades
     WHERE order_id = p_order_id AND trade_id <> COALESCE(p_replaced_trade_id, -1);
    SELECT COALESCE(SUM(executed_quantity), 0) INTO v_done_route FROM trades
     WHERE order_id = p_order_id AND exchange_id = p_exchange_id
       AND trade_id <> COALESCE(p_replaced_trade_id, -1);

    IF v_done_order + p_qty > v_order_qty THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Total executed quantity would exceed the order quantity';
    END IF;
    IF v_routed_qty IS NOT NULL AND v_done_route + p_qty > v_routed_qty THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Executed quantity would exceed the quantity routed to this exchange';
    END IF;
END$$

CREATE TRIGGER trg_trades_before_insert BEFORE INSERT ON trades
FOR EACH ROW
BEGIN
    CALL sp_validate_trade(NEW.order_id, NEW.exchange_id, NEW.executed_quantity, NULL);
END$$

CREATE TRIGGER trg_trades_before_update BEFORE UPDATE ON trades
FOR EACH ROW
BEGIN
    CALL sp_validate_trade(NEW.order_id, NEW.exchange_id, NEW.executed_quantity, OLD.trade_id);
END$$

DELIMITER ;

-- Rule A (exactly 100 %): a row-level trigger cannot demand "sum = 100" while
-- owners are still being inserted one by one, so it is verified with this view.
CREATE VIEW v_portfolio_ownership_check AS
SELECT p.portfolio_id,
       p.portfolio_name,
       COALESCE(SUM(po.ownership_percentage), 0) AS total_ownership_pct,
       CASE WHEN COALESCE(SUM(po.ownership_percentage), 0) = 100 THEN 'OK' ELSE 'INCOMPLETE' END AS ownership_status
  FROM portfolios p
  LEFT JOIN portfolio_owners po ON po.portfolio_id = p.portfolio_id
 GROUP BY p.portfolio_id, p.portfolio_name;

-- Order status vs. actual trades consistency (status is stored, fills are derived).
CREATE VIEW v_order_execution_summary AS
SELECT o.order_id,
       o.status,
       o.quantity,
       COALESCE(SUM(t.executed_quantity), 0)              AS executed_quantity,
       o.quantity - COALESCE(SUM(t.executed_quantity), 0) AS remaining_quantity,
       CASE
         WHEN o.status = 'FILLED'           AND COALESCE(SUM(t.executed_quantity),0) =  o.quantity THEN 'OK'
         WHEN o.status = 'PARTIALLY_FILLED' AND COALESCE(SUM(t.executed_quantity),0) >  0
                                            AND COALESCE(SUM(t.executed_quantity),0) <  o.quantity THEN 'OK'
         WHEN o.status IN ('NEW','PENDING','REJECTED') AND COALESCE(SUM(t.executed_quantity),0) = 0 THEN 'OK'
         WHEN o.status = 'CANCELLED'        AND COALESCE(SUM(t.executed_quantity),0) < o.quantity THEN 'OK'
         ELSE 'MISMATCH'
       END AS status_check
  FROM orders o
  LEFT JOIN trades t ON t.order_id = o.order_id
 GROUP BY o.order_id, o.status, o.quantity;

-- =====================================================================
-- SECTION 4 : DUMMY DATA (fictional, inserted parents-first)
-- =====================================================================

INSERT INTO traders (trader_id, full_name, email, desk, role, status, created_at) VALUES
(1,  'Aarav Sharma',     'aarav.sharma@quantedge.example',   'Equity Algo',          'Senior Trader',     'ACTIVE',   '2021-04-12 09:00:00'),
(2,  'Priya Nair',       'priya.nair@quantedge.example',     'Quant Research',       'Quant Developer',   'ACTIVE',   '2021-07-01 09:30:00'),
(3,  'Rohan Mehta',      'rohan.mehta@quantedge.example',    'Market Making',        'Head of Desk',      'ACTIVE',   '2020-01-15 08:45:00'),
(4,  'Ananya Iyer',      'ananya.iyer@quantedge.example',    'Statistical Arbitrage','Quant Developer',   'ACTIVE',   '2022-02-21 10:00:00'),
(5,  'Karthik Reddy',    'karthik.reddy@quantedge.example',  'Execution Services',    'Execution Trader',  'ACTIVE',   '2022-06-06 09:10:00'),
(6,  'Sneha Kulkarni',   'sneha.kulkarni@quantedge.example', 'Portfolio Management', 'Portfolio Manager', 'ACTIVE',   '2019-11-03 09:00:00'),
(7,  'Vikram Singh',     'vikram.singh@quantedge.example',   'Global Equities',      'Senior Trader',     'ACTIVE',   '2020-09-14 08:30:00'),
(8,  'Emily Carter',     'emily.carter@quantedge.example',   'Global Equities',      'Portfolio Manager', 'ACTIVE',   '2018-03-26 08:00:00'),
(9,  'James Okafor',     'james.okafor@quantedge.example',   'Market Making',        'Trader',            'ACTIVE',   '2023-01-09 09:00:00'),
(10, 'Li Wei',           'li.wei@quantedge.example',         'Quant Research',       'Quant Developer',   'ACTIVE',   '2021-10-18 09:45:00'),
(11, 'Meera Pillai',     'meera.pillai@quantedge.example',   'Risk and Compliance',  'Risk Analyst',      'ACTIVE',   '2022-08-29 10:15:00'),
(12, 'Daniel Fischer',   'daniel.fischer@quantedge.example', 'Execution Services',   'Junior Trader',     'INACTIVE', '2023-05-15 09:00:00');

INSERT INTO algorithms (algorithm_id, algorithm_name, version, strategy_type, programming_language, status, description, created_at) VALUES
(1,  'AlphaMaker',       '1.0', 'Market Making',          'C++',    'RETIRED',     'Quotes two-sided markets using inventory-skew pricing.',                '2023-03-01 10:00:00'),
(2,  'AlphaMaker',       '2.1', 'Market Making',          'C++',    'ACTIVE',      'Successor of AlphaMaker 1.0 with adaptive spread control.',            '2024-02-15 10:00:00'),
(3,  'MomentumX',        '1.3', 'Momentum Trading',       'Java',   'ACTIVE',      'Trades intraday breakouts confirmed by volume surges.',                '2023-06-10 11:00:00'),
(4,  'MeanRevert Pro',   '2.0', 'Mean Reversion',         'Python', 'ACTIVE',      'Fades short-term price deviations from a rolling VWAP band.',          '2023-07-22 11:30:00'),
(5,  'StatArb Engine',   '1.5', 'Statistical Arbitrage',  'Rust',   'ACTIVE',      'Cointegration-based basket arbitrage across US large caps.',           '2023-09-05 12:00:00'),
(6,  'PairsTrader',      '1.1', 'Pairs Trading',          'Python', 'ACTIVE',      'Trades spread convergence between correlated stock pairs.',            '2023-10-30 12:00:00'),
(7,  'CrossVenue Arb',   '3.0', 'Arbitrage',              'C++',    'ACTIVE',      'Exploits price differences for the same security across exchanges.',   '2024-01-05 09:00:00'),
(8,  'VWAP Slicer',      '2.2', 'VWAP',                   'Java',   'ACTIVE',      'Slices large parent orders to track the interval VWAP.',               '2023-04-18 09:30:00'),
(9,  'TWAP Executor',    '1.0', 'TWAP',                   'Go',     'TESTING',     'Executes equal slices over a fixed time window.',                      '2024-04-02 14:00:00'),
(10, 'MomentumX',        '2.0', 'Momentum Trading',       'Rust',   'TESTING',     'Rewrite of MomentumX with lower latency and ML signal filter.',        '2024-05-20 15:00:00'),
(11, 'PairsTrader',      '2.0', 'Pairs Trading',          'C++',    'DEVELOPMENT', 'Adds Kalman-filter hedge ratios to PairsTrader.',                      '2024-06-25 15:30:00'),
(12, 'LiquiditySeeker',  '1.0', 'Market Making',          'Go',     'ACTIVE',      'Posts passive orders on thin books to earn the spread rebate.',        '2024-07-12 16:00:00');

INSERT INTO portfolios (portfolio_id, portfolio_name, base_currency, risk_profile, status, created_at) VALUES
(1,  'India Large Cap Alpha',        'INR', 'MODERATE',     'ACTIVE',    '2020-04-01 09:00:00'),
(2,  'Global Tech Growth',           'USD', 'AGGRESSIVE',   'ACTIVE',    '2020-06-15 09:00:00'),
(3,  'Market Making Book - Asia',    'INR', 'AGGRESSIVE',   'ACTIVE',    '2020-02-10 09:00:00'),
(4,  'US Momentum Fund',             'USD', 'AGGRESSIVE',   'ACTIVE',    '2021-01-20 09:00:00'),
(5,  'Stat Arb Neutral Fund',        'USD', 'MODERATE',     'ACTIVE',    '2022-03-05 09:00:00'),
(6,  'Dividend Income Portfolio',    'INR', 'CONSERVATIVE', 'ACTIVE',    '2019-12-01 09:00:00'),
(7,  'UK and Europe Opportunities',  'GBP', 'MODERATE',     'ACTIVE',    '2021-09-09 09:00:00'),
(8,  'Cross-Venue Arbitrage Desk',   'USD', 'MODERATE',     'ACTIVE',    '2023-01-16 09:00:00'),
(9,  'ETF Core Holdings',            'USD', 'CONSERVATIVE', 'ACTIVE',    '2020-08-24 09:00:00'),
(10, 'Banking Sector Focus',         'INR', 'MODERATE',     'ACTIVE',    '2021-05-11 09:00:00'),
(11, 'Execution Test Portfolio',     'INR', 'CONSERVATIVE', 'CLOSED',    '2023-06-01 09:00:00'),
(12, 'Global Macro Blend',           'USD', 'AGGRESSIVE',   'ACTIVE',    '2022-11-14 09:00:00');

INSERT INTO securities (security_id, isin, security_name, asset_type, currency, country, status) VALUES
(1,  'INE009A01021', 'Infosys Ltd',                    'EQUITY', 'INR', 'India',          'ACTIVE'),
(2,  'INE467B01029', 'Tata Consultancy Services Ltd',  'EQUITY', 'INR', 'India',          'ACTIVE'),
(3,  'INE002A01018', 'Reliance Industries Ltd',        'EQUITY', 'INR', 'India',          'ACTIVE'),
(4,  'INE040A01034', 'HDFC Bank Ltd',                  'EQUITY', 'INR', 'India',          'ACTIVE'),
(5,  'INF204KB14I2', 'Nippon India ETF Nifty BeES',    'ETF',    'INR', 'India',          'ACTIVE'),
(6,  'US5949181045', 'Microsoft Corporation',          'EQUITY', 'USD', 'United States',  'ACTIVE'),
(7,  'US0378331005', 'Apple Inc.',                     'EQUITY', 'USD', 'United States',  'ACTIVE'),
(8,  'US67066G1040', 'NVIDIA Corporation',             'EQUITY', 'USD', 'United States',  'ACTIVE'),
(9,  'US88160R1014', 'Tesla, Inc.',                    'EQUITY', 'USD', 'United States',  'ACTIVE'),
(10, 'US02079K3059', 'Alphabet Inc. Class A',          'EQUITY', 'USD', 'United States',  'ACTIVE'),
(11, 'US78462F1030', 'SPDR S&P 500 ETF Trust',         'ETF',    'USD', 'United States',  'ACTIVE'),
(12, 'US46090E1038', 'Invesco QQQ Trust',              'ETF',    'USD', 'United States',  'ACTIVE'),
(13, 'GB0005405286', 'HSBC Holdings plc',              'EQUITY', 'GBP', 'United Kingdom', 'ACTIVE'),
(14, 'GB0007980591', 'BP plc',                         'EQUITY', 'GBP', 'United Kingdom', 'ACTIVE');

INSERT INTO exchanges (exchange_id, exchange_name, mic_code, country, timezone, status) VALUES
(1,  'National Stock Exchange of India', 'XNSE', 'India',          'Asia/Kolkata',        'ACTIVE'),
(2,  'Bombay Stock Exchange',            'XBOM', 'India',          'Asia/Kolkata',        'ACTIVE'),
(3,  'NASDAQ Stock Market',              'XNAS', 'United States',  'America/New_York',    'ACTIVE'),
(4,  'New York Stock Exchange',          'XNYS', 'United States',  'America/New_York',    'ACTIVE'),
(5,  'London Stock Exchange',            'XLON', 'United Kingdom', 'Europe/London',       'ACTIVE'),
(6,  'Deutsche Boerse Xetra',            'XETR', 'Germany',        'Europe/Berlin',       'ACTIVE'),
(7,  'Hong Kong Exchanges',              'XHKG', 'Hong Kong',      'Asia/Hong_Kong',      'ACTIVE'),
(8,  'Tokyo Stock Exchange',             'XTKS', 'Japan',          'Asia/Tokyo',          'ACTIVE'),
(9,  'Singapore Exchange',               'XSES', 'Singapore',      'Asia/Singapore',      'ACTIVE'),
(10, 'Euronext Paris',                   'XPAR', 'France',         'Europe/Paris',        'ACTIVE'),
(11, 'Cboe BZX Exchange',                'BATS', 'United States',  'America/New_York',    'ACTIVE'),
(12, 'Toronto Stock Exchange',           'XTSE', 'Canada',         'America/Toronto',     'SUSPENDED');

INSERT INTO security_listings (listing_id, security_id, exchange_id, ticker_symbol, listing_date, currency, is_active) VALUES
(1,  1,  1, 'INFY',      '1993-06-14', 'INR', TRUE),
(2,  1,  2, '500209',    '1993-06-14', 'INR', TRUE),
(3,  2,  1, 'TCS',       '2004-08-25', 'INR', TRUE),
(4,  2,  2, '532540',    '2004-08-25', 'INR', TRUE),
(5,  3,  1, 'RELIANCE',  '1995-11-29', 'INR', TRUE),
(6,  3,  2, '500325',    '1977-01-01', 'INR', TRUE),
(7,  4,  1, 'HDFCBANK',  '1995-11-08', 'INR', TRUE),
(8,  4,  2, '500180',    '1995-11-08', 'INR', TRUE),
(9,  5,  1, 'NIFTYBEES', '2002-01-08', 'INR', TRUE),
(10, 6,  3, 'MSFT',      '1986-03-13', 'USD', TRUE),
(11, 7,  3, 'AAPL',      '1980-12-12', 'USD', TRUE),
(12, 8,  3, 'NVDA',      '1999-01-22', 'USD', TRUE),
(13, 9,  3, 'TSLA',      '2010-06-29', 'USD', TRUE),
(14, 10, 3, 'GOOGL',     '2004-08-19', 'USD', TRUE),
(15, 11, 4, 'SPY',       '1993-01-29', 'USD', TRUE),
(16, 12, 3, 'QQQ',       '1999-03-10', 'USD', TRUE),
(17, 13, 5, 'HSBA',      '1991-07-01', 'GBP', TRUE),
(18, 14, 5, 'BP.',       '1954-01-01', 'GBP', TRUE),
(19, 6,  6, 'MSF',       '2002-01-02', 'EUR', TRUE),
(20, 7,  6, 'APC',       '2002-01-02', 'EUR', TRUE),
(21, 13, 7, '0005',      '1991-07-01', 'HKD', TRUE);

-- Joint ownership: every portfolio's percentages add up to exactly 100.
INSERT INTO portfolio_owners (trader_id, portfolio_id, ownership_percentage, ownership_start_date) VALUES
(1,  1,  60.00, '2020-04-01'),
(6,  1,  40.00, '2020-04-01'),
(7,  2,  50.00, '2020-06-15'),
(8,  2,  50.00, '2020-06-15'),
(3,  3, 100.00, '2020-02-10'),
(7,  4,  40.00, '2021-01-20'),
(8,  4,  30.00, '2021-01-20'),
(9,  4,  30.00, '2023-01-09'),
(4,  5,  55.00, '2022-03-05'),
(10, 5,  45.00, '2022-03-05'),
(6,  6, 100.00, '2019-12-01'),
(8,  7,  70.00, '2021-09-09'),
(7,  7,  30.00, '2021-09-09'),
(5,  8,  50.00, '2023-01-16'),
(3,  8,  50.00, '2023-01-16'),
(6,  9,  35.00, '2020-08-24'),
(8,  9,  35.00, '2020-08-24'),
(1,  9,  30.00, '2020-08-24'),
(1,  10, 25.00, '2021-05-11'),
(6,  10, 75.00, '2021-05-11'),
(12, 11, 100.00,'2023-06-01'),
(8,  12, 60.00, '2022-11-14'),
(10, 12, 40.00, '2022-11-14');

INSERT INTO algorithm_developers (trader_id, algorithm_id, contribution_role, developed_at) VALUES
(2,  1,  'Lead Developer',    '2023-03-10'),
(3,  1,  'Reviewer',          '2023-04-02'),
(2,  2,  'Lead Developer',    '2024-02-20'),
(10, 2,  'Contributor',       '2024-03-05'),
(1,  3,  'Strategy Designer', '2023-06-18'),
(10, 3,  'Lead Developer',    '2023-06-25'),
(4,  4,  'Lead Developer',    '2023-08-01'),
(4,  5,  'Lead Developer',    '2023-09-12'),
(2,  5,  'Contributor',       '2023-09-30'),
(10, 6,  'Lead Developer',    '2023-11-05'),
(4,  6,  'Strategy Designer', '2023-11-01'),
(5,  7,  'Lead Developer',    '2024-01-08'),
(3,  7,  'Contributor',       '2024-01-20'),
(5,  8,  'Lead Developer',    '2023-05-14'),
(1,  8,  'Reviewer',          '2023-05-30'),
(9,  9,  'Lead Developer',    '2024-04-11'),
(10, 10, 'Lead Developer',    '2024-06-03'),
(2,  10, 'Contributor',       '2024-06-10'),
(4,  11, 'Lead Developer',    '2024-07-15'),
(9,  12, 'Lead Developer',    '2024-08-01'),
(3,  12, 'Strategy Designer', '2024-07-28');

INSERT INTO portfolio_holdings (portfolio_id, security_id, quantity_held, avg_price, last_updated) VALUES
(1,  1,  1500.0000, 1520.4000, '2024-03-14 17:30:00'),
(1,  2,   800.0000, 3890.2500, '2024-03-14 17:30:00'),
(1,  3,  1200.0000, 2450.7500, '2024-03-14 17:30:00'),
(2,  6,   300.0000,  415.2000, '2024-03-14 21:00:00'),
(2,  7,   450.0000,  185.6000, '2024-03-14 21:00:00'),
(2,  8,   200.0000,  480.3000, '2024-03-14 21:00:00'),
(2,  10,  150.0000,  140.1000, '2024-03-14 21:00:00'),
(3,  3,  5000.0000, 2510.0000, '2024-03-14 17:30:00'),
(3,  4,  3000.0000, 1620.0000, '2024-03-14 17:30:00'),
(4,  9,   250.0000,  245.5000, '2024-03-14 21:00:00'),
(4,  8,   100.0000,  520.0000, '2024-03-14 21:00:00'),
(4,  7,   300.0000,  190.2000, '2024-03-14 21:00:00'),
(5,  6,   100.0000,  410.0000, '2024-03-14 21:00:00'),
(5,  10,  120.0000,  138.0000, '2024-03-14 21:00:00'),
(5,  7,   140.0000,  188.0000, '2024-03-14 21:00:00'),
(6,  1,   500.0000, 1480.0000, '2024-03-14 17:30:00'),
(6,  4,   700.0000, 1590.5000, '2024-03-14 17:30:00'),
(6,  2,   300.0000, 3820.0000, '2024-03-14 17:30:00'),
(7,  13, 2000.0000,    6.4500, '2024-03-14 16:30:00'),
(7,  14, 1500.0000,    4.8500, '2024-03-14 16:30:00'),
(8,  4,   200.0000, 1445.0000, '2024-03-14 17:30:00'),
(8,  6,    50.0000,  418.0000, '2024-03-14 21:00:00'),
(9,  11,  400.0000,  440.0000, '2024-03-14 21:00:00'),
(9,  12,  300.0000,  370.0000, '2024-03-14 21:00:00'),
(9,  5, 10000.0000,  245.5000, '2024-03-14 17:30:00'),
(10, 4,  2500.0000, 1605.0000, '2024-03-14 17:30:00'),
(10, 1,   400.0000, 1500.0000, '2024-03-14 17:30:00'),
(12, 11,  100.0000,  505.0000, '2024-03-14 21:00:00'),
(12, 12,   80.0000,  430.0000, '2024-03-14 21:00:00');

INSERT INTO market_feed_data (feed_id, listing_id, feed_timestamp, bid_price, ask_price, last_price, bid_size, ask_size, traded_volume, source) VALUES
(1,  1,  '2024-03-15 03:45:00.250', 1651.2000, 1651.4500, 1651.3000, 1200,  900,   15400, 'NSE_DIRECT'),
(2,  1,  '2024-03-15 03:45:01.100', 1651.3000, 1651.5500, 1651.5000,  800, 1100,   15900, 'NSE_DIRECT'),
(3,  2,  '2024-03-15 03:45:00.400', 1651.0000, 1651.6000, 1651.2500,  300,  250,    4100, 'BSE_DIRECT'),
(4,  3,  '2024-03-15 03:50:00.100', 4048.5000, 4049.0000, 4048.7500,  500,  600,    8200, 'NSE_DIRECT'),
(5,  4,  '2024-03-15 03:50:00.300', 4048.0000, 4049.5000, 4048.6000,  120,  150,    1900, 'BSE_DIRECT'),
(6,  5,  '2024-03-15 04:00:00.050', 2950.1000, 2950.4000, 2950.2500, 2200, 1800,   31000, 'NSE_DIRECT'),
(7,  6,  '2024-03-15 04:00:00.120', 2950.0000, 2950.7000, 2950.3000,  400,  350,    5200, 'BSE_DIRECT'),
(8,  7,  '2024-03-15 04:30:00.500', 1440.2000, 1440.3500, 1440.3000, 3500, 3000,   52000, 'NSE_DIRECT'),
(9,  8,  '2024-03-15 04:30:00.650', 1440.0000, 1440.6000, 1440.1500,  600,  500,    7000, 'BSE_DIRECT'),
(10, 9,  '2024-03-15 04:35:00.000',  249.9500,  250.0000,  249.9800,15000,12000,  310000, 'NSE_DIRECT'),
(11, 10, '2024-03-15 14:30:00.200',  419.8500,  419.9000,  419.8800,  300,  400,  125000, 'NASDAQ_ITCH'),
(12, 10, '2024-03-15 14:30:01.350',  419.8800,  419.9300,  419.9000,  250,  350,  126500, 'NASDAQ_ITCH'),
(13, 19, '2024-03-15 08:00:00.800',  388.1000,  388.3000,  388.2000,   80,   60,    2400, 'XETRA_MDI'),
(14, 11, '2024-03-15 14:31:00.100',  174.9400,  174.9600,  174.9500,  900, 1100,   98000, 'NASDAQ_ITCH'),
(15, 11, '2024-03-15 14:31:02.500',  174.9600,  174.9900,  174.9800,  700,  850,   98900, 'NASDAQ_ITCH'),
(16, 20, '2024-03-15 08:01:00.200',  161.1000,  161.3000,  161.2000,  100,  120,    3100, 'XETRA_MDI'),
(17, 12, '2024-03-15 14:32:00.300',  885.0000,  885.3000,  885.2000,  150,  200,   45000, 'NASDAQ_ITCH'),
(18, 13, '2024-03-15 14:33:00.400',  173.4000,  173.5000,  173.4500,  600,  500,   87000, 'NASDAQ_ITCH'),
(19, 14, '2024-03-15 14:34:00.150',  149.8000,  149.9000,  149.8500,  400,  450,   52000, 'NASDAQ_ITCH'),
(20, 15, '2024-03-15 14:35:00.600',  520.2800,  520.3200,  520.3000, 1200, 1500,  310000, 'NYSE_PILLAR'),
(21, 16, '2024-03-15 14:36:00.250',  444.1000,  444.2000,  444.1500,  700,  900,  120000, 'NASDAQ_ITCH'),
(22, 17, '2024-03-15 09:00:00.500',    6.5800,    6.6000,    6.5900,25000,30000, 1250000, 'LSE_DIRECT'),
(23, 18, '2024-03-15 09:01:00.100',    4.9000,    4.9100,    4.9100,18000,22000,  900000, 'LSE_DIRECT'),
(24, 21, '2024-03-15 02:00:00.300',   65.2000,   65.2500,   65.2000,50000,60000, 2100000, 'HKEX_OMDC');

INSERT INTO algorithm_training_data (algorithm_id, feed_id, data_split, added_at) VALUES
(1,  1,  'TRAINING',   '2023-03-12 10:00:00'),
(1,  2,  'TRAINING',   '2023-03-12 10:00:00'),
(1,  3,  'VALIDATION', '2023-03-12 10:00:00'),
(1,  6,  'TESTING',    '2023-03-12 10:00:00'),
(2,  1,  'TRAINING',   '2024-02-22 10:00:00'),
(2,  6,  'TRAINING',   '2024-02-22 10:00:00'),
(2,  8,  'VALIDATION', '2024-02-22 10:00:00'),
(3,  11, 'TRAINING',   '2023-06-28 11:00:00'),
(3,  12, 'TRAINING',   '2023-06-28 11:00:00'),
(3,  14, 'TRAINING',   '2023-06-28 11:00:00'),
(3,  17, 'TESTING',    '2023-06-28 11:00:00'),
(3,  18, 'TESTING',    '2023-06-28 11:00:00'),
(4,  4,  'TRAINING',   '2023-08-05 12:00:00'),
(4,  8,  'TRAINING',   '2023-08-05 12:00:00'),
(4,  9,  'VALIDATION', '2023-08-05 12:00:00'),
(5,  11, 'VALIDATION', '2023-09-15 12:00:00'),
(5,  14, 'TRAINING',   '2023-09-15 12:00:00'),
(5,  17, 'TESTING',    '2023-09-15 12:00:00'),
(5,  19, 'TRAINING',   '2023-09-15 12:00:00'),
(6,  22, 'TRAINING',   '2023-11-08 12:00:00'),
(6,  23, 'TRAINING',   '2023-11-08 12:00:00'),
(6,  24, 'VALIDATION', '2023-11-08 12:00:00'),
(7,  8,  'TRAINING',   '2024-01-10 09:00:00'),
(7,  9,  'TRAINING',   '2024-01-10 09:00:00'),
(7,  11, 'TRAINING',   '2024-01-10 09:00:00'),
(7,  13, 'VALIDATION', '2024-01-10 09:00:00'),
(7,  14, 'TRAINING',   '2024-01-10 09:00:00'),
(7,  16, 'TESTING',    '2024-01-10 09:00:00'),
(8,  1,  'TRAINING',   '2023-05-20 09:30:00'),
(8,  4,  'TRAINING',   '2023-05-20 09:30:00'),
(8,  6,  'VALIDATION', '2023-05-20 09:30:00'),
(9,  10, 'TRAINING',   '2024-04-12 14:00:00'),
(9,  20, 'TRAINING',   '2024-04-12 14:00:00'),
(9,  21, 'TESTING',    '2024-04-12 14:00:00'),
(10, 17, 'TRAINING',   '2024-06-05 15:00:00'),
(10, 18, 'TRAINING',   '2024-06-05 15:00:00'),
(11, 22, 'TRAINING',   '2024-07-16 15:30:00'),
(11, 23, 'VALIDATION', '2024-07-16 15:30:00'),
(12, 10, 'TRAINING',   '2024-08-02 16:00:00'),
(12, 20, 'TRAINING',   '2024-08-02 16:00:00'),
(12, 21, 'TRAINING',   '2024-08-02 16:00:00');

-- Orders: trader_id/portfolio_id pairs all exist in portfolio_owners.
INSERT INTO orders (order_id, trader_id, portfolio_id, security_id, algorithm_id, side, order_type, quantity, limit_price, time_in_force, status, created_at, updated_at) VALUES
(1,  1,  1,  1,  8,    'BUY',  'LIMIT',  1000.0000, 1652.0000, 'DAY', 'FILLED',           '2024-03-15 03:50:00', '2024-03-15 04:05:12'),
(2,  6,  1,  2,  NULL, 'BUY',  'LIMIT',   500.0000, 4050.0000, 'DAY', 'PARTIALLY_FILLED', '2024-03-15 03:52:00', '2024-03-15 04:10:00'),
(3,  3,  3,  3,  1,    'SELL', 'LIMIT',  2000.0000, 2951.0000, 'IOC', 'FILLED',           '2024-03-15 04:00:30', '2024-03-15 04:00:31'),
(4,  7,  2,  6,  3,    'BUY',  'MARKET',  150.0000, NULL,      'DAY', 'FILLED',           '2024-03-15 14:30:00', '2024-03-15 14:30:03'),
(5,  8,  2,  7,  NULL, 'BUY',  'LIMIT',   200.0000,  175.0000, 'GTC', 'PARTIALLY_FILLED', '2024-03-15 14:31:00', '2024-03-15 14:45:00'),
(6,  4,  5,  8,  5,    'SELL', 'LIMIT',   100.0000,  885.0000, 'DAY', 'FILLED',           '2024-03-15 14:32:00', '2024-03-15 14:32:05'),
(7,  5,  8,  4,  7,    'BUY',  'MARKET', 1000.0000, NULL,      'FOK', 'FILLED',           '2024-03-15 04:30:00', '2024-03-15 04:30:01'),
(8,  3,  8,  4,  7,    'SELL', 'MARKET', 1000.0000, NULL,      'FOK', 'FILLED',           '2024-03-15 04:30:02', '2024-03-15 04:30:03'),
(9,  7,  4,  9,  NULL, 'SELL', 'STOP',    100.0000,  170.0000, 'DAY', 'NEW',              '2024-03-15 14:40:00', '2024-03-15 14:40:00'),
(10, 8,  7,  13, 6,    'BUY',  'LIMIT',   800.0000,    6.6000, 'DAY', 'PARTIALLY_FILLED', '2024-03-15 09:00:00', '2024-03-15 09:20:00'),
(11, 6,  6,  2,  NULL, 'SELL', 'LIMIT',   200.0000, 4100.0000, 'GTC', 'CANCELLED',        '2024-03-14 05:00:00', '2024-03-15 03:46:00'),
(12, 1,  10, 4,  4,    'BUY',  'LIMIT',   500.0000, 1438.0000, 'DAY', 'REJECTED',         '2024-03-15 04:31:00', '2024-03-15 04:31:01'),
(13, 6,  9,  11, NULL, 'BUY',  'LIMIT',   150.0000,  520.5000, 'DAY', 'FILLED',           '2024-03-15 14:35:00', '2024-03-15 14:35:04'),
(14, 8,  12, 12, NULL, 'BUY',  'LIMIT',   300.0000,  444.0000, 'DAY', 'PENDING',          '2024-03-15 14:36:00', '2024-03-15 14:36:01'),
(15, 3,  3,  1,  2,    'BUY',  'LIMIT',  3000.0000, 1651.0000, 'DAY', 'PARTIALLY_FILLED', '2024-03-15 03:46:00', '2024-03-15 05:30:00'),
(16, 10, 5,  10, 5,    'BUY',  'LIMIT',    80.0000,  150.0000, 'DAY', 'FILLED',           '2024-03-15 14:34:00', '2024-03-15 14:34:02'),
(17, 9,  4,  9,  10,   'BUY',  'LIMIT',    75.0000,  173.0000, 'DAY', 'CANCELLED',        '2024-03-15 14:41:00', '2024-03-15 14:42:00');

-- Orders 4, 5, 7, 8, 10 and 15 are split across several exchanges.
INSERT INTO order_routes (order_id, exchange_id, routed_quantity, routed_at, route_status, routing_reason) VALUES
(1,  1,  1000.0000, '2024-03-15 03:50:00.100', 'FILLED',           'Best displayed price on primary venue'),
(2,  1,   500.0000, '2024-03-15 03:52:00.100', 'PARTIALLY_FILLED', 'Primary venue holds deepest liquidity'),
(3,  1,  2000.0000, '2024-03-15 04:00:30.200', 'FILLED',           'IOC sweep of primary venue book'),
(4,  3,   100.0000, '2024-03-15 14:30:00.300', 'FILLED',           'Primary listing venue'),
(4,  6,    50.0000, '2024-03-15 14:30:00.300', 'FILLED',           'Split to capture EUR liquidity on Xetra'),
(5,  3,   150.0000, '2024-03-15 14:31:00.200', 'PARTIALLY_FILLED', 'Primary listing venue'),
(5,  6,    50.0000, '2024-03-15 14:31:00.200', 'SENT',             'Secondary venue for extra liquidity'),
(6,  3,   100.0000, '2024-03-15 14:32:00.400', 'FILLED',           'Only active US listing'),
(7,  1,   600.0000, '2024-03-15 04:30:00.200', 'FILLED',           'Arbitrage leg - NSE'),
(7,  2,   400.0000, '2024-03-15 04:30:00.200', 'FILLED',           'Arbitrage leg - BSE'),
(8,  1,   550.0000, '2024-03-15 04:30:02.100', 'FILLED',           'Arbitrage leg - NSE'),
(8,  2,   450.0000, '2024-03-15 04:30:02.100', 'FILLED',           'Arbitrage leg - BSE'),
(10, 5,   500.0000, '2024-03-15 09:00:00.300', 'FILLED',           'Primary UK listing'),
(10, 7,   300.0000, '2024-03-15 09:00:00.300', 'SENT',             'Secondary listing in Hong Kong'),
(11, 1,   200.0000, '2024-03-14 05:00:00.100', 'CANCELLED',        'Cancelled by trader before execution'),
(12, 1,   500.0000, '2024-03-15 04:31:00.100', 'REJECTED',         'Price outside circuit-limit band'),
(13, 4,   150.0000, '2024-03-15 14:35:00.200', 'FILLED',           'Primary listing venue'),
(14, 3,   300.0000, '2024-03-15 14:36:00.300', 'PENDING',          'Resting passive limit order'),
(15, 1,  2000.0000, '2024-03-15 03:46:00.200', 'PARTIALLY_FILLED', 'Quote on primary venue'),
(15, 2,  1000.0000, '2024-03-15 03:46:00.200', 'PARTIALLY_FILLED', 'Quote on secondary venue'),
(16, 3,    80.0000, '2024-03-15 14:34:00.200', 'FILLED',           'Primary listing venue');

INSERT INTO trades (trade_id, order_id, exchange_id, execution_reference, executed_quantity, execution_price, executed_at, commission, settlement_status) VALUES
(1,  1,  1, 'NSE-20240315-000001',  400.0000, 1651.3000, '2024-03-15 03:50:01.120',  198.1600, 'SETTLED'),
(2,  1,  1, 'NSE-20240315-000002',  350.0000, 1651.5000, '2024-03-15 03:52:10.450',  173.4100, 'SETTLED'),
(3,  1,  1, 'NSE-20240315-000003',  250.0000, 1651.4500, '2024-03-15 04:05:12.000',  123.8600, 'SETTLED'),
(4,  2,  1, 'NSE-20240315-000004',  200.0000, 4048.7500, '2024-03-15 03:55:00.300',  242.9300, 'SETTLED'),
(5,  2,  1, 'NSE-20240315-000005',  100.0000, 4049.0000, '2024-03-15 04:10:00.000',  121.4700, 'SETTLED'),
(6,  3,  1, 'NSE-20240315-000006', 1200.0000, 2951.3000, '2024-03-15 04:00:30.500', 1062.4700, 'SETTLED'),
(7,  3,  1, 'NSE-20240315-000007',  800.0000, 2951.1000, '2024-03-15 04:00:30.900',  708.2600, 'SETTLED'),
(8,  4,  3, 'XNAS-20240315-000001',  60.0000,  419.8800, '2024-03-15 14:30:01.000',    1.0000, 'SETTLED'),
(9,  4,  3, 'XNAS-20240315-000002',  40.0000,  419.9000, '2024-03-15 14:30:01.800',    1.0000, 'SETTLED'),
(10, 4,  6, 'XETR-20240315-000001',  50.0000,  388.2000, '2024-03-15 14:30:02.400',    1.7500, 'SETTLED'),
(11, 5,  3, 'XNAS-20240315-000003',  90.0000,  174.9500, '2024-03-15 14:31:05.200',    1.0000, 'PENDING'),
(12, 5,  3, 'XNAS-20240315-000004',  30.0000,  175.0000, '2024-03-15 14:45:00.000',    1.0000, 'PENDING'),
(13, 6,  3, 'XNAS-20240315-000005',  60.0000,  885.4000, '2024-03-15 14:32:03.100',    1.0000, 'SETTLED'),
(14, 6,  3, 'XNAS-20240315-000006',  40.0000,  885.1000, '2024-03-15 14:32:04.700',    1.0000, 'SETTLED'),
(15, 7,  1, 'NSE-20240315-000008',  350.0000, 1440.3000, '2024-03-15 04:30:00.400',  151.2300, 'SETTLED'),
(16, 7,  1, 'NSE-20240315-000009',  250.0000, 1440.3500, '2024-03-15 04:30:00.700',  108.0300, 'SETTLED'),
(17, 7,  2, 'BSE-20240315-000001',  400.0000, 1440.4500, '2024-03-15 04:30:00.900',  172.8500, 'SETTLED'),
(18, 8,  1, 'NSE-20240315-000010',  550.0000, 1440.2000, '2024-03-15 04:30:02.300',  237.6300, 'SETTLED'),
(19, 8,  2, 'BSE-20240315-000002',  450.0000, 1440.0500, '2024-03-15 04:30:02.800',  194.4100, 'SETTLED'),
(20, 10, 5, 'XLON-20240315-000001', 300.0000,    6.5800, '2024-03-15 09:05:00.100',    1.9700, 'SETTLED'),
(21, 10, 5, 'XLON-20240315-000002', 200.0000,    6.5900, '2024-03-15 09:20:00.000',    1.3200, 'PENDING'),
(22, 13, 4, 'XNYS-20240315-000001', 100.0000,  520.3000, '2024-03-15 14:35:02.100',    1.0000, 'PENDING'),
(23, 13, 4, 'XNYS-20240315-000002',  50.0000,  520.4500, '2024-03-15 14:35:04.000',    1.0000, 'PENDING'),
(24, 15, 1, 'NSE-20240315-000011',  900.0000, 1650.7000, '2024-03-15 03:47:10.100',  445.6900, 'SETTLED'),
(25, 15, 2, 'BSE-20240315-000003',  800.0000, 1650.9500, '2024-03-15 03:50:20.600',  396.2300, 'SETTLED'),
(26, 15, 1, 'NSE-20240315-000012',  700.0000, 1650.9000, '2024-03-15 05:30:00.000',  346.6900, 'SETTLED'),
(27, 16, 3, 'XNAS-20240315-000007',   80.0000,  149.8500, '2024-03-15 14:34:01.500',    1.0000, 'PENDING');

-- Row counts (sanity check)
SELECT 'traders' AS table_name, COUNT(*) AS row_count FROM traders
UNION ALL SELECT 'algorithms', COUNT(*) FROM algorithms
UNION ALL SELECT 'portfolios', COUNT(*) FROM portfolios
UNION ALL SELECT 'securities', COUNT(*) FROM securities
UNION ALL SELECT 'exchanges', COUNT(*) FROM exchanges
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'trades', COUNT(*) FROM trades
UNION ALL SELECT 'market_feed_data', COUNT(*) FROM market_feed_data
UNION ALL SELECT 'algorithm_developers', COUNT(*) FROM algorithm_developers
UNION ALL SELECT 'portfolio_owners', COUNT(*) FROM portfolio_owners
UNION ALL SELECT 'portfolio_holdings', COUNT(*) FROM portfolio_holdings
UNION ALL SELECT 'security_listings', COUNT(*) FROM security_listings
UNION ALL SELECT 'algorithm_training_data', COUNT(*) FROM algorithm_training_data
UNION ALL SELECT 'order_routes', COUNT(*) FROM order_routes;