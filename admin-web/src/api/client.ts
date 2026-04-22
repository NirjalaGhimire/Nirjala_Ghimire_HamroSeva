
import axios from 'axios';

const baseURL = import.meta.env.VITE_API_BASE || '';

export const api = axios.create({
  baseURL,
  headers: { 'Content-Type': 'application/json' },
});

export function setAuthHeader(access: string | null) {
  if (access) {
    api.defaults.headers.common.Authorization = `Bearer ${access}`;
  } else {
    delete api.defaults.headers.common.Authorization;
  }
}

const STORAGE_KEY = 'hamro_admin_tokens';

export function loadTokens(): { access: string; refresh: string } | null {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const o = JSON.parse(raw);
    if (o?.access && o?.refresh) return o;
  } catch {
    /* ignore */
  }
  return null;
}

export function saveTokens(access: string, refresh: string) {
  sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ access, refresh }));
}

export function clearTokens() {
  sessionStorage.removeItem(STORAGE_KEY);
  setAuthHeader(null);
}
