'use client';
import { useState } from 'react';
import { useApi } from '@/lib/client';
import { Alert, Loading, Table } from '@/components/ui';

export default function AuditPage() {
  const [table, setTable] = useState('');
  const { data, error, loading, reload } = useApi('/api/audit?limit=200' + (table ? `&table=${table}` : ''));
  return (
    <>
      <h1>Audit log</h1>
      <p className="muted">Every INSERT / UPDATE / DELETE on <code>orders</code> and <code>trades</code> is recorded by database triggers (who, when, before and after).</p>
      <div className="toolbar">
        <select value={table} onChange={(e) => setTable(e.target.value)}><option value="">All tables</option><option>orders</option><option>trades</option></select>
        <button className="secondary" onClick={reload}>Refresh</button>
        <span className="muted">{data ? `${data.length} entries` : ''}</span>
      </div>
      <Alert>{error}</Alert><Loading loading={loading} />
      <Table rows={data?.map((a) => ({ ...a, old_values: a.old_values ? JSON.stringify(a.old_values) : null, new_values: a.new_values ? JSON.stringify(a.new_values) : null }))} />
    </>
  );
}
