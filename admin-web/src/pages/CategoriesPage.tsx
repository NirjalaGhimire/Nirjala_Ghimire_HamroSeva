import { FormEvent, useEffect, useState } from 'react';
import { api } from '../api/client';
import { DataTable } from '../components/DataTable';
import { Spinner } from '../components/Spinner';

type Row = Record<string, unknown> & { id: number };

export default function CategoriesPage() {
  const [rows, setRows] = useState<Row[]>([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  function reload() {
    setLoading(true);
    api
      .get('/api/admin/categories/', { params: { page, search } })
      .then((r) => {
        setRows(r.data.results);
        setCount(r.data.count);
      })
      .catch((e) => setErr(e?.response?.data?.detail || 'Failed'))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    reload();
  }, [page, search]);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    await api.post('/api/admin/categories/', { name, description: '', icon: '' });
    setName('');
    reload();
  }

  async function remove(id: number) {
    if (!confirm(`Delete category #${id}?`)) return;
    await api.delete(`/api/admin/categories/${id}/`);
    reload();
  }

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Categories</h1>
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
              { key: 'name', header: 'Name' },
              { key: 'description', header: 'Description' },
              {
                key: '_actions',
                header: '',
                render: (row) => (
                  <button type="button" className="hs-btn hs-btn-danger" onClick={() => remove(row.id)}>
                    Delete
                  </button>
                ),
              },
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
      <h2 style={{ fontSize: '1rem', marginTop: 28 }}>Add category</h2>
      <form onSubmit={onCreate} className="hs-card" style={{ display: 'flex', gap: 8, maxWidth: 400 }}>
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Name" required />
        <button type="submit" className="hs-btn hs-btn-primary">
          Add
        </button>
      </form>
    </div>
  );
}
