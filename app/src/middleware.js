// Route protection: no valid session -> /login (pages) or 401 (API).
import { NextResponse } from 'next/server';
import { COOKIE_NAME, verifyToken } from '@/lib/token';
import { canOpen } from '@/lib/roles';

const PUBLIC = ['/login', '/api/auth/login'];

export async function middleware(request) {
  const { pathname } = request.nextUrl;
  if (PUBLIC.includes(pathname)) return NextResponse.next();

  const token = request.cookies.get(COOKIE_NAME)?.value;
  const session = token ? await verifyToken(token) : null;

  if (!session) {
    if (pathname.startsWith('/api/')) {
      return NextResponse.json({ error: 'Not logged in' }, { status: 401 });
    }
    return NextResponse.redirect(new URL('/login', request.url));
  }
  if (!pathname.startsWith('/api/') && !canOpen(session.role, pathname)) {
    return NextResponse.redirect(new URL('/dashboard', request.url));
  }
  return NextResponse.next();
}

export const config = { matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'] };
