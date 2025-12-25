import { BrowserRouter as Router, Routes, Route, Navigate, Link } from 'react-router-dom';
import Login from './pages/Login';
import UserActivities from './pages/UserActivities';
import RealTimeAdminDashboard from './pages/RealTimeAdminDashboard';
import IdentityVerifications from './pages/IdentityVerifications';
import PaymentManagement from './pages/PaymentManagement';
import DeliveryPaymentManagement from './pages/DeliveryPaymentManagement';
import AllUsersManagement from './pages/AllUsersManagement';
import DonationVerification from './pages/DonationVerification';
import RequestVerification from './pages/RequestVerification';
import ProtectedRoute from './ProtectedRoute';
import './App.css';

function App() {
  return (
    <Router>
      <div className="app">
        <nav style={{
          padding: '15px 25px',
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          borderBottom: '1px solid rgba(255,255,255,0.2)',
          marginBottom: '0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.1)'
        }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            maxWidth: '1200px',
            margin: '0 auto'
          }}>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '30px'
            }}>
              <h2 style={{
                color: 'white',
                margin: 0,
                fontSize: '1.5rem',
                textShadow: '1px 1px 2px rgba(0,0,0,0.3)'
              }}>
                🍽️ Care Connect Admin
              </h2>
              <div style={{ display: 'flex', gap: '20px' }}>
                <Link to="/real-time-dashboard" style={{
                  color: 'white',
                  textDecoration: 'none',
                  padding: '10px 20px',
                  borderRadius: '20px',
                  background: 'rgba(255,255,255,0.3)',
                  backdropFilter: 'blur(10px)',
                  transition: 'all 0.3s ease',
                  fontWeight: '600',
                  border: '2px solid rgba(255,255,255,0.4)'
                }}
                  onMouseEnter={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.4)';
                    e.target.style.transform = 'translateY(-2px)';
                  }}
                  onMouseLeave={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.3)';
                    e.target.style.transform = 'translateY(0)';
                  }}>
                  🔴 Real-Time Dashboard
                </Link>

                <Link to="/user-activities" style={{
                  color: 'white',
                  textDecoration: 'none',
                  padding: '10px 20px',
                  borderRadius: '20px',
                  background: 'rgba(255,255,255,0.2)',
                  backdropFilter: 'blur(10px)',
                  transition: 'all 0.3s ease',
                  fontWeight: '500'
                }}
                  onMouseEnter={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.3)';
                    e.target.style.transform = 'translateY(-2px)';
                  }}
                  onMouseLeave={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.2)';
                    e.target.style.transform = 'translateY(0)';
                  }}>
                  📊 Activities
                </Link>
                <Link to="/identity-verifications" style={{
                  color: 'white',
                  textDecoration: 'none',
                  padding: '10px 20px',
                  borderRadius: '20px',
                  background: 'rgba(255,255,255,0.2)',
                  backdropFilter: 'blur(10px)',
                  transition: 'all 0.3s ease',
                  fontWeight: '500'
                }}
                  onMouseEnter={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.3)';
                    e.target.style.transform = 'translateY(-2px)';
                  }}
                  onMouseLeave={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.2)';
                    e.target.style.transform = 'translateY(0)';
                  }}>
                  🆔 ID Verification
                </Link>
                <Link to="/donation-verification" style={{
                  color: 'white',
                  textDecoration: 'none',
                  padding: '10px 20px',
                  borderRadius: '20px',
                  background: 'rgba(255,255,255,0.2)',
                  backdropFilter: 'blur(10px)',
                  transition: 'all 0.3s ease',
                  fontWeight: '500'
                }}
                  onMouseEnter={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.3)';
                    e.target.style.transform = 'translateY(-2px)';
                  }}
                  onMouseLeave={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.2)';
                    e.target.style.transform = 'translateY(0)';
                  }}>
                  🎁 Donation Verification
                </Link>
                <Link to="/request-verification" style={{
                  color: 'white',
                  textDecoration: 'none',
                  padding: '10px 20px',
                  borderRadius: '20px',
                  background: 'rgba(255,255,255,0.2)',
                  backdropFilter: 'blur(10px)',
                  transition: 'all 0.3s ease',
                  fontWeight: '500'
                }}
                  onMouseEnter={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.3)';
                    e.target.style.transform = 'translateY(-2px)';
                  }}
                  onMouseLeave={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.2)';
                    e.target.style.transform = 'translateY(0)';
                  }}>
                  📋 Request Verification
                </Link>
                <Link to="/payment-management" style={{
                  color: 'white',
                  textDecoration: 'none',
                  padding: '10px 20px',
                  borderRadius: '20px',
                  background: 'rgba(255,255,255,0.2)',
                  backdropFilter: 'blur(10px)',
                  transition: 'all 0.3s ease',
                  fontWeight: '500'
                }}
                  onMouseEnter={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.3)';
                    e.target.style.transform = 'translateY(-2px)';
                  }}
                  onMouseLeave={(e) => {
                    e.target.style.background = 'rgba(255,255,255,0.2)';
                    e.target.style.transform = 'translateY(0)';
                  }}>
                  💳 Payments
                </Link>
              </div>
            </div>
            <button
              onClick={() => {
                localStorage.removeItem('admin_token');
                window.location.href = '/login';
              }}
              style={{
                background: 'rgba(255,255,255,0.2)',
                border: 'none',
                color: 'white',
                padding: '10px 20px',
                borderRadius: '20px',
                cursor: 'pointer',
                fontWeight: '500',
                transition: 'all 0.3s ease'
              }}
              onMouseEnter={(e) => {
                e.target.style.background = 'rgba(255,0,0,0.3)';
              }}
              onMouseLeave={(e) => {
                e.target.style.background = 'rgba(255,255,255,0.2)';
              }}
            >
              🚪 Logout
            </button>
          </div>
        </nav>

        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/real-time-dashboard" element={
            <ProtectedRoute>
              <RealTimeAdminDashboard />
            </ProtectedRoute>
          } />
          <Route path="/all-users" element={
            <ProtectedRoute>
              <AllUsersManagement />
            </ProtectedRoute>
          } />
          <Route path="/user-activities" element={
            <ProtectedRoute>
              <UserActivities />
            </ProtectedRoute>
          } />
          <Route path="/identity-verifications" element={
            <ProtectedRoute>
              <IdentityVerifications />
            </ProtectedRoute>
          } />
          <Route path="/donation-verification" element={
            <ProtectedRoute>
              <DonationVerification />
            </ProtectedRoute>
          } />
          <Route path="/request-verification" element={
            <ProtectedRoute>
              <RequestVerification />
            </ProtectedRoute>
          } />
          <Route path="/payment-management" element={
            <ProtectedRoute>
              <PaymentManagement />
            </ProtectedRoute>
          } />
          <Route path="/" element={<Navigate to="/real-time-dashboard" />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
