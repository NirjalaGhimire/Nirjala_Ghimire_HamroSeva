import { useEffect, useState } from 'react';
import { api } from '../api/client';
import { Spinner } from '../components/Spinner';

export default function SettingsPage() {
  const [data, setData] = useState<Record<string, unknown> | null>(null);
  useEffect(() => {
    api.get('/api/admin/settings/').then((r) => setData(r.data));
  }, []);

  if (!data) return <Spinner />;

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Settings</h1>
      <div className="hs-card">
        <pre style={{ margin: 0, whiteSpace: 'pre-wrap' }}>{JSON.stringify(data, null, 2)}</pre>
      </div>
    </div>
  );
}
