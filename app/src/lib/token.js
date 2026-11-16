// Session token (JWT) helpers. Pure "jose" so they also work in the edge middleware.
import { SignJWT, jwtVerify } from 'jose';

export const COOKIE_NAME = 'hft_session';
const secret = () => new TextEncoder().encode(process.env.JWT_SECRET || 'dev-only-secret-change-me');

export async function signToken(payload) {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(process.env.JWT_EXPIRES_IN || '8h')
    .sign(secret());
}

export async function verifyToken(token) {
  try {
    const { payload } = await jwtVerify(token, secret());
    return payload;            // { username, role, traderId, userId, iat, exp }
  } catch {
    return null;
  }
}
