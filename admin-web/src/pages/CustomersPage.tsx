import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import { DataTable } from '../components/DataTable';
import { Spinner } from '../components/Spinner';

type Row = Record<string, unknown> & { id: number };

export default function CustomersPage() {
  const [rows, setRows] = useState<Row[]>([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    api
      .get('/api/admin/customers/', { params: { page, search } })
      .then((r) => {
        setRows(r.data.results);
        setCount(r.data.count);
      })
      .catch((e) => setErr(e?.response?.data?.detail || 'Failed'))
      .finally(() => setLoading(false));
  }, [page, search]);

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Customers</h1>
      <input
        placeholder="Search"
        value={search}
        onChange={(e) => {
          setPage(1);
          setSearch(e.target.value);
        }}
        style={{ marginBottom: 16 }}
      />
      {err && <p style={{ color: '#f87171' }}>{err}</p>}
      {loading ? (
        <Spinner />
      ) : (
        <>
          <DataTable<Row>
            columns={[
              { key: 'id', header: 'ID' },
              {
                key: 'email',
                header: 'Email',
                render: (row) => <Link to={`/app/customers/${row.id}`}>{String(row.email)}</Link>,
              },
              { key: 'username', header: 'Username' },
              { key: 'phone', header: 'Phone' },
              { key: 'is_active', header: 'Active', render: (r) => (r.is_active ? 'Yes' : 'No') },
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
