import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole, dbError } from '@/lib/api';

export const dynamic = 'force-dynamic';

// GET /api/portfolios            -> list with owners, holdings count, market value (fn_portfolio_value)
// GET /api/portfolios?id=3       -> holdings of one portfolio
export async function GET(request) {
  const { error, account } = await requireRole();
  if (error) return error;
  try {
    const id = new URL(request.url).searchParams.get('id');
    if (id) {
      const holdings = await query(account, `
        SELECT s.security_name, s.currency, ph.quantity_held, ph.avg_price,
               ph.quantity_held * ph.avg_price AS cost_basis, ph.last_updated
          FROM portfolio_holdings ph JOIN securities s ON s.security_id = ph.security_id
         WHERE ph.portfolio_id = ? ORDER BY s.security_name`, [Number(id)]);
      return NextResponse.json(holdings);
    }
    const rows = await query(account, `
      SELECT p.portfolio_id, p.portfolio_name, p.base_currency, p.risk_profile, p.status,
             (SELECT GROUP_CONCAT(CONCAT(t.full_name, ' ', po.ownership_percentage, '%') ORDER BY po.ownership_percentage DESC SEPARATOR ' | ')
                FROM portfolio_owners po JOIN traders t ON t.trader_id = po.trader_id WHERE po.portfolio_id = p.portfolio_id) AS owners,
             (SELECT COUNT(*) FROM portfolio_holdings h WHERE h.portfolio_id = p.portfolio_id) AS holdings,
             fn_portfolio_value(p.portfolio_id) AS market_value,
             c.ownership_status
        FROM portfolios p JOIN v_portfolio_ownership_check c ON c.portfolio_id = p.portfolio_id
       ORDER BY p.portfolio_id`);
    return NextResponse.json(rows);
  } catch (e) { return dbError(e); }
}
