import { NextResponse } from 'next/server';
import { query, withConnection } from '@/lib/mysql';
import { requireRole, dbError, bad } from '@/lib/api';
import { logOrderEvent } from '@/lib/mongo';

export const dynamic = 'force-dynamic';

// POST /api/orders/:id/routes { exchange_id, quantity, reason } - sp_route_order
export async function POST(request, { params }) {
  const { error, account, session } = await requireRole(['ADMIN', 'TRADER']);
  if (error) return error;
  try {
    const id = Number(params.id);
    const b = await request.json();
    if (!b.exchange_id || !b.quantity) return bad('Choose an exchange and a quantity');
    if (session.role === 'TRADER') {
      const [o] = await query(account, 'SELECT trader_id FROM orders WHERE order_id = ?', [id]);
      if (!o) return bad('Order not found', 404);
      if (o.trader_id !== session.traderId) return bad('You can only route your own orders', 403);
    }
    await withConnection(account, session.username, (conn) =>
      conn.query('CALL sp_route_order(?,?,?,?)', [id, Number(b.exchange_id), b.quantity, b.reason || null]));
    await logOrderEvent(id, 'ROUTED', 'web', { exchange_id: Number(b.exchange_id), routed_quantity: Number(b.quantity) });
    return NextResponse.json({ ok: true }, { status: 201 });
  } catch (e) { return dbError(e); }
}
