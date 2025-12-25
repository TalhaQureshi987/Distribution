import React, { useState, useEffect } from 'react';
import './DeliveryManagement.css';

const DeliveryManagement = () => {
    const [activeTab, setActiveTab] = useState('deliveries');
    const [deliveries, setDeliveries] = useState([]);
    const [payoutRequests, setPayoutRequests] = useState([]);
    const [personnel, setPersonnel] = useState([]);
    const [analytics, setAnalytics] = useState(null);
    const [loading, setLoading] = useState(false);
    const [filters, setFilters] = useState({
        status: '',
        deliveryType: '',
        dateFrom: '',
        dateTo: '',
        search: ''
    });
    const [pagination, setPagination] = useState({
        current: 1,
        total: 1,
        limit: 20
    });

    // Fetch deliveries
    const fetchDeliveries = async (page = 1) => {
        setLoading(true);
        try {
            const token = localStorage.getItem('admin_token');
            const queryParams = new URLSearchParams({
                page,
                limit: pagination.limit,
                ...filters
            });

            const response = await fetch(`http://localhost:3001/api/admin/delivery/deliveries?${queryParams}`, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            if (response.ok) {
                const data = await response.json();
                setDeliveries(data.deliveries);
                setPagination(data.pagination);
            }
        } catch (error) {
            console.error('Error fetching deliveries:', error);
        } finally {
            setLoading(false);
        }
    };

    // Fetch payout requests
    const fetchPayoutRequests = async (page = 1) => {
        setLoading(true);
        try {
            const token = localStorage.getItem('admin_token');
            const response = await fetch(`http://localhost:3001/api/admin/delivery/payouts?page=${page}&limit=${pagination.limit}`, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            if (response.ok) {
                const data = await response.json();
                setPayoutRequests(data.payoutRequests);
                setPagination(data.pagination);
            }
        } catch (error) {
            console.error('Error fetching payout requests:', error);
        } finally {
            setLoading(false);
        }
    };

    // Fetch delivery personnel
    const fetchPersonnel = async (page = 1) => {
        setLoading(true);
        try {
            const token = localStorage.getItem('admin_token');
            const response = await fetch(`http://localhost:3001/api/admin/delivery/personnel?page=${page}&limit=${pagination.limit}`, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            if (response.ok) {
                const data = await response.json();
                setPersonnel(data.personnel);
                setPagination(data.pagination);
            }
        } catch (error) {
            console.error('Error fetching personnel:', error);
        } finally {
            setLoading(false);
        }
    };

    // Fetch analytics
    const fetchAnalytics = async (period = '30') => {
        setLoading(true);
        try {
            const token = localStorage.getItem('admin_token');
            const response = await fetch(`http://localhost:3001/api/admin/delivery/analytics?period=${period}`, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            if (response.ok) {
                const data = await response.json();
                setAnalytics(data.analytics);
            }
        } catch (error) {
            console.error('Error fetching analytics:', error);
        } finally {
            setLoading(false);
        }
    };

    // Cancel delivery
    const cancelDelivery = async (deliveryId, reason) => {
        // Frontend validation
        if (!reason || reason.trim().length < 5) {
            alert('Cancellation reason must be at least 5 characters long');
            return;
        }

        if (!window.confirm(`Are you sure you want to cancel this delivery?\nReason: ${reason.trim()}`)) {
            return;
        }

        try {
            const token = localStorage.getItem('admin_token');
            if (!token) {
                alert('Admin authentication required');
                window.location.href = '/login';
                return;
            }

            const response = await fetch(`http://localhost:3001/api/admin/delivery/deliveries/${deliveryId}/cancel`, {
                method: 'PATCH',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ reason: reason.trim() })
            });

            const data = await response.json();

            if (response.ok) {
                alert('Delivery cancelled successfully');
                fetchDeliveries(pagination.current);
            } else {
                alert(`Failed to cancel delivery: ${data.message || 'Unknown error'}`);
            }
        } catch (error) {
            console.error('Error cancelling delivery:', error);
            alert('Network error occurred while cancelling delivery');
        }
    };

    // Approve payout
    const approvePayout = async (earningId, transactionId) => {
        // Frontend validation
        if (!transactionId || transactionId.trim().length < 5) {
            alert('Transaction ID must be at least 5 characters long');
            return;
        }

        // Check for valid transaction ID format (alphanumeric)
        const transactionIdRegex = /^[a-zA-Z0-9]+$/;
        if (!transactionIdRegex.test(transactionId.trim())) {
            alert('Transaction ID must contain only letters and numbers');
            return;
        }

        if (!window.confirm(`Approve payout with Transaction ID: ${transactionId.trim()}?\nThis action cannot be undone.`)) {
            return;
        }

        try {
            const token = localStorage.getItem('admin_token');
            if (!token) {
                alert('Admin authentication required');
                window.location.href = '/login';
                return;
            }

            const response = await fetch(`http://localhost:3001/api/admin/delivery/payouts/${earningId}/approve`, {
                method: 'PATCH',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ transactionId: transactionId.trim() })
            });

            const data = await response.json();

            if (response.ok) {
                alert('Payout approved successfully');
                fetchPayoutRequests(pagination.current);
            } else {
                alert(`Failed to approve payout: ${data.message || 'Unknown error'}`);
            }
        } catch (error) {
            console.error('Error approving payout:', error);
            alert('Network error occurred while approving payout');
        }
    };

    // Reject payout
    const rejectPayout = async (earningId, reason) => {
        // Frontend validation
        if (!reason || reason.trim().length < 5) {
            alert('Rejection reason must be at least 5 characters long');
            return;
        }

        if (!window.confirm(`Reject payout with reason: ${reason.trim()}?\nThis will return the amount to user's pending earnings.`)) {
            return;
        }

        try {
            const token = localStorage.getItem('admin_token');
            if (!token) {
                alert('Admin authentication required');
                window.location.href = '/login';
                return;
            }

            const response = await fetch(`http://localhost:3001/api/admin/delivery/payouts/${earningId}/reject`, {
                method: 'PATCH',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ reason: reason.trim() })
            });

            const data = await response.json();

            if (response.ok) {
                alert('Payout rejected successfully');
                fetchPayoutRequests(pagination.current);
            } else {
                alert(`Failed to reject payout: ${data.message || 'Unknown error'}`);
            }
        } catch (error) {
            console.error('Error rejecting payout:', error);
            alert('Network error occurred while rejecting payout');
        }
    };

    useEffect(() => {
        switch (activeTab) {
            case 'deliveries':
                fetchDeliveries();
                break;
            case 'payouts':
                fetchPayoutRequests();
                break;
            case 'personnel':
                fetchPersonnel();
                break;
            case 'analytics':
                fetchAnalytics();
                break;
            default:
                break;
        }
    }, [activeTab]);

    const getStatusColor = (status) => {
        const colors = {
            pending: '#ffa500',
            accepted: '#2196f3',
            in_progress: '#ff9800',
            completed: '#4caf50',
            cancelled: '#f44336'
        };
        return colors[status] || '#666';
    };

    const formatCurrency = (amount) => {
        return `PKR ${amount?.toFixed(2) || '0.00'}`;
    };

    const formatDate = (date) => {
        return new Date(date).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    return (
        <div className="delivery-management">
            <div className="delivery-header">
                <h1>🚚 Delivery Management</h1>
                <p>Comprehensive delivery system oversight and management</p>
            </div>

            <div className="delivery-tabs">
                <button
                    className={`tab-button ${activeTab === 'deliveries' ? 'active' : ''}`}
                    onClick={() => setActiveTab('deliveries')}
                >
                    📦 Deliveries
                </button>
                <button
                    className={`tab-button ${activeTab === 'payouts' ? 'active' : ''}`}
                    onClick={() => setActiveTab('payouts')}
                >
                    💸 Payouts
                </button>
                <button
                    className={`tab-button ${activeTab === 'personnel' ? 'active' : ''}`}
                    onClick={() => setActiveTab('personnel')}
                >
                    👥 Personnel
                </button>
                <button
                    className={`tab-button ${activeTab === 'analytics' ? 'active' : ''}`}
                    onClick={() => setActiveTab('analytics')}
                >
                    📊 Analytics
                </button>
            </div>

            {loading && <div className="loading">Loading...</div>}

            {/* Deliveries Tab */}
            {activeTab === 'deliveries' && (
                <div className="tab-content">
                    <div className="filters">
                        <select
                            value={filters.status}
                            onChange={(e) => setFilters({ ...filters, status: e.target.value })}
                        >
                            <option value="">All Statuses</option>
                            <option value="pending">Pending</option>
                            <option value="accepted">Accepted</option>
                            <option value="in_progress">In Progress</option>
                            <option value="completed">Completed</option>
                            <option value="cancelled">Cancelled</option>
                        </select>

                        <select
                            value={filters.deliveryType}
                            onChange={(e) => setFilters({ ...filters, deliveryType: e.target.value })}
                        >
                            <option value="">All Types</option>
                            <option value="volunteer">Volunteer</option>
                            <option value="paid">Paid</option>
                        </select>

                        <button onClick={() => fetchDeliveries(1)}>Apply Filters</button>
                    </div>

                    <div className="deliveries-grid">
                        {deliveries.map(delivery => (
                            <div key={delivery._id} className="delivery-card">
                                <div className="delivery-header">
                                    <span
                                        className="status-badge"
                                        style={{ backgroundColor: getStatusColor(delivery.status) }}
                                    >
                                        {delivery.status}
                                    </span>
                                    <span className="delivery-type">{delivery.deliveryType}</span>
                                </div>

                                <div className="delivery-info">
                                    <p><strong>ID:</strong> {delivery._id.slice(-8)}</p>
                                    <p><strong>Item:</strong> {delivery.itemType}</p>
                                    <p><strong>Distance:</strong> {delivery.estimatedDistance?.toFixed(2) || 0} km</p>
                                    <p><strong>Earning:</strong> {formatCurrency(delivery.totalEarning)}</p>
                                    <p><strong>Created:</strong> {formatDate(delivery.createdAt)}</p>

                                    {delivery.deliveryPerson && (
                                        <p><strong>Assigned to:</strong> {delivery.deliveryPerson.name}</p>
                                    )}
                                </div>

                                {!['completed', 'cancelled'].includes(delivery.status) && (
                                    <div className="delivery-actions">
                                        <button
                                            className="cancel-btn"
                                            onClick={() => {
                                                const reason = prompt('Enter cancellation reason (minimum 5 characters):');
                                                if (reason && reason.trim().length >= 5) {
                                                    cancelDelivery(delivery._id, reason);
                                                } else if (reason !== null) {
                                                    alert('Cancellation reason must be at least 5 characters long');
                                                }
                                            }}
                                        >
                                            Cancel
                                        </button>
                                    </div>
                                )}
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {/* Payouts Tab */}
            {activeTab === 'payouts' && (
                <div className="tab-content">
                    <div className="payouts-grid">
                        {payoutRequests.map(payout => (
                            <div key={payout._id} className="payout-card">
                                <div className="payout-header">
                                    <span className="payout-amount">{formatCurrency(payout.netAmount)}</span>
                                    <span className="payout-status">{payout.status}</span>
                                </div>

                                <div className="payout-info">
                                    <p><strong>User:</strong> {payout.user.name}</p>
                                    <p><strong>Email:</strong> {payout.user.email}</p>
                                    <p><strong>Method:</strong> {payout.payoutRequest.method}</p>
                                    <p><strong>Requested:</strong> {formatDate(payout.payoutRequest.requestedAt)}</p>
                                </div>

                                {payout.status === 'requested' && (
                                    <div className="payout-actions">
                                        <button
                                            className="approve-btn"
                                            onClick={() => {
                                                const transactionId = prompt('Enter transaction ID (minimum 5 characters, alphanumeric only):');
                                                if (transactionId && transactionId.trim().length >= 5) {
                                                    const regex = /^[a-zA-Z0-9]+$/;
                                                    if (regex.test(transactionId.trim())) {
                                                        approvePayout(payout._id, transactionId);
                                                    } else {
                                                        alert('Transaction ID must contain only letters and numbers');
                                                    }
                                                } else if (transactionId !== null) {
                                                    alert('Transaction ID must be at least 5 characters long');
                                                }
                                            }}
                                        >
                                            Approve
                                        </button>
                                        <button
                                            className="reject-btn"
                                            onClick={() => {
                                                const reason = prompt('Enter rejection reason (minimum 5 characters):');
                                                if (reason && reason.trim().length >= 5) {
                                                    rejectPayout(payout._id, reason);
                                                } else if (reason !== null) {
                                                    alert('Rejection reason must be at least 5 characters long');
                                                }
                                            }}
                                        >
                                            Reject
                                        </button>
                                    </div>
                                )}
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {/* Personnel Tab */}
            {activeTab === 'personnel' && (
                <div className="tab-content">
                    <div className="personnel-grid">
                        {personnel.map(person => (
                            <div key={person._id} className="personnel-card">
                                <div className="personnel-header">
                                    <h3>{person.name}</h3>
                                    <span className={`status-badge ${person.status}`}>{person.status}</span>
                                </div>

                                <div className="personnel-info">
                                    <p><strong>Email:</strong> {person.email}</p>
                                    <p><strong>Phone:</strong> {person.phone}</p>
                                    <p><strong>Total Earnings:</strong> {formatCurrency(person.totalEarnings)}</p>
                                    <p><strong>Pending:</strong> {formatCurrency(person.pendingEarnings)}</p>
                                    <p><strong>Joined:</strong> {formatDate(person.createdAt)}</p>
                                </div>

                                <div className="personnel-stats">
                                    <div className="stat">
                                        <span className="stat-value">{person.deliveryStats.totalDeliveries}</span>
                                        <span className="stat-label">Total Deliveries</span>
                                    </div>
                                    <div className="stat">
                                        <span className="stat-value">{person.deliveryStats.completedDeliveries}</span>
                                        <span className="stat-label">Completed</span>
                                    </div>
                                    <div className="stat">
                                        <span className="stat-value">{person.deliveryStats.activeDeliveries}</span>
                                        <span className="stat-label">Active</span>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {/* Analytics Tab */}
            {activeTab === 'analytics' && analytics && (
                <div className="tab-content">
                    <div className="analytics-grid">
                        <div className="analytics-card">
                            <h3>📈 Performance by Type</h3>
                            {analytics.performanceByType.map(type => (
                                <div key={type._id} className="performance-item">
                                    <span className="type-name">{type._id}</span>
                                    <div className="performance-stats">
                                        <span>Total: {type.totalDeliveries}</span>
                                        <span>Completed: {type.completedDeliveries}</span>
                                        <span>Rate: {(type.completionRate * 100).toFixed(1)}%</span>
                                        <span>Earnings: {formatCurrency(type.totalEarnings)}</span>
                                    </div>
                                </div>
                            ))}
                        </div>

                        <div className="analytics-card">
                            <h3>🏆 Top Performers</h3>
                            {analytics.topDeliveryPersonnel.map((person, index) => (
                                <div key={person._id} className="performer-item">
                                    <span className="rank">#{index + 1}</span>
                                    <span className="performer-name">{person.name}</span>
                                    <div className="performer-stats">
                                        <span>{person.completedDeliveries} deliveries</span>
                                        <span>{formatCurrency(person.totalEarnings)}</span>
                                    </div>
                                </div>
                            ))}
                        </div>

                        <div className="analytics-card">
                            <h3>💰 Earnings Overview</h3>
                            <div className="earnings-stats">
                                <div className="earning-stat">
                                    <span className="stat-label">Total Earnings</span>
                                    <span className="stat-value">{formatCurrency(analytics.earningsOverview.totalEarnings)}</span>
                                </div>
                                <div className="earning-stat">
                                    <span className="stat-label">Commission</span>
                                    <span className="stat-value">{formatCurrency(analytics.earningsOverview.totalCommission)}</span>
                                </div>
                                <div className="earning-stat">
                                    <span className="stat-label">Net Earnings</span>
                                    <span className="stat-value">{formatCurrency(analytics.earningsOverview.totalNetEarnings)}</span>
                                </div>
                                <div className="earning-stat">
                                    <span className="stat-label">Pending Payouts</span>
                                    <span className="stat-value">{formatCurrency(analytics.earningsOverview.pendingPayouts)}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Pagination */}
            <div className="pagination">
                <button
                    disabled={pagination.current <= 1}
                    onClick={() => {
                        const newPage = pagination.current - 1;
                        switch (activeTab) {
                            case 'deliveries': fetchDeliveries(newPage); break;
                            case 'payouts': fetchPayoutRequests(newPage); break;
                            case 'personnel': fetchPersonnel(newPage); break;
                        }
                    }}
                >
                    Previous
                </button>

                <span>Page {pagination.current} of {pagination.total}</span>

                <button
                    disabled={pagination.current >= pagination.total}
                    onClick={() => {
                        const newPage = pagination.current + 1;
                        switch (activeTab) {
                            case 'deliveries': fetchDeliveries(newPage); break;
                            case 'payouts': fetchPayoutRequests(newPage); break;
                            case 'personnel': fetchPersonnel(newPage); break;
                        }
                    }}
                >
                    Next
                </button>
            </div>
        </div>
    );
};

export default DeliveryManagement;
