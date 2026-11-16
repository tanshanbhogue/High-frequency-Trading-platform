'use client';
import { useEffect, useState } from 'react';
import { api, useApi } from '@/lib/client';
import { Alert, Table } from '@/components/ui';

export default function ReportsPage() {
  const list = useApi('/api/reports');
  const [id, setId] = useState('');
  const [result, setResult] = useState(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => { if (list.data?.length && !id) setId(list.data[0].id); }, [list.data]); // eslint-disable-line

  async function run(reportId) {
    setBusy(true); setError('');
    try { setResult(await api(`/api/reports?id=${reportId}`)); } catch (e) { setError(e.message); setResult(null); }
    setBusy(false);
  }
  useEffect(() => { if (id) run(id); }, [id]);

  return (
    <>
      <h1>SQL reports</h1>
      <p className="muted">Joins, nested and correlated queries, CTEs, a recursive CTE, window functions and stored functions. They run with <b>your role’s</b> database account.</p>
      <Alert>{list.error}</Alert>
      <div className="toolbar">
        <select value={id} onChange={(e) => setId(e.target.value)} style={{ minWidth: 380 }}>
          {list.data?.map((r) => <option key={r.id} value={r.id}>{r.concept} — {r.title}</option>)}
        </select>
        <button className="secondary" disabled={busy || !id} onClick={() => run(id)}>{busy ? 'Running…' : 'Run again'}</button>
      </div>
      <Alert>{error}</Alert>
      {result && (
        <>
          <p><span className="badge">{result.concept}</span> <b>{result.title}</b> <span className="muted">· {result.rows.length} rows</span></p>
          <Table rows={result.rows} />
          <h2>The SQL</h2>
          <pre className="sql">{result.sql}</pre>
        </>
      )}
    </>
  );
}
