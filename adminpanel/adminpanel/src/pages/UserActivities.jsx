import { useEffect, useState } from 'react';
import api from '../api';
import './UserActivities.css';

export default function UserActivities() {
  const [activities, setActivities] = useState([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState('');
  const [selectedUser, setSelectedUser] = useState('');
  const [activityType, setActivityType] = useState('');
  const [users, setUsers] = useState([]);
  const [stats, setStats] = useState({});
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);

  const loadActivities = async () => {
    setLoading(true);
    setErr('');
    try {
      const params = new URLSearchParams({
        page: page.toString(),
        limit: '50'
      });
      
      if (selectedUser) params.append('userId', selectedUser);
      if (activityType) params.append('type', activityType);

      const { data } = await api.get(`/auth/admin/activities/all?${params}`);
      setActivities(data.activities || []);
      setTotalPages(data.pages || 1);
    } catch (e) {
      setErr(e?.response?.data?.message || e.message || 'Failed to load activities');
    } finally {
      setLoading(false);
    }
  };

  const loadUsers = async () => {
    try {
      const { data } = await api.get('/auth/admin/users/all');
      setUsers(data.users || []);
    } catch (e) {
      console.error('Failed to load users:', e);
    }
  };

  const loadStats = async () => {
    try {
      const { data } = await api.get('/auth/admin/stats');
      setStats(data.stats || {});
    } catch (e) {
      console.error('Failed to load stats:', e);
    }
  };

  useEffect(() => {
    loadUsers();
    loadStats();
  }, []);

  useEffect(() => {
    loadActivities();
  }, [page, selectedUser, activityType]);

  const getActivityIcon = (type) => {
    const icons = {
      registration: '👤',
      login: '🔐',
      logout: '🚪',
      email_verification: '✉️',
      payment: '💰',
      profile_update: '✏️',
      role_change: '🎭',
      status_change: '📊',
      donation_created: '🤝',
      donation_updated: '📝',
      request_created: '🙏',
      request_updated: '📋',
      volunteer_activity: '❤️',
      delivery_activity: '🚚',
      admin_action: '⚡',
      password_change: '🔑',
      account_deletion: '🗑️'
    };
    return icons[type] || '📌';
  };

  const getActivityColor = (type) => {
    const colors = {
      registration: '#10b981',
      login: '#3b82f6',
      logout: '#6b7280',
      email_verification: '#8b5cf6',
      payment: '#f59e0b',
      profile_update: '#06b6d4',
      role_change: '#ec4899',
      status_change: '#84cc16',
      donation_created: '#10b981',
      donation_updated: '#06b6d4',
      request_created: '#f59e0b',
      request_updated: '#06b6d4',
      volunteer_activity: '#ef4444',
      delivery_activity: '#8b5cf6',
      admin_action: '#dc2626',
      password_change: '#f97316',
      account_deletion: '#ef4444'
    };
    return colors[type] || '#6b7280';
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  };

  if (loading && activities.length === 0) {
    return (
      <div className="activities-container">
        <div className="loading-spinner">
          <div className="spinner"></div>
          <p>Loading activities...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="activities-container">
      {/* Header */}
      <div className="activities-header">
        <h1>📊 User Activities</h1>
        <p>Monitor all user actions and system events</p>
      </div>

      {/* Stats Overview */}
      <div className="activity-stats">
        <div className="stat-item">
          <span className="stat-label">Today's Registrations:</span>
          <span className="stat-value">{stats.activity?.todayRegistrations || 0}</span>
        </div>
        <div className="stat-item">
          <span className="stat-label">Recent Activities:</span>
          <span className="stat-value">{stats.activity?.recentActivities || 0}</span>
        </div>
        <div className="stat-item">
          <span className="stat-label">Total Users:</span>
          <span className="stat-value">{stats.users?.total || 0}</span>
        </div>
        <div className="stat-item">
          <span className="stat-label">Active Users:</span>
          <span className="stat-value">{stats.users?.approved || 0}</span>
        </div>
      </div>

      {/* Filters */}
      <div className="activity-filters">
        <div className="filter-group">
          <label>Filter by User:</label>
          <select
            value={selectedUser}
            onChange={(e) => {
              setSelectedUser(e.target.value);
              setPage(1);
            }}
            className="filter-select"
          >
            <option value="">All Users</option>
            {users.map(user => (
              <option key={user._id} value={user._id}>
                {user.name} ({user.email})
              </option>
            ))}
          </select>
        </div>
        <div className="filter-group">
          <label>Filter by Activity:</label>
          <select
            value={activityType}
            onChange={(e) => {
              setActivityType(e.target.value);
              setPage(1);
            }}
            className="filter-select"
          >
            <option value="">All Activities</option>
            <option value="registration">Registration</option>
            <option value="login">Login</option>
            <option value="logout">Logout</option>
            <option value="email_verification">Email Verification</option>
            <option value="payment">Payment</option>
            <option value="profile_update">Profile Update</option>
            <option value="role_change">Role Change</option>
            <option value="status_change">Status Change</option>
            <option value="donation_created">Donation Created</option>
            <option value="request_created">Request Created</option>
            <option value="volunteer_activity">Volunteer Activity</option>
            <option value="delivery_activity">Delivery Activity</option>
            <option value="admin_action">Admin Action</option>
          </select>
        </div>
      </div>

      {err && <div className="error-message">❌ {err}</div>}

      {/* Activities List */}
      <div className="activities-list">
        {activities.map(activity => (
          <div key={activity._id} className="activity-item">
            <div className="activity-icon" style={{ backgroundColor: getActivityColor(activity.type) }}>
              {getActivityIcon(activity.type)}
            </div>
            <div className="activity-content">
              <div className="activity-main">
                <div className="activity-user">
                  <strong>{activity.userId?.name || 'Unknown User'}</strong>
                  <span className="activity-email">({activity.userId?.email})</span>
                </div>
                <div className="activity-description">{activity.description}</div>
              </div>
              <div className="activity-meta">
                <span className="activity-type">{activity.type.replace('_', ' ').toUpperCase()}</span>
                <span className="activity-time">{formatDate(activity.createdAt)}</span>
                {activity.ipAddress && (
                  <span className="activity-ip">IP: {activity.ipAddress}</span>
                )}
              </div>
              {activity.details && Object.keys(activity.details).length > 0 && (
                <div className="activity-details">
                  <strong>Details:</strong>
                  <pre>{JSON.stringify(activity.details, null, 2)}</pre>
                </div>
              )}
            </div>
          </div>
        ))}
        
        {activities.length === 0 && !loading && (
          <div className="no-activities">
            <div className="no-activities-icon">📭</div>
            <p>No activities found matching your criteria</p>
          </div>
        )}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="pagination">
          <button
            onClick={() => setPage(p => Math.max(1, p - 1))}
            disabled={page === 1}
            className="pagination-btn"
          >
            ← Previous
          </button>
          <span className="pagination-info">
            Page {page} of {totalPages}
          </span>
          <button
            onClick={() => setPage(p => Math.min(totalPages, p + 1))}
            disabled={page === totalPages}
            className="pagination-btn"
          >
            Next →
          </button>
        </div>
      )}

      {loading && (
        <div className="loading-overlay">
          <div className="spinner"></div>
        </div>
      )}
    </div>
  );
}
