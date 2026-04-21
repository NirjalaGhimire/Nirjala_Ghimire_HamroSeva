import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../api/client';
import { Spinner } from '../components/Spinner';
import { HomeLink } from '../layout/AdminLayout';

const STATUSES = [
  'pending',
  'quoted',
  'awaiting_payment',
  'confirmed',
  'paid',
  'completed',
  'cancelled',
  'rejected',
  'cancel_req',
  'refund_pending',
  'refund_p_approved',
  'refund_p_rejected',
  'refunded',
];

export default function BookingDetailPage() {
  const { id } = useParams();
  const [data, setData] = useState<Record<string, unknown> | null>(null);
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  function load() {
    if (!id) return;
    return api.get(`/api/admin/bookings/${id}/`).then((r) => {
      setData(r.data);
      setStatus(String(r.data.status || ''));
    });
  }

  useEffect(() => {
    if (!id) return;
    load()
      .catch((e) => setErr(e?.response?.data?.detail || 'Not found'))
      .finally(() => setLoading(false));
  }, [id]);

  async function saveStatus() {
    if (!id) return;
    setMsg(null);
    try {
      await api.patch(`/api/admin/bookings/${id}/`, { status });
      setMsg('Status updated in Supabase; sync may take a moment.');
      await load();
    } catch (e: unknown) {
      const d =
        e && typeof e === 'object' && 'response' in e
          ? (e as { response?: { data?: { detail?: string } } }).response?.data?.detail
          : null;
      setMsg(d || 'Update failed');
    }
  }

  if (loading) return <Spinner />;
  if (err || !data) return <p style={{ color: '#f87171' }}>{err}</p>;

  const cur = String(data.status || '');
  const statusOptions = Array.from(new Set([...STATUSES, cur].filter(Boolean)));

  return (
    <div>
      <HomeLink />
      <h1 style={{ marginTop: 12 }}>Booking #{id}</h1>
      <div className="hs-card" style={{ marginBottom: 16 }}>
        <pre style={{ margin: 0, whiteSpace: 'pre-wrap', fontSize: '0.85rem' }}>
          {JSON.stringify(data, null, 2)}
        </pre>
      </div>
      <div className="hs-card" style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
        <label className="hs-muted" style={{ fontSize: '0.85rem' }}>
          Set status (admin)
          <select value={status} onChange={(e) => setStatus(e.target.value)} style={{ marginLeft: 8 }}>
            {statusOptions.map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        </label>
        <button type="button" className="hs-btn hs-btn-primary" onClick={saveStatus}>
          Save
        </button>
        {msg && <span className="hs-muted">{msg}</span>}
      </div>
    </div>
  );
}
