import { FormEvent, useEffect, useState } from 'react';
import { api } from '../api/client';
import { Spinner } from '../components/Spinner';

type Row = Record<string, unknown>;

export default function NotificationsPage() {
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [user_id, setUserId] = useState('');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [booking_id, setBookingId] = useState('');

  function load() {
    setLoading(true);
    api
      .get('/api/admin/notifications/', { params: { limit: 150 } })
      .then((r) => setRows(r.data.results || []))
      .catch((e) => setErr(e?.response?.data?.detail || 'Failed'))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    load();
  }, []);

  async function send(e: FormEvent) {
    e.preventDefault();
    setErr(null);
    await api.post('/api/admin/notifications/', {
      user_id: Number(user_id),
      title,
      body,
      booking_id: booking_id ? Number(booking_id) : undefined,
    });
    setTitle('');
    setBody('');
    setBookingId('');
    load();
  }

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Notifications</h1>
      <p className="hs-muted">Listed from Supabase `seva_notification` (not necessarily in local SQLite).</p>
      <div className="hs-card" style={{ marginBottom: 20 }}>
        <h3 style={{ marginTop: 0 }}>Send manual notification</h3>
        <form onSubmit={send} style={{ display: 'grid', gap: 8, maxWidth: 420 }}>
          <input placeholder="User id" value={user_id} onChange={(e) => setUserId(e.target.value)} required />
          <input placeholder="Title" value={title} onChange={(e) => setTitle(e.target.value)} required />
          <textarea placeholder="Body" value={body} onChange={(e) => setBody(e.target.value)} rows={3} />
          <input placeholder="Booking id (optional)" value={booking_id} onChange={(e) => setBookingId(e.target.value)} />
          <button type="submit" className="hs-btn hs-btn-primary">
            Send
          </button>
        </form>
      </div>
      {loading ? (
        <Spinner />
      ) : (
        <div className="hs-card">
          <h3 style={{ marginTop: 0 }}>Recent</h3>
          {err && <p style={{ color: '#f87171' }}>{err}</p>}
          <ul style={{ margin: 0, paddingLeft: 18, fontSize: '0.875rem' }}>
            {rows.map((r) => (
              <li key={String(r.id)} style={{ marginBottom: 10 }}>
                <strong>{String(r.title)}</strong>
                <span className="hs-muted"> → user {String(r.user_id)}</span>
                <div className="hs-muted">{String(r.body || '')}</div>
                <div className="hs-muted" style={{ fontSize: '0.75rem' }}>
                  {String(r.created_at || '')}
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
