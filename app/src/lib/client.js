'use client';
// Browser-side helpers: fetch wrapper and small hooks.
import { useCallback, useEffect, useState } from 'react';

export async function api(url, { method = 'GET', body } = {}) {
  const res = await fetch(url, {
    method, headers: { 'content-type': 'application/json' }, body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try { data = await res.json(); } catch { /* no JSON body */ }
  if (!res.ok) {
    if (res.status === 401 && typeof window !== 'undefined' && window.location.pathname !== '/login') window.location.href = '/login';
    const err = new Error(data?.error || `Request failed (${res.status})`);
    err.status = res.status;
    throw err;
  }
  return data;
}

// useApi(url) -> { data, error, loading, reload }.  Pass null to skip.
export function useApi(url) {
  const [state, setState] = useState({ data: null, error: null, loading: !!url });
  const load = useCallback(async () => {
    if (!url) { setState({ data: null, error: null, loading: false }); return; }
    setState((s) => ({ ...s, loading: true, error: null }));
    try { setState({ data: await api(url), error: null, loading: false }); }
    catch (e) { setState({ data: null, error: e.message, loading: false }); }
  }, [url]);
  useEffect(() => { load(); }, [load]);
  return { ...state, reload: load };
}

export const useMe = () => useApi('/api/auth/me').data;
