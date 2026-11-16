'use client';
import Link from 'next/link';
import { useState } from 'react';
import { useApi, useMe } from '@/lib/client';
import { Alert, Loading, Table, fmt } from '@/components/ui';

const STATUSES = ['NEW', 'PENDING', 'PARTIALLY_FILLED', 'FILLED', 'CANCELLED', 'REJECTED'];

export default function OrdersPage() {
  const me = useMe();
  const [status, setStatus] = useState('');
  const { data, error, loading } = useApi('/api/orders' + (status ? `?status=${status}` : ''));
  const columns = [
    { key: 'order_id', label: 'Order', render: (r) => <Link href={`/orders/${r.order_id}`}>#{r.order_id}</Link> },
    { key: 'status', label: 'Status' },
    { key: 'side', label: 'Side' }, { key: 'order_type', label: 'Type' },
    { key: 'security_name', label: 'Security' }, { key: 'quantity', label: 'Qty' },
    { key: 'executed_quantity', label: 'Executed' }, { key: 'remaining_quantity', label: 'Remaining' },
    { key: 'limit_price', label: 'Limit' }, { key: 'trader', label: 'Trader' },
    { key: 'portfolio_name', label: 'Portfolio' }, { key: 'algorithm', label: 'Algorithm' },
  ];
  return (
    <>
      <h1>Orders</h1>
      <div className="toolbar">
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">All statuses</option>
          {STATUSES.map((s) => <option key={s}>{s}</option>)}
        </select>
        {me && ['ADMIN', 'TRADER'].includes(me.role) && <Link href="/orders/new"><button>New order</button></Link>}
        <span className="muted">{data ? `${data.length} orders` : ''}</span>
      </div>
      <Alert>{error}</Alert><Loading loading={loading} />
      <Table rows={data} columns={columns} />
    </>
  );
}
