import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole, dbError } from '@/lib/api';

export const dynamic = 'force-dynamic';

// GET /api/audit?table=orders&limit=100  - ADMIN and AUDITOR only
export async function GET(request) {
  const { error, account } = await requireRole(['ADMIN', 'AUDITOR']);
  if (error) return error;
  try {
    const sp = new URL(request.url).searchParams;
    const table = sp.get('table');
    const limit = Math.min(Number(sp.get('limit') || 100), 500);
    const rows = await query(account, `
      SELECT audit_id, table_name, action, row_key, old_values, new_values, changed_by, changed_at
        FROM audit_log ${table ? 'WHERE table_name = ?' : ''} ORDER BY audit_id DESC LIMIT ?`,
      table ? [table, limit] : [limit]);
    return NextResponse.json(rows);
  } catch (e) { return dbError(e); }
}
