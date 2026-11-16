// Helpers shared by the API route handlers.
import { NextResponse } from 'next/server';
import { getSession } from './auth';
import { accountForRole } from './mysql';

// Returns { session, account } or { error: Response }.
export async function requireRole(allowed) {
  const session = await getSession();
  if (!session) return { error: NextResponse.json({ error: 'Not logged in' }, { status: 401 }) };
  if (allowed && !allowed.includes(session.role)) {
    return { error: NextResponse.json({ error: `Your role (${session.role}) is not allowed to do this` }, { status: 403 }) };
  }
  return { session, account: accountForRole[session.role] };
}

// Turns a MySQL / driver error into a readable JSON response.
export function dbError(e) {
  const message = e.sqlMessage || e.message || 'Unexpected error';
  let status = 400;
  if ([1142, 1143, 1044, 1370, 1045].includes(e.errno)) status = 403;            // MySQL privilege errors
  else if (['ECONNREFUSED', 'ETIMEDOUT', 'PROTOCOL_CONNECTION_LOST'].includes(e.code)) status = 503;
  else if (!e.errno && !e.sqlState) status = 500;
  return NextResponse.json({ error: message, code: e.code || null, errno: e.errno || null }, { status });
}

export const bad = (message, status = 400) => NextResponse.json({ error: message }, { status });
