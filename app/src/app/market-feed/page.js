'use client';
import { useState } from 'react';
import { useApi } from '@/lib/client';
import { Alert, Loading, Table } from '@/components/ui';

export default function MarketFeed() {
  const securities = useApi('/api/reference?type=securities').data;
  const exchanges = useApi('/api/reference?type=exchanges').data;
  const [sec, setSec] = useState('');
  const [exch, setExch] = useState('');
  const qs = new URLSearchParams({ ...(sec && { security_id: sec }), ...(exch && { exchange_id: exch }), limit: '100' }).toString();
  const { data, error, loading } = useApi('/api/market-feed?' + qs);
  return (
    <>
      <h1>Market feed</h1>
      <p className="muted">Timestamped quotes per security listing (security × exchange). Times are UTC.</p>
      <div className="toolbar">
        <select value={sec} onChange={(e) => setSec(e.target.value)}><option value="">All securities</option>{securities?.map((s) => <option key={s.security_id} value={s.security_id}>{s.security_name}</option>)}</select>
        <select value={exch} onChange={(e) => setExch(e.target.value)}><option value="">All exchanges</option>{exchanges?.map((x) => <option key={x.exchange_id} value={x.exchange_id}>{x.mic_code} – {x.exchange_name}</option>)}</select>
        <span className="muted">{data ? `${data.length} quotes` : ''}</span>
      </div>
      <Alert>{error}</Alert><Loading loading={loading} />
      <Table rows={data} />
    </>
  );
}
