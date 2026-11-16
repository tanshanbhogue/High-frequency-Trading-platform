'use client';
// Small shared UI pieces.

// "75.0000" -> "75", "1651.3000" -> "1651.3"
export function fmt(v) {
  if (v === null || v === undefined || v === '') return '–';
  if (typeof v === 'object') return JSON.stringify(v);
  if (typeof v === 'boolean') return v ? 'yes' : 'no';
  if (typeof v === 'string' && /^-?\d+\.\d+$/.test(v)) return v.replace(/(\.\d*?[1-9])0+$|\.0+$/, '$1');
  return String(v);
}

const isNumeric = (v) => (typeof v === 'number') || (typeof v === 'string' && /^-?\d+(\.\d+)?$/.test(v));
const STATUS = /^[A-Z_]{2,20}$/;

export function Badge({ children }) {
  return <span className={`badge b-${children}`}>{children}</span>;
}

export function Alert({ kind = 'error', children }) {
  if (!children) return null;
  return <div className={`alert ${kind}`}>{children}</div>;
}

export function Table({ rows, columns, empty = 'No rows.', onRowClick }) {
  if (!rows) return null;
  if (!rows.length) return <p className="muted">{empty}</p>;
  const cols = columns || Object.keys(rows[0]).map((k) => ({ key: k, label: k.replace(/_/g, ' ') }));
  return (
    <div className="table-wrap">
      <table>
        <thead><tr>{cols.map((c) => <th key={c.key}>{c.label}</th>)}</tr></thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i} className={onRowClick ? 'click' : ''} onClick={onRowClick ? () => onRowClick(r) : undefined}>
              {cols.map((c) => {
                const v = r[c.key];
                if (c.render) return <td key={c.key}>{c.render(r)}</td>;
                if (typeof v === 'string' && STATUS.test(v) && /status|action|state/i.test(c.key)) return <td key={c.key}><Badge>{v}</Badge></td>;
                return <td key={c.key} className={isNumeric(v) ? 'num' : ''}>{fmt(v)}</td>;
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function Loading({ loading }) {
  return loading ? <p className="muted">Loading…</p> : null;
}
