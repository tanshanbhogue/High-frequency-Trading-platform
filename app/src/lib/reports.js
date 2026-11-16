// Read-only SQL reports for the "SQL reports" page. Each one demonstrates a
// concept the rubric asks for. Only SELECT / WITH statements - the API runs
// them with the logged-in user's own database account.
export const REPORTS = [
  { id: 'orders_overview', title: 'Orders with trader, portfolio, security, algorithm', concept: 'Multi-table JOIN',
    sql: `SELECT o.order_id, t.full_name AS trader, p.portfolio_name, s.security_name,
       COALESCE(CONCAT(a.algorithm_name, ' v', a.version), 'MANUAL') AS algorithm, o.side, o.order_type, o.quantity, o.status
FROM orders o
JOIN traders t ON t.trader_id = o.trader_id
JOIN portfolios p ON p.portfolio_id = o.portfolio_id
JOIN securities s ON s.security_id = o.security_id
LEFT JOIN algorithms a ON a.algorithm_id = o.algorithm_id
ORDER BY o.order_id` },
  { id: 'org_chart', title: 'Trading-desk hierarchy (who reports to whom)', concept: 'RECURSIVE CTE',
    sql: `WITH RECURSIVE hierarchy AS (
  SELECT trader_id, full_name, role, 0 AS level, CAST(full_name AS CHAR(300)) AS path
  FROM traders WHERE reports_to IS NULL
  UNION ALL
  SELECT t.trader_id, t.full_name, t.role, h.level + 1, CONCAT(h.path, ' > ', t.full_name)
  FROM traders t JOIN hierarchy h ON t.reports_to = h.trader_id
)
SELECT CONCAT(REPEAT('    ', level), full_name) AS org_chart, role, level, path
FROM hierarchy ORDER BY path` },
  { id: 'team_size', title: 'Team size under every manager', concept: 'RECURSIVE CTE + GROUP BY',
    sql: `WITH RECURSIVE subtree AS (
  SELECT trader_id AS manager_id, trader_id AS member_id FROM traders
  UNION ALL
  SELECT s.manager_id, t.trader_id FROM traders t JOIN subtree s ON t.reports_to = s.member_id
)
SELECT m.full_name AS manager, COUNT(*) - 1 AS people_below
FROM subtree s JOIN traders m ON m.trader_id = s.manager_id
GROUP BY m.trader_id, m.full_name HAVING COUNT(*) - 1 > 0
ORDER BY people_below DESC, manager` },
  { id: 'exchange_share', title: "Each exchange's share of total volume", concept: 'CTE',
    sql: `WITH exchange_volume AS (
  SELECT exchange_id, SUM(executed_quantity) AS volume FROM trades GROUP BY exchange_id
)
SELECT e.mic_code, ev.volume,
       ROUND(100 * ev.volume / (SELECT SUM(volume) FROM exchange_volume), 2) AS pct_of_total
FROM exchange_volume ev JOIN exchanges e ON e.exchange_id = ev.exchange_id
ORDER BY ev.volume DESC` },
  { id: 'fill_classes', title: 'Orders classified by how much was executed', concept: 'Chained CTEs',
    sql: `WITH executed AS (
  SELECT o.order_id, o.quantity, COALESCE(SUM(t.executed_quantity), 0) AS done
  FROM orders o LEFT JOIN trades t ON t.order_id = o.order_id GROUP BY o.order_id, o.quantity
), classified AS (
  SELECT order_id, quantity, done,
         CASE WHEN done = 0 THEN 'NOT EXECUTED' WHEN done < quantity THEN 'PARTIAL' ELSE 'COMPLETE' END AS fill_class
  FROM executed
)
SELECT fill_class, COUNT(*) AS orders, SUM(quantity) AS total_ordered, SUM(done) AS total_done
FROM classified GROUP BY fill_class ORDER BY orders DESC` },
  { id: 'above_order_avg', title: "Trades priced above the average of their own order", concept: 'Correlated subquery',
    sql: `SELECT t.trade_id, t.order_id, t.execution_price,
       (SELECT AVG(t2.execution_price) FROM trades t2 WHERE t2.order_id = t.order_id) AS order_avg_price
FROM trades t
WHERE t.execution_price > (SELECT AVG(t2.execution_price) FROM trades t2 WHERE t2.order_id = t.order_id)
ORDER BY t.order_id, t.trade_id` },
  { id: 'latest_quote', title: 'Latest market quote for each listing', concept: 'Correlated subquery',
    sql: `SELECT sl.ticker_symbol, e.mic_code, m.feed_timestamp, m.bid_price, m.ask_price, m.last_price
FROM market_feed_data m
JOIN security_listings sl ON sl.listing_id = m.listing_id
JOIN exchanges e ON e.exchange_id = sl.exchange_id
WHERE m.feed_timestamp = (SELECT MAX(m2.feed_timestamp) FROM market_feed_data m2 WHERE m2.listing_id = m.listing_id)
ORDER BY sl.ticker_symbol, e.mic_code` },
  { id: 'unfilled_orders', title: 'Orders not completely executed (uses stored functions)', concept: 'Nested query + functions',
    sql: `SELECT o.order_id, o.status, o.quantity,
       fn_executed_quantity(o.order_id) AS executed, fn_remaining_quantity(o.order_id) AS remaining, fn_order_vwap(o.order_id) AS vwap
FROM orders o
WHERE o.quantity > (SELECT COALESCE(SUM(t.executed_quantity), 0) FROM trades t WHERE t.order_id = o.order_id)
ORDER BY o.order_id` },
  { id: 'multi_exchange_traders', title: 'Traders who executed on 2 or more exchanges', concept: 'JOIN + GROUP BY + HAVING',
    sql: `SELECT t.full_name, COUNT(DISTINCT tr.exchange_id) AS exchanges_used, SUM(tr.executed_quantity) AS total_qty
FROM traders t JOIN orders o ON o.trader_id = t.trader_id JOIN trades tr ON tr.order_id = o.order_id
GROUP BY t.trader_id, t.full_name HAVING COUNT(DISTINCT tr.exchange_id) >= 2
ORDER BY exchanges_used DESC, t.full_name` },
  { id: 'never_ordered', title: 'Securities that have never been ordered', concept: 'NOT EXISTS (nested)',
    sql: `SELECT s.security_id, s.security_name FROM securities s
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.security_id = s.security_id)` },
  { id: 'notional_rank', title: 'Traders ranked by traded value', concept: 'Window function RANK()',
    sql: `WITH notional AS (
  SELECT o.trader_id, SUM(t.executed_quantity * t.execution_price) AS notional
  FROM orders o JOIN trades t ON t.order_id = o.order_id GROUP BY o.trader_id
)
SELECT tr.full_name, n.notional, RANK() OVER (ORDER BY n.notional DESC) AS notional_rank
FROM notional n JOIN traders tr ON tr.trader_id = n.trader_id ORDER BY notional_rank` },
  { id: 'running_volume', title: 'Running executed volume per exchange', concept: 'Window function SUM() OVER',
    sql: `SELECT e.mic_code, t.executed_at, t.executed_quantity,
       SUM(t.executed_quantity) OVER (PARTITION BY t.exchange_id ORDER BY t.executed_at) AS running_volume
FROM trades t JOIN exchanges e ON e.exchange_id = t.exchange_id
ORDER BY e.mic_code, t.executed_at` },
  { id: 'portfolio_values', title: 'Portfolio market values (stored function)', concept: 'Function + view',
    sql: `SELECT p.portfolio_id, p.portfolio_name, p.base_currency, c.total_ownership_pct, c.ownership_status,
       fn_portfolio_value(p.portfolio_id) AS market_value
FROM portfolios p JOIN v_portfolio_ownership_check c ON c.portfolio_id = p.portfolio_id
ORDER BY p.portfolio_id` },
];
