import { NextResponse } from 'next/server';
import { getSession } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export async function GET() {
  const s = await getSession();
  if (!s) return NextResponse.json({ error: 'Not logged in' }, { status: 401 });
  return NextResponse.json({ userId: s.userId, username: s.username, role: s.role, traderId: s.traderId });
}
