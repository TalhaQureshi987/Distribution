import React, { useState, useEffect } from 'react';
import api from '../api';
import './IdentityVerifications.css';

const IdentityVerifications = () => {
  const [verifications, setVerifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedVerification, setSelectedVerification] = useState(null);
  const [showModal, setShowModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [rejectionReason, setRejectionReason] = useState('');
  const [adminNotes, setAdminNotes] = useState('');

  useEffect(() => {
    fetchPendingVerifications();
  }, []);

  const fetchPendingVerifications = async () => {
    try {
      setLoading(true);
      const response = await api.get('/auth/admin/identity-verifications/pending');
      setVerifications(response.data.pendingVerifications || []);
    } catch (error) {
      console.error('Error fetching verifications:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleViewDetails = (verification) => {
    setSelectedVerification(verification);
    setShowModal(true);
  };

  const handleApprove = async (verificationId) => {
    try {
      setActionLoading(true);
      await api.patch(`/auth/admin/identity-verifications/${verificationId}/approve`);

      // Remove from list
      setVerifications(verifications.filter(v => v._id !== verificationId));
      setShowModal(false);
      setAdminNotes('');

      alert('Identity verification approved successfully!');
    } catch (error) {
      console.error('Error approving verification:', error);
      alert('Error approving verification: ' + (error.response?.data?.message || error.message));
    } finally {
      setActionLoading(false);
    }
  };

  const handleReject = async (verificationId) => {
    if (!rejectionReason.trim()) {
      alert('Please provide a rejection reason');
      return;
    }

    try {
      setActionLoading(true);
      await api.patch(`/auth/admin/identity-verifications/${verificationId}/reject`, {
        reason: rejectionReason
      });

      // Remove from list
      setVerifications(verifications.filter(v => v._id !== verificationId));
      setShowModal(false);
      setRejectionReason('');
      setAdminNotes('');

      alert('Identity verification rejected successfully!');
    } catch (error) {
      console.error('Error rejecting verification:', error);
      alert('Error rejecting verification: ' + (error.response?.data?.message || error.message));
    } finally {
      setActionLoading(false);
    }
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleString();
  };

  const getImageUrl = (imagePath) => {
    // Convert backend path to accessible URL
    return `${api.defaults.baseURL.replace('/api', '')}/${imagePath}`;
  };

  if (loading) {
    return (
      <div className="identity-verifications">
        <div className="loading-container">
          <div className="spinner"></div>
          <p>Loading identity verifications...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="identity-verifications">
      <div className="header">
        <h1>Identity Verifications</h1>
        <button onClick={fetchPendingVerifications} className="refresh-btn">
          🔄 Refresh
        </button>
      </div>

      {verifications.length === 0 ? (
        <div className="empty-state">
          <div className="empty-icon">✅</div>
          <h3>No Pending Verifications</h3>
          <p>All identity verifications have been processed.</p>
        </div>
      ) : (
        <div className="verifications-grid">
          {verifications.map((verification) => (
            <div key={verification._id} className="verification-card">
              <div className="card-header">
                <div className="user-info">
                  <h3>{verification.name || 'Unknown User'}</h3>
                  <p>{verification.email}</p>
                  <span className="user-role">
                    {verification.role || 'No role'}
                  </span>
                </div>
                <div className="status-badge pending">
                  Pending Review
                </div>
              </div>

              <div className="card-body">
                <div className="info-row">
                  <span className="label">CNIC:</span>
                  <span className="value">{verification.cnicNumber || 'Not provided'}</span>
                </div>
                <div className="info-row">
                  <span className="label">Submitted:</span>
                  <span className="value">{formatDate(verification.createdAt)}</span>
                </div>
                <div className="info-row">
                  <span className="label">Status:</span>
                  <span className="value">Pending Verification</span>
                </div>
              </div>

              <div className="card-actions">
                <button
                  onClick={() => handleViewDetails(verification)}
                  className="btn-primary"
                >
                  View Details
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal for verification details */}
      {showModal && selectedVerification && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h2>Identity Verification Details</h2>
              <button
                onClick={() => setShowModal(false)}
                className="close-btn"
              >
                ×
              </button>
            </div>

            <div className="modal-body">
              <div className="user-details">
                <h3>User Information</h3>
                <div className="detail-grid">
                  <div className="detail-item">
                    <label>Name:</label>
                    <span>{selectedVerification.name}</span>
                  </div>
                  <div className="detail-item">
                    <label>Email:</label>
                    <span>{selectedVerification.email}</span>
                  </div>
                  <div className="detail-item">
                    <label>CNIC:</label>
                    <span>{selectedVerification.cnicNumber}</span>
                  </div>
                  <div className="detail-item">
                    <label>Roles:</label>
                    <span>{selectedVerification.role}</span>
                  </div>
                </div>
              </div>

              <div className="documents-section">
                <h3>Uploaded Documents</h3>
                <div className="documents-grid">
                  <div className="document-item">
                    <h4>CNIC Front</h4>
                    {selectedVerification.cnicFrontPhoto ? (
                      <img
                        src={getImageUrl(selectedVerification.cnicFrontPhoto)}
                        alt="CNIC Front"
                        className="document-image"
                        onClick={() => window.open(getImageUrl(selectedVerification.cnicFrontPhoto), '_blank')}
                      />
                    ) : (
                      <div className="no-image">No front photo uploaded</div>
                    )}
                  </div>
                  <div className="document-item">
                    <h4>CNIC Back</h4>
                    {selectedVerification.cnicBackPhoto ? (
                      <img
                        src={getImageUrl(selectedVerification.cnicBackPhoto)}
                        alt="CNIC Back"
                        className="document-image"
                        onClick={() => window.open(getImageUrl(selectedVerification.cnicBackPhoto), '_blank')}
                      />
                    ) : (
                      <div className="no-image">No back photo uploaded</div>
                    )}
                  </div>
                  <div className="document-item selfie-document">
                    <h4>📸 Selfie Photo</h4>
                    {selectedVerification.selfiePhoto ? (
                      <img
                        src={getImageUrl(selectedVerification.selfiePhoto)}
                        alt="Selfie Photo"
                        className="document-image selfie-image"
                        onClick={() => window.open(getImageUrl(selectedVerification.selfiePhoto), '_blank')}
                      />
                    ) : (
                      <div className="no-image">No selfie photo uploaded</div>
                    )}
                  </div>
                </div>
              </div>

              <div className="admin-actions">
                <h3>Admin Actions</h3>

                <div className="form-group">
                  <label>Admin Notes (Optional):</label>
                  <textarea
                    value={adminNotes}
                    onChange={(e) => setAdminNotes(e.target.value)}
                    placeholder="Add any notes about this verification..."
                    rows="3"
                  />
                </div>

                <div className="form-group">
                  <label>Rejection Reason (Required for rejection):</label>
                  <textarea
                    value={rejectionReason}
                    onChange={(e) => setRejectionReason(e.target.value)}
                    placeholder="Provide reason if rejecting..."
                    rows="2"
                  />
                </div>

                <div className="action-buttons">
                  <button
                    onClick={() => handleApprove(selectedVerification._id)}
                    disabled={actionLoading}
                    className="btn-approve"
                  >
                    {actionLoading ? 'Processing...' : '✅ Approve'}
                  </button>
                  <button
                    onClick={() => handleReject(selectedVerification._id)}
                    disabled={actionLoading}
                    className="btn-reject"
                  >
                    {actionLoading ? 'Processing...' : '❌ Reject'}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default IdentityVerifications;
