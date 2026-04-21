import { FormEvent, useEffect, useState } from 'react';
import { api } from '../api/client';
import { DataTable } from '../components/DataTable';
import { Spinner } from '../components/Spinner';

type Row = Record<string, unknown> & { id: number };

export default function ServicesPage() {
  const [rows, setRows] = useState<Row[]>([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [category_id, setCategoryId] = useState('');
  const [provider_id, setProviderId] = useState('');
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [form, setForm] = useState({
    provider_id: '',
    category_id: '',
    title: '',
    description: '',
    price: '',
    duration_minutes: '60',
    location: '',
    status: 'active',
  });

  function reload() {
    setLoading(true);
    api
      .get('/api/admin/services/', {
        params: {
          page,
          search,
          category_id: category_id || undefined,
          provider_id: provider_id || undefined,
        },
      })
      .then((r) => {
        setRows(r.data.results);
        setCount(r.data.count);
      })
      .catch((e) => setErr(e?.response?.data?.detail || 'Failed'))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    reload();
  }, [page, search, category_id, provider_id]);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    setErr(null);
    try {
      await api.post('/api/admin/services/', {
        provider_id: Number(form.provider_id),
        category_id: Number(form.category_id),
        title: form.title,
        description: form.description,
        price: form.price,
        duration_minutes: Number(form.duration_minutes),
        location: form.location,
        status: form.status,
      });
      reload();
    } catch (e: unknown) {
      const d =
        e && typeof e === 'object' && 'response' in e
          ? (e as { response?: { data?: { detail?: string } } }).response?.data?.detail
          : null;
      setErr(d || 'Create failed');
    }
  }

  async function removeService(id: number) {
    if (!confirm(`Delete service #${id}?`)) return;
    await api.delete(`/api/admin/services/${id}/`);
    reload();
  }

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Services</h1>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 16 }}>
        <input
          placeholder="Search title/description"
          value={search}
          onChange={(e) => {
            setPage(1);
            setSearch(e.target.value);
          }}
        />
        <input
          placeholder="Filter category id"
          value={category_id}
          onChange={(e) => {
            setPage(1);
            setCategoryId(e.target.value);
          }}
          style={{ width: 140 }}
        />
        <input
          placeholder="Filter provider id"
          value={provider_id}
          onChange={(e) => {
            setPage(1);
            setProviderId(e.target.value);
          }}
          style={{ width: 140 }}
        />
      </div>
      {err && <p style={{ color: '#f87171' }}>{err}</p>}
      {loading ? (
        <Spinner />
      ) : (
        <>
          <DataTable<Row>
            columns={[
              { key: 'id', header: 'ID' },
              { key: 'title', header: 'Title' },
              { key: 'provider_email', header: 'Provider' },
              { key: 'category_name', header: 'Category' },
              { key: 'price', header: 'Price' },
              { key: 'status', header: 'Status' },
              {
                key: '_actions',
                header: '',
                render: (row) => (
                  <button type="button" className="hs-btn hs-btn-danger" onClick={() => removeService(row.id)}>
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

      <h2 style={{ fontSize: '1rem', marginTop: 32 }}>Add service (Supabase)</h2>
      <form className="hs-card" onSubmit={onCreate} style={{ display: 'grid', gap: 10, maxWidth: 480 }}>
        <input
          placeholder="Provider user id"
          value={form.provider_id}
          onChange={(e) => setForm((f) => ({ ...f, provider_id: e.target.value }))}
          required
        />
        <input
          placeholder="Category id"
          value={form.category_id}
          onChange={(e) => setForm((f) => ({ ...f, category_id: e.target.value }))}
          required
        />
        <input
          placeholder="Title"
          value={form.title}
          onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
          required
        />
        <textarea
          placeholder="Description"
          value={form.description}
          onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
          rows={3}
        />
        <input
          placeholder="Price"
          value={form.price}
          onChange={(e) => setForm((f) => ({ ...f, price: e.target.value }))}
          required
        />
        <input
          placeholder="Duration minutes"
          value={form.duration_minutes}
          onChange={(e) => setForm((f) => ({ ...f, duration_minutes: e.target.value }))}
        />
        <input
          placeholder="Location"
          value={form.location}
          onChange={(e) => setForm((f) => ({ ...f, location: e.target.value }))}
        />
        <button type="submit" className="hs-btn hs-btn-primary">
          Create
        </button>
      </form>
    </div>
  );
}
