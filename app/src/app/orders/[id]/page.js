'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { api, useApi, useMe } from '@/lib/client';
import { Alert, Badge, Loading, Table, fmt } from '@/components/ui';

export default function OrderDetail({ params }) {
  const id = params.id;
  const me = useMe();
  const { data, error, loading, reload } = useApi(`/api/orders/${id}`);
  const events = useApi(`/api/mongo/events?order_id=${id}`);
  const [msg, setMsg] = useState({ kind: 'ok', text: '' });
  const [route, setRoute] = useState({ exchange_id: '', quantity: '', reason: '' });
  const [trade, setTrade] = useState({ exchange_id: '', quantity: '', price: '', commission: '0' });

  const order = data?.order;
  const canAct = me && order && (me.role === 'ADMIN' || (me.role === 'TRADER' && me.traderId === order.trader_id));
  const open = order && ['NEW', 'PENDING', 'PARTIALLY_FILLED'].includes(order.status);
  const routedTotal = data ? data.routes.reduce((s, r) => s + Number(r.routed_quantity), 0) : 0;
  const unrouted = order ? Math.max(Number(order.quantity) - routedTotal, 0) : 0;
  const routesWithRoom = data ? data.routes.filter((r) => Number(r.executed) < Number(r.routed_quantity)) : [];

  useEffect(() => { if (data?.eligible?.length && !route.exchange_id) setRoute((r) => ({ ...r, exchange_id: String(data.eligible[0].exchange_id), quantity: String(unrouted) })); }, [data]); // eslint-disable-line
  useEffect(() => {
    if (routesWithRoom.length && !trade.exchange_id) {
      const r = routesWithRoom[0];
      setTrade((t) => ({ ...t, exchange_id: String(r.exchange_id), quantity: String(Number(r.routed_quantity) - Number(r.executed)), price: order?.limit_price ? String(Number(order.limit_price)) : '' }));
    }
  }, [data]); // eslint-disable-line

  async function run(fn, okText) {
    setMsg({ kind: 'ok', text: '' });
    try { await fn(); setMsg({ kind: 'ok', text: okText }); setRoute({ exchange_id: '', quantity: '', reason: '' }); setTrade({ exchange_id: '', quantity: '', price: '', commission: '0' }); reload(); events.reload(); }
    catch (e) { setMsg({ kind: 'error', text: e.message }); }
  }

  return (
    <>
      <p><Link href="/orders">← All orders</Link></p>
      <Alert>{error}</Alert><Loading loading={loading} />
      {order && (
        <>
          <h1>Order #{order.order_id} <Badge>{order.status}</Badge></h1>
          <div className="grid cols-3">
            {[['Trader', order.trader], ['Portfolio', order.portfolio_name], ['Security', order.security_name], ['Algorithm', order.algorithm],
              ['Order', `${order.side} ${order.order_type}${order.limit_price ? ' @ ' + fmt(order.limit_price) : ''} · ${order.time_in_force}`],
              ['Quantity', fmt(order.quantity)], ['Executed', fmt(order.executed_quantity)], ['Remaining', fmt(order.remaining_quantity)]].map(([k, v]) => (
              <div className="card" key={k}><div className="stat-label">{k}</div><div style={{ fontSize: 16, fontWeight: 600 }}>{v}</div></div>
            ))}
          </div>
          {msg.text && <Alert kind={msg.kind}>{msg.text}</Alert>}

          <h2>Routes (order ↔ exchange)</h2>
          <Table rows={data.routes} columns={[
            { key: 'mic_code', label: 'Exchange' }, { key: 'exchange_name', label: 'Name' }, { key: 'routed_quantity', label: 'Routed' },
            { key: 'executed', label: 'Executed' }, { key: 'route_status', label: 'Status' }, { key: 'routing_reason', label: 'Reason' }, { key: 'routed_at', label: 'Routed at (UTC)' }]} empty="Not routed to any exchange yet." />

          <h2>Trades (executions)</h2>
          <Table rows={data.trades} empty="No trades yet." />

          {canAct && open && (
            <div className="grid cols-2" style={{ marginTop: 18 }}>
              <div className="card">
                <h2 style={{ marginTop: 0 }}>Route to an exchange</h2>
                <p className="muted small">Only exchanges where this security is listed. Calls <code>sp_route_order</code>.</p>
                {data.eligible.length === 0 ? <p className="muted">No more exchanges available for this security.</p> : (
                  <form className="stack" onSubmit={(e) => { e.preventDefault(); run(() => api(`/api/orders/${id}/routes`, { method: 'POST', body: route }), 'Order routed.'); }}>
                    <label>Exchange<select value={route.exchange_id} onChange={(e) => setRoute({ ...route, exchange_id: e.target.value })}>{data.eligible.map((x) => <option key={x.exchange_id} value={x.exchange_id}>{x.mic_code} – {x.exchange_name} ({x.ticker_symbol})</option>)}</select></label>
                    <label>Quantity (unrouted: {fmt(String(unrouted))})<input type="number" min="0" step="any" value={route.quantity} onChange={(e) => setRoute({ ...route, quantity: e.target.value })} required /></label>
                    <label>Reason<input value={route.reason} onChange={(e) => setRoute({ ...route, reason: e.target.value })} placeholder="e.g. best displayed price" /></label>
                    <div><button>Route order</button></div>
                  </form>)}
              </div>
              <div className="card">
                <h2 style={{ marginTop: 0 }}>Record a trade</h2>
                <p className="muted small">Only exchanges this order was routed to. Calls <code>sp_add_trade</code>; a trigger updates the order status.</p>
                {routesWithRoom.length === 0 ? <p className="muted">Route the order first (or all routed quantity is already executed).</p> : (
                  <form className="stack" onSubmit={(e) => { e.preventDefault(); run(() => api(`/api/orders/${id}/trades`, { method: 'POST', body: trade }), 'Trade recorded.'); }}>
                    <label>Exchange<select value={trade.exchange_id} onChange={(e) => setTrade({ ...trade, exchange_id: e.target.value })}>{routesWithRoom.map((x) => <option key={x.exchange_id} value={x.exchange_id}>{x.mic_code} (room: {fmt(String(Number(x.routed_quantity) - Number(x.executed)))})</option>)}</select></label>
                    <div className="row">
                      <label>Quantity<input type="number" min="0" step="any" value={trade.quantity} onChange={(e) => setTrade({ ...trade, quantity: e.target.value })} required /></label>
                      <label>Price<input type="number" min="0" step="any" value={trade.price} onChange={(e) => setTrade({ ...trade, price: e.target.value })} required /></label>
                      <label>Commission<input type="number" min="0" step="any" value={trade.commission} onChange={(e) => setTrade({ ...trade, commission: e.target.value })} /></label>
                    </div>
                    <div><button>Record trade</button></div>
                  </form>)}
              </div>
            </div>
          )}
          {canAct && open && (
            <p style={{ marginTop: 14 }}>
              <button className="danger" onClick={() => { if (confirm('Cancel this order?')) run(() => api(`/api/orders/${id}`, { method: 'POST', body: { action: 'cancel' } }), 'Order cancelled.'); }}>Cancel order</button>
            </p>
          )}
          {!canAct && me && me.role !== 'AUDITOR' && <p className="hint">Only the trader who placed this order (or an admin) can route, trade or cancel it.</p>}
          {me?.role === 'AUDITOR' && <p className="hint">Auditors have read-only access.</p>}

          <h2>Event log (MongoDB)</h2>
          {events.error ? <Alert kind="info">{events.error}</Alert> : (
            <Table rows={events.data?.map((e) => ({ time: e.ts, event: e.event_type, source: e.source, details: e.payload }))} empty="No events recorded." />
          )}
        </>
      )}
    </>
  );
}
