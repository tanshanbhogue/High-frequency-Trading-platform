-- =====================================================================
-- 07_cte_and_recursive.sql  -  CTEs, RECURSIVE CTE and window functions
-- (rubric 4: CTE)
-- Run:  mysql -u root -p -t < sql/07_cte_and_recursive.sql
-- =====================================================================
USE HFT;

-- C1. Simple CTE: each exchange's share of total traded volume
WITH exchange_volume AS (
    SELECT exchange_id, SUM(executed_quantity) AS volume
    FROM trades GROUP BY exchange_id
)
SELECT e.mic_code, ev.volume,
       ROUND(100 * ev.volume / (SELECT SUM(volume) FROM exchange_volume), 2) AS pct_of_total
FROM exchange_volume ev
JOIN exchanges e ON e.exchange_id = ev.exchange_id
ORDER BY ev.volume DESC;

-- C2. Several CTEs chained: classify every order by how much of it was executed
WITH executed AS (
    SELECT o.order_id, o.quantity, COALESCE(SUM(t.executed_quantity), 0) AS done
    FROM orders o LEFT JOIN trades t ON t.order_id = o.order_id
    GROUP BY o.order_id, o.quantity
),
classified AS (
    SELECT order_id, quantity, done,
           CASE WHEN done = 0 THEN 'NOT EXECUTED'
                WHEN done < quantity THEN 'PARTIAL'
                ELSE 'COMPLETE' END AS fill_class
    FROM executed
)
SELECT fill_class, COUNT(*) AS orders, SUM(quantity) AS total_ordered, SUM(done) AS total_done
FROM classified GROUP BY fill_class ORDER BY orders DESC;

-- C3. RECURSIVE CTE: the trading-desk hierarchy with level and full reporting path
WITH RECURSIVE hierarchy AS (
    SELECT trader_id, full_name, role, reports_to, 0 AS level,
           CAST(full_name AS CHAR(300)) AS path
    FROM traders
    WHERE reports_to IS NULL
  UNION ALL
    SELECT t.trader_id, t.full_name, t.role, t.reports_to, h.level + 1,
           CONCAT(h.path, ' > ', t.full_name)
    FROM traders t
    JOIN hierarchy h ON t.reports_to = h.trader_id
)
SELECT CONCAT(REPEAT('    ', level), full_name) AS org_chart, role, level, path
FROM hierarchy
ORDER BY path;

-- C4. RECURSIVE CTE: team size under every manager (all direct and indirect reports)
WITH RECURSIVE subtree AS (
    SELECT trader_id AS manager_id, trader_id AS member_id FROM traders
  UNION ALL
    SELECT s.manager_id, t.trader_id
    FROM traders t JOIN subtree s ON t.reports_to = s.member_id
)
SELECT m.full_name AS manager, COUNT(*) - 1 AS people_below
FROM subtree s
JOIN traders m ON m.trader_id = s.manager_id
GROUP BY m.trader_id, m.full_name
HAVING COUNT(*) - 1 > 0
ORDER BY people_below DESC, manager;

-- C5. RECURSIVE CTE as a number series: order ids 1..17 with their fill status
WITH RECURSIVE n AS (
    SELECT 1 AS id
  UNION ALL
    SELECT id + 1 FROM n WHERE id < 17
)
SELECT n.id AS order_id, o.status, fn_remaining_quantity(n.id) AS remaining
FROM n JOIN orders o ON o.order_id = n.id
ORDER BY n.id;

-- C6. WINDOW function: rank traders by traded notional value (qty x price) per exchange currency group
WITH notional AS (
    SELECT o.trader_id, SUM(t.executed_quantity * t.execution_price) AS notional
    FROM orders o JOIN trades t ON t.order_id = o.order_id
    GROUP BY o.trader_id
)
SELECT tr.full_name, n.notional,
       RANK() OVER (ORDER BY n.notional DESC) AS notional_rank
FROM notional n JOIN traders tr ON tr.trader_id = n.trader_id
ORDER BY notional_rank;

-- C7. WINDOW function: running total of executed quantity on each exchange, in time order
SELECT e.mic_code, t.executed_at, t.executed_quantity,
       SUM(t.executed_quantity) OVER (PARTITION BY t.exchange_id ORDER BY t.executed_at) AS running_volume
FROM trades t JOIN exchanges e ON e.exchange_id = t.exchange_id
ORDER BY e.mic_code, t.executed_at;

-- C8. WINDOW function LAG: change in last price between consecutive quotes of a listing
SELECT sl.ticker_symbol, m.feed_timestamp, m.last_price,
       m.last_price - LAG(m.last_price) OVER (PARTITION BY m.listing_id ORDER BY m.feed_timestamp) AS price_change
FROM market_feed_data m JOIN security_listings sl ON sl.listing_id = m.listing_id
WHERE m.listing_id IN (1, 10, 11)
ORDER BY sl.ticker_symbol, m.feed_timestamp;
