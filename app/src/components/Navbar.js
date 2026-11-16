'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useMe, api } from '@/lib/client';
import { NAV } from '@/lib/roles';

export default function Navbar() {
  const pathname = usePathname();
  const router = useRouter();
  const me = useMe();
  if (pathname === '/login' || !me) return null;

  const logout = async () => { await api('/api/auth/logout', { method: 'POST' }); router.push('/login'); router.refresh(); };
  const items = NAV.filter((n) => n.roles.includes(me.role));
  const active = (href) => pathname === href || (href !== '/orders' && href !== '/dashboard' && pathname.startsWith(href + '/'));

  return (
    <nav className="top">
      <span className="brand">HFT Platform</span>
      {items.map((n) => (
        <Link key={n.href} href={n.href} className={'link' + (active(n.href) || (n.href === '/orders' && pathname.startsWith('/orders') && pathname !== '/orders/new') ? ' active' : '')}>{n.label}</Link>
      ))}
      <span className="spacer" />
      <span className="who">{me.username} · {me.role}</span>
      <button className="secondary small" onClick={logout}>Log out</button>
    </nav>
  );
}
