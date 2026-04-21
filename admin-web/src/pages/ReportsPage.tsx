import { useEffect, useState } from 'react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
  Legend,
} from 'recharts';
import { api } from '../api/client';
import { Spinner } from '../components/Spinner';

type Charts = {
  bookings_by_month: { month: string; bookings: number }[];
  revenue_by_month: { month: string; revenue: string }[];
  provider_verification: { status: string; count: number }[];
  booking_status_distribution: { status: string; count: number }[];
};

export default function ReportsPage() {
  const [data, setData] = useState<Charts | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    api
      .get<Charts>('/api/admin/reports/charts/', { params: { months: 12 } })
      .then((r) => setData(r.data))
      .catch((e) => setErr(e?.response?.data?.detail || 'Failed'));
  }, []);

  if (err) return <p style={{ color: '#f87171' }}>{err}</p>;
  if (!data) return <Spinner />;

  const revData = data.revenue_by_month.map((x) => ({
    month: x.month,
    revenue: Number(x.revenue),
  }));

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      <h1 style={{ marginTop: 0 }}>Reports & analytics</h1>
      <div className="hs-card">
        <h3 style={{ marginTop: 0 }}>Bookings by month</h3>
        <div style={{ width: '100%', height: 300 }}>
          <ResponsiveContainer>
            <BarChart data={data.bookings_by_month}>
              <CartesianGrid strokeDasharray="3 3" stroke="#27272a" />
              <XAxis dataKey="month" tick={{ fill: '#71717a', fontSize: 11 }} />
              <YAxis tick={{ fill: '#71717a', fontSize: 11 }} allowDecimals={false} />
              <Tooltip contentStyle={{ background: '#18181b', border: '1px solid #27272a' }} />
              <Bar dataKey="bookings" fill="#10b981" name="Bookings" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
      <div className="hs-card">
        <h3 style={{ marginTop: 0 }}>Revenue by month (completed-like payments)</h3>
        <div style={{ width: '100%', height: 300 }}>
          <ResponsiveContainer>
            <BarChart data={revData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#27272a" />
              <XAxis dataKey="month" tick={{ fill: '#71717a', fontSize: 11 }} />
              <YAxis tick={{ fill: '#71717a', fontSize: 11 }} />
              <Tooltip contentStyle={{ background: '#18181b', border: '1px solid #27272a' }} />
              <Bar dataKey="revenue" fill="#3b82f6" name="Revenue" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
        <div className="hs-card">
          <h3 style={{ marginTop: 0 }}>Provider verification (users)</h3>
          <div style={{ width: '100%', height: 260 }}>
            <ResponsiveContainer>
              <BarChart data={data.provider_verification} layout="vertical">
                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" />
                <XAxis type="number" allowDecimals={false} tick={{ fill: '#71717a', fontSize: 11 }} />
                <YAxis type="category" dataKey="status" width={100} tick={{ fill: '#a1a1aa', fontSize: 11 }} />
                <Tooltip contentStyle={{ background: '#18181b', border: '1px solid #27272a' }} />
                <Legend />
                <Bar dataKey="count" fill="#a855f7" name="Providers" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
        <div className="hs-card">
          <h3 style={{ marginTop: 0 }}>Booking status distribution</h3>
          <div style={{ width: '100%', height: 260 }}>
            <ResponsiveContainer>
              <BarChart data={data.booking_status_distribution}>
                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" />
                <XAxis dataKey="status" tick={{ fill: '#71717a', fontSize: 10 }} interval={0} angle={-25} textAnchor="end" height={70} />
                <YAxis tick={{ fill: '#71717a', fontSize: 11 }} allowDecimals={false} />
                <Tooltip contentStyle={{ background: '#18181b', border: '1px solid #27272a' }} />
                <Bar dataKey="count" fill="#eab308" name="Bookings" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
}
