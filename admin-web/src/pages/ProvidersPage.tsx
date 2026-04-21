import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import { DataTable } from '../components/DataTable';
import { Spinner } from '../components/Spinner';

type Row = Record<string, unknown> & { id: number };

export default function ProvidersPage() {
  const [rows, setRows] = useState<Row[]>([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [verification_status, setVerificationStatus] = useState('');
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    api
      .get('/api/admin/providers/', {
        params: { page, search, verification_status: verification_status || undefined },
      })
      .then((r) => {
        setRows(r.data.results);
        setCount(r.data.count);
      })
      .catch((e) => setErr(e?.response?.data?.detail || 'Failed'))
      .finally(() => setLoading(false));
  }, [page, search, verification_status]);

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Providers</h1>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 16 }}>
        <input
          placeholder="Search"
          value={search}
          onChange={(e) => {
            setPage(1);
            setSearch(e.target.value);
          }}
        />
        <select
          value={verification_status}
          onChange={(e) => {
            setPage(1);
            setVerificationStatus(e.target.value);
          }}
        >
          <option value="">All verification states</option>
          <option value="unverified">Unverified</option>
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
        </select>
      </div>
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
                render: (row) => <Link to={`/app/providers/${row.id}`}>{String(row.email)}</Link>,
              },
              { key: 'verification_status', header: 'Verification' },
              { key: 'is_verified', header: 'Verified' },
              { key: 'submitted_at', header: 'Submitted' },
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
