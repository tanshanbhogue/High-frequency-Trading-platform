-- =====================================================================
-- 08_procedures.sql  -  STORED PROCEDURES  (rubric 4: procedure)
-- Run after 01, 02, 03:   mysql -u root -p < sql/08_procedures.sql
-- Re-runnable (drops and recreates the procedures).
--
-- These four procedures are the ONLY way the 'hft_trader' account can
-- change data. They validate business rules, then write. Because they run
-- with SQL SECURITY DEFINER (the admin who created them), the trader
-- account needs no INSERT/UPDATE privileges on the tables themselves.
--
--   sp_place_order  - validates trader/portfolio/security/algorithm, inserts NEW order
--   sp_route_order  - routes an open order to an exchange (trigger checks listing + qty)
--   sp_add_trade    - records an execution (triggers check qty and sync order status)
--   sp_cancel_order - cancels an open order and its unsent routes
-- =====================================================================

USE HFT;

DROP PROCEDURE IF EXISTS sp_place_order;
DROP PROCEDURE IF EXISTS sp_route_order;
DROP PROCEDURE IF EXISTS sp_add_trade;
DROP PROCEDURE IF EXISTS sp_cancel_order;

DELIMITER $$

-- ---------------------------------------------------------------------
-- sp_place_order: returns the new order id in p_order_id
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_place_order(
    IN  p_trader_id     INT,
    IN  p_portfolio_id  INT,
    IN  p_security_id   INT,
    IN  p_algorithm_id  INT,              -- NULL = manual order
    IN  p_side          VARCHAR(4),
    IN  p_order_type    VARCHAR(6),
    IN  p_quantity      DECIMAL(18,4),
    IN  p_limit_price   DECIMAL(18,4),    -- NULL for MARKET orders
    IN  p_time_in_force VARCHAR(3),       -- NULL = DAY
    OUT p_order_id      BIGINT)
BEGIN
    DECLARE v_status VARCHAR(12);
    DECLARE v_owner  INT DEFAULT 0;

    SET v_status = NULL;
    SELECT status INTO v_status FROM traders WHERE trader_id = p_trader_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trader does not exist';
    ELSEIF v_status <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trader is not ACTIVE and cannot place orders';
    END IF;

    SET v_status = NULL;
    SELECT status INTO v_status FROM portfolios WHERE portfolio_id = p_portfolio_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Portfolio does not exist';
    ELSEIF v_status <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Portfolio is not ACTIVE';
    END IF;

    SELECT COUNT(*) INTO v_owner FROM portfolio_owners
     WHERE trader_id = p_trader_id AND portfolio_id = p_portfolio_id;
    IF v_owner = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trader is not an owner of this portfolio';
    END IF;

    SET v_status = NULL;
    SELECT status INTO v_status FROM securities WHERE security_id = p_security_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Security does not exist';
    ELSEIF v_status <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Security is not ACTIVE for trading';
    END IF;

    IF p_algorithm_id IS NOT NULL THEN
        SET v_status = NULL;
        SELECT status INTO v_status FROM algorithms WHERE algorithm_id = p_algorithm_id;
        IF v_status IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Algorithm does not exist';
        ELSEIF v_status IN ('RETIRED', 'DEVELOPMENT') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Algorithm is RETIRED or still in DEVELOPMENT';
        END IF;
    END IF;

    INSERT INTO orders (trader_id, portfolio_id, security_id, algorithm_id, side,
                        order_type, quantity, limit_price, time_in_force, status)
    VALUES (p_trader_id, p_portfolio_id, p_security_id, p_algorithm_id, p_side,
            p_order_type, p_quantity, p_limit_price, COALESCE(p_time_in_force, 'DAY'), 'NEW');

    SET p_order_id = LAST_INSERT_ID();
END$$

-- ---------------------------------------------------------------------
-- sp_route_order: the trg_routes_* triggers verify that the security is
-- listed on the exchange and that routed quantity <= order quantity.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_route_order(
    IN p_order_id    BIGINT,
    IN p_exchange_id INT,
    IN p_quantity    DECIMAL(18,4),
    IN p_reason      VARCHAR(150))
