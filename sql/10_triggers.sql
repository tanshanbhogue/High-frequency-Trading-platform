-- =====================================================================
-- 10_triggers.sql  -  NEW TRIGGERS  (rubric 4: trigger)
-- Run after 02, 08, 09:   mysql -u root -p < sql/10_triggers.sql
-- Re-runnable (drops and recreates these triggers only).
--
-- Triggers created earlier in 01_HFT.sql (still active):
--   trg_po_before_insert/_update      ownership of a portfolio <= 100 %
--   trg_routes_before_insert/_update  security must be listed on the exchange;
--                                     routed quantity <= order quantity
--   trg_trades_before_insert/_update  executed quantity <= order / route quantity
-- Trigger created in 02_schema_additions.sql:
--   trg_app_users_before_insert/_update  a TRADER login needs a trader_id
--
-- Created here:
--   AUDIT      orders and trades: every INSERT/UPDATE/DELETE is written to
--              audit_log as JSON (who = @app_user set by the web app, else USER())
--   STATUS SYNC trg_trades_sync_status: a new trade moves the order to
--              PARTIALLY_FILLED / FILLED and updates its route's status
-- =====================================================================

USE HFT;

DROP TRIGGER IF EXISTS trg_orders_audit_ai;
DROP TRIGGER IF EXISTS trg_orders_audit_au;
DROP TRIGGER IF EXISTS trg_orders_audit_ad;
DROP TRIGGER IF EXISTS trg_trades_audit_ai;
DROP TRIGGER IF EXISTS trg_trades_audit_au;
DROP TRIGGER IF EXISTS trg_trades_audit_ad;
DROP TRIGGER IF EXISTS trg_trades_sync_status;

DELIMITER $$

-- ---------------------------------------------------------------------
-- AUDIT: orders
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_orders_audit_ai AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, row_key, old_values, new_values, changed_by)
    VALUES ('orders', 'INSERT', NEW.order_id, NULL,
            JSON_OBJECT('trader_id', NEW.trader_id, 'portfolio_id', NEW.portfolio_id,
                        'security_id', NEW.security_id, 'algorithm_id', NEW.algorithm_id,
                        'side', NEW.side, 'order_type', NEW.order_type, 'quantity', NEW.quantity,
                        'limit_price', NEW.limit_price, 'status', NEW.status),
            COALESCE(@app_user, USER()));
END$$

CREATE TRIGGER trg_orders_audit_au AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, row_key, old_values, new_values, changed_by)
    VALUES ('orders', 'UPDATE', NEW.order_id,
            JSON_OBJECT('quantity', OLD.quantity, 'limit_price', OLD.limit_price, 'status', OLD.status),
            JSON_OBJECT('quantity', NEW.quantity, 'limit_price', NEW.limit_price, 'status', NEW.status),
            COALESCE(@app_user, USER()));
END$$

CREATE TRIGGER trg_orders_audit_ad AFTER DELETE ON orders
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, row_key, old_values, new_values, changed_by)
    VALUES ('orders', 'DELETE', OLD.order_id,
            JSON_OBJECT('trader_id', OLD.trader_id, 'portfolio_id', OLD.portfolio_id,
                        'security_id', OLD.security_id, 'side', OLD.side,
                        'quantity', OLD.quantity, 'status', OLD.status),
            NULL, COALESCE(@app_user, USER()));
END$$

-- ---------------------------------------------------------------------
-- AUDIT: trades
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_trades_audit_ai AFTER INSERT ON trades
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, row_key, old_values, new_values, changed_by)
    VALUES ('trades', 'INSERT', NEW.trade_id, NULL,
            JSON_OBJECT('order_id', NEW.order_id, 'exchange_id', NEW.exchange_id,
                        'execution_reference', NEW.execution_reference,
                        'executed_quantity', NEW.executed_quantity,
                        'execution_price', NEW.execution_price, 'commission', NEW.commission),
            COALESCE(@app_user, USER()));
END$$

