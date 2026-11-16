// End-to-end API test. Start the app first (npm run dev), then:  npm run test:api
// NOTE: it creates a few TEST orders/trades in the database (they are real rows).
//       To get a pristine demo database again, re-run the MySQL setup (see README).
const BASE = process.env.APP_URL || 'http://localhost:3000';

function client() {
  let cookie = '';
  return async (method, url, body) => {
    const res = await fetch(BASE + url, {
      method, redirect: 'manual',
      headers: { 'content-type': 'application/json', ...(cookie ? { cookie } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    const set = res.headers.getSetCookie?.() || [];
    if (set.length) cookie = set.map((c) => c.split(';')[0]).join('; ');
    let data = null;
    try { data = await res.json(); } catch { /* not JSON */ }
    return { status: res.status, data };
  };
}

let pass = 0, fail = 0;
function check(name, cond, extra = '') {
  cond ? pass++ : fail++;
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}${cond ? '' : '   <-- ' + extra}`);
}
const has = (r, text) => JSON.stringify(r.data || '').toLowerCase().includes(text.toLowerCase());

(async () => {
  const anon = client(), aarav = client(), rohan = client(), auditor = client(), admin = client();

  console.log('--- Authentication');
  check('anonymous request is rejected (401)', (await anon('GET', '/api/orders')).status === 401);
  check('wrong password is rejected (401)', (await anon('POST', '/api/auth/login', { username: 'aarav', password: 'nope' })).status === 401);
  check('trader aarav logs in', (await aarav('POST', '/api/auth/login', { username: 'aarav', password: 'Trader@123' })).status === 200);
  check('trader rohan logs in', (await rohan('POST', '/api/auth/login', { username: 'rohan', password: 'Trader@123' })).status === 200);
  check('auditor logs in', (await auditor('POST', '/api/auth/login', { username: 'auditor', password: 'Auditor@123' })).status === 200);
  check('admin logs in', (await admin('POST', '/api/auth/login', { username: 'admin', password: 'Admin@123' })).status === 200);

  console.log('--- Role restrictions (UI-independent, enforced by API and MySQL)');
  check('trader cannot open admin users (403)', (await aarav('GET', '/api/admin/users')).status === 403);
  check('trader cannot read the audit log (403)', (await aarav('GET', '/api/audit')).status === 403);
  check('auditor cannot place an order (403)', (await auditor('POST', '/api/orders', { portfolio_id: 1, security_id: 1, side: 'BUY', order_type: 'LIMIT', quantity: 1, limit_price: 1 })).status === 403);
  check('auditor can read orders', (await auditor('GET', '/api/orders')).status === 200);
  check('auditor can read the audit log', (await auditor('GET', '/api/audit')).status === 200);
  check('admin can read users', (await admin('GET', '/api/admin/users')).status === 200);

  console.log('--- Trading workflow as trader aarav (portfolio 1, Infosys)');
  const place = { portfolio_id: 1, security_id: 1, side: 'BUY', order_type: 'LIMIT', quantity: 100, limit_price: 1650, time_in_force: 'DAY' };
  let r = await aarav('POST', '/api/orders', place);
  check('place order via sp_place_order (201)', r.status === 201 && r.data.order_id > 0, JSON.stringify(r.data));
  const id = r.data.order_id;
  r = await aarav('POST', '/api/orders', { ...place, portfolio_id: 3 });
  check('cannot order on a portfolio he does not own', r.status === 400 && has(r, 'not an owner'), JSON.stringify(r.data));
  r = await aarav('POST', `/api/orders/${id}/routes`, { exchange_id: 3, quantity: 100 });
  check('cannot route Infosys to NASDAQ (not listed there)', r.status === 400 && has(r, 'not actively listed'), JSON.stringify(r.data));
  r = await aarav('POST', `/api/orders/${id}/routes`, { exchange_id: 1, quantity: 150 });
  check('cannot route more than the order quantity', r.status === 400 && has(r, 'exceeds'), JSON.stringify(r.data));
  r = await aarav('POST', `/api/orders/${id}/routes`, { exchange_id: 1, quantity: 100, reason: 'api test' });
  check('route order to NSE (201)', r.status === 201, JSON.stringify(r.data));
  r = await rohan('POST', `/api/orders/${id}/trades`, { exchange_id: 1, quantity: 10, price: 1649 });
  check("another trader cannot add trades to aarav's order (403)", r.status === 403, JSON.stringify(r.data));
  r = await aarav('POST', `/api/orders/${id}/trades`, { exchange_id: 1, quantity: 60, price: 1655 });
  check('trade above the BUY limit is rejected', r.status === 400 && has(r, 'above the BUY limit'), JSON.stringify(r.data));
  r = await aarav('POST', `/api/orders/${id}/trades`, { exchange_id: 1, quantity: 60, price: 1649, commission: 30 });
  check('first trade 60/100 -> order PARTIALLY_FILLED', r.status === 201 && r.data.order_status === 'PARTIALLY_FILLED', JSON.stringify(r.data));
  r = await aarav('POST', `/api/orders/${id}/trades`, { exchange_id: 1, quantity: 50, price: 1649 });
  check('over-execution (50 > remaining 40) is rejected', r.status === 400 && has(r, 'exceed'), JSON.stringify(r.data));
  r = await aarav('POST', `/api/orders/${id}/trades`, { exchange_id: 1, quantity: 40, price: 1648.5, commission: 20 });
  check('second trade 40 -> order FILLED', r.status === 201 && r.data.order_status === 'FILLED', JSON.stringify(r.data));
  r = await aarav('GET', `/api/orders/${id}`);
  check('detail shows executed 100 / remaining 0', r.status === 200 && Number(r.data.order.executed_quantity) === 100 && Number(r.data.order.remaining_quantity) === 0, JSON.stringify(r.data?.order));
  check('route status synced to FILLED by trigger', r.data?.routes?.[0]?.route_status === 'FILLED');
  r = await aarav('POST', `/api/orders/${id}`, { action: 'cancel' });
  check('a FILLED order cannot be cancelled', r.status === 400 && has(r, 'cannot be cancelled'), JSON.stringify(r.data));

  console.log('--- Cancel workflow');
  r = await aarav('POST', '/api/orders', place);
  const id2 = r.data.order_id;
  r = await rohan('POST', `/api/orders/${id2}`, { action: 'cancel' });
  check("another trader cannot cancel aarav's order", r.status === 400 && has(r, 'only the trader who placed'), JSON.stringify(r.data));
  r = await aarav('POST', `/api/orders/${id2}`, { action: 'cancel' });
  check('owner cancels a new order', r.status === 200, JSON.stringify(r.data));
  r = await aarav('GET', `/api/orders/${id2}`);
  check('status is CANCELLED', r.data?.order?.status === 'CANCELLED');

  console.log('--- Audit trail (written by triggers)');
  r = await auditor('GET', '/api/audit?table=trades&limit=20');
  check('audit log has trade rows made by aarav', r.status === 200 && r.data.some((a) => a.changed_by === 'aarav'), JSON.stringify(r.data?.[0]));

  console.log('--- SQL reports (run with each role\'s own database account)');
  const list = (await auditor('GET', '/api/reports')).data || [];
  check('13 reports available', list.length === 13, String(list.length));
  let okReports = 0;
  for (const rep of list) {
    const x = await auditor('GET', `/api/reports?id=${rep.id}`);
    if (x.status === 200 && Array.isArray(x.data.rows)) okReports++; else console.log('   report failed:', rep.id, JSON.stringify(x.data));
  }
  check('every report runs as the read-only auditor', okReports === list.length, `${okReports}/${list.length}`);

  console.log('--- Admin: user management');
  const uname = 'apitest' + Date.now().toString().slice(-6);
  r = await admin('POST', '/api/admin/users', { username: uname, password: 'secret12', role: 'AUDITOR' });
  check('admin creates a user', r.status === 201, JSON.stringify(r.data));
  const created = ((await admin('GET', '/api/admin/users')).data || []).find((u) => u.username === uname);
  const newUser = client();
  check('new user can log in', (await newUser('POST', '/api/auth/login', { username: uname, password: 'secret12' })).status === 200);
  r = await admin('PATCH', '/api/admin/users', { user_id: created?.user_id, is_active: false });
  check('admin disables the user', r.status === 200, JSON.stringify(r.data));
  check('disabled user can no longer log in', (await client()('POST', '/api/auth/login', { username: uname, password: 'secret12' })).status === 401);
  r = await admin('POST', '/api/admin/users', { username: 'x' + uname, password: 'secret12', role: 'TRADER' });
  check('TRADER login without a trader is rejected by the database trigger', r.status === 400 && has(r, 'linked to a trader_id'), JSON.stringify(r.data));

  console.log('--- MongoDB (backtests + order events)');
  r = await aarav('GET', '/api/mongo/backtests');
  if (r.status === 503) {
    console.log('SKIP  MongoDB is not running - ' + r.data.error);
  } else {
    check('read backtests', r.status === 200 && r.data.length >= 12, String(r.data?.length));
    const doc = r.data.find((d) => d.run_label === 'Q1-2024 wide spread') || r.data[0];
    r = await aarav('PATCH', '/api/mongo/backtests', { id: doc._id, add_tag: 'api-test', notes: 'updated by api test' });
    check('trader updates a backtest (tag + note)', r.status === 200 && r.data.matched === 1, JSON.stringify(r.data));
    r = await aarav('DELETE', `/api/mongo/backtests?id=${doc._id}`);
    check('trader cannot delete a backtest (403)', r.status === 403);
    r = await auditor('PATCH', '/api/mongo/backtests', { id: doc._id, status: 'REVIEWED' });
    check('auditor cannot update a backtest (403)', r.status === 403);
    r = await aarav('POST', '/api/mongo/backtests', { algorithm_id: 2, algorithm_name: 'AlphaMaker', run_label: 'api-test-run', sharpe: 1.1 });
    check('trader creates a backtest', r.status === 201, JSON.stringify(r.data));
    const newId = r.data?._id;
    r = await admin('DELETE', `/api/mongo/backtests?id=${newId}`);
    check('admin deletes it', r.status === 200 && r.data.deleted === 1, JSON.stringify(r.data));
    r = await aarav('GET', `/api/mongo/events?order_id=${id}`);
    check('order events were logged in MongoDB for the new order', r.status === 200 && r.data.length >= 4, JSON.stringify(r.data?.length));
    r = await aarav('GET', '/api/mongo/backtests?stats=1');
    check('strategy statistics endpoint', r.status === 200 && r.data.length > 3, JSON.stringify(r.data));
  }

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(2); });
