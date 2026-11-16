-- =====================================================================
-- 05_dml_operations.sql  -  DML: INSERT, UPDATE, DELETE, TRANSACTIONS
-- (rubric 3: DML operations)
-- Run:  mysql -u root -p -t < sql/05_dml_operations.sql
--
-- Every demo runs inside a transaction that is ROLLED BACK at the end, so
-- the script can be run any number of times and leaves the data unchanged.
-- Statements that are REJECTED on purpose are at the bottom, commented out;
-- run them one at a time to see the error.
-- =====================================================================

USE HFT;
START TRANSACTION;

-- 1. INSERT a single row (a new exchange)
INSERT INTO exchanges (exchange_name, mic_code, country, timezone)
VALUES ('Frankfurt Stock Exchange', 'XFRA', 'Germany', 'Europe/Berlin');
SELECT exchange_id, exchange_name, mic_code FROM exchanges WHERE mic_code = 'XFRA';

-- 2. INSERT several rows in one statement (two new traders in the hierarchy)
INSERT INTO traders (full_name, email, desk, role, reports_to) VALUES
('Test Trader One', 'test.one@quantedge.example', 'Equity Algo', 'Trader', 1),
('Test Trader Two', 'test.two@quantedge.example', 'Equity Algo', 'Trader', 1);
SELECT trader_id, full_name, reports_to FROM traders WHERE email LIKE 'test.%@quantedge.example';

-- 3. INSERT ... SELECT (copy half of portfolio 6's holdings into closed portfolio 11)
INSERT INTO portfolio_holdings (portfolio_id, security_id, quantity_held, avg_price)
SELECT 11, security_id, quantity_held / 2, avg_price
  FROM portfolio_holdings WHERE portfolio_id = 6;
SELECT portfolio_id, security_id, quantity_held FROM portfolio_holdings WHERE portfolio_id = 11;

-- 4. UPDATE one row (suspend a portfolio)
UPDATE portfolios SET status = 'SUSPENDED' WHERE portfolio_id = 4;
SELECT portfolio_id, portfolio_name, status FROM portfolios WHERE portfolio_id = 4;

-- 5. UPDATE with a subquery (grow every ETF holding by 10 %)
SELECT portfolio_id, security_id, quantity_held FROM portfolio_holdings
 WHERE security_id IN (SELECT security_id FROM securities WHERE asset_type = 'ETF') AND portfolio_id = 9;
UPDATE portfolio_holdings
   SET quantity_held = quantity_held * 1.10
 WHERE security_id IN (SELECT security_id FROM securities WHERE asset_type = 'ETF');
SELECT portfolio_id, security_id, quantity_held FROM portfolio_holdings
 WHERE security_id IN (SELECT security_id FROM securities WHERE asset_type = 'ETF') AND portfolio_id = 9;

-- 6. UPDATE with a JOIN (annotate each algorithm with how many orders it produced)
UPDATE algorithms a
  JOIN (SELECT algorithm_id, COUNT(*) AS n FROM orders WHERE algorithm_id IS NOT NULL GROUP BY algorithm_id) x
    ON x.algorithm_id = a.algorithm_id
   SET a.description = CONCAT(a.description, ' [orders: ', x.n, ']');
SELECT algorithm_id, algorithm_name, version, description FROM algorithms WHERE algorithm_id IN (2, 5, 7);

-- 7. DELETE with a condition (remove the TESTING rows of algorithm 3)
SELECT COUNT(*) AS before_delete FROM algorithm_training_data WHERE algorithm_id = 3;
DELETE FROM algorithm_training_data WHERE algorithm_id = 3 AND data_split = 'TESTING';
SELECT COUNT(*) AS after_delete FROM algorithm_training_data WHERE algorithm_id = 3;

-- 8. DELETE using a subquery (remove market quotes of listings on a suspended exchange)
--    none exist here, so 0 rows are affected - shows the form of the statement
DELETE FROM market_feed_data
 WHERE listing_id IN (SELECT sl.listing_id FROM security_listings sl
                       JOIN exchanges e ON e.exchange_id = sl.exchange_id
                      WHERE e.status = 'SUSPENDED');
SELECT ROW_COUNT() AS rows_deleted;

-- 9. SAVEPOINT: undo only part of a transaction
SAVEPOINT before_status_change;
UPDATE orders SET status = 'CANCELLED' WHERE order_id = 9;
SELECT order_id, status FROM orders WHERE order_id = 9;            -- CANCELLED
ROLLBACK TO SAVEPOINT before_status_change;
SELECT order_id, status FROM orders WHERE order_id = 9;            -- NEW again

-- Undo EVERYTHING done above
ROLLBACK;
SELECT COUNT(*) AS exchanges_after_rollback FROM exchanges;        -- 12 (XFRA is gone)

-- 10. COMMIT demo, harmless: a transaction that changes a value and commits it back
START TRANSACTION;
UPDATE portfolios SET status = 'ACTIVE' WHERE portfolio_id = 4;    -- already ACTIVE
COMMIT;

-- ---------------------------------------------------------------------
-- REJECTED ON PURPOSE (run one at a time; each fails with the message shown)
-- ---------------------------------------------------------------------
-- DELETE FROM exchanges WHERE exchange_id = 1;
--   ERROR 1451: Cannot delete or update a parent row (security_listings and trades reference NSE)
-- INSERT INTO trades (order_id, exchange_id, execution_reference, executed_quantity, execution_price, executed_at)
--   VALUES (2, 2, 'X-2', 1, 4000, NOW());
--   ERROR 1452: order 2 was never routed to the BSE (composite FK fk_trades_route)
-- UPDATE orders SET quantity = -5 WHERE order_id = 9;
--   ERROR 3819: Check constraint 'chk_orders_qty' is violated
-- DELETE FROM traders WHERE trader_id = 1;
--   ERROR 1451: trader 1 owns portfolios and has orders (ON DELETE RESTRICT)
