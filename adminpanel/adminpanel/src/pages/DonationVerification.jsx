import React, { useState, useEffect } from 'react';
import './DonationVerification.css';

const DonationVerification = () => {
    const [donations, setDonations] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [selectedDonation, setSelectedDonation] = useState(null);
    const [verificationNotes, setVerificationNotes] = useState('');
    const [rejectionReason, setRejectionReason] = useState('');
    const [actionLoading, setActionLoading] = useState(false);
    const [activeTab, setActiveTab] = useState('verification'); // 'verification' or 'history'
    const [filter, setFilter] = useState('pending');
    const [typeStats, setTypeStats] = useState({});

    useEffect(() => {
        if (activeTab === 'verification') {
            fetchPendingDonations();
        } else {
            fetchDonationHistory();
        }
        fetchDonationStats();
    }, [activeTab]);

    const fetchPendingDonations = async () => {
        try {
            setLoading(true);
            const token = localStorage.getItem('admin_token');
            const response = await fetch('http://localhost:3001/api/donations/admin/pending', {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                },
            });

            if (!response.ok) {
                throw new Error('Failed to fetch pending donations');
            }

            const data = await response.json();
            setDonations(data.donations || []);
        } catch (error) {
            console.error('Error fetching donations:', error);
            setError('Failed to load donations');
        } finally {
            setLoading(false);
        }
    };

    const fetchDonationHistory = async () => {
        try {
            setLoading(true);
            const token = localStorage.getItem('admin_token');
            const response = await fetch('http://localhost:3001/api/donations/admin/all', {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                },
            });

            if (!response.ok) {
                throw new Error('Failed to fetch donation history');
            }

            const data = await response.json();
            setDonations(data.donations || []);
        } catch (error) {
            console.error('Error fetching donation history:', error);
            setError('Failed to load donation history');
        } finally {
            setLoading(false);
        }
    };

    const fetchDonationStats = async () => {
        try {
            const token = localStorage.getItem('admin_token');
            const response = await fetch('http://localhost:3001/api/donations/admin/stats', {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                },
            });

            if (response.ok) {
                const data = await response.json();
                setTypeStats(data.typeStats || {});
            }
        } catch (error) {
            console.error('Error fetching donation stats:', error);
        }
    };

    const handleVerifyDonation = async (donationId) => {
        try {
            setActionLoading(true);
            const token = localStorage.getItem('admin_token');
            const response = await fetch(`http://localhost:3001/api/donations/${donationId}/verify`, {
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
                throw new Error('Failed to verify donation');
            }

            const data = await response.json();

            // Remove verified donation from list
            setDonations(prev => prev.filter(d => d._id !== donationId));
            setSelectedDonation(null);
            setVerificationNotes('');

            alert('Donation verified successfully!');
        } catch (error) {
            console.error('Error verifying donation:', error);
            alert('Failed to verify donation');
        } finally {
            setActionLoading(false);
        }
    };

    const handleRejectDonation = async (donationId) => {
        if (!rejectionReason.trim()) {
            alert('Please provide a reason for rejection');
            return;
        }

        try {
            setActionLoading(true);
            const token = localStorage.getItem('admin_token');
            const response = await fetch(`http://localhost:3001/api/donations/${donationId}/reject`, {
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
                throw new Error('Failed to reject donation');
            }

            const data = await response.json();

            // Remove rejected donation from list
            setDonations(prev => prev.filter(d => d._id !== donationId));
            setSelectedDonation(null);
            setRejectionReason('');

            alert('Donation rejected successfully!');
        } catch (error) {
            console.error('Error rejecting donation:', error);
            alert('Failed to reject donation');
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

    const getDonationType = (donation) => {
        const typeMapping = {
            'Food': 'Food',
            'Clothes': 'Clothes',
            'Medicine': 'Medicine',
            'Other': 'Other',
            'food': 'Food',
            'clothes': 'Clothes',
            'clothing': 'Clothes',
            'medicine': 'Medicine',
            'other': 'Other',
            'furniture': 'Furniture',
            'electronics': 'Electronics',
        };

        // Check foodType field first, then fallback to other possible fields
        const donationType = donation.foodType || donation.type || donation.category || 'Other';
        return typeMapping[donationType] || donationType || 'Other';
    };

    if (loading) {
        return (
            <div className="donation-verification">
                <div className="loading-container">
                    <div className="loading-spinner"></div>
                    <p>Loading donations...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="donation-verification">
            <div className="page-header">
                <h1>🎯 Donation Verification</h1>
                <p>Review and verify pending donations</p>
            </div>

            {error && (
                <div className="error-message">
                    <span>⚠️ {error}</span>
                    <button onClick={fetchPendingDonations}>Retry</button>
                </div>
            )}

            <div className="donations-stats">
                <div className="stat-card">
                    <div className="stat-number">{donations.length}</div>
                    <div className="stat-label">Pending Donations</div>
                </div>

                {/* Type Statistics Dropdown */}
                <div className="stats-dropdown">
                    <button className="stats-dropdown-btn">
                        📊 Donation Types Stats
                        <span className="dropdown-arrow">▼</span>
                    </button>
                    <div className="stats-dropdown-content">
                        <div className="type-stat-item">
                            <span className="type-icon">🍽️</span>
                            <span className="type-name">Food</span>
                            <span className="type-count">{typeStats.food || 0}</span>
                        </div>
                        <div className="type-stat-item">
                            <span className="type-icon">💊</span>
                            <span className="type-name">Medicine</span>
                            <span className="type-count">{typeStats.medicine || 0}</span>
                        </div>
                        <div className="type-stat-item">
                            <span className="type-icon">👕</span>
                            <span className="type-name">Clothes</span>
                            <span className="type-count">{typeStats.clothes || 0}</span>
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

            <div className="donations-container">
                {donations.length === 0 ? (
                    <div className="empty-state">
                        <div className="empty-icon">📝</div>
                        <h3>No {activeTab === 'verification' ? 'Pending' : 'Donation History'}</h3>
                        <p>{activeTab === 'verification' ? 'All donations have been reviewed!' : 'No donation history available'}</p>
                    </div>
                ) : (
                    <div className="donations-grid">
                        {donations.map((donation) => (
                            <div key={donation._id} className="donation-card">
                                <div className="donation-header">
                                    <h3>{donation.title}</h3>
                                    {getStatusBadge(donation.verificationStatus)}
                                </div>

                                <div className="donation-details">
                                    <div className="detail-row">
                                        <span className="label">Donor:</span>
                                        <span className="value">{donation.donorId?.name || 'Unknown'}</span>
                                    </div>
                                    <div className="detail-row">
                                        <span className="label">Email:</span>
                                        <span className="value">{donation.donorId?.email || 'N/A'}</span>
                                    </div>
                                    <div className="detail-row">
                                        <span className="label">Donation Type:</span>
                                        <span className="value">{getDonationType(donation)}</span>
                                    </div>
                                    <div className="detail-row">
                                        <span className="label">Quantity:</span>
                                        <span className="value">{donation.quantity}</span>
                                    </div>
                                    <div className="detail-row">
                                        <span className="label">Address:</span>
                                        <span className="value">{donation.pickupAddress}</span>
                                    </div>
                                    <div className="detail-row">
                                        <span className="label">Created:</span>
                                        <span className="value">{formatDate(donation.createdAt)}</span>
                                    </div>
                                </div>

                                <div className="donation-description">
                                    <h4>Description:</h4>
                                    <p>{donation.description}</p>
                                </div>

                                <div className="donation-actions">
                                    <button
                                        className="btn btn-success"
                                        onClick={() => {
                                            setSelectedDonation(donation);
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
            {selectedDonation && (
                <div className="modal-overlay">
                    <div className="modal-content">
                        <div className="modal-header">
                            <h2>Review Donation</h2>
                            <button
                                className="close-btn"
                                onClick={() => setSelectedDonation(null)}
                            >
                                ✕
                            </button>
                        </div>

                        <div className="modal-body">
                            <div className="donation-summary">
                                <h3>{selectedDonation.title}</h3>

                                {/* Basic Information */}
                                <div className="form-section">
                                    <h4>Basic Information</h4>
                                    <p><strong>Donor:</strong> {selectedDonation.donorId?.name}</p>
                                    <p><strong>Email:</strong> {selectedDonation.donorId?.email}</p>
                                    <p><strong>Phone:</strong> {selectedDonation.donorId?.phone || 'N/A'}</p>
                                    <p><strong>Description:</strong> {selectedDonation.description}</p>
                                    <p><strong>Donation Type:</strong> {getDonationType(selectedDonation)}</p>
                                    <p><strong>Quantity:</strong> {selectedDonation.quantity} {selectedDonation.quantityUnit || 'items'}</p>
                                </div>

                                {/* Location & Delivery */}
                                <div className="form-section">
                                    <h4>Location & Delivery</h4>
                                    <p><strong>Pickup Address:</strong> {selectedDonation.pickupAddress}</p>
                                    <p><strong>Delivery Option:</strong> {selectedDonation.deliveryOption || 'Self delivery'}</p>
                                    {selectedDonation.latitude && selectedDonation.longitude && (
                                        <p><strong>Coordinates:</strong> {selectedDonation.latitude}, {selectedDonation.longitude}</p>
                                    )}
                                </div>

                                {/* Category-Specific Fields */}
                                {selectedDonation.foodType === 'Food' && (
                                    <div className="form-section">
                                        <h4>Food Details</h4>
                                        {selectedDonation.foodName && <p><strong>Food Name:</strong> {selectedDonation.foodName}</p>}
                                        {selectedDonation.foodCategory && <p><strong>Food Category:</strong> {selectedDonation.foodCategory}</p>}
                                        {selectedDonation.expiryDate && (
                                            <p><strong>Expiry Date:</strong> {new Date(selectedDonation.expiryDate).toLocaleDateString()}</p>
                                        )}
                                    </div>
                                )}

                                {selectedDonation.foodType === 'Medicine' && (
                                    <div className="form-section">
                                        <h4>Medicine Details</h4>
                                        {selectedDonation.medicineName && <p><strong>Medicine Name:</strong> {selectedDonation.medicineName}</p>}
                                        {selectedDonation.expiryDate && (
                                            <p><strong>Expiry Date:</strong> {new Date(selectedDonation.expiryDate).toLocaleDateString()}</p>
                                        )}
                                        {selectedDonation.prescriptionRequired !== undefined && (
                                            <p><strong>Prescription Required:</strong> {selectedDonation.prescriptionRequired ? 'Yes' : 'No'}</p>
                                        )}
                                    </div>
                                )}

                                {selectedDonation.foodType === 'Clothes' && (
                                    <div className="form-section">
                                        <h4>Clothes Details</h4>
                                        {selectedDonation.clothesGenderAge && <p><strong>Gender/Age:</strong> {selectedDonation.clothesGenderAge}</p>}
                                        {selectedDonation.clothesCondition && <p><strong>Condition:</strong> {selectedDonation.clothesCondition}</p>}
                                    </div>
                                )}

                                {selectedDonation.foodType === 'Other' && selectedDonation.otherDescription && (
                                    <div className="form-section">
                                        <h4>Other Details</h4>
                                        <p><strong>Description:</strong> {selectedDonation.otherDescription}</p>
                                    </div>
                                )}

                                {/* Additional Information */}
                                <div className="form-section">
                                    <h4>Additional Information</h4>
                                    {selectedDonation.notes && <p><strong>Notes:</strong> {selectedDonation.notes}</p>}
                                    <p><strong>Urgent:</strong> {selectedDonation.isUrgent ? 'Yes' : 'No'}</p>
                                    <p><strong>Created:</strong> {formatDate(selectedDonation.createdAt)}</p>
                                    {selectedDonation.paymentAmount && (
                                        <p><strong>Payment Amount:</strong> {selectedDonation.paymentAmount} PKR</p>
                                    )}
                                </div>

                                {/* Display donation images if available */}
                                {selectedDonation.images && selectedDonation.images.length > 0 && (
                                    <div className="donation-images">
                                        <h4>Images:</h4>
                                        <div className="images-grid">
                                            {selectedDonation.images.map((image, index) => (
                                                <div key={index} className="image-container">
                                                    <img
                                                        src={`${import.meta.env.VITE_API_URL || 'http://localhost:3001'}${image.startsWith('/') ? image : '/' + image}`}
                                                        alt={`Donation ${index + 1}`}
                                                        className="donation-image"
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
                            </div>

                            <div className="verification-form">
                                <div className="form-group">
                                    <label>Verification Notes (Optional):</label>
                                    <textarea
                                        value={verificationNotes}
                                        onChange={(e) => setVerificationNotes(e.target.value)}
                                        placeholder="Add any notes about this donation..."
                                        rows="3"
                                    />
                                </div>

                                <div className="form-group">
                                    <label>Rejection Reason (Required for rejection):</label>
                                    <textarea
                                        value={rejectionReason}
                                        onChange={(e) => setRejectionReason(e.target.value)}
                                        placeholder="Explain why this donation is being rejected..."
                                        rows="3"
                                    />
                                </div>
                            </div>
                        </div>

                        <div className="modal-actions">
                            <button
                                className="btn btn-success"
                                onClick={() => handleVerifyDonation(selectedDonation._id)}
                                disabled={actionLoading}
                            >
                                {actionLoading ? 'Processing...' : '✅ Verify Donation'}
                            </button>
                            <button
                                className="btn btn-danger"
                                onClick={() => handleRejectDonation(selectedDonation._id)}
                                disabled={actionLoading || !rejectionReason.trim()}
                            >
                                {actionLoading ? 'Processing...' : '❌ Reject Donation'}
                            </button>
                            <button
                                className="btn btn-secondary"
                                onClick={() => setSelectedDonation(null)}
                                disabled={actionLoading}
                            >
                                Cancel
                            </button>
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

                .donation-verification {
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

                .donations-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
                    gap: 20px;
                    margin-bottom: 30px;
                }

                .donation-card {
                    background: white;
                    border-radius: 12px;
                    padding: 20px;
                    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
                    border: 1px solid #ecf0f1;
                    transition: transform 0.2s ease, box-shadow 0.2s ease;
                }

                .donation-card:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
                }

                .donation-header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 15px;
                }

                .donation-type {
                    background: #3498db;
                    color: white;
                    padding: 5px 12px;
                    border-radius: 20px;
                    font-size: 12px;
                    font-weight: 500;
                }

                .donation-status {
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

                .donation-info {
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

                .donation-actions {
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

                .donation-images {
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

                .donation-image {
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
                    background: none;
                    border: none;
                    padding: 10px 20px;
                    font-size: 16px;
                    font-weight: 500;
                    cursor: pointer;
                    color: #7f8c8d;
                }

                .stats-dropdown-btn:hover {
                    color: #3498db;
                }

                .stats-dropdown-content {
                    position: absolute;
                    top: 100%;
                    left: 0;
                    background: white;
                    border: 1px solid #ddd;
                    padding: 10px;
                    border-radius: 6px;
                    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
                    display: none;
                }

                .stats-dropdown-content.show {
                    display: block;
                }

                .type-stat-item {
                    display: flex;
                    align-items: center;
                    margin-bottom: 10px;
                }

                .type-icon {
                    font-size: 20px;
                    margin-right: 10px;
                }

                .type-name {
                    font-weight: 500;
                    color: #2c3e50;
                }

                .type-count {
                    color: #7f8c8d;
                    margin-left: auto;
                }

                .type-stat-divider {
                    border-bottom: 1px solid #ddd;
                    margin-bottom: 10px;
                }

                .type-stat-item.total {
                    font-weight: 600;
                    color: #3498db;
                }
            `}</style>
        </div>
    );
};

export default DonationVerification;
