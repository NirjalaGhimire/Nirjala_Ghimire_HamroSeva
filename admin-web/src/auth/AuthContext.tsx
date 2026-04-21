import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api, clearTokens, loadTokens, saveTokens, setAuthHeader } from '../api/client';

type User = {
  id: number;
  email: string;
  username: string;
  role: string;
};

type AuthState = {
  user: User | null;
  access: string | null;
  loading: boolean;
  error: string | null;
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
};

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [access, setAccess] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const t = loadTokens();
    if (t?.access) {
      setAuthHeader(t.access);
      setAccess(t.access);
      api
        .get('/api/auth/me/')
        .then((res) => setUser(res.data))
        .catch(() => {
          clearTokens();
          setAccess(null);
        })
        .finally(() => setLoading(false));
    } else {
      setLoading(false);
    }
  }, []);

  const login = useCallback(async (username: string, password: string) => {
    setError(null);
    const { data } = await api.post('/api/auth/login/', { username, password });
    const u = data.user as User;
    if ((u.role || '').toLowerCase() !== 'admin') {
      const msg = 'Only admin accounts can use this panel.';
      setError(msg);
      throw new Error(msg);
    }
    const tokens = data.tokens as { access: string; refresh: string };
    saveTokens(tokens.access, tokens.refresh);
    setAuthHeader(tokens.access);
    setAccess(tokens.access);
    setUser(u);
  }, []);

  const logout = useCallback(() => {
    clearTokens();
    setAccess(null);
    setUser(null);
  }, []);

  const value = useMemo(
    () => ({
      user,
      access,
      loading,
      error,
      login,
      logout,
    }),
    [user, access, loading, error, login, logout]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth outside AuthProvider');
  return ctx;
}
