import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole, dbError, bad } from '@/lib/api';
import { hashPassword } from '@/lib/auth';

export const dynamic = 'force-dynamic';
const ROLES = ['ADMIN', 'TRADER', 'AUDITOR'];

// ADMIN only: the admin database account is the only one allowed to see/change app_users.
export async function GET() {
  const { error, account } = await requireRole(['ADMIN']);
  if (error) return error;
  try {
    return NextResponse.json(await query(account,
      'SELECT user_id, username, role, trader_id, is_active, created_at, last_login FROM app_users ORDER BY user_id'));
  } catch (e) { return dbError(e); }
}

// POST { username, password, role, trader_id }
export async function POST(request) {
  const { error, account } = await requireRole(['ADMIN']);
  if (error) return error;
  try {
    const b = await request.json();
    if (!b.username || b.username.length < 3) return bad('Username must be at least 3 characters');
    if (!b.password || b.password.length < 6) return bad('Password must be at least 6 characters');
    if (!ROLES.includes(b.role)) return bad('Invalid role');
    const hash = await hashPassword(b.password);
    await query(account, 'INSERT INTO app_users (username, password_hash, role, trader_id) VALUES (?,?,?,?)',
      [b.username, hash, b.role, b.role === 'TRADER' ? Number(b.trader_id) || null : null]);
    return NextResponse.json({ ok: true }, { status: 201 });
  } catch (e) { return dbError(e); }
}

// PATCH { user_id, role?, is_active?, password? }
export async function PATCH(request) {
  const { error, account, session } = await requireRole(['ADMIN']);
  if (error) return error;
  try {
    const b = await request.json();
    const id = Number(b.user_id);
    if (!id) return bad('user_id is required');
    if (id === session.userId && (b.is_active === false || (b.role && b.role !== 'ADMIN'))) return bad('You cannot demote or disable your own account');
    if (b.role !== undefined) {
      if (!ROLES.includes(b.role)) return bad('Invalid role');
      await query(account, 'UPDATE app_users SET role = ? WHERE user_id = ?', [b.role, id]);
    }
    if (b.is_active !== undefined) await query(account, 'UPDATE app_users SET is_active = ? WHERE user_id = ?', [b.is_active ? 1 : 0, id]);
    if (b.password) {
      if (b.password.length < 6) return bad('Password must be at least 6 characters');
      await query(account, 'UPDATE app_users SET password_hash = ? WHERE user_id = ?', [await hashPassword(b.password), id]);
    }
    return NextResponse.json({ ok: true });
  } catch (e) { return dbError(e); }
}
