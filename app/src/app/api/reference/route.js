import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole, dbError, bad } from '@/lib/api';

export const dynamic = 'force-dynamic';

// GET /api/reference?type=traders|securities|exchanges|algorithms|portfolios[&trader_id=1]
export async function GET(request) {
  const { error, account } = await requireRole();
  if (error) return error;
  try {
    const sp = new URL(request.url).searchParams;
    switch (sp.get('type')) {
      case 'traders':
        return NextResponse.json(await query(account, "SELECT trader_id, full_name FROM traders WHERE status = 'ACTIVE' ORDER BY full_name"));
      case 'securities':
        return NextResponse.json(await query(account, "SELECT security_id, security_name, isin FROM securities WHERE status = 'ACTIVE' ORDER BY security_name"));
      case 'exchanges':
        return NextResponse.json(await query(account, 'SELECT exchange_id, exchange_name, mic_code FROM exchanges ORDER BY mic_code'));
      case 'algorithms':
        return NextResponse.json(await query(account, "SELECT algorithm_id, algorithm_name, version, status FROM algorithms WHERE status IN ('ACTIVE','TESTING') ORDER BY algorithm_name, version"));
      case 'portfolios': {
        const traderId = sp.get('trader_id');
        if (!traderId) return NextResponse.json([]);
        return NextResponse.json(await query(account, `
          SELECT p.portfolio_id, p.portfolio_name, p.base_currency FROM portfolios p
            JOIN portfolio_owners po ON po.portfolio_id = p.portfolio_id
           WHERE po.trader_id = ? AND p.status = 'ACTIVE' ORDER BY p.portfolio_name`, [Number(traderId)]));
      }
      default:
        return bad('Unknown reference type');
    }
  } catch (e) { return dbError(e); }
}
