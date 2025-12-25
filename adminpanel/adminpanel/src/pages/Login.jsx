import { useState } from 'react';
import api from '../api';
import { saveToken } from '../auth';
import { useNavigate } from 'react-router-dom';
import './Login.css';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState('');
  const [loading, setLoading] = useState(false);
  const nav = useNavigate();

  const onSubmit = async (e) => {
    e.preventDefault();
    setErr('');
    setLoading(true);

    try {
      console.log('🔐 Attempting login with:', email);

      const { data } = await api.post('/auth/login', { email, password });
      console.log('✅ Login response:', data);

      const token = data.token || data.accessToken;
      if (!token) throw new Error('No token received');

      console.log('🔑 Token received, checking admin status...');

      // Check admin status from login response user data
      const userData = data.user;
      console.log('👤 User data from login:', userData);

      const userRole = userData?.role;
      console.log('🎭 User role:', userRole);

      if (userRole !== 'admin') {
        console.log('❌ Admin role not found. User role:', userRole);
        throw new Error('Access denied: Admin privileges required');
      }

      console.log('✅ Admin verified, saving token...');
      saveToken(token);
      nav('/real-time-dashboard');
    } catch (e) {
      console.error('❌ Login error:', e);
      setErr(e?.response?.data?.message || e.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <div className="login-header">
          <div className="login-icon">🍽️</div>
          <h1>Care Connect</h1>
          <h2>Admin Panel</h2>
          <p>Sign in to manage the platform</p>
        </div>

        <form onSubmit={onSubmit} className="login-form">
          <div className="form-group">
            <label htmlFor="email">Email Address</label>
            <input
              id="email"
              type="email"
              placeholder="Enter your admin email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={loading}
              className="form-input"
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              placeholder="Enter your password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              disabled={loading}
              className="form-input"
            />
          </div>

          {err && (
            <div className="error-message">
              <span className="error-icon">⚠️</span>
              {err}
            </div>
          )}

          <button
            type="submit"
            disabled={loading || !email || !password}
            className="login-button"
          >
            {loading ? (
              <>
                <div className="button-spinner"></div>
                Signing in...
              </>
            ) : (
              <>
                <span>🔐</span>
                Sign In
              </>
            )}
          </button>
        </form>

        <div className="login-footer">
          <div className="demo-credentials">

          </div>
        </div>
      </div>
    </div>
  );
}