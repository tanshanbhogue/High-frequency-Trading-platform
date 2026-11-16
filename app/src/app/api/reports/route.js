import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole, dbError, bad } from '@/lib/api';
import { REPORTS } from '@/lib/reports';

export const dynamic = 'force-dynamic';

// GET /api/reports            -> list of available reports
// GET /api/reports?id=org_chart -> run one (only the fixed, whitelisted SQL runs)
export async function GET(request) {
  const { error, account } = await requireRole();
  if (error) return error;
  try {
    const id = new URL(request.url).searchParams.get('id');
    if (!id) return NextResponse.json(REPORTS.map(({ id, title, concept }) => ({ id, title, concept })));
    const report = REPORTS.find((r) => r.id === id);
    if (!report) return bad('Unknown report', 404);
    const rows = await query(account, report.sql);
    return NextResponse.json({ id: report.id, title: report.title, concept: report.concept, sql: report.sql, rows });
  } catch (e) { return dbError(e); }
}
