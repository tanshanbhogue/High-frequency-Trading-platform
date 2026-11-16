'use client';
import { useState } from 'react';
import { api, useApi, useMe } from '@/lib/client';
import { Alert, Badge, Loading, Table } from '@/components/ui';

export default function UsersPage() {
  const me = useMe();
  const users = useApi('/api/admin/users');
  const traders = useApi('/api/reference?type=traders').data;
  const [f, setF] = useState({ username: '', password: '', role: 'TRADER', trader_id: '' });
  const [msg, setMsg] = useState({ kind: 'ok', text: '' });

  async function act(fn, text) {
    setMsg({ kind: 'ok', text: '' });
    try { await fn(); setMsg({ kind: 'ok', text }); users.reload(); } catch (e) { setMsg({ kind: 'error', text: e.message }); }
  }
  const columns = [
    { key: 'user_id', label: 'ID' }, { key: 'username', label: 'Username' },
    { key: 'role', label: 'Role', render: (u) => (
      <select value={u.role} style={{ width: 'auto' }} onChange={(e) => act(() => api('/api/admin/users', { method: 'PATCH', body: { user_id: u.user_id, role: e.target.value } }), 'Role changed.')}>
        <option>ADMIN</option><option>TRADER</option><option>AUDITOR</option>
      </select>) },
    { key: 'trader_id', label: 'Trader id' },
    { key: 'is_active', label: 'Active', render: (u) => <Badge>{u.is_active ? 'ACTIVE' : 'SUSPENDED'}</Badge> },
    { key: 'last_login', label: 'Last login (UTC)' },
    { key: 'a', label: '', render: (u) => (
      <span style={{ display: 'flex', gap: 6 }}>
        <button className="small secondary" disabled={u.user_id === me?.userId} onClick={() => act(() => api('/api/admin/users', { method: 'PATCH', body: { user_id: u.user_id, is_active: !u.is_active } }), u.is_active ? 'User disabled.' : 'User enabled.')}>{u.is_active ? 'Disable' : 'Enable'}</button>
        <button className="small secondary" onClick={() => { const p = prompt(`New password for ${u.username} (min 6 characters):`); if (p) act(() => api('/api/admin/users', { method: 'PATCH', body: { user_id: u.user_id, password: p } }), 'Password changed.'); }}>Reset password</button>
      </span>) },
  ];
  return (
    <>
      <h1>Users</h1>
      <p className="muted">Only the admin database account can read this table. Passwords are stored as bcrypt hashes.</p>
      {msg.text && <Alert kind={msg.kind}>{msg.text}</Alert>}
      <Alert>{users.error}</Alert><Loading loading={users.loading} />
      <Table rows={users.data} columns={columns} />
      <h2>Create a user</h2>
      <div className="card" style={{ maxWidth: 720 }}>
        <form className="stack" onSubmit={(e) => { e.preventDefault(); act(() => api('/api/admin/users', { method: 'POST', body: f }), 'User created.').then(() => setF({ ...f, username: '', password: '' })); }}>
          <div className="row">
            <label>Username<input value={f.username} onChange={(e) => setF({ ...f, username: e.target.value })} required /></label>
            <label>Password<input type="password" value={f.password} onChange={(e) => setF({ ...f, password: e.target.value })} required /></label>
          </div>
          <div className="row">
            <label>Role<select value={f.role} onChange={(e) => setF({ ...f, role: e.target.value })}><option>TRADER</option><option>AUDITOR</option><option>ADMIN</option></select></label>
            <label>Linked trader (TRADER role only)
              <select value={f.trader_id} onChange={(e) => setF({ ...f, trader_id: e.target.value })} disabled={f.role !== 'TRADER'}><option value="">Choose…</option>{traders?.map((t) => <option key={t.trader_id} value={t.trader_id}>{t.full_name}</option>)}</select>
            </label>
          </div>
          <div><button>Create user</button></div>
        </form>
      </div>
    </>
  );
}
