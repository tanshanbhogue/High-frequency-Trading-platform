// Server-side authentication helpers (cookies + bcrypt).
import bcrypt from 'bcryptjs';
import { cookies } from 'next/headers';
import { COOKIE_NAME, signToken, verifyToken } from './token';

export const checkPassword = (plain, hash) => bcrypt.compare(plain, hash);
export const hashPassword = (plain) => bcrypt.hash(plain, 10);

export async function startSession(user) {
  const token = await signToken({
    userId: user.user_id, username: user.username, role: user.role, traderId: user.trader_id ?? null,
  });
  cookies().set(COOKIE_NAME, token, {
    httpOnly: true, sameSite: 'lax', path: '/', maxAge: 8 * 60 * 60,
    secure: process.env.COOKIE_SECURE === 'true',
  });
}

export function endSession() {
  cookies().delete(COOKIE_NAME);
}

export async function getSession() {
  const token = cookies().get(COOKIE_NAME)?.value;
  return token ? verifyToken(token) : null;
}
