// Automated role-permission tests. Run:  npm run test:roles
// Connects to MySQL as each role account (from ../.env) and checks that every
// statement is ALLOWED or DENIED exactly as designed. Writes are rolled back.
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

// --- tiny .env loader (no extra dependency) ---
const envFile = path.join(__dirname, '..', '.env');
const rootEnv = path.join(__dirname, '..', '..', '.env');
for (const f of [envFile, rootEnv]) {
  if (fs.existsSync(f)) {
    for (const line of fs.readFileSync(f, 'utf8').split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (m && !(m[1] in process.env)) process.env[m[1]] = m[2];
    }
    break;
  }
}
const E = process.env;
const accounts = {
  admin:   { user: E.MYSQL_ADMIN_USER,   password: E.MYSQL_ADMIN_PASSWORD },
  trader:  { user: E.MYSQL_TRADER_USER,  password: E.MYSQL_TRADER_PASSWORD },
  auditor: { user: E.MYSQL_AUDITOR_USER, password: E.MYSQL_AUDITOR_PASSWORD },
  auth:    { user: E.MYSQL_AUTH_USER,    password: E.MYSQL_AUTH_PASSWORD },
};

// [account, description, SQL, expected 'ALLOW' | 'DENY' | 'ERROR:<text>']
const tests = [
  ['trader', 'read orders', 'SELECT COUNT(*) FROM orders', 'ALLOW'],
  ['trader', 'read app_users (password hashes)', 'SELECT * FROM app_users', 'DENY'],
  ['trader', 'read audit_log', 'SELECT * FROM audit_log', 'DENY'],
  ['trader', 'direct INSERT into orders', "INSERT INTO orders (trader_id,portfolio_id,security_id,side,order_type,quantity,limit_price) VALUES (3,3,4,'BUY','LIMIT',10,1440)", 'DENY'],
  ['trader', 'direct UPDATE of orders', "UPDATE orders SET status='NEW' WHERE order_id=1", 'DENY'],
  ['trader', 'DELETE from trades', 'DELETE FROM trades WHERE trade_id=1', 'DENY'],
  ['trader', 'DROP TABLE', 'DROP TABLE trades', 'DENY'],
  ['trader', 'internal helper procedure', 'CALL sp_validate_trade(1,1,1,NULL)', 'DENY'],
  ['trader', 'sp_place_order for an owned portfolio', "CALL sp_place_order(3,3,4,NULL,'BUY','LIMIT',10,1440,'DAY',@o)", 'ALLOW'],
  ['trader', 'sp_place_order for a portfolio the trader does not own', "CALL sp_place_order(2,3,4,NULL,'BUY','LIMIT',10,1440,'DAY',@o)", 'ERROR:not an owner'],
  ['trader', 'function fn_remaining_quantity', 'SELECT fn_remaining_quantity(2)', 'ALLOW'],
  ['auditor', 'read trades', 'SELECT COUNT(*) FROM trades', 'ALLOW'],
  ['auditor', 'read audit_log', 'SELECT COUNT(*) FROM audit_log', 'ALLOW'],
  ['auditor', 'read app_users', 'SELECT * FROM app_users', 'DENY'],
  ['auditor', 'INSERT', "INSERT INTO exchanges (exchange_name,mic_code,country,timezone) VALUES ('T','TEST','X','UTC')", 'DENY'],
  ['auditor', 'UPDATE', "UPDATE orders SET status='NEW' WHERE order_id=1", 'DENY'],
  ['auditor', 'DELETE', 'DELETE FROM orders WHERE order_id=9', 'DENY'],
  ['auditor', 'run sp_place_order', "CALL sp_place_order(3,3,4,NULL,'BUY','LIMIT',10,1440,'DAY',@o)", 'DENY'],
  ['auditor', 'read-only function', 'SELECT fn_portfolio_value(1)', 'ALLOW'],
  ['auth', 'read app_users', 'SELECT COUNT(*) FROM app_users', 'ALLOW'],
  ['auth', 'stamp last_login', 'UPDATE app_users SET last_login = last_login WHERE user_id=1', 'ALLOW'],
  ['auth', 'change a role', "UPDATE app_users SET role='ADMIN' WHERE user_id=2", 'DENY'],
  ['auth', 'read orders', 'SELECT * FROM orders', 'DENY'],
  ['admin', 'read app_users', 'SELECT COUNT(*) FROM app_users', 'ALLOW'],
  ['admin', 'read audit_log', 'SELECT COUNT(*) FROM audit_log', 'ALLOW'],
  ['admin', 'insert + remove an exchange', null, 'ALLOW'],
];

(async () => {
  let pass = 0, fail = 0;
  const conns = {};
  for (const [role, cfg] of Object.entries(accounts)) {
    conns[role] = await mysql.createConnection({ host: E.MYSQL_HOST || 'localhost', port: +(E.MYSQL_PORT || 3306), database: E.MYSQL_DATABASE || 'HFT', ...cfg });
  }
  for (const [role, desc, sql, expect] of tests) {
    const c = conns[role];
    let outcome;
    try {
      if (sql === null) {
        await c.query("INSERT INTO exchanges (exchange_name,mic_code,country,timezone) VALUES ('ZZ','ZZZZ','X','UTC')");
        await c.query("DELETE FROM exchanges WHERE mic_code='ZZZZ'");
      } else {
        await c.query('START TRANSACTION');
        await c.query(sql);
        await c.query('ROLLBACK');
      }
      outcome = 'ALLOW';
    } catch (e) {
      try { await c.query('ROLLBACK'); } catch (_) {}
      outcome = /command denied|access denied/i.test(e.sqlMessage || e.message) ? 'DENY' : 'ERROR:' + (e.sqlMessage || e.message);
    }
    const ok = outcome === expect || (expect.startsWith('ERROR:') && outcome.startsWith('ERROR:') && outcome.toLowerCase().includes(expect.slice(6).toLowerCase()));
    ok ? pass++ : fail++;
    console.log(`${ok ? 'PASS' : 'FAIL'}  [${role.padEnd(7)}] ${desc.padEnd(58)} expected ${expect.padEnd(8)} got ${outcome.slice(0, 60)}`);
  }
  for (const c of Object.values(conns)) await c.end();
  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(2); });
