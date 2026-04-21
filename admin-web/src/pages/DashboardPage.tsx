import { useEffect, useState } from 'react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
} from 'recharts';
import { api } from '../api/client';
import { Spinner } from '../components/Spinner';

type Overview = {
  stats: Record<string, string | number>;
  market_pulse: { score: number; completion_ratio: number; pending_bookings: number; total_bookings: number };
  trend_7d: { date: string; bookings: number; payments: number }[];
  pipeline: { status: string; count: number; percent: number }[];
  mix: { users: number; bookings: number; services: number };
  recent_actions: { type: string; id: number; summary: string; customer?: string; service?: string }[];
};

function StatCard({ label, value, hint }: { label: string; value: string | number; hint?: string }) {
  return (
    <div className="hs-card" style={{ minHeight: 100 }}>
      <div className="hs-muted" style={{ fontSize: '0.7rem', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
        {label}
      </div>
      <div style={{ fontSize: '1.5rem', fontWeight: 700, marginTop: 8 }}>{value}</div>
      {hint && (
        <div className="hs-muted" style={{ fontSize: '0.75rem', marginTop: 6 }}>
          {hint}
        </div>
      )}
    </div>
  );
}

export default function DashboardPage() {
  const [data, setData] = useState<Overview | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    api
      .get<Overview>('/api/admin/dashboard/')
      .then((r) => setData(r.data))
      .catch((e) => setErr(e?.response?.data?.detail || 'Failed to load dashboard'));
  }, []);

  if (err) return <p style={{ color: '#f87171' }}>{err}</p>;
  if (!data) return <Spinner />;

  const s = data.stats;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      <div>
        <h1 style={{ margin: '0 0 4px', fontSize: '1.35rem' }}>Dashboard</h1>
        <p className="hs-muted" style={{ margin: 0 }}>
          Live counts from your synced admin database (run sync if numbers look stale).
        </p>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))',
          gap: 12,
        }}
      >
        <StatCard label="Total users" value={s.total_users} />
        <StatCard label="Customers" value={s.total_customers} />
        <StatCard label="Providers" value={s.total_providers} />
        <StatCard label="Total bookings" value={s.total_bookings} />
        <StatCard label="Pending bookings" value={s.pending_bookings} />
        <StatCard label="Completed" value={s.completed_bookings} />
        <StatCard label="Cancelled / rejected" value={s.cancelled_bookings} />
        <StatCard label="Pending verifications" value={s.pending_verification_requests} />
        <StatCard label="Services" value={s.total_services} />
        <StatCard label="Categories" value={s.total_categories} />
        <StatCard label="Reviews" value={s.total_reviews} />
        <StatCard label="Payments (rows)" value={s.total_payments} />
        <StatCard label="Revenue (completed)" value={s.total_revenue} hint="Sum of completed-like payment amounts" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 16, alignItems: 'stretch' }}>
        <div className="hs-card">
          <h3 style={{ margin: '0 0 4px', fontSize: '1rem' }}>Bookings & payments (7 days)</h3>
          <p className="hs-muted" style={{ margin: '0 0 12px', fontSize: '0.8rem' }}>
            Last 90 days (daily): bookings by created date; payments by created date (fallback updated_at).
          </p>
          <div style={{ width: '100%', height: 280 }}>
            <ResponsiveContainer>
              <LineChart data={data.trend_7d}>
                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" />
                <XAxis dataKey="date" tick={{ fill: '#71717a', fontSize: 11 }} />
                <YAxis tick={{ fill: '#71717a', fontSize: 11 }} allowDecimals={false} />
                <Tooltip
                  contentStyle={{ background: '#18181b', border: '1px solid #27272a' }}
                  labelStyle={{ color: '#e4e4e7' }}
                />
                <Line type="monotone" dataKey="bookings" stroke="#10b981" strokeWidth={2} dot={false} name="Bookings" />
                <Line type="monotone" dataKey="payments" stroke="#3b82f6" strokeWidth={2} dot={false} name="Payments" />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
        <div className="hs-card">
          <h3 style={{ margin: '0 0 4px', fontSize: '1rem' }}>Market pulse</h3>
          <p className="hs-muted" style={{ margin: '0 0 12px', fontSize: '0.8rem' }}>
            Heuristic from completion rate vs pending queue (not a product tier).
          </p>
          <div style={{ fontSize: '2.5rem', fontWeight: 800, color: 'var(--hs-accent)' }}>
            {data.market_pulse.score}
            <span style={{ fontSize: '1rem', color: 'var(--hs-muted)' }}>/100</span>
          </div>
          <p className="hs-muted" style={{ fontSize: '0.8rem', marginTop: 12 }}>
            Completion ratio {Math.round(data.market_pulse.completion_ratio * 100)}% · Pending{' '}
            {data.market_pulse.pending_bookings} of {data.market_pulse.total_bookings} bookings
          </p>
        </div>
      </div>

      <div className="hs-card">
        <h3 style={{ margin: '0 0 12px', fontSize: '1rem' }}>Booking status mix</h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {data.pipeline.map((p) => (
            <div key={p.status}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem' }}>
                <span>{p.status || 'unknown'}</span>
                <span className="hs-muted">
                  {p.count} ({p.percent}%)
                </span>
              </div>
              <div
                style={{
                  height: 6,
                  borderRadius: 4,
                  background: '#27272a',
                  marginTop: 4,
                  overflow: 'hidden',
                }}
              >
                <div
                  style={{
                    width: `${Math.min(100, p.percent)}%`,
                    height: '100%',
                    background: 'var(--hs-accent)',
                    opacity: 0.85,
                  }}
                />
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="hs-card">
        <h3 style={{ margin: '0 0 12px', fontSize: '1rem' }}>Recent bookings</h3>
        <ul style={{ margin: 0, paddingLeft: 18, fontSize: '0.875rem' }}>
          {data.recent_actions.map((a) => (
            <li key={`${a.type}-${a.id}`} style={{ marginBottom: 6 }}>
              {a.summary}
              {a.customer && <span className="hs-muted"> · {a.customer}</span>}
              {a.service && <span className="hs-muted"> · {a.service}</span>}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
