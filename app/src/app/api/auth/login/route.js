import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { checkPassword, startSession } from '@/lib/auth';
import { dbError } from '@/lib/api';

export const dynamic = 'force-dynamic';

// POST { username, password }  - uses the restricted "auth" database account
export async function POST(request) {
  try {
    const { username, password } = await request.json();
    if (!username || !password) return NextResponse.json({ error: 'Enter a username and password' }, { status: 400 });

    const rows = await query('auth',
      'SELECT user_id, username, password_hash, role, trader_id, is_active FROM app_users WHERE username = ?', [username]);
    const user = rows[0];
    const valid = user && user.is_active && (await checkPassword(password, user.password_hash));
    if (!valid) return NextResponse.json({ error: 'Invalid username or password' }, { status: 401 });

    await query('auth', 'UPDATE app_users SET last_login = UTC_TIMESTAMP() WHERE user_id = ?', [user.user_id]);
    await startSession(user);
    return NextResponse.json({ username: user.username, role: user.role, traderId: user.trader_id });
  } catch (e) {
    return dbError(e);
  }
}
