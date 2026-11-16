import { NextResponse } from 'next/server';
import { query, withConnection } from '@/lib/mysql';
import { requireRole, dbError, bad } from '@/lib/api';
import { logOrderEvent } from '@/lib/mongo';

export const dynamic = 'force-dynamic';

// GET /api/orders/:id - order, routes, trades, and the exchanges it could still be routed to
export async function GET(request, { params }) {
  const { error, account } = await requireRole();
  if (error) return error;
  try {
    const id = Number(params.id);
    const [order] = await query(account, `
      SELECT o.*, t.full_name AS trader, p.portfolio_name, s.security_name, s.currency,
             COALESCE(CONCAT(a.algorithm_name, ' v', a.version), 'MANUAL') AS algorithm,
             v.executed_quantity, v.remaining_quantity
        FROM orders o
        JOIN traders t ON t.trader_id = o.trader_id
        JOIN portfolios p ON p.portfolio_id = o.portfolio_id
        JOIN securities s ON s.security_id = o.security_id
        LEFT JOIN algorithms a ON a.algorithm_id = o.algorithm_id
        JOIN v_order_execution_summary v ON v.order_id = o.order_id
       WHERE o.order_id = ?`, [id]);
    if (!order) return bad('Order not found', 404);
    const routes = await query(account, `
      SELECT r.exchange_id, e.mic_code, e.exchange_name, r.routed_quantity, r.routed_at, r.route_status, r.routing_reason,
             (SELECT COALESCE(SUM(t.executed_quantity), 0) FROM trades t WHERE t.order_id = r.order_id AND t.exchange_id = r.exchange_id) AS executed
        FROM order_routes r JOIN exchanges e ON e.exchange_id = r.exchange_id WHERE r.order_id = ? ORDER BY r.routed_at`, [id]);
    const trades = await query(account, `
      SELECT t.trade_id, e.mic_code, t.execution_reference, t.executed_quantity, t.execution_price, t.commission, t.executed_at, t.settlement_status
        FROM trades t JOIN exchanges e ON e.exchange_id = t.exchange_id WHERE t.order_id = ? ORDER BY t.executed_at`, [id]);
    const eligible = await query(account, `
      SELECT e.exchange_id, e.mic_code, e.exchange_name, sl.ticker_symbol
        FROM security_listings sl JOIN exchanges e ON e.exchange_id = sl.exchange_id
       WHERE sl.security_id = ? AND sl.is_active = TRUE AND e.status = 'ACTIVE'
         AND sl.exchange_id NOT IN (SELECT exchange_id FROM order_routes WHERE order_id = ?)
       ORDER BY e.mic_code`, [order.security_id, id]);
    return NextResponse.json({ order, routes, trades, eligible });
  } catch (e) { return dbError(e); }
}

// POST /api/orders/:id  { action: 'cancel' } - sp_cancel_order
export async function POST(request, { params }) {
  const { error, account, session } = await requireRole(['ADMIN', 'TRADER']);
  if (error) return error;
  try {
    const { action } = await request.json();
    if (action !== 'cancel') return bad('Unknown action');
    const id = Number(params.id);
    await withConnection(account, session.username, (conn) =>
      conn.query('CALL sp_cancel_order(?, ?)', [id, session.role === 'TRADER' ? session.traderId : null]));
    await logOrderEvent(id, 'CANCELLED', 'web', { reason: 'Cancelled by ' + session.username });
    return NextResponse.json({ ok: true });
  } catch (e) { return dbError(e); }
}
