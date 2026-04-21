import { FormEvent, useState } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

export default function LoginPage() {
  const { login, user, loading, error, access } = useAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [localError, setLocalError] = useState<string | null>(null);
  const navigate = useNavigate();

  if (!loading && access && user?.role === 'admin') {
    return <Navigate to="/app/dashboard" replace />;
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setLocalError(null);
    try {
      await login(username, password);
      navigate('/app/dashboard');
    } catch (err: unknown) {
      const msg =
        err && typeof err === 'object' && 'response' in err
          ? String((err as { response?: { data?: { message?: string } } }).response?.data?.message)
          : 'Login failed';
      setLocalError(msg || 'Login failed');
    }
  }

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 24,
      }}
    >
      <div className="hs-card" style={{ width: '100%', maxWidth: 400 }}>
        <h1 style={{ marginTop: 0, fontSize: '1.25rem' }}>Hamro Sewa Admin</h1>
        <p className="hs-muted">Sign in with an admin account (role: admin).</p>
        <form onSubmit={onSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <label>
            <span className="hs-muted" style={{ display: 'block', marginBottom: 4, fontSize: '0.8rem' }}>
              Email or username
            </span>
            <input
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              autoComplete="username"
              style={{ width: '100%' }}
              required
            />
          </label>
          <label>
            <span className="hs-muted" style={{ display: 'block', marginBottom: 4, fontSize: '0.8rem' }}>
              Password
            </span>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              style={{ width: '100%' }}
              required
            />
          </label>
          {(error || localError) && (
            <p style={{ color: '#f87171', margin: 0, fontSize: '0.875rem' }}>{error || localError}</p>
          )}
          <button type="submit" className="hs-btn hs-btn-primary" disabled={loading}>
            {loading ? 'Please wait…' : 'Sign in'}
          </button>
        </form>
      </div>
    </div>
  );
}
