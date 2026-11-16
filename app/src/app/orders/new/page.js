'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api, useApi, useMe } from '@/lib/client';
import { Alert } from '@/components/ui';

export default function NewOrder() {
  const router = useRouter();
  const me = useMe();
  const traders = useApi('/api/reference?type=traders').data;
  const securities = useApi('/api/reference?type=securities').data;
  const algorithms = useApi('/api/reference?type=algorithms').data;

  const [traderId, setTraderId] = useState('');
  const [f, setF] = useState({ portfolio_id: '', security_id: '', algorithm_id: '', side: 'BUY', order_type: 'LIMIT', quantity: '', limit_price: '', time_in_force: 'DAY' });
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => { if (me?.role === 'TRADER') setTraderId(String(me.traderId)); }, [me]);
  // Only portfolios the chosen trader owns (the database enforces this too)
  const portfolios = useApi(traderId ? `/api/reference?type=portfolios&trader_id=${traderId}` : null).data;
  useEffect(() => { setF((x) => ({ ...x, portfolio_id: '' })); }, [traderId]);

  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });

  async function submit(e) {
    e.preventDefault();
    setBusy(true); setError('');
    try {
      const r = await api('/api/orders', { method: 'POST', body: { ...f, trader_id: traderId } });
      router.push(`/orders/${r.order_id}`);
    } catch (err) { setError(err.message); setBusy(false); }
  }

  if (!me) return null;
  return (
    <>
      <h1>New order</h1>
      <p className="muted">Calls the stored procedure <code>sp_place_order</code>. The database checks that the trader owns the portfolio.</p>
      <div className="card" style={{ maxWidth: 720 }}>
        <form className="stack" onSubmit={submit}>
          <div className="row">
            <label>Trader
              {me.role === 'ADMIN'
                ? <select value={traderId} onChange={(e) => setTraderId(e.target.value)} required><option value="">Choose…</option>{traders?.map((t) => <option key={t.trader_id} value={t.trader_id}>{t.full_name}</option>)}</select>
                : <input value={me.username} disabled />}
            </label>
            <label>Portfolio (owned by trader)
              <select value={f.portfolio_id} onChange={set('portfolio_id')} required disabled={!traderId}>
                <option value="">Choose…</option>{portfolios?.map((p) => <option key={p.portfolio_id} value={p.portfolio_id}>{p.portfolio_name} ({p.base_currency})</option>)}
              </select>
            </label>
          </div>
          <div className="row">
            <label>Security
              <select value={f.security_id} onChange={set('security_id')} required><option value="">Choose…</option>{securities?.map((s) => <option key={s.security_id} value={s.security_id}>{s.security_name}</option>)}</select>
            </label>
            <label>Algorithm (optional)
              <select value={f.algorithm_id} onChange={set('algorithm_id')}><option value="">Manual order</option>{algorithms?.map((a) => <option key={a.algorithm_id} value={a.algorithm_id}>{a.algorithm_name} v{a.version}</option>)}</select>
            </label>
          </div>
          <div className="row">
            <label>Side<select value={f.side} onChange={set('side')}><option>BUY</option><option>SELL</option></select></label>
            <label>Type<select value={f.order_type} onChange={set('order_type')}><option>MARKET</option><option>LIMIT</option><option>STOP</option></select></label>
            <label>Time in force<select value={f.time_in_force} onChange={set('time_in_force')}><option>DAY</option><option>IOC</option><option>FOK</option><option>GTC</option></select></label>
          </div>
          <div className="row">
            <label>Quantity<input type="number" min="0" step="any" value={f.quantity} onChange={set('quantity')} required /></label>
            <label>{f.order_type === 'STOP' ? 'Stop (trigger) price' : 'Limit price'}
              <input type="number" min="0" step="any" value={f.order_type === 'MARKET' ? '' : f.limit_price} onChange={set('limit_price')} disabled={f.order_type === 'MARKET'} required={f.order_type !== 'MARKET'} />
            </label>
          </div>
          <Alert>{error}</Alert>
          <div><button disabled={busy}>{busy ? 'Placing…' : 'Place order'}</button></div>
        </form>
      </div>
    </>
  );
}
