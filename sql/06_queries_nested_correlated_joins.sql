-- =====================================================================
-- 06_queries_nested_correlated_joins.sql
-- Join, nested (subquery) and correlated queries (rubric 3)
-- Run:  mysql -u root -p -t < sql/06_queries_nested_correlated_joins.sql
-- =====================================================================
USE HFT;

-- Q1. JOIN (5 tables): every order with trader, portfolio, security and algorithm
SELECT o.order_id, t.full_name AS trader, p.portfolio_name, s.security_name,
       COALESCE(CONCAT(a.algorithm_name, ' v', a.version), 'MANUAL') AS algorithm, o.status
FROM orders o
JOIN traders t    ON t.trader_id = o.trader_id
JOIN portfolios p ON p.portfolio_id = o.portfolio_id
JOIN securities s ON s.security_id = o.security_id
LEFT JOIN algorithms a ON a.algorithm_id = o.algorithm_id
ORDER BY o.order_id;

-- Q2. SELF JOIN: every trader and their manager
SELECT t.trader_id, t.full_name AS trader, t.role, m.full_name AS reports_to
FROM traders t
LEFT JOIN traders m ON m.trader_id = t.reports_to
ORDER BY t.trader_id;

-- Q3. Nested query, IN: traders who have placed at least one algorithmic order
SELECT trader_id, full_name, desk
FROM traders
WHERE trader_id IN (SELECT trader_id FROM orders WHERE algorithm_id IS NOT NULL);

-- Q4. Nested query, NOT EXISTS: securities that have never been ordered
SELECT s.security_id, s.security_name
FROM securities s
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.security_id = s.security_id);

-- Q5. Nested query, scalar subquery: orders larger than the average order quantity
SELECT order_id, security_id, quantity
FROM orders
WHERE quantity > (SELECT AVG(quantity) FROM orders)
ORDER BY quantity DESC;

-- Q6. Nested query, ALL: holdings bigger than EVERY holding of portfolio 7
SELECT ph.portfolio_id, ph.security_id, ph.quantity_held
FROM portfolio_holdings ph
WHERE ph.quantity_held > ALL (SELECT quantity_held FROM portfolio_holdings WHERE portfolio_id = 7)
ORDER BY ph.quantity_held DESC;

-- Q7. Derived table (subquery in FROM): exchanges whose traded volume beats the average exchange volume
SELECT e.mic_code, v.volume
FROM (SELECT exchange_id, SUM(executed_quantity) AS volume FROM trades GROUP BY exchange_id) v
JOIN exchanges e ON e.exchange_id = v.exchange_id
WHERE v.volume > (SELECT AVG(volume) FROM (SELECT SUM(executed_quantity) AS volume FROM trades GROUP BY exchange_id) x)
ORDER BY v.volume DESC;

-- Q8. CORRELATED subquery: trades executed above the average price of THEIR OWN order
SELECT t.trade_id, t.order_id, t.execution_price,
       (SELECT AVG(t2.execution_price) FROM trades t2 WHERE t2.order_id = t.order_id) AS order_avg_price
FROM trades t
WHERE t.execution_price > (SELECT AVG(t2.execution_price) FROM trades t2 WHERE t2.order_id = t.order_id)
ORDER BY t.order_id, t.trade_id;

-- Q9. CORRELATED subquery: the latest quote for each listing
SELECT sl.ticker_symbol, e.mic_code, m.feed_timestamp, m.bid_price, m.ask_price, m.last_price
FROM market_feed_data m
JOIN security_listings sl ON sl.listing_id = m.listing_id
JOIN exchanges e          ON e.exchange_id = sl.exchange_id
WHERE m.feed_timestamp = (SELECT MAX(m2.feed_timestamp) FROM market_feed_data m2 WHERE m2.listing_id = m.listing_id)
ORDER BY sl.ticker_symbol, e.mic_code;

-- Q10. CORRELATED subquery: orders that are not completely executed
SELECT o.order_id, o.status, o.quantity,
       (SELECT COALESCE(SUM(t.executed_quantity), 0) FROM trades t WHERE t.order_id = o.order_id) AS executed
FROM orders o
WHERE o.quantity > (SELECT COALESCE(SUM(t.executed_quantity), 0) FROM trades t WHERE t.order_id = o.order_id)
ORDER BY o.order_id;

-- Q11. CORRELATED EXISTS: portfolios owned by more than one trader that also hold an ETF
SELECT p.portfolio_id, p.portfolio_name
FROM portfolios p
WHERE (SELECT COUNT(*) FROM portfolio_owners po WHERE po.portfolio_id = p.portfolio_id) > 1
  AND EXISTS (SELECT 1 FROM portfolio_holdings ph JOIN securities s ON s.security_id = ph.security_id
               WHERE ph.portfolio_id = p.portfolio_id AND s.asset_type = 'ETF');

-- Q12. JOIN + GROUP BY + HAVING: traders who executed trades on 2 or more different exchanges
SELECT t.full_name, COUNT(DISTINCT tr.exchange_id) AS exchanges_used, SUM(tr.executed_quantity) AS total_qty
FROM traders t
JOIN orders o  ON o.trader_id = t.trader_id
JOIN trades tr ON tr.order_id = o.order_id
GROUP BY t.trader_id, t.full_name
HAVING COUNT(DISTINCT tr.exchange_id) >= 2
ORDER BY exchanges_used DESC, t.full_name;

-- Q13. LEFT JOINs with aggregates: each algorithm's developers, orders and training rows
SELECT a.algorithm_name, a.version,
       (SELECT COUNT(*) FROM algorithm_developers ad WHERE ad.algorithm_id = a.algorithm_id) AS developers,
       (SELECT COUNT(*) FROM orders o WHERE o.algorithm_id = a.algorithm_id)                 AS orders_placed,
       (SELECT COUNT(*) FROM algorithm_training_data atd WHERE atd.algorithm_id = a.algorithm_id) AS training_rows
FROM algorithms a
ORDER BY a.algorithm_id;

-- Q14. UNION: every exchange that either lists a security or executed a trade, with the reason
SELECT e.mic_code, 'has listings' AS reason FROM exchanges e WHERE e.exchange_id IN (SELECT exchange_id FROM security_listings)
UNION
SELECT e.mic_code, 'has trades'   AS reason FROM exchanges e WHERE e.exchange_id IN (SELECT exchange_id FROM trades)
ORDER BY mic_code, reason;
