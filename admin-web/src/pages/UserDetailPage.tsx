import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api } from '../api/client';
import { Spinner } from '../components/Spinner';
import { HomeLink } from '../layout/AdminLayout';

type U = Record<string, unknown>;

export default function UserDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [user, setUser] = useState<U | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!id) return;
    api
      .get(`/api/admin/users/${id}/`)
      .then((r) => setUser(r.data))
      .catch((e) => setErr(e?.response?.data?.detail || 'Not found'))
      .finally(() => setLoading(false));
  }, [id]);

  async function setActive(active: boolean) {
    if (!id) return;
    await api.patch(`/api/admin/users/${id}/`, { is_active: active });
    setUser((u) => (u ? { ...u, is_active: active } : u));
  }

  async function deactivateAccount() {
    if (!id || !confirm('Deactivate this user? They will not be able to sign in.')) return;
    await api.delete(`/api/admin/users/${id}/`);
    navigate('/app/users');
  }

  if (loading) return <Spinner />;
  if (err || !user) return <p style={{ color: '#f87171' }}>{err}</p>;

  return (
    <div>
      <HomeLink />
      <h1 style={{ marginTop: 12 }}>User #{id}</h1>
      <div className="hs-card" style={{ maxWidth: 520 }}>
        <pre style={{ margin: 0, whiteSpace: 'pre-wrap', fontSize: '0.85rem' }}>
          {JSON.stringify(user, null, 2)}
        </pre>
      </div>
      <div style={{ marginTop: 16, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <button type="button" className="hs-btn hs-btn-primary" onClick={() => setActive(true)}>
          Activate
        </button>
        <button type="button" className="hs-btn hs-btn-ghost" onClick={() => setActive(false)}>
          Deactivate
        </button>
        <button type="button" className="hs-btn hs-btn-danger" onClick={deactivateAccount}>
          Deactivate (same as delete)
        </button>
      </div>
    </div>
  );
}
