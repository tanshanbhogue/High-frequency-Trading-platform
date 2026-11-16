import { NextResponse } from 'next/server';
import { query, withConnection } from '@/lib/mysql';
import { requireRole, dbError, bad } from '@/lib/api';
import { logOrderEvent } from '@/lib/mongo';

export const dynamic = 'force-dynamic';

// POST /api/orders/:id/trades { exchange_id, quantity, price, commission } - sp_add_trade
export async function POST(request, { params }) {
  const { error, account, session } = await requireRole(['ADMIN', 'TRADER']);
  if (error) return error;
  try {
    const id = Number(params.id);
    const b = await request.json();
    if (!b.exchange_id || !b.quantity || !b.price) return bad('Choose an exchange, quantity and price');
    if (session.role === 'TRADER') {
      const [o] = await query(account, 'SELECT trader_id FROM orders WHERE order_id = ?', [id]);
      if (!o) return bad('Order not found', 404);
      if (o.trader_id !== session.traderId) return bad('You can only add trades to your own orders', 403);
    }
    const tradeId = await withConnection(account, session.username, async (conn) => {
      await conn.query('CALL sp_add_trade(?,?,?,?,?,@tid)', [id, Number(b.exchange_id), b.quantity, b.price, b.commission || 0]);
      const [[r]] = await conn.query('SELECT @tid AS id');
      return Number(r.id);
    });
    const [o] = await query(account, 'SELECT status FROM orders WHERE order_id = ?', [id]);
    await logOrderEvent(id, 'FILL', 'web', { exchange_id: Number(b.exchange_id), executed_quantity: Number(b.quantity), price: Number(b.price) });
    if (o?.status === 'FILLED') await logOrderEvent(id, 'FILLED', 'system', { total: 'complete' });
    return NextResponse.json({ trade_id: tradeId, order_status: o?.status }, { status: 201 });
  } catch (e) { return dbError(e); }
}
