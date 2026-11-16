'use client';
import { useState } from 'react';
import { api } from '@/lib/client';
import { Alert } from '@/components/ui';

export default function LoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(e) {
    e.preventDefault();
    setBusy(true); setError('');
    try {
      await api('/api/auth/login', { method: 'POST', body: { username, password } });
      window.location.href = '/dashboard';     // full reload so the navbar picks up the session
    } catch (err) { setError(err.message); setBusy(false); }
  }

  return (
    <div className="login-box card">
      <h1>HFT Platform</h1>
      <p className="muted">Sign in to continue</p>
      <form className="stack" onSubmit={submit}>
        <label>Username<input value={username} onChange={(e) => setUsername(e.target.value)} autoFocus autoComplete="username" /></label>
        <label>Password<input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" /></label>
        <Alert>{error}</Alert>
        <button disabled={busy || !username || !password}>{busy ? 'Signing in…' : 'Sign in'}</button>
      </form>
      <div className="hint">Demo logins: <b>admin</b> / Admin@123 · <b>aarav</b> or <b>rohan</b> / Trader@123 · <b>auditor</b> / Auditor@123</div>
    </div>
  );
}
