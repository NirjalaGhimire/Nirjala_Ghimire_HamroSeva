import { useEffect, useState } from 'react';
import { api } from '../api/client';
import { DataTable } from '../components/DataTable';
import { Spinner } from '../components/Spinner';

type Row = Record<string, unknown> & { id: number };

export default function PaymentsPage() {
  const [rows, setRows] = useState<Row[]>([]);
  const [count, setCount] = useState(0);
  const [revenue, setRevenue] = useState<string>('');
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [from_date, setFromDate] = useState('');
  const [to_date, setToDate] = useState('');
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    api
      .get('/api/admin/payments/', {
        params: {
          page,
          search,
          status: status || undefined,
          from_date: from_date || undefined,
          to_date: to_date || undefined,
        },
      })
      .then((r) => {
        setRows(r.data.results);
        setCount(r.data.count);
        setRevenue(r.data.revenue_summary?.completed_total ?? '');
      })
      .catch((e) => setErr(e?.response?.data?.detail || 'Failed'))
      .finally(() => setLoading(false));
  }, [page, search, status, from_date, to_date]);

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Payments</h1>
      <p className="hs-muted">
        Completed revenue (all matching filters on server aggregate): <strong>{revenue || '—'}</strong>
      </p>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 16 }}>
        <input
          placeholder="Search"
          value={search}
          onChange={(e) => {
            setPage(1);
            setSearch(e.target.value);
          }}
        />
        <select value={status} onChange={(e) => { setPage(1); setStatus(e.target.value); }}>
          <option value="">All statuses</option>
          <option value="pending">pending</option>
          <option value="completed">completed</option>
          <option value="failed">failed</option>
          <option value="refund_pending">refund_pending</option>
          <option value="refunded">refunded</option>
        </select>
        <input type="date" value={from_date} onChange={(e) => { setPage(1); setFromDate(e.target.value); }} />
        <input type="date" value={to_date} onChange={(e) => { setPage(1); setToDate(e.target.value); }} />
      </div>
      {err && <p style={{ color: '#f87171' }}>{err}</p>}
      {loading ? (
        <Spinner />
      ) : (
        <>
          <DataTable<Row>
            columns={[
              { key: 'id', header: 'ID' },
              { key: 'booking_id', header: 'Booking' },
              { key: 'customer_email', header: 'Customer' },
              { key: 'provider_email', header: 'Provider' },
              { key: 'amount', header: 'Amount' },
              { key: 'payment_method', header: 'Method' },
              { key: 'status', header: 'Status' },
              { key: 'transaction_id', header: 'Txn' },
              { key: 'created_at', header: 'Date' },
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
