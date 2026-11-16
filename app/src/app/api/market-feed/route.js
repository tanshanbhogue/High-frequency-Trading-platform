import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole, dbError } from '@/lib/api';

export const dynamic = 'force-dynamic';

// GET /api/market-feed?security_id=6&exchange_id=3&limit=50
export async function GET(request) {
  const { error, account } = await requireRole();
  if (error) return error;
  try {
    const sp = new URL(request.url).searchParams;
    const where = [], params = [];
    if (sp.get('security_id')) { where.push('sl.security_id = ?'); params.push(Number(sp.get('security_id'))); }
    if (sp.get('exchange_id')) { where.push('sl.exchange_id = ?'); params.push(Number(sp.get('exchange_id'))); }
    const limit = Math.min(Number(sp.get('limit') || 50), 200);
    const rows = await query(account, `
      SELECT m.feed_id, s.security_name, sl.ticker_symbol, e.mic_code, m.feed_timestamp,
             m.bid_price, m.ask_price, (m.ask_price - m.bid_price) AS spread, m.last_price,
             m.bid_size, m.ask_size, m.traded_volume, m.source
        FROM market_feed_data m
        JOIN security_listings sl ON sl.listing_id = m.listing_id
        JOIN securities s ON s.security_id = sl.security_id
        JOIN exchanges e ON e.exchange_id = sl.exchange_id
       ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
       ORDER BY m.feed_timestamp DESC LIMIT ?`, [...params, limit]);
    return NextResponse.json(rows);
  } catch (e) { return dbError(e); }
}
