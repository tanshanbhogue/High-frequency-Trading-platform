import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole, dbError } from '@/lib/api';

export const dynamic = 'force-dynamic';

export async function GET() {
  const { error, account } = await requireRole();
  if (error) return error;
  try {
    const [counts] = await query(account, `SELECT
      (SELECT COUNT(*) FROM orders) AS orders, (SELECT COUNT(*) FROM trades) AS trades,
      (SELECT COUNT(*) FROM portfolios) AS portfolios, (SELECT COUNT(*) FROM securities) AS securities,
      (SELECT COUNT(*) FROM exchanges) AS exchanges, (SELECT COUNT(*) FROM algorithms) AS algorithms`);
    const byStatus = await query(account, 'SELECT status, COUNT(*) AS n FROM orders GROUP BY status ORDER BY n DESC');
    const volume = await query(account, `SELECT e.mic_code, e.exchange_name, COUNT(*) AS trades, SUM(t.executed_quantity) AS volume
      FROM trades t JOIN exchanges e ON e.exchange_id = t.exchange_id
      GROUP BY e.exchange_id, e.mic_code, e.exchange_name ORDER BY volume DESC`);
    const latest = await query(account, `SELECT t.trade_id, t.order_id, e.mic_code, t.executed_quantity, t.execution_price, t.executed_at
      FROM trades t JOIN exchanges e ON e.exchange_id = t.exchange_id ORDER BY t.executed_at DESC LIMIT 8`);
    return NextResponse.json({ counts, byStatus, volume, latest });
  } catch (e) { return dbError(e); }
}
