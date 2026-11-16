import { NextResponse } from 'next/server';
import { query, withConnection } from '@/lib/mysql';
import { requireRole, dbError, bad } from '@/lib/api';
import { logOrderEvent } from '@/lib/mongo';

export const dynamic = 'force-dynamic';

// GET /api/orders?status=FILLED   - any logged-in role
export async function GET(request) {
  const { error, account } = await requireRole();
  if (error) return error;
  try {
    const status = new URL(request.url).searchParams.get('status');
    const rows = await query(account, `
      SELECT o.order_id, o.status, o.side, o.order_type, o.quantity, o.limit_price, o.time_in_force, o.created_at,
             t.full_name AS trader, p.portfolio_name, s.security_name,
             COALESCE(CONCAT(a.algorithm_name, ' v', a.version), 'MANUAL') AS algorithm,
             v.executed_quantity, v.remaining_quantity
        FROM orders o
        JOIN traders t    ON t.trader_id = o.trader_id
        JOIN portfolios p ON p.portfolio_id = o.portfolio_id
        JOIN securities s ON s.security_id = o.security_id
        LEFT JOIN algorithms a ON a.algorithm_id = o.algorithm_id
        JOIN v_order_execution_summary v ON v.order_id = o.order_id
       ${status ? 'WHERE o.status = ?' : ''}
       ORDER BY o.order_id DESC`, status ? [status] : []);
    return NextResponse.json(rows);
  } catch (e) { return dbError(e); }
}

// POST /api/orders - places an order through the stored procedure sp_place_order
export async function POST(request) {
  const { error, account, session } = await requireRole(['ADMIN', 'TRADER']);
  if (error) return error;
  try {
    const b = await request.json();
    // A trader can only place orders as themselves; an admin may choose.
    const traderId = session.role === 'TRADER' ? session.traderId : Number(b.trader_id);
    if (!traderId) return bad('Choose a trader');
    if (!b.portfolio_id || !b.security_id || !b.side || !b.order_type || !b.quantity) return bad('Fill in all required fields');

    const orderId = await withConnection(account, session.username, async (conn) => {
      await conn.query('CALL sp_place_order(?,?,?,?,?,?,?,?,?,@oid)', [
        traderId, Number(b.portfolio_id), Number(b.security_id), b.algorithm_id ? Number(b.algorithm_id) : null,
        b.side, b.order_type, b.quantity, b.order_type === 'MARKET' ? null : b.limit_price || null, b.time_in_force || 'DAY',
      ]);
      const [[r]] = await conn.query('SELECT @oid AS id');
      return Number(r.id);
    });
    await logOrderEvent(orderId, 'ORDER_CREATED', 'web', { side: b.side, quantity: Number(b.quantity), channel: b.algorithm_id ? 'algorithm' : 'manual', by: session.username });
    return NextResponse.json({ order_id: orderId }, { status: 201 });
  } catch (e) { return dbError(e); }
}
