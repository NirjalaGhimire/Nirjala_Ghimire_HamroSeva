import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import { DataTable } from '../components/DataTable';
import { Spinner } from '../components/Spinner';

type Row = Record<string, unknown> & { id: number };

export default function BookingsPage() {
  const [rows, setRows] = useState<Row[]>([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    api
      .get('/api/admin/bookings/', { params: { page, search, status: status || undefined } })
      .then((r) => {
        setRows(r.data.results);
        setCount(r.data.count);
      })
      .catch((e) => setErr(e?.response?.data?.detail || 'Failed'))
      .finally(() => setLoading(false));
  }, [page, search, status]);

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Bookings</h1>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 16 }}>
        <input
          placeholder="Search customer, service, id"
          value={search}
          onChange={(e) => {
            setPage(1);
            setSearch(e.target.value);
          }}
        />
        <select value={status} onChange={(e) => { setPage(1); setStatus(e.target.value); }}>
          <option value="">All statuses</option>
          <option value="pending">pending</option>
          <option value="quoted">quoted</option>
          <option value="awaiting_payment">awaiting_payment</option>
          <option value="confirmed">confirmed</option>
          <option value="paid">paid</option>
          <option value="completed">completed</option>
          <option value="cancelled">cancelled</option>
          <option value="rejected">rejected</option>
          <option value="cancel_req">cancel_req</option>
        </select>
      </div>
      {err && <p style={{ color: '#f87171' }}>{err}</p>}
      {loading ? (
        <Spinner />
      ) : (
        <>
          <DataTable<Row>
            columns={[
              {
                key: 'id',
                header: 'ID',
                render: (row) => <Link to={`/app/bookings/${row.id}`}>#{row.id}</Link>,
              },
              { key: 'status', header: 'Status' },
              { key: 'customer_email', header: 'Customer' },
              { key: 'provider_email', header: 'Provider' },
              { key: 'service_title', header: 'Service' },
              { key: 'booking_date', header: 'Date' },
              { key: 'payment_status', header: 'Payment' },
              { key: 'total_amount', header: 'Amount' },
            ]}
            rows={rows}
            rowKey={(r) => r.id}
          />
          <div className="hs-muted" style={{ marginTop: 12, display: 'flex', gap: 12, alignItems: 'center' }}>
            <span>
              Page {page} · {count} total
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
        </>
      )}
    </div>
  );
}
