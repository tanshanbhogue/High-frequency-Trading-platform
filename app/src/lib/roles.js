// Role definitions. NOTE: this only controls what the UI shows and which pages
// open. The REAL enforcement is in MySQL (see sql/03_roles_and_grants.sql).
export const ADMIN = 'ADMIN';
export const TRADER = 'TRADER';
export const AUDITOR = 'AUDITOR';
export const ALL_ROLES = [ADMIN, TRADER, AUDITOR];

export const NAV = [
  { href: '/dashboard',   label: 'Dashboard',   roles: ALL_ROLES },
  { href: '/orders',      label: 'Orders',      roles: ALL_ROLES },
  { href: '/orders/new',  label: 'New order',   roles: [ADMIN, TRADER] },
  { href: '/portfolios',  label: 'Portfolios',  roles: ALL_ROLES },
  { href: '/market-feed', label: 'Market feed', roles: ALL_ROLES },
  { href: '/algorithms',  label: 'Algorithms',  roles: ALL_ROLES },
  { href: '/reports',     label: 'SQL reports', roles: ALL_ROLES },
  { href: '/audit',       label: 'Audit log',   roles: [ADMIN, AUDITOR] },
  { href: '/admin/users', label: 'Users',       roles: [ADMIN] },
];

// Pages that need a specific role (everything else: any logged-in user).
export const PAGE_ACCESS = {
  '/orders/new': [ADMIN, TRADER],
  '/audit': [ADMIN, AUDITOR],
  '/admin': [ADMIN],
};

export function canOpen(role, pathname) {
  for (const [prefix, roles] of Object.entries(PAGE_ACCESS)) {
    if (pathname === prefix || pathname.startsWith(prefix + '/')) return roles.includes(role);
  }
  return true;
}
