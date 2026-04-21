import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../api/client';
import { Spinner } from '../components/Spinner';
import { HomeLink } from '../layout/AdminLayout';

type Detail = {
  user: Record<string, unknown>;
  verification_documents: Record<string, unknown>[];
  services: Record<string, unknown>[];
  recent_bookings: Record<string, unknown>[];
  recent_reviews: Record<string, unknown>[];
};

export default function ProviderDetailPage() {
  const { id } = useParams();
  const [data, setData] = useState<Detail | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [note, setNote] = useState('');

  useEffect(() => {
    if (!id) return;
    api
      .get(`/api/admin/providers/${id}/`)
      .then((r) => setData(r.data))
      .catch((e) => setErr(e?.response?.data?.detail || 'Not found'))
      .finally(() => setLoading(false));
  }, [id]);

  async function verify(action: 'approve' | 'reject') {
    if (!id) return;
    await api.post(`/api/admin/providers/${id}/verification/`, {
      action,
      rejection_reason: action === 'reject' ? note : undefined,
    });
    const r = await api.get(`/api/admin/providers/${id}/`);
    setData(r.data);
    setNote('');
  }

  if (loading) return <Spinner />;
  if (err || !data) return <p style={{ color: '#f87171' }}>{err}</p>;

  return (
    <div>
      <HomeLink />
      <h1 style={{ marginTop: 12 }}>Provider #{id}</h1>
      <div className="hs-card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginTop: 0 }}>Profile</h3>
        <pre style={{ margin: 0, whiteSpace: 'pre-wrap', fontSize: '0.85rem' }}>
          {JSON.stringify(data.user, null, 2)}
        </pre>
        <div style={{ marginTop: 12, display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
          <button type="button" className="hs-btn hs-btn-primary" onClick={() => verify('approve')}>
            Approve verification
          </button>
          <input
            placeholder="Rejection reason (if rejecting)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            style={{ flex: 1, minWidth: 200 }}
          />
          <button type="button" className="hs-btn hs-btn-danger" onClick={() => verify('reject')}>
            Reject
          </button>
        </div>
      </div>
      <div className="hs-card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginTop: 0 }}>Documents (Supabase)</h3>
        <pre style={{ margin: 0, whiteSpace: 'pre-wrap', fontSize: '0.8rem' }}>
          {JSON.stringify(data.verification_documents, null, 2)}
        </pre>
      </div>
      <div className="hs-card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginTop: 0 }}>Services</h3>
        <pre style={{ margin: 0, whiteSpace: 'pre-wrap', fontSize: '0.8rem' }}>
          {JSON.stringify(data.services, null, 2)}
        </pre>
      </div>
      <div className="hs-card">
        <h3 style={{ marginTop: 0 }}>Recent bookings & reviews</h3>
        <pre style={{ margin: 0, whiteSpace: 'pre-wrap', fontSize: '0.8rem' }}>
          {JSON.stringify({ bookings: data.recent_bookings, reviews: data.recent_reviews }, null, 2)}
        </pre>
      </div>
    </div>
  );
}
