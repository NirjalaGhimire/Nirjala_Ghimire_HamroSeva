import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../api/client';
import { DataTable } from '../components/DataTable';
import { Spinner } from '../components/Spinner';
import { HomeLink } from '../layout/AdminLayout';

type Row = Record<string, unknown> & { id: number };

export default function CustomerDetailPage() {
  const { id } = useParams();
  const [customer, setCustomer] = useState<Record<string, unknown> | null>(null);
  const [rows, setRows] = useState<Row[]>([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!id) return;
    setLoading(true);
    api
      .get(`/api/admin/customers/${id}/`, { params: { page } })
      .then((r) => {
        setCustomer((r.data.customer as Record<string, unknown>) || null);
        setRows(r.data.results);
        setCount(r.data.count);
      })
      .catch((e) => setErr(e?.response?.data?.detail || 'Not found'))
      .finally(() => setLoading(false));
  }, [id, page]);

  if (loading) return <Spinner />;
  if (err) return <p style={{ color: '#f87171' }}>{err}</p>;

  return (
    <div>
      <HomeLink />
      <h1 style={{ marginTop: 12 }}>Customer #{id}</h1>
      {customer && (
        <div className="hs-card" style={{ marginBottom: 16 }}>
          <pre style={{ margin: 0, whiteSpace: 'pre-wrap', fontSize: '0.85rem' }}>
            {JSON.stringify(customer, null, 2)}
          </pre>
        </div>
      )}
      <h2 style={{ fontSize: '1rem' }}>Booking history</h2>
      <DataTable<Row>
        columns={[
          { key: 'id', header: 'Booking' },
          { key: 'status', header: 'Status' },
          { key: 'service_title', header: 'Service' },
          { key: 'provider_email', header: 'Provider' },
          { key: 'booking_date', header: 'Date' },
          { key: 'total_amount', header: 'Amount' },
        ]}
        rows={rows}
        rowKey={(r) => r.id}
        empty="No bookings yet."
      />
      <div className="hs-muted" style={{ marginTop: 12, display: 'flex', gap: 12, alignItems: 'center' }}>
        <span>
          Page {page} · {count} bookings
        </span>
        <button type="button" className="hs-btn hs-btn-ghost" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
          Previous
        </button>
        <button
          type="button"
          className="hs-btn hs-btn-ghost"
          disabled={page * 20 >= count}
          onClick={() => setPage((p) => p + 1)}
        >
          Next
        </button>
      </div>
    </div>
  );
}
