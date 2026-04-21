import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import { Spinner } from '../components/Spinner';

type Pending = {
  pending_booking_requests: Record<string, unknown>[];
  pending_provider_verifications: Record<string, unknown>[];
  pending_service_category_requests?: Record<string, unknown>[];
};

type ServiceRequestRow = {
  id: number;
  customer_id: number | null;
  customer_email: string | null;
  customer_username: string | null;
  requested_title: string;
  description: string | null;
  address: string | null;
  image_urls: string[];
  status: 'pending' | 'approved' | 'rejected';
  created_at: string | null;
  storage: string;
};

export default function PendingPage() {
  const [data, setData] = useState<Pending | null>(null);
  const [serviceRows, setServiceRows] = useState<ServiceRequestRow[]>([]);
  const [reviewBusyId, setReviewBusyId] = useState<number | null>(null);
  const [err, setErr] = useState<string | null>(null);

  function loadServiceRequests() {
    api
      .get<{ count: number; results: ServiceRequestRow[] }>('/api/admin/service-category-requests/', {
        params: { status: 'pending' },
      })
      .then((r) => setServiceRows(r.data.results || []))
      .catch((e) => setErr(e?.response?.data?.detail || 'Failed'));
  }

  useEffect(() => {
    api
      .get<Pending>('/api/admin/pending/')
      .then((r) => setData(r.data))
      .catch((e) => setErr(e?.response?.data?.detail || 'Failed'));
    loadServiceRequests();
  }, []);

  async function reviewRequest(id: number, status: 'approved' | 'rejected') {
    const note =
      status === 'rejected'
        ? window.prompt('Add optional rejection note for user (optional):', '') || ''
        : window.prompt('Add optional approval note for user (optional):', '') || '';
    try {
      setReviewBusyId(id);
      await api.patch(`/api/admin/service-category-requests/${id}/review/`, {
        status,
        admin_note: note,
      });
      setServiceRows((prev) => prev.filter((r) => r.id !== id));
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? (e as { response?: { data?: { detail?: string } } }).response?.data?.detail
          : null;
      setErr(msg || 'Failed to review request');
    } finally {
      setReviewBusyId(null);
    }
  }

  if (err) return <p style={{ color: '#f87171' }}>{err}</p>;
  if (!data) return <Spinner />;

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Pending requests</h1>
      <div className="hs-card" style={{ marginBottom: 20 }}>
        <h2 style={{ marginTop: 0, fontSize: '1.05rem' }}>Booking requests</h2>
        {data.pending_booking_requests.length === 0 ? (
          <p className="hs-muted">None.</p>
        ) : (
          <ul style={{ margin: 0, paddingLeft: 20 }}>
            {data.pending_booking_requests.map((b) => (
              <li key={String(b.id)} style={{ marginBottom: 8 }}>
                <Link to={`/app/bookings/${b.id}`}>Booking #{String(b.id)}</Link>
                <span className="hs-muted"> — {String(b.status)} · {String(b.customer_email)}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
      <div className="hs-card">
        <h2 style={{ marginTop: 0, fontSize: '1.05rem' }}>Provider verification queue</h2>
        {data.pending_provider_verifications.length === 0 ? (
          <p className="hs-muted">None.</p>
        ) : (
          <ul style={{ margin: 0, paddingLeft: 20 }}>
            {data.pending_provider_verifications.map((u) => (
              <li key={String(u.id)} style={{ marginBottom: 8 }}>
                <Link to={`/app/providers/${u.id}`}>{String(u.email)}</Link>
                <span className="hs-muted"> · submitted {String(u.submitted_at || '—')}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
      <div className="hs-card" style={{ marginTop: 20 }}>
        <h2 style={{ marginTop: 0, fontSize: '1.05rem' }}>New service requests from users</h2>
        {serviceRows.length === 0 ? (
          <p className="hs-muted">None.</p>
        ) : (
          <ul style={{ margin: 0, paddingLeft: 20 }}>
            {serviceRows.map((r) => (
              <li key={r.id} style={{ marginBottom: 14 }}>
                <div>
                  <strong>{r.requested_title}</strong>
                  <span className="hs-muted">
                    {' '}
                    by {r.customer_username || r.customer_email || `User ${r.customer_id || ''}`}
                  </span>
                </div>
                {r.description ? <div className="hs-muted">{r.description}</div> : null}
                {r.address ? <div className="hs-muted">Address: {r.address}</div> : null}
                {r.image_urls?.length ? (
                  <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 8 }}>
                    {r.image_urls.map((url, idx) => (
                      <a key={`${r.id}-${idx}`} href={url} target="_blank" rel="noreferrer">
                        Photo {idx + 1}
                      </a>
                    ))}
                  </div>
                ) : null}
                <div className="hs-muted" style={{ marginTop: 4 }}>
                  {r.created_at || '—'} {r.storage === 'local_fallback' ? '· local fallback' : ''}
                </div>
                <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                  <button
                    type="button"
                    className="hs-btn hs-btn-primary"
                    disabled={reviewBusyId === r.id}
                    onClick={() => reviewRequest(r.id, 'approved')}
                  >
                    Approve
                  </button>
                  <button
                    type="button"
                    className="hs-btn hs-btn-danger"
                    disabled={reviewBusyId === r.id}
                    onClick={() => reviewRequest(r.id, 'rejected')}
                  >
                    Reject
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
