import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole, dbError } from '@/lib/api';

export const dynamic = 'force-dynamic';

export async function GET() {
  const { error, account } = await requireRole();
  if (error) return error;
  try {
    const rows = await query(account, `
      SELECT a.algorithm_id, a.algorithm_name, a.version, a.strategy_type, a.programming_language, a.status,
             (SELECT GROUP_CONCAT(CONCAT(t.full_name, ' (', ad.contribution_role, ')') ORDER BY t.full_name SEPARATOR '; ')
                FROM algorithm_developers ad JOIN traders t ON t.trader_id = ad.trader_id WHERE ad.algorithm_id = a.algorithm_id) AS developers,
             (SELECT COUNT(*) FROM orders o WHERE o.algorithm_id = a.algorithm_id) AS orders_placed
        FROM algorithms a ORDER BY a.algorithm_id`);
    return NextResponse.json(rows);
  } catch (e) { return dbError(e); }
}
