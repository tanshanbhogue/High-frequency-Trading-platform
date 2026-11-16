'use client';
import { useState } from 'react';
import { api, useApi, useMe } from '@/lib/client';
import { Alert, Loading, Table, Badge, fmt } from '@/components/ui';

export default function AlgorithmsPage() {
  const me = useMe();
  const algos = useApi('/api/algorithms');
  const [algoId, setAlgoId] = useState('');
  const runs = useApi('/api/mongo/backtests' + (algoId ? `?algorithm_id=${algoId}` : ''));
  const stats = useApi('/api/mongo/backtests?stats=1');
  const [msg, setMsg] = useState({ kind: 'ok', text: '' });

  const canEdit = me && ['ADMIN', 'TRADER'].includes(me.role);
  const canDelete = me?.role === 'ADMIN';

  async function act(fn, text) {
    setMsg({ kind: 'ok', text: '' });
    try { await fn(); setMsg({ kind: 'ok', text }); runs.reload(); stats.reload(); } catch (e) { setMsg({ kind: 'error', text: e.message }); }
  }

  const runColumns = [
    { key: 'run_label', label: 'Run' }, { key: 'algorithm', label: 'Algorithm', render: (r) => `${r.algorithm_name} v${r.version}` },
    { key: 'status', label: 'Status', render: (r) => <Badge>{r.status}</Badge> },
    { key: 'ret', label: 'Return %', render: (r) => fmt(r.metrics.total_return_pct) }, { key: 'sh', label: 'Sharpe', render: (r) => fmt(r.metrics.sharpe) },
    { key: 'dd', label: 'Max DD %', render: (r) => fmt(r.metrics.max_drawdown_pct) }, { key: 'tr', label: 'Trades', render: (r) => fmt(r.metrics.num_trades) },
    { key: 'tags', label: 'Tags', render: (r) => (r.tags || []).join(', ') || '–' }, { key: 'notes', label: 'Notes', render: (r) => r.notes || r.comment || '–' },
    { key: 'actions', label: '', render: (r) => (
      <span style={{ display: 'flex', gap: 6 }}>
        {canEdit && r.status !== 'REVIEWED' && <button className="small secondary" onClick={() => act(() => api('/api/mongo/backtests', { method: 'PATCH', body: { id: r._id, status: 'REVIEWED' } }), 'Marked as reviewed.')}>Mark reviewed</button>}
        {canEdit && <button className="small secondary" onClick={() => { const t = prompt('Tag to add:'); if (t) act(() => api('/api/mongo/backtests', { method: 'PATCH', body: { id: r._id, add_tag: t } }), `Tag “${t}” added.`); }}>+ tag</button>}
        {canEdit && <button className="small secondary" onClick={() => { const n = prompt('Note:', r.notes || ''); if (n !== null) act(() => api('/api/mongo/backtests', { method: 'PATCH', body: { id: r._id, notes: n } }), 'Note updated.'); }}>Note</button>}
        {canDelete && <button className="small danger" onClick={() => { if (confirm('Delete this backtest run?')) act(() => api(`/api/mongo/backtests?id=${r._id}`, { method: 'DELETE' }), 'Run deleted.'); }}>Delete</button>}
      </span>) },
  ];

  return (
    <>
      <h1>Algorithms</h1>
      <Alert>{algos.error}</Alert><Loading loading={algos.loading} />
      <Table rows={algos.data} />

      <h2>Backtest results <span className="muted small">(MongoDB document store)</span></h2>
      <p className="muted">Update and delete work on documents in MongoDB. Traders may edit; only admins may delete; auditors are read-only.</p>
      {msg.text && <Alert kind={msg.kind}>{msg.text}</Alert>}
      {stats.data && stats.data.length > 0 && (
        <>
          <h2 style={{ marginTop: 6 }}>Average Sharpe ratio per strategy</h2>
          <Table rows={stats.data} />
        </>
      )}
      <div className="toolbar">
        <select value={algoId} onChange={(e) => setAlgoId(e.target.value)}>
          <option value="">All algorithms</option>{algos.data?.map((a) => <option key={a.algorithm_id} value={a.algorithm_id}>{a.algorithm_name} v{a.version}</option>)}
        </select>
        <span className="muted">{runs.data ? `${runs.data.length} runs` : ''}</span>
      </div>
      {runs.error ? <Alert kind="info">{runs.error}</Alert> : <Table rows={runs.data} columns={runColumns} empty="No backtest runs." />}
    </>
  );
}
