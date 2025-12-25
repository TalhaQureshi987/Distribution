import React, { useState, useEffect } from 'react';
import './RequestVerification.css';

const RequestVerification = () => {
    const [requests, setRequests] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [selectedRequest, setSelectedRequest] = useState(null);
    const [verificationNotes, setVerificationNotes] = useState('');
    const [rejectionReason, setRejectionReason] = useState('');
    const [actionLoading, setActionLoading] = useState(false);
    const [activeTab, setActiveTab] = useState('verification'); // 'verification' or 'history'
    const [filter, setFilter] = useState('pending');
    const [typeStats, setTypeStats] = useState({});

    useEffect(() => {
        if (activeTab === 'verification') {
            fetchPendingRequests();
        } else {
            fetchRequestHistory();
        }
        fetchRequestStats();
    }, [activeTab]);

    const fetchPendingRequests = async () => {
        try {
            setLoading(true);
            const token = localStorage.getItem('admin_token');
            const response = await fetch('http://localhost:3001/api/admin/requests/pending', {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                },
            });

            if (!response.ok) {
                throw new Error('Failed to fetch pending requests');
            }

            const data = await response.json();
            setRequests(data.requests || []);
        } catch (error) {
            console.error('Error fetching requests:', error);
            setError('Failed to load requests');
        } finally {
            setLoading(false);
        }
    };

    const fetchRequestHistory = async () => {
        try {
            setLoading(true);
            const token = localStorage.getItem('admin_token');
            const response = await fetch('http://localhost:3001/api/admin/requests/history', {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                },
            });

            if (!response.ok) {
                throw new Error('Failed to fetch request history');
            }

            const data = await response.json();
            setRequests(data.requests || []);
        } catch (error) {
            console.error('Error fetching request history:', error);
            setError('Failed to load request history');
        } finally {
            setLoading(false);
        }
    };

    const fetchRequestStats = async () => {
        try {
            const token = localStorage.getItem('admin_token');
            const response = await fetch('http://localhost:3001/api/admin/requests/stats', {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                },
            });

            if (response.ok) {
                const data = await response.json();
                setTypeStats(data.stats?.byType || {});
            }
        } catch (error) {
            console.error('Error fetching request stats:', error);
        }
    };

    const handleVerifyRequest = async (requestId) => {
        try {
            setActionLoading(true);
            const token = localStorage.getItem('admin_token');
            const response = await fetch(`http://localhost:3001/api/requests/admin/${requestId}/approve`, {
                method: 'PATCH',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    notes: verificationNotes,
                }),
            });

            if (!response.ok) {
                throw new Error('Failed to verify request');
            }

            const data = await response.json();

            // Remove verified request from list
            setRequests(prev => prev.filter(r => r._id !== requestId));
            setSelectedRequest(null);
            setVerificationNotes('');

            alert('Request verified successfully!');
        } catch (error) {
            console.error('Error verifying request:', error);
            alert('Failed to verify request');
        } finally {
            setActionLoading(false);
        }
    };

    const handleRejectRequest = async (requestId) => {
        if (!rejectionReason.trim()) {
            alert('Please provide a reason for rejection');
            return;
        }

        try {
            setActionLoading(true);
            const token = localStorage.getItem('admin_token');
            const response = await fetch(`http://localhost:3001/api/requests/admin/${requestId}/reject`, {
                method: 'PATCH',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    reason: rejectionReason,
                }),
            });

            if (!response.ok) {
                throw new Error('Failed to reject request');
            }

            const data = await response.json();

            // Remove rejected request from list
            setRequests(prev => prev.filter(r => r._id !== requestId));
            setSelectedRequest(null);
            setRejectionReason('');

            alert('Request rejected successfully!');
        } catch (error) {
            console.error('Error rejecting request:', error);
            alert('Failed to reject request');
        } finally {
            setActionLoading(false);
        }
    };

    const formatDate = (dateString) => {
        return new Date(dateString).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
        });
    };

    const getStatusBadge = (status) => {
        const statusConfig = {
            pending: { color: 'orange', text: 'Pending' },
            verified: { color: 'green', text: 'Verified' },
            rejected: { color: 'red', text: 'Rejected' },
        };

        const config = statusConfig[status] || { color: 'gray', text: status };

        return (
            <span className={`status-badge status-${config.color}`}>
                {config.text}
            </span>
        );
    };

    const getRequestType = (request) => {
        const typeMapping = {
            'food_request': 'Food',
            'volunteer_application': 'Volunteer Application',
            'partnership_request': 'Partnership',
            'feedback_report': 'Feedback',
            'account_verification': 'Account Verification',
            'other': 'Other',
            // Legacy mappings for backward compatibility
            'Food': 'Food',
            'Medicine': 'Medicine',
            'Clothes': 'Clothes',
            'Other': 'Other',
            'food': 'Food',
            'medicine': 'Medicine',
            'clothes': 'Clothes',
            'clothing': 'Clothes'
        };

        // Check requestType field first, then fallback to other possible fields
        const requestType = request.requestType || request.type || request.foodType || 'other';
        return typeMapping[requestType] || requestType || 'Other';
    };

    if (loading) {
        return (
            <div className="request-verification">
                <div className="loading-container">
                    <div className="loading-spinner"></div>
                    <p>Loading requests...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="request-verification">
            <div className="page-header">
                <h1>🎯 Request Verification</h1>
                <p>Review and verify pending requests</p>
            </div>

            {error && (
                <div className="error-message">
                    <span>⚠️ {error}</span>
                    <button onClick={fetchPendingRequests}>Retry</button>
                </div>
            )}

            <div className="requests-stats">
                <div className="stat-card">
                    <div className="stat-number">{requests.length}</div>
                    <div className="stat-label">Pending Requests</div>
                </div>

                {/* Type Statistics Dropdown */}
                <div className="stats-dropdown">
                    <button className="stats-dropdown-btn">
                        📊 Request Types Stats
                        <span className="dropdown-arrow">▼</span>
                    </button>
                    <div className="stats-dropdown-content">
                        <div className="type-stat-item">
                            <span className="type-icon">🍽️</span>
                            <span className="type-name">Food Request</span>
                            <span className="type-count">{typeStats.food_request || 0}</span>
                        </div>
                        <div className="type-stat-item">
                            <span className="type-icon">👥</span>
                            <span className="type-name">Volunteer Application</span>
                            <span className="type-count">{typeStats.volunteer_application || 0}</span>
                        </div>
                        <div className="type-stat-item">
                            <span className="type-icon">🤝</span>
                            <span className="type-name">Partnership Request</span>
                            <span className="type-count">{typeStats.partnership_request || 0}</span>
                        </div>
                        <div className="type-stat-item">
                            <span className="type-icon">📝</span>
                            <span className="type-name">Feedback Report</span>
                            <span className="type-count">{typeStats.feedback_report || 0}</span>
                        </div>
                        <div className="type-stat-item">
                            <span className="type-icon">📊</span>
                            <span className="type-name">Account Verification</span>
                            <span className="type-count">{typeStats.account_verification || 0}</span>
                        </div>
                        <div className="type-stat-item">
                            <span className="type-icon">📦</span>
                            <span className="type-name">Other</span>
                            <span className="type-count">{typeStats.other || 0}</span>
                        </div>
                        <div className="type-stat-divider"></div>
                        <div className="type-stat-item total">
                            <span className="type-icon">📈</span>
                            <span className="type-name">Total</span>
                            <span className="type-count">{Object.values(typeStats).reduce((a, b) => a + b, 0)}</span>
                        </div>
                    </div>
                </div>
            </div>

            <div className="tabs">
                <button
                    className={`tab-button ${activeTab === 'verification' ? 'active' : ''}`}
                    onClick={() => setActiveTab('verification')}
                >
                    Verification
                </button>
                <button
                    className={`tab-button ${activeTab === 'history' ? 'active' : ''}`}
                    onClick={() => setActiveTab('history')}
                >
                    History
                </button>
            </div>

            <div className="requests-container">
                {requests.length === 0 ? (
                    <div className="empty-state">
                        <div className="empty-icon">📝</div>
                        <h3>No {activeTab === 'verification' ? 'Pending' : 'Request History'}</h3>
                        <p>{activeTab === 'verification' ? 'All requests have been reviewed!' : 'No request history available'}</p>
                    </div>
                ) : (
                    <div className="requests-grid">
                        {requests.map((request) => (
                            <div key={request._id} className="request-card">
                                <div className="request-header">
                                    <h3>{request.title}</h3>
                                    {getStatusBadge(request.verificationStatus)}
                                </div>

                                <div className="request-details">
                                    <div className="detail-row">
                                        <span className="label">Requester:</span>
                                        <span className="value">{request.userId?.name || 'Unknown'}</span>
                                    </div>
                                    <div className="detail-row">
                                        <span className="label">Email:</span>
                                        <span className="value">{request.userId?.email || request.contactInfo?.email || 'N/A'}</span>
                                    </div>
                                    <div className="detail-row">
                                        <span className="label">Phone:</span>
                                        <span className="value">{request.userId?.phone || request.contactInfo?.phone || 'N/A'}</span>
                                    </div>
                                    <div className="detail-row">
                                        <span className="label">Request Type:</span>
                                        <span className="value">{getRequestType(request)}</span>
                                    </div>
                                    <div className="detail-row">
                                        <span className="label">Priority:</span>
                                        <span className="value">{request.priority || 'Medium'}</span>
                                    </div>
                                    <div className="detail-row">
                                        <span className="label">Address:</span>
                                        <span className="value">{request.contactInfo?.address || request.metadata?.pickupAddress || 'No address provided'}</span>
                                    </div>
                                    <div className="detail-row">
                                        <span className="label">Created:</span>
                                        <span className="value">{formatDate(request.createdAt)}</span>
                                    </div>
                                </div>

                                <div className="request-actions">
                                    <button
                                        className="btn btn-success"
                                        onClick={() => {
                                            setSelectedRequest(request);
                                            setVerificationNotes('');
                                            setRejectionReason('');
                                        }}
                                        disabled={actionLoading}
                                    >
                                        ✅ Review
                                    </button>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>

            {/* Verification Modal */}
            {selectedRequest && (
                <div className="modal-overlay">
                    <div className="modal-content">
                        <div className="modal-header">
                            <h2>Review Request</h2>
                            <button
                                className="close-btn"
                                onClick={() => setSelectedRequest(null)}
                            >
                                ✕
                            </button>
                        </div>

                        <div className="modal-body">
                            <div className="request-summary">
                                <h3>{selectedRequest.title}</h3>

                                {/* Basic Information */}
                                <div className="form-section">
                                    <h4>Basic Information</h4>
                                    <p><strong>Requester:</strong> {selectedRequest.userId?.name || 'Unknown'}</p>
                                    <p><strong>Email:</strong> {selectedRequest.userId?.email || selectedRequest.contactInfo?.email || 'N/A'}</p>
                                    <p><strong>Phone:</strong> {selectedRequest.userId?.phone || selectedRequest.contactInfo?.phone || 'N/A'}</p>
                                    <p><strong>Description:</strong> {selectedRequest.description}</p>
                                    <p><strong>Request Type:</strong> {getRequestType(selectedRequest)}</p>
                                    <p><strong>Priority:</strong> {selectedRequest.priority || 'Medium'}</p>
                                </div>

                                {/* Location & Contact */}
                                <div className="form-section">
                                    <h4>Location & Contact</h4>
                                    <p><strong>Address:</strong> {selectedRequest.contactInfo?.address || selectedRequest.metadata?.pickupAddress || 'No address provided'}</p>
                                    <p><strong>Delivery Option:</strong> {selectedRequest.metadata?.deliveryOption || 'Self delivery'}</p>
                                    {selectedRequest.metadata?.paymentAmount && selectedRequest.metadata?.paymentAmount > 0 && (
                                        <p><strong>Payment Amount:</strong> {selectedRequest.metadata.paymentAmount} PKR</p>
                                    )}
                                    {selectedRequest.metadata?.deliveryDistance && (
                                        <p><strong>Delivery Distance:</strong> {selectedRequest.metadata.deliveryDistance.toFixed(2)} km</p>
                                    )}
                                    {selectedRequest.metadata?.latitude && selectedRequest.metadata?.longitude && (
                                        <p><strong>Coordinates:</strong> {selectedRequest.metadata.latitude}, {selectedRequest.metadata.longitude}</p>
                                    )}
                                </div>

                                {/* Additional Information */}
                                <div className="form-section">
                                    <h4>Additional Information</h4>
                                    {selectedRequest.metadata?.quantity && (
                                        <p><strong>Quantity:</strong> {selectedRequest.metadata.quantity}</p>
                                    )}
                                    {selectedRequest.metadata?.urgencyLevel && (
                                        <p><strong>Urgency:</strong> {selectedRequest.metadata.urgencyLevel}</p>
                                    )}
                                    {selectedRequest.metadata?.neededBy && (
                                        <p><strong>Needed By:</strong> {new Date(selectedRequest.metadata.neededBy).toLocaleDateString()}</p>
                                    )}
                                    {selectedRequest.metadata?.notes && (
                                        <p><strong>Notes:</strong> {selectedRequest.metadata.notes}</p>
                                    )}
                                    <p><strong>Created:</strong> {formatDate(selectedRequest.createdAt)}</p>
                                </div>

                                {/* Display request images/attachments */}
                                {selectedRequest.attachments && selectedRequest.attachments.length > 0 && (
                                    <div className="request-images">
                                        <h4>Attachments:</h4>
                                        <div className="images-grid">
                                            {selectedRequest.attachments.map((attachment, index) => (
                                                <div key={index} className="image-container">
                                                    <img
                                                        src={attachment.url || `${import.meta.env.VITE_API_URL || 'http://localhost:3001'}${attachment.url?.startsWith('/') ? attachment.url : '/' + attachment.url}`}
                                                        alt={attachment.filename || `Attachment ${index + 1}`}
                                                        className="request-image"
                                                        onError={(e) => {
                                                            console.error(`Image failed to load: ${attachment.url}`);
                                                            e.target.style.display = 'none';
                                                        }}
                                                        onLoad={() => {
                                                            console.log(`Image loaded successfully: ${attachment.url}`);
                                                        }}
                                                    />
                                                    <span className="image-label">{attachment.filename || `Attachment ${index + 1}`}</span>
                                                </div>
                                            ))}
                                        </div>
                                    </div>
                                )}

                                {/* Fallback for legacy images field */}
                                {selectedRequest.images && selectedRequest.images.length > 0 && (
                                    <div className="request-images">
                                        <h4>Images:</h4>
                                        <div className="images-grid">
                                            {selectedRequest.images.map((image, index) => (
                                                <div key={index} className="image-container">
                                                    <img
                                                        src={`${import.meta.env.VITE_API_URL || 'http://localhost:3001'}${image.startsWith('/') ? image : '/' + image}`}
                                                        alt={`Request ${index + 1}`}
                                                        className="request-image"
                                                        onError={(e) => {
                                                            console.error(`Image failed to load: ${image}`);
                                                            e.target.style.display = 'none';
                                                        }}
                                                        onLoad={() => {
                                                            console.log(`Image loaded successfully: ${image}`);
                                                        }}
                                                    />
                                                </div>
                                            ))}
                                        </div>
                                    </div>
                                )}

                                {/* Show message if no images */}
                                {(!selectedRequest.attachments || selectedRequest.attachments.length === 0) &&
                                    (!selectedRequest.images || selectedRequest.images.length === 0) && (
                                        <div className="no-images">
                                            <p><strong>Images:</strong> No images provided</p>
                                        </div>
                                    )}

                                <div className="verification-form">
                                    <div className="form-group">
                                        <label>Verification Notes (Optional):</label>
                                        <textarea
                                            value={verificationNotes}
                                            onChange={(e) => setVerificationNotes(e.target.value)}
                                            placeholder="Add any notes about this request..."
                                            rows="3"
                                        />
                                    </div>

                                    <div className="form-group">
                                        <label>Rejection Reason (Required for rejection):</label>
                                        <textarea
                                            value={rejectionReason}
                                            onChange={(e) => setRejectionReason(e.target.value)}
                                            placeholder="Explain why this request is being rejected..."
                                            rows="3"
                                        />
                                    </div>
                                </div>
                            </div>

                            <div className="modal-actions">
                                <button
                                    className="btn btn-success"
                                    onClick={() => handleVerifyRequest(selectedRequest._id)}
                                    disabled={actionLoading}
                                >
                                    {actionLoading ? 'Processing...' : '✅ Verify Request'}
                                </button>
                                <button
                                    className="btn btn-danger"
                                    onClick={() => handleRejectRequest(selectedRequest._id)}
                                    disabled={actionLoading || !rejectionReason.trim()}
                                >
                                    {actionLoading ? 'Processing...' : '❌ Reject Request'}
                                </button>
                                <button
                                    className="btn btn-secondary"
                                    onClick={() => setSelectedRequest(null)}
                                    disabled={actionLoading}
                                >
                                    Cancel
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
            <style jsx>{`
                .notification {
                    position: fixed;
                    top: 20px;
                    right: 20px;
                    padding: 15px 25px;
                    border-radius: 8px;
                    font-weight: 500;
                    z-index: 1000;
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
                    animation: slideIn 0.3s ease-out;
                }

                .notification-success {
                    background-color: #d4edda;
                    color: #155724;
                    border: 1px solid #c3e6cb;
                }

                .notification-error {
                    background-color: #f8d7da;
                    color: #721c24;
                    border: 1px solid #f5c6cb;
                }

                @keyframes slideIn {
                    from {
                        transform: translateX(100%);
                        opacity: 0;
                    }
                    to {
                        transform: translateX(0);
                        opacity: 1;
                    }
                }

                .request-verification {
                    padding: 20px;
                    max-width: 1200px;
                    margin: 0 auto;
                }

                .page-header {
                    margin-bottom: 30px;
                    text-align: center;
                }

                .page-header h1 {
                    color: #2c3e50;
                    margin-bottom: 10px;
                }

                .page-header p {
                    color: #7f8c8d;
                    font-size: 16px;
                }

                .tabs {
                    display: flex;
                    margin-bottom: 30px;
                    border-bottom: 2px solid #ecf0f1;
                }

                .tab {
                    padding: 15px 30px;
                    background: none;
                    border: none;
                    font-size: 16px;
                    font-weight: 500;
                    cursor: pointer;
                    color: #7f8c8d;
                    border-bottom: 3px solid transparent;
                    transition: all 0.3s ease;
                }

                .tab.active {
                    color: #3498db;
                    border-bottom-color: #3498db;
                }

                .tab:hover {
                    color: #2980b9;
                }

                .requests-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
                    gap: 20px;
                    margin-bottom: 30px;
                }

                .request-card {
                    background: white;
                    border-radius: 12px;
                    padding: 20px;
                    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
                    border: 1px solid #ecf0f1;
                    transition: transform 0.2s ease, box-shadow 0.2s ease;
                }

                .request-card:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
                }

                .request-header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 15px;
                }

                .request-type {
                    background: #3498db;
                    color: white;
                    padding: 5px 12px;
                    border-radius: 20px;
                    font-size: 12px;
                    font-weight: 500;
                }

                .request-status {
                    padding: 5px 12px;
                    border-radius: 20px;
                    font-size: 12px;
                    font-weight: 500;
                }

                .status-pending {
                    background: #fff3cd;
                    color: #856404;
                }

                .status-verified {
                    background: #d4edda;
                    color: #155724;
                }

                .status-rejected {
                    background: #f8d7da;
                    color: #721c24;
                }

                .request-info {
                    margin-bottom: 15px;
                }

                .info-row {
                    display: flex;
                    justify-content: space-between;
                    margin-bottom: 8px;
                    font-size: 14px;
                }

                .info-label {
                    font-weight: 500;
                    color: #2c3e50;
                }

                .info-value {
                    color: #7f8c8d;
                }

                .request-actions {
                    display: flex;
                    gap: 10px;
                    margin-top: 15px;
                }

                .btn {
                    padding: 8px 16px;
                    border: none;
                    border-radius: 6px;
                    font-size: 14px;
                    font-weight: 500;
                    cursor: pointer;
                    transition: all 0.2s ease;
                }

                .btn-primary {
                    background: #3498db;
                    color: white;
                }

                .btn-primary:hover {
                    background: #2980b9;
                }

                .btn-success {
                    background: #27ae60;
                    color: white;
                }

                .btn-success:hover {
                    background: #229954;
                }

                .btn-danger {
                    background: #e74c3c;
                    color: white;
                }

                .btn-danger:hover {
                    background: #c0392b;
                }

                .btn:disabled {
                    opacity: 0.6;
                    cursor: not-allowed;
                }

                .modal-overlay {
                    position: fixed;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    background: rgba(0, 0, 0, 0.5);
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    z-index: 1000;
                }

                .modal {
                    background: white;
                    border-radius: 12px;
                    padding: 30px;
                    max-width: 600px;
                    width: 90%;
                    max-height: 80vh;
                    overflow-y: auto;
                }

                .modal-header {
                    margin-bottom: 20px;
                }

                .modal-title {
                    color: #2c3e50;
                    margin-bottom: 10px;
                }

                .modal-content {
                    margin-bottom: 20px;
                }

                .detail-grid {
                    display: grid;
                    grid-template-columns: 1fr 2fr;
                    gap: 15px;
                    margin-bottom: 20px;
                }

                .detail-label {
                    font-weight: 600;
                    color: #2c3e50;
                }

                .detail-value {
                    color: #7f8c8d;
                }

                .textarea {
                    width: 100%;
                    min-height: 100px;
                    padding: 12px;
                    border: 1px solid #ddd;
                    border-radius: 6px;
                    font-family: inherit;
                    font-size: 14px;
                    resize: vertical;
                }

                .modal-actions {
                    display: flex;
                    gap: 10px;
                    justify-content: flex-end;
                }

                .empty-state {
                    text-align: center;
                    padding: 60px 20px;
                    color: #7f8c8d;
                }

                .empty-state h3 {
                    margin-bottom: 10px;
                    color: #2c3e50;
                }

                .request-images {
                    margin-top: 20px;
                }

                .images-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
                    gap: 10px;
                }

                .image-container {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    padding: 10px;
                    border: 1px solid #ddd;
                    border-radius: 6px;
                }

                .request-image {
                    width: 100%;
                    height: 100px;
                    object-fit: cover;
                    border-radius: 6px;
                }

                .stats-dropdown {
                    position: relative;
                    display: inline-block;
                }

                .stats-dropdown-btn {
                    background: white;
                    border: 1px solid #ddd;
                    padding: 10px 20px;
                    font-size: 14px;
                    font-weight: 500;
                    cursor: pointer;
                    color: #2c3e50;
                    border-radius: 6px;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }

                .stats-dropdown-btn:hover {
                    background: #f8f9fa;
                    border-color: #3498db;
                }

                .dropdown-arrow {
                    font-size: 12px;
                    transition: transform 0.3s ease;
                }

                .stats-dropdown:hover .dropdown-arrow {
                    transform: rotate(180deg);
                }

                .stats-dropdown-content {
                    position: absolute;
                    top: 100%;
                    left: 0;
                    background: white;
                    border: 1px solid #ddd;
                    padding: 15px;
                    border-radius: 8px;
                    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
                    min-width: 200px;
                    z-index: 1000;
                    opacity: 0;
                    visibility: hidden;
                    transform: translateY(-10px);
                    transition: all 0.3s ease;
                }

                .stats-dropdown:hover .stats-dropdown-content {
                    opacity: 1;
                    visibility: visible;
                    transform: translateY(0);
                }

                .type-stat-item {
                    display: flex;
                    align-items: center;
                    padding: 8px 0;
                    border-bottom: 1px solid #f0f0f0;
                }

                .type-stat-item:last-child {
                    border-bottom: none;
                }

                .type-icon {
                    font-size: 18px;
                    margin-right: 12px;
                    width: 24px;
                    text-align: center;
                }

                .type-name {
                    font-weight: 500;
                    color: #2c3e50;
                    flex: 1;
                }

                .type-count {
                    background: #3498db;
                    color: white;
                    padding: 2px 8px;
                    border-radius: 12px;
                    font-size: 12px;
                    font-weight: 600;
                    min-width: 24px;
                    text-align: center;
                }

                .type-stat-divider {
                    border-bottom: 2px solid #ecf0f1;
                    margin: 8px 0;
                }

                .type-stat-item.total {
                    font-weight: 600;
                    color: #27ae60;
                    border-bottom: none;
                    margin-top: 5px;
                }

                .type-stat-item.total .type-count {
                    background: #27ae60;
                }
            `}</style>
        </div>
    );
};

export default RequestVerification;
