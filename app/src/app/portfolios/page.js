'use client';
import { useState } from 'react';
import { useApi } from '@/lib/client';
import { Alert, Loading, Table } from '@/components/ui';

export default function PortfoliosPage() {
  const { data, error, loading } = useApi('/api/portfolios');
  const [selected, setSelected] = useState(null);
  const holdings = useApi(selected ? `/api/portfolios?id=${selected.portfolio_id}` : null);
  const columns = [
    { key: 'portfolio_id', label: 'ID' }, { key: 'portfolio_name', label: 'Portfolio' }, { key: 'base_currency', label: 'Ccy' },
    { key: 'risk_profile', label: 'Risk' }, { key: 'status', label: 'Status' }, { key: 'owners', label: 'Owners' },
    { key: 'holdings', label: 'Holdings' }, { key: 'market_value', label: 'Market value*' }, { key: 'ownership_status', label: 'Ownership =100%' },
  ];
  return (
    <>
      <h1>Portfolios</h1>
      <p className="muted">Click a portfolio to see its holdings. *Market value uses <code>fn_portfolio_value()</code> (latest quote × quantity, in each security’s own currency).</p>
      <Alert>{error}</Alert><Loading loading={loading} />
      <Table rows={data} columns={columns} onRowClick={setSelected} />
      {selected && (<><h2>Holdings of {selected.portfolio_name}</h2><Alert>{holdings.error}</Alert><Table rows={holdings.data} empty="No holdings." /></>)}
    </>
  );
}
