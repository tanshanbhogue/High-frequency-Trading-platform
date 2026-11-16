-- =====================================================================
-- 09_functions.sql  -  STORED FUNCTIONS  (rubric 4: function)
-- Run after 03:   mysql -u root -p < sql/09_functions.sql
-- Re-runnable.
--
--   fn_executed_quantity(order_id)   total quantity executed so far
--   fn_remaining_quantity(order_id)  order quantity minus executed
--   fn_order_vwap(order_id)          volume-weighted average execution price
--   fn_portfolio_value(portfolio_id) holdings x latest quote in the
--                                    security's own currency (see note)
-- =====================================================================

USE HFT;

DROP FUNCTION IF EXISTS fn_executed_quantity;
DROP FUNCTION IF EXISTS fn_remaining_quantity;
DROP FUNCTION IF EXISTS fn_order_vwap;
DROP FUNCTION IF EXISTS fn_portfolio_value;

DELIMITER $$

CREATE FUNCTION fn_executed_quantity(p_order_id BIGINT)
RETURNS DECIMAL(18,4)
READS SQL DATA
BEGIN
    DECLARE v_done DECIMAL(18,4);
    SELECT COALESCE(SUM(executed_quantity), 0) INTO v_done FROM trades WHERE order_id = p_order_id;
    RETURN v_done;
END$$

CREATE FUNCTION fn_remaining_quantity(p_order_id BIGINT)
RETURNS DECIMAL(18,4)
READS SQL DATA
BEGIN
    DECLARE v_qty DECIMAL(18,4);
    SELECT quantity INTO v_qty FROM orders WHERE order_id = p_order_id;
    RETURN v_qty - fn_executed_quantity(p_order_id);   -- NULL if the order does not exist
END$$

CREATE FUNCTION fn_order_vwap(p_order_id BIGINT)
RETURNS DECIMAL(18,6)
READS SQL DATA
BEGIN
    DECLARE v_vwap DECIMAL(18,6);
    SELECT SUM(executed_quantity * execution_price) / SUM(executed_quantity)
      INTO v_vwap FROM trades WHERE order_id = p_order_id;
    RETURN v_vwap;                                      -- NULL when there are no trades
END$$

-- NOTE: value is in each security's own currency. A portfolio that mixes
-- currencies (e.g. INR and USD holdings) therefore adds raw numbers; a real
-- system would convert with an FX table, which is outside this project.
CREATE FUNCTION fn_portfolio_value(p_portfolio_id INT)
RETURNS DECIMAL(24,4)
READS SQL DATA
BEGIN
    DECLARE v_value DECIMAL(24,4);
    SELECT COALESCE(SUM(ph.quantity_held *
             (SELECT m.last_price
                FROM market_feed_data m
                JOIN security_listings sl ON sl.listing_id = m.listing_id
               WHERE sl.security_id = ph.security_id AND sl.currency = s.currency
               ORDER BY m.feed_timestamp DESC LIMIT 1)), 0)
      INTO v_value
      FROM portfolio_holdings ph
      JOIN securities s ON s.security_id = ph.security_id
     WHERE ph.portfolio_id = p_portfolio_id;
    RETURN v_value;
END$$

DELIMITER ;

-- Read-only functions: both trader and auditor may use them.
GRANT EXECUTE ON FUNCTION HFT.fn_executed_quantity  TO 'hft_trader', 'hft_auditor';
GRANT EXECUTE ON FUNCTION HFT.fn_remaining_quantity TO 'hft_trader', 'hft_auditor';
GRANT EXECUTE ON FUNCTION HFT.fn_order_vwap         TO 'hft_trader', 'hft_auditor';
GRANT EXECUTE ON FUNCTION HFT.fn_portfolio_value    TO 'hft_trader', 'hft_auditor';

-- ---------------------------------------------------------------------
-- Sample calls
-- ---------------------------------------------------------------------
SELECT order_id, quantity, status,
       fn_executed_quantity(order_id)  AS executed,
       fn_remaining_quantity(order_id) AS remaining,
       fn_order_vwap(order_id)         AS vwap
  FROM orders ORDER BY order_id;

SELECT portfolio_id, portfolio_name, base_currency, fn_portfolio_value(portfolio_id) AS market_value
  FROM portfolios ORDER BY portfolio_id;