CREATE TRIGGER trg_trades_audit_au AFTER UPDATE ON trades
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, row_key, old_values, new_values, changed_by)
    VALUES ('trades', 'UPDATE', NEW.trade_id,
            JSON_OBJECT('executed_quantity', OLD.executed_quantity, 'execution_price', OLD.execution_price,
                        'settlement_status', OLD.settlement_status),
            JSON_OBJECT('executed_quantity', NEW.executed_quantity, 'execution_price', NEW.execution_price,
                        'settlement_status', NEW.settlement_status),
            COALESCE(@app_user, USER()));
END$$

CREATE TRIGGER trg_trades_audit_ad AFTER DELETE ON trades
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, row_key, old_values, new_values, changed_by)
    VALUES ('trades', 'DELETE', OLD.trade_id,
            JSON_OBJECT('order_id', OLD.order_id, 'exchange_id', OLD.exchange_id,
                        'executed_quantity', OLD.executed_quantity, 'execution_price', OLD.execution_price),
            NULL, COALESCE(@app_user, USER()));
END$$

-- ---------------------------------------------------------------------
-- STATUS SYNC: keeps the stored order/route status consistent with trades.
-- Only open orders change (NEW/PENDING/PARTIALLY_FILLED); a CANCELLED or
-- REJECTED order keeps its status.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_trades_sync_status AFTER INSERT ON trades
FOR EACH ROW
BEGIN
    DECLARE v_order_qty  DECIMAL(18,4);
    DECLARE v_order_done DECIMAL(18,4);
    DECLARE v_route_qty  DECIMAL(18,4);
    DECLARE v_route_done DECIMAL(18,4);

    SELECT quantity INTO v_order_qty FROM orders WHERE order_id = NEW.order_id;
    SELECT SUM(executed_quantity) INTO v_order_done FROM trades WHERE order_id = NEW.order_id;

    UPDATE orders
       SET status = IF(v_order_done >= v_order_qty, 'FILLED', 'PARTIALLY_FILLED')
     WHERE order_id = NEW.order_id
       AND status IN ('NEW', 'PENDING', 'PARTIALLY_FILLED');

    SELECT routed_quantity INTO v_route_qty FROM order_routes
     WHERE order_id = NEW.order_id AND exchange_id = NEW.exchange_id;
    SELECT SUM(executed_quantity) INTO v_route_done FROM trades
     WHERE order_id = NEW.order_id AND exchange_id = NEW.exchange_id;

    UPDATE order_routes
       SET route_status = IF(v_route_done >= v_route_qty, 'FILLED', 'PARTIALLY_FILLED')
     WHERE order_id = NEW.order_id AND exchange_id = NEW.exchange_id
       AND route_status IN ('PENDING', 'SENT', 'PARTIALLY_FILLED');
END$$

DELIMITER ;

SELECT trigger_name, event_object_table AS on_table, action_timing AS timing, event_manipulation AS event
  FROM information_schema.triggers WHERE trigger_schema = 'HFT'
 ORDER BY event_object_table, action_timing DESC, event_manipulation, trigger_name;

-- ---------------------------------------------------------------------
-- Test (rolled back, leaves no trace): partial fill -> full fill + audit rows
-- ---------------------------------------------------------------------
START TRANSACTION;
SET @app_user = 'demo-script';
CALL sp_place_order(3, 3, 4, NULL, 'BUY', 'LIMIT', 100, 1440.00, 'DAY', @oid);
CALL sp_route_order(@oid, 1, 100, 'trigger test');
SELECT order_id, status FROM orders WHERE order_id = @oid;                       -- PENDING
CALL sp_add_trade(@oid, 1, 60, 1439.50, 8.64, @tid);
SELECT order_id, status FROM orders WHERE order_id = @oid;                       -- PARTIALLY_FILLED
SELECT exchange_id, route_status FROM order_routes WHERE order_id = @oid;        -- PARTIALLY_FILLED
CALL sp_add_trade(@oid, 1, 40, 1439.00, 5.76, @tid);
SELECT order_id, status FROM orders WHERE order_id = @oid;                       -- FILLED
SELECT exchange_id, route_status FROM order_routes WHERE order_id = @oid;        -- FILLED
SELECT table_name, action, row_key, changed_by FROM audit_log ORDER BY audit_id DESC LIMIT 8;
ROLLBACK;
SET @app_user = NULL;
