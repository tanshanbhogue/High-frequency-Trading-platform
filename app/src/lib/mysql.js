// MySQL connection pools - ONE PER DATABASE ACCOUNT.
// The account used for a request is chosen from the logged-in user's role, so
// MySQL itself enforces what that role may do (see sql/03_roles_and_grants.sql).
import mysql from 'mysql2/promise';

const ACCOUNTS = {
  admin:   ['MYSQL_ADMIN_USER', 'MYSQL_ADMIN_PASSWORD'],
  trader:  ['MYSQL_TRADER_USER', 'MYSQL_TRADER_PASSWORD'],
  auditor: ['MYSQL_AUDITOR_USER', 'MYSQL_AUDITOR_PASSWORD'],
  auth:    ['MYSQL_AUTH_USER', 'MYSQL_AUTH_PASSWORD'],   // login lookup only
};

export const accountForRole = { ADMIN: 'admin', TRADER: 'trader', AUDITOR: 'auditor' };

const pools = globalThis.__hftPools || (globalThis.__hftPools = {});

export function getPool(account) {
  if (!ACCOUNTS[account]) throw new Error('Unknown database account: ' + account);
  if (!pools[account]) {
    const [userVar, passVar] = ACCOUNTS[account];
    pools[account] = mysql.createPool({
      host: process.env.MYSQL_HOST || 'localhost',
      port: Number(process.env.MYSQL_PORT || 3306),
      database: process.env.MYSQL_DATABASE || 'HFT',
      user: process.env[userVar],
      password: process.env[passVar],
      waitForConnections: true,
      connectionLimit: 5,
      dateStrings: true,   // return DATETIME as plain text (UTC), no time-zone conversion
      timezone: 'Z',
    });
  }
  return pools[account];
}

// Run one statement and return the rows.
export async function query(account, sql, params = []) {
  const [rows] = await getPool(account).query(sql, params);
  return rows;
}

// Run several statements on ONE connection. @app_user is set first so the audit
// triggers record WHO made the change.
export async function withConnection(account, appUser, fn) {
  const conn = await getPool(account).getConnection();
  try {
    await conn.query('SET @app_user = ?', [appUser || null]);
    return await fn(conn);
  } finally {
    conn.release();
  }
}
