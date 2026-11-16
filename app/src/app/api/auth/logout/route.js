import { NextResponse } from 'next/server';
import { endSession } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export async function POST() {
  endSession();
  return NextResponse.json({ ok: true });
}
