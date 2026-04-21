import { Link, NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

const nav = [
  { to: '/app/dashboard', label: 'Dashboard' },
  { to: '/app/users', label: 'Users' },
  { to: '/app/providers', label: 'Providers' },
  { to: '/app/customers', label: 'Customers' },
  { to: '/app/bookings', label: 'Bookings' },
  { to: '/app/pending', label: 'Pending requests' },
  { to: '/app/services', label: 'Services' },
  { to: '/app/categories', label: 'Categories' },
  { to: '/app/payments', label: 'Payments' },
  { to: '/app/reviews', label: 'Reviews' },
  { to: '/app/refunds', label: 'Refunds' },
  { to: '/app/notifications', label: 'Notifications' },
  { to: '/app/reports', label: 'Reports' },
  { to: '/app/settings', label: 'Settings' },
];

export function AdminLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  return (
    <div style={{ display: 'flex', minHeight: '100vh' }}>
      <aside
        style={{
          width: 220,
          flexShrink: 0,
          borderRight: '1px solid var(--hs-border)',
          padding: '1rem 0.75rem',
          background: '#0c0c0e',
        }}
      >
        <div style={{ padding: '0 0.75rem 1rem', fontWeight: 700, fontSize: '1.05rem' }}>
          Hamro Sewa
        </div>
        <nav style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          {nav.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              style={({ isActive }) => ({
                padding: '0.45rem 0.65rem',
                borderRadius: 8,
                color: isActive ? '#022c22' : 'var(--hs-muted)',
                background: isActive ? 'var(--hs-accent)' : 'transparent',
                fontWeight: isActive ? 600 : 400,
                fontSize: '0.875rem',
                textDecoration: 'none',
              })}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
      </aside>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        <header
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0.75rem 1.25rem',
            borderBottom: '1px solid var(--hs-border)',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <span className="hs-muted" style={{ fontSize: '0.8rem' }}>
            Signed in as <strong style={{ color: 'var(--hs-text)' }}>{user?.email}</strong>
          </span>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <a href="http://127.0.0.1:8000/admin/" target="_blank" rel="noreferrer">
              Django admin
            </a>
            <button
              type="button"
              className="hs-btn hs-btn-ghost"
              onClick={() => {
                logout();
                navigate('/login');
              }}
            >
              Log out
            </button>
          </div>
        </header>
        <main style={{ padding: '1.25rem', flex: 1 }}>
          <Outlet />
        </main>
      </div>
    </div>
  );
}

export function HomeLink() {
  return (
    <Link to="/app/dashboard" className="hs-muted" style={{ fontSize: '0.875rem' }}>
      ← Dashboard
    </Link>
  );
}
