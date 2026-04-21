export function Spinner({ label }: { label?: string }) {
  return (
    <div className="hs-muted" style={{ padding: '2rem', textAlign: 'center' }}>
      {label ?? 'Loading…'}
    </div>
  );
}