BEGIN
    DECLARE v_status VARCHAR(16);

    SET v_status = NULL;
    SELECT status INTO v_status FROM orders WHERE order_id = p_order_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order does not exist';
    ELSEIF v_status NOT IN ('NEW', 'PENDING', 'PARTIALLY_FILLED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order is not open for routing (filled, cancelled or rejected)';
    END IF;

    INSERT INTO order_routes (order_id, exchange_id, routed_quantity, routed_at, route_status, routing_reason)
    VALUES (p_order_id, p_exchange_id, p_quantity, UTC_TIMESTAMP(3), 'SENT', p_reason);

    UPDATE orders SET status = 'PENDING' WHERE order_id = p_order_id AND status = 'NEW';
END$$

-- ---------------------------------------------------------------------
-- sp_add_trade: records an execution. The FK to order_routes guarantees
-- the exchange was routed to; trg_trades_before_insert checks quantities;
-- trg_trades_sync_status then moves the order to PARTIALLY_FILLED/FILLED.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_add_trade(
    IN  p_order_id    BIGINT,
    IN  p_exchange_id INT,
    IN  p_quantity    DECIMAL(18,4),
    IN  p_price       DECIMAL(18,4),
    IN  p_commission  DECIMAL(14,4),
    OUT p_trade_id    BIGINT)
BEGIN
    DECLARE v_status VARCHAR(16);
    DECLARE v_side   VARCHAR(4);
    DECLARE v_type   VARCHAR(6);
    DECLARE v_limit  DECIMAL(18,4);
    DECLARE v_mic    CHAR(4);

    SET v_status = NULL;
    SELECT status, side, order_type, limit_price INTO v_status, v_side, v_type, v_limit
      FROM orders WHERE order_id = p_order_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order does not exist';
    ELSEIF v_status NOT IN ('PENDING', 'PARTIALLY_FILLED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order must be routed (PENDING) or PARTIALLY_FILLED to accept trades';
    END IF;

    -- A LIMIT order may not execute at a worse price than its limit.
    IF v_type = 'LIMIT' AND v_side = 'BUY'  AND p_price > v_limit THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Execution price is above the BUY limit price';
    END IF;
    IF v_type = 'LIMIT' AND v_side = 'SELL' AND p_price < v_limit THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Execution price is below the SELL limit price';
    END IF;

    SET v_mic = NULL;
    SELECT mic_code INTO v_mic FROM exchanges WHERE exchange_id = p_exchange_id;
    IF v_mic IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exchange does not exist';
    END IF;

    INSERT INTO trades (order_id, exchange_id, execution_reference, executed_quantity,
                        execution_price, executed_at, commission, settlement_status)
    VALUES (p_order_id, p_exchange_id, CONCAT(v_mic, '-', UUID_SHORT()), p_quantity,
            p_price, UTC_TIMESTAMP(3), COALESCE(p_commission, 0), 'PENDING');

    SET p_trade_id = LAST_INSERT_ID();
END$$

-- ---------------------------------------------------------------------
-- sp_cancel_order: p_trader_id = the caller (must own the order), or NULL
-- when an administrator cancels. Uses its own transaction, so do not call
-- it inside an open transaction (START TRANSACTION would commit it).
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_cancel_order(
    IN p_order_id  BIGINT,
    IN p_trader_id INT)
BEGIN
    DECLARE v_status VARCHAR(16);
    DECLARE v_owner  INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_status = NULL;
    SELECT status, trader_id INTO v_status, v_owner FROM orders WHERE order_id = p_order_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order does not exist';
    ELSEIF p_trader_id IS NOT NULL AND p_trader_id <> v_owner THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only the trader who placed the order can cancel it';
    ELSEIF v_status NOT IN ('NEW', 'PENDING', 'PARTIALLY_FILLED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order cannot be cancelled in its current status';
    END IF;

    START TRANSACTION;
    UPDATE order_routes SET route_status = 'CANCELLED'
     WHERE order_id = p_order_id AND route_status IN ('PENDING', 'SENT');
    UPDATE orders SET status = 'CANCELLED' WHERE order_id = p_order_id;
    COMMIT;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- Who may run them: the trader role only (auditor: none).
-- ---------------------------------------------------------------------
GRANT EXECUTE ON PROCEDURE HFT.sp_place_order  TO 'hft_trader';
GRANT EXECUTE ON PROCEDURE HFT.sp_route_order  TO 'hft_trader';
GRANT EXECUTE ON PROCEDURE HFT.sp_add_trade    TO 'hft_trader';
GRANT EXECUTE ON PROCEDURE HFT.sp_cancel_order TO 'hft_trader';

-- ---------------------------------------------------------------------
-- Sample calls (inside a transaction, then rolled back)
-- ---------------------------------------------------------------------
START TRANSACTION;
CALL sp_place_order(3, 3, 4, NULL, 'BUY', 'LIMIT', 100, 1440.00, 'DAY', @oid);
SELECT @oid AS new_order_id;
CALL sp_route_order(@oid, 1, 100, 'Sample route to NSE');
CALL sp_add_trade(@oid, 1, 60, 1439.50, 8.64, @tid);
SELECT order_id, status, quantity FROM orders WHERE order_id = @oid;
ROLLBACK;
