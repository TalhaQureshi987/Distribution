import React, { useState, useEffect } from 'react';
import api from '../api';
import './RealTimeAdminDashboard.css';

const RealTimeAdminDashboard = () => {
  const [users, setUsers] = useState([]);
  const [stats, setStats] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [editingUser, setEditingUser] = useState(null);
  const [deletingUser, setDeletingUser] = useState(null);
  const [selectedImage, setSelectedImage] = useState(null);
  const [showUserInfo, setShowUserInfo] = useState(false);
  const [notification, setNotification] = useState(null);
  const [filters, setFilters] = useState({
    role: 'all',
    status: 'all',
    verification: 'all',
    verified: 'all',
    searchCnic: '',
    searchPhone: '',
    multiRole: []
  });

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const response = await api.get('/auth/admin/users');
      
      if (response.data.success && Array.isArray(response.data.users)) {
        setUsers(response.data.users);
      } else {
        console.error('Invalid users data structure:', response.data);
        setUsers([]);
      }
    } catch (error) {
      console.error('Error fetching users:', error);
      setError(error.message);
      setUsers([]);
    } finally {
      setLoading(false);
    }
  };

  const fetchStats = async () => {
    try {
      const response = await api.get('/auth/admin/stats');
      if (response.data.success) {
        setStats(response.data.stats);
      }
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  };

  useEffect(() => {
    fetchUsers();
    fetchStats();

    // Setup real-time notifications for user verification
    const eventSource = new EventSource('http://localhost:3001/api/auth/admin/verification-events', {
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('admin_token')}`
      }
    });

    eventSource.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.type === 'user_verified') {
        setNotification({
          type: 'success',
          title: 'User Verified!',
          message: `${data.user.name} has been verified and can now access ${data.user.role} features.`,
          user: data.user,
          timestamp: new Date()
        });
        fetchUsers(); // Refresh user list
        fetchStats(); // Refresh stats
      }
    };

    return () => {
      eventSource.close();
    };
  }, []);

  const handleRefresh = () => {
    fetchUsers();
    fetchStats();
  };

  const handleEdit = (user) => {
    setEditingUser({ ...user });
  };

  const handleSaveEdit = async () => {
    try {
      const response = await api.put(`/auth/admin/users/${editingUser._id}`, editingUser);
      
      if (response.data.success) {
        fetchUsers();
        setEditingUser(null);
      } else {
        throw new Error('Failed to update user');
      }
    } catch (error) {
      console.error('Error updating user:', error);
      alert('Error updating user: ' + error.message);
    }
  };

  const handleDelete = async () => {
    try {
      const response = await api.delete(`/auth/admin/users/${deletingUser._id}`);

      if (response.data.success) {
        fetchUsers();
        setDeletingUser(null);
      } else {
        throw new Error('Failed to delete user');
      }
    } catch (error) {
      console.error('Error deleting user:', error);
      alert('Error deleting user: ' + error.message);
    }
  };

  const getImageUrl = (imagePath) => {
    if (!imagePath) return null;
    return `http://localhost:3001/${imagePath}`;
  };

  const handleRoleToggle = (role) => {
    const newMultiRole = filters.multiRole.includes(role)
      ? filters.multiRole.filter(r => r !== role)
      : [...filters.multiRole, role];
    setFilters({ ...filters, multiRole: newMultiRole });
  };

  const handleVerifyUser = async (userId, status) => {
    try {
      const response = await api.put(`/auth/admin/users/${userId}/verify`, {
        status: status,
        verificationNotes: `Verified by admin on ${new Date().toLocaleDateString()}`
      });

      if (response.data.success) {
        fetchUsers(); // Refresh user list
        fetchStats(); // Refresh stats

        // Show success notification
        setNotification({
          type: 'success',
          title: 'User Verified Successfully!',
          message: `${response.data.user.name} has been verified and can now access ${response.data.user.role} features.`,
          user: response.data.user,
          timestamp: new Date()
        });
      } else {
        throw new Error('Failed to verify user');
      }
    } catch (error) {
      console.error('Error verifying user:', error);
      alert('Error verifying user: ' + error.message);
    }
  };

  const filteredUsers = users.filter(user => {
    // Role filter
    if (filters.role !== 'all' && user.role !== filters.role) return false;

    // Multi-role filter
    if (filters.multiRole.length > 0 && !filters.multiRole.includes(user.role)) return false;

    // Status filter
    if (filters.status !== 'all' && user.status !== filters.status) return false;

    // Verification filter
    if (filters.verification !== 'all') {
      const hasDocuments = user.cnicFrontPhoto || user.cnicBackPhoto || user.selfiePhoto;
      if (filters.verification === 'submitted' && !hasDocuments) return false;
      if (filters.verification === 'not_submitted' && hasDocuments) return false;
    }

    // Verified/Unverified filter
    if (filters.verified !== 'all') {
      const isVerified = user.status === 'approved';
      if (filters.verified === 'verified' && !isVerified) return false;
      if (filters.verified === 'unverified' && isVerified) return false;
    }

    // CNIC search
    if (filters.searchCnic && !user.cnic?.toLowerCase().includes(filters.searchCnic.toLowerCase())) return false;

    // Phone search
    if (filters.searchPhone && !user.phone?.toLowerCase().includes(filters.searchPhone.toLowerCase())) return false;

    return true;
  });

  const pendingVerifications = users.filter(user =>
    (user.cnicFrontPhoto || user.cnicBackPhoto || user.selfiePhoto) && user.status === 'pending'
  ).length;

  const dismissNotification = () => {
    setNotification(null);
  };

  if (loading) {
    return (
      <div className="dashboard">
        <div style={{ textAlign: 'center', padding: '50px', color: 'white' }}>
          <h2>Loading dashboard...</h2>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="dashboard">
        <div style={{ textAlign: 'center', padding: '50px', color: 'white' }}>
          <h2>Error: {error}</h2>
          <button onClick={handleRefresh} className="refresh-btn">
            Try Again
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="dashboard">
      {/* Real-time Notification */}
      {notification && (
        <div className="notification-popup">
          <div className="notification-content">
            <div className="notification-header">
              <span className="notification-icon">✅</span>
              <h4>{notification.title}</h4>
              <button onClick={dismissNotification} className="notification-close">×</button>
            </div>
            <p>{notification.message}</p>
            <div className="notification-user">
              <strong>User:</strong> {notification.user.name} ({notification.user.email})
            </div>
            <div className="notification-time">
              {notification.timestamp.toLocaleTimeString()}
            </div>
          </div>
        </div>
      )}

      {/* Dashboard Header */}
      <div className="dashboard-header">
        <div className="header-content">
          <div className="header-left">
            <div className="status-indicator"></div>
            <h1>Real-Time Admin Dashboard</h1>
          </div>
          <div className="header-actions">
            <button className="new-identity-btn">
              New Identity Verification
            </button>
            <button onClick={handleRefresh} className="refresh-btn">
              Refresh Data
            </button>
          </div>
        </div>
      </div>

      {/* Warning Banner */}
      {pendingVerifications > 0 && (
        <div className="warning-banner">
          <span className="warning-icon">⚠️</span>
          <span>
            {pendingVerifications} identity verification{pendingVerifications > 1 ? 's' : ''} pending review
          </span>
          <button className="review-btn">
            Review Now
          </button>
        </div>
      )}

      {/* Stats Container */}
      <div className="stats-container">
        <div className="stat-card">
          <div className="stat-number">{stats.totalUsers || 0}</div>
          <div className="stat-label">Total Users</div>
        </div>
        <div className="stat-card">
          <div className="stat-number">{stats.approvedUsers || 0}</div>
          <div className="stat-label">Approved</div>
        </div>
        <div className="stat-card">
          <div className="stat-number">{stats.pendingUsers || 0}</div>
          <div className="stat-label">Pending</div>
        </div>
        <div className="stat-card">
          <div className="stat-number">{stats.rejectedUsers || 0}</div>
          <div className="stat-label">Rejected</div>
        </div>
      </div>

      {/* Enhanced Filter Section */}
      <div className="filter-section">
        <div className="filter-row">
          <span className="filter-label">Search:</span>
          <input
            type="text"
            className="search-input"
            placeholder="Search by CNIC number..."
            value={filters.searchCnic}
            onChange={(e) => setFilters({ ...filters, searchCnic: e.target.value })}
          />
          <input
            type="text"
            className="search-input"
            placeholder="Search by phone number..."
            value={filters.searchPhone}
            onChange={(e) => setFilters({ ...filters, searchPhone: e.target.value })}
          />
        </div>

        <div className="filter-row">
          <span className="filter-label">Filter by:</span>
          <select
            className="filter-select"
            value={filters.role}
            onChange={(e) => setFilters({ ...filters, role: e.target.value, multiRole: [] })}
          >
            <option value="all">All Roles</option>
            <option value="donor">Donors</option>
            <option value="requester">Requesters</option>
            <option value="volunteer">Volunteers</option>
            <option value="delivery">Delivery</option>
            <option value="admin">Admins</option>
          </select>

          <select
            className="filter-select"
            value={filters.status}
            onChange={(e) => setFilters({ ...filters, status: e.target.value })}
          >
            <option value="all">All Status</option>
            <option value="approved">Approved</option>
            <option value="pending">Pending</option>
            <option value="rejected">Rejected</option>
          </select>

          <select
            className="filter-select"
            value={filters.verified}
            onChange={(e) => setFilters({ ...filters, verified: e.target.value })}
          >
            <option value="all">All Users</option>
            <option value="verified">Verified Only</option>
            <option value="unverified">Unverified Only</option>
          </select>

          <select
            className="filter-select"
            value={filters.verification}
            onChange={(e) => setFilters({ ...filters, verification: e.target.value })}
          >
            <option value="all">All Verifications</option>
            <option value="submitted">Documents Submitted</option>
            <option value="not_submitted">No Documents</option>
          </select>
        </div>

        {/* Multi-Role Selection */}
        <div className="filter-row">
          <span className="filter-label">Multi-Role Filter:</span>
          <div className="role-checkboxes">
            {['donor', 'requester', 'volunteer', 'delivery', 'admin'].map(role => (
              <label key={role} className="role-checkbox">
                <input
                  type="checkbox"
                  checked={filters.multiRole.includes(role)}
                  onChange={() => handleRoleToggle(role)}
                />
                <span className="checkbox-label">{role.charAt(0).toUpperCase() + role.slice(1)}</span>
              </label>
            ))}
          </div>
        </div>
      </div>

      {/* Identity Verification Submissions */}
      <div className="submissions-section">
        <div className="submissions-header">
          <span className="submissions-icon">🆔</span>
          <span className="submissions-title">Identity Verification Submissions ({filteredUsers.length})</span>
        </div>

        {/* Users Grid */}
        <div className="users-grid">
          {filteredUsers.length === 0 ? (
            <div className="no-users">
              <h3>No Users Found</h3>
              <p>There are currently no users in the system.</p>
            </div>
          ) : (
            filteredUsers.map((u) => (
              <div key={u._id} className="user-verification-card">
                <div className="user-header">
                  <h3 className="user-name">{u.name}</h3>
                  <div className="status-badges">
                    <span className={`status-badge ${u.role}`}>{u.role?.toUpperCase()}</span>
                    <span className={`verification-badge ${u.identityVerificationStatus || 'not_submitted'}`}>
                      {(u.identityVerificationStatus || 'NOT SUBMITTED').toUpperCase()}
                    </span>
                  </div>
                </div>

                <div className="user-details">
                  <div className="detail-row">
                    <span className="detail-label">Email:</span>
                    <span className="detail-value">{u.email}</span>
                  </div>
                  <div className="detail-row">
                    <span className="detail-label">CNIC:</span>
                    <span className="detail-value">{u.cnicNumber || 'Not provided'}</span>
                  </div>
                  <div className="detail-row">
                    <span className="detail-label">Submitted:</span>
                    <span className="detail-value">{new Date(u.createdAt).toLocaleDateString()}</span>
                  </div>
                </div>

                {(u.cnicFrontPhoto || u.cnicBackPhoto || u.selfiePhoto) && (
                  <div className="documents-section">
                    <div className="documents-header">
                      <span>📄</span>
                      <span>Identity Documents</span>
                    </div>
                    <div className="document-images">
                      {u.cnicFrontPhoto && (
                        <div className="document-item">
                          <img
                            src={getImageUrl(u.cnicFrontPhoto)}
                            alt="CNIC Front"
                            onClick={() => setSelectedImage({
                              url: getImageUrl(u.cnicFrontPhoto),
                              title: 'CNIC Front Photo',
                              user: u
                            })}
                          />
                          <span className="document-label">CNIC Front</span>
                        </div>
                      )}
                      {u.cnicBackPhoto && (
                        <div className="document-item">
                          <img
                            src={getImageUrl(u.cnicBackPhoto)}
                            alt="CNIC Back"
                            onClick={() => setSelectedImage({
                              url: getImageUrl(u.cnicBackPhoto),
                              title: 'CNIC Back Photo',
                              user: u
                            })}
                          />
                          <span className="document-label">CNIC Back</span>
                        </div>
                      )}
                      {u.selfiePhoto && (
                        <div className="document-item selfie">
                          <img
                            src={getImageUrl(u.selfiePhoto)}
                            alt="Selfie Photo"
                            onClick={() => setSelectedImage({
                              url: getImageUrl(u.selfiePhoto),
                              title: 'Selfie Photo',
                              user: u
                            })}
                          />
                          <span className="document-label">📸 Selfie</span>
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {u.payments && u.payments.length > 0 && (
                  <div className="payment-section">
                    <div className="payment-header">
                      <span className="payment-icon">💳</span>
                      <span className="payment-title">Payment History</span>
                    </div>
                    <div className="payment-cards">
                      {u.payments.slice(0, 2).map((payment, index) => (
                        <div key={index} className="payment-card">
                          <div className="payment-amount">
                            ${payment.amount || 'N/A'}
                          </div>
                          <div className="payment-method">
                            {payment.method || 'Unknown Method'}
                          </div>
                          <div className="payment-date">
                            {payment.date ? new Date(payment.date).toLocaleDateString() : 'No Date'}
                          </div>
                          <span className={`payment-status ${payment.status || 'pending'}`}>
                            {payment.status || 'Pending'}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                <div className="card-actions">
                  <button
                    className="edit-btn"
                    onClick={() => handleEdit(u)}
                  >
                    Edit User
                  </button>
                  <button
                    className="delete-btn"
                    onClick={() => setDeletingUser(u)}
                  >
                    Delete User
                  </button>
                  {u.status === 'pending' && (
                    <button
                      className="verify-btn"
                      onClick={() => handleVerifyUser(u._id, 'approved')}
                    >
                      Verify User
                    </button>
                  )}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Edit Modal */}
      {editingUser && (
        <div className="modal-overlay" onClick={() => setEditingUser(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>Edit User</h2>
            <input
              type="text"
              value={editingUser.name}
              onChange={(e) => setEditingUser({ ...editingUser, name: e.target.value })}
            />
            <input
              type="text"
              value={editingUser.email}
              onChange={(e) => setEditingUser({ ...editingUser, email: e.target.value })}
            />
            <select
              value={editingUser.role}
              onChange={(e) => setEditingUser({ ...editingUser, role: e.target.value })}
            >
              <option value="user">User</option>
              <option value="admin">Admin</option>
              <option value="volunteer">Volunteer</option>
            </select>
            <button onClick={handleSaveEdit}>Save</button>
            <button onClick={() => setEditingUser(null)}>Cancel</button>
          </div>
        </div>
      )}

      {/* Delete Modal */}
      {deletingUser && (
        <div className="modal-overlay" onClick={() => setDeletingUser(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>Confirm Delete</h2>
            <p>
              Are you sure you want to delete user <strong>{deletingUser.name}</strong>?
            </p>
            <div className="modal-actions">
              <button className="confirm-delete-btn" onClick={handleDelete}>
                Yes, Delete
              </button>
              <button onClick={() => setDeletingUser(null)}>Cancel</button>
            </div>
          </div>
        </div>
      )}

      {/* Image Modal */}
      {selectedImage && (
        <div className="image-modal-overlay" onClick={() => setSelectedImage(null)}>
          <div className="image-modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="image-modal-header">
              <h3>{selectedImage.title} - {selectedImage.user.name}</h3>
              <button onClick={() => setSelectedImage(null)} className="close-btn">×</button>
            </div>

            <div className="image-modal-body">
              <div className="modal-layout">
                <div className="image-section">
                  <img src={selectedImage.url} alt={selectedImage.title} className="full-size-image" />
                </div>

                <div className="user-info-section">
                  <h4>📋 Complete User Information</h4>
                  <div className="info-grid">
                    <div className="info-item"><strong>👤 Name:</strong><span>{selectedImage.user?.name || 'N/A'}</span></div>
                    <div className="info-item"><strong>📧 Email:</strong><span>{selectedImage.user?.email || 'N/A'}</span></div>
                    <div className="info-item"><strong>📱 Phone:</strong><span>{selectedImage.user?.phone || 'Not provided'}</span></div>
                    <div className="info-item"><strong>🏠 Address:</strong><span>{selectedImage.user?.address || 'Not provided'}</span></div>
                    <div className="info-item"><strong>🎭 Role:</strong><span>{(selectedImage.user?.role?.toString() || 'N/A').toUpperCase()}</span></div>
                    <div className="info-item"><strong>📊 Status:</strong><span>{(selectedImage.user?.status || 'N/A').toUpperCase()}</span></div>
                    <div className="info-item"><strong>🆔 CNIC Number:</strong><span>{selectedImage.user?.cnicNumber || 'Not provided'}</span></div>
                    <div className="info-item"><strong>✅ Email Verified:</strong><span>{selectedImage.user?.isEmailVerified ? '✅ Verified' : '❌ Not Verified'}</span></div>
                    <div className="info-item"><strong>🔍 Identity Status:</strong><span>{(selectedImage.user?.identityVerificationStatus || 'NOT SUBMITTED').toUpperCase()}</span></div>
                    <div className="info-item"><strong>💳 Payment Status:</strong><span>{(selectedImage.user?.paymentStatus || 'PENDING').toUpperCase()}</span></div>
                    <div className="info-item"><strong>📅 Joined:</strong><span>{selectedImage.user?.createdAt ? new Date(selectedImage.user.createdAt).toLocaleDateString() : 'N/A'}</span></div>
                  </div>
                </div>
              </div>
            </div>

            <div className="image-modal-footer">
              <button onClick={() => setSelectedImage(null)} className="close-modal-btn">Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default RealTimeAdminDashboard;
