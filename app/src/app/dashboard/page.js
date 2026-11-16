'use client';
import { useApi } from '@/lib/client';
import { Alert, Badge, Loading, Table, fmt } from '@/components/ui';

export default function Dashboard() {
  const { data, error, loading } = useApi('/api/dashboard');
  const maxVol = data ? Math.max(...data.volume.map((v) => Number(v.volume)), 1) : 1;

  return (
    <>
      <h1>Dashboard</h1>
      <p className="muted">Live figures from the HFT database (MySQL).</p>
      <Alert>{error}</Alert><Loading loading={loading} />
      {data && (
        <>
          <div className="grid cols-3">
            {Object.entries(data.counts[0] ?? data.counts).map(([k, v]) => (
              <div className="card" key={k}><div className="stat">{v}</div><div className="stat-label">{k}</div></div>
            ))}
          </div>

          <div className="grid cols-2" style={{ marginTop: 14 }}>
            <div className="card">
              <h2 style={{ marginTop: 0 }}>Orders by status</h2>
              {data.byStatus.map((s) => (
                <div key={s.status} style={{ display: 'flex', justifyContent: 'space-between', margin: '8px 0' }}>
                  <Badge>{s.status}</Badge><b>{s.n}</b>
                </div>
              ))}
            </div>
            <div className="card">
              <h2 style={{ marginTop: 0 }}>Traded volume per exchange (shares)</h2>
              {data.volume.map((v) => (
                <div className="bar-row" key={v.mic_code} title={v.exchange_name}>
                  <span>{v.mic_code}</span>
                  <div className="bar" style={{ width: `${(Number(v.volume) / maxVol) * 100}%` }} />
                  <span className="muted">{fmt(v.volume)} · {v.trades} trades</span>
                </div>
              ))}
            </div>
          </div>

          <h2>Latest trades</h2>
          <Table rows={data.latest} />
        </>
      )}
    </>
  );
}
