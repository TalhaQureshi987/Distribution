import React, { useState, useEffect } from 'react';
import api from '../api';
import './PaymentManagement.css';

const DeliveryPaymentManagement = () => {
    const [deliveryPayments, setDeliveryPayments] = useState([]);
    const [loading, setLoading] = useState(true);
    const [selectedPayment, setSelectedPayment] = useState(null);
    const [showModal, setShowModal] = useState(false);
    const [actionLoading, setActionLoading] = useState(false);
    const [filter, setFilter] = useState('all');
    const [stats, setStats] = useState(null);
    const [dateFilter, setDateFilter] = useState({
        from: '',
        to: ''
    });
    const [searchTerm, setSearchTerm] = useState('');

    useEffect(() => {
        fetchDeliveryPayments();
        fetchDeliveryStats();
    }, [filter, dateFilter]);

    const fetchDeliveryPayments = async () => {
        try {
            setLoading(true);
            let url = `/payments/delivery?status=${filter}&page=1&limit=50`;

            if (dateFilter.from) url += `&startDate=${dateFilter.from}`;
            if (dateFilter.to) url += `&endDate=${dateFilter.to}`;

            const response = await api.get(url);
            let fetchedPayments = response.data.deliveryPayments || [];

            // Apply search filter
            if (searchTerm.trim()) {
                fetchedPayments = fetchedPayments.filter(payment =>
                    payment.user?.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    payment.user?.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    payment.stripePaymentIntentId?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    payment.description?.toLowerCase().includes(searchTerm.toLowerCase())
                );
            }

            setDeliveryPayments(fetchedPayments);
        } catch (error) {
            console.error('Error fetching delivery payments:', error);
            setDeliveryPayments([]);
        } finally {
            setLoading(false);
        }
    };

    const fetchDeliveryStats = async () => {
        try {
            const response = await api.get('/payments/delivery/stats');
            setStats(response.data.stats);
        } catch (error) {
            console.error('Error fetching delivery stats:', error);
        }
    };

    const handleViewDetails = async (payment) => {
        try {
            setActionLoading(true);
            setSelectedPayment(payment);
            setShowModal(true);
        } catch (error) {
            console.error('Error viewing payment details:', error);
        } finally {
            setActionLoading(false);
        }
    };

    const getStatusBadge = (status) => {
        const statusClasses = {
            completed: 'status-paid',
            paid: 'status-paid',
            pending: 'status-pending',
            processing: 'status-pending',
            failed: 'status-failed',
            canceled: 'status-failed'
        };

        const statusLabels = {
            completed: 'COMPLETED',
            paid: 'PAID',
            pending: 'PENDING',
            processing: 'PROCESSING',
            failed: 'FAILED',
            canceled: 'CANCELED'
        };

        return (
            <span className={`status-badge ${statusClasses[status] || 'status-unknown'}`}>
                {statusLabels[status] || status?.toUpperCase() || 'UNKNOWN'}
            </span>
        );
    };

    const formatAmount = (amount, currency = 'PKR') => {
        if (amount === null || amount === undefined || isNaN(amount)) {
            return `${currency.toUpperCase()} 0`;
        }
        return `${currency.toUpperCase()} ${Number(amount).toLocaleString()}`;
    };

    const formatDate = (dateString) => {
        return new Date(dateString).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    const handleDateFilterChange = (field, value) => {
        setDateFilter(prev => ({
            ...prev,
            [field]: value
        }));
    };

    const clearFilters = () => {
        setFilter('all');
        setDateFilter({ from: '', to: '' });
        setSearchTerm('');
    };

    if (loading) {
        return (
            <div className="payment-management">
                <div className="loading-container">
                    <div className="loading-spinner"></div>
                    <p>Loading delivery payments...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="payment-management">
            <div className="page-header">
                <h1>🚚 Delivery Payment Management</h1>
                <p>Manage delivery payments, track commissions, and view delivery statistics</p>
            </div>

            {/* Delivery Payment Statistics */}
            {stats && (
                <div className="stats-container" style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
                    gap: '15px',
                    marginBottom: '25px'
                }}>
                    <div className="stat-card" style={{
                        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                        color: 'white',
                        padding: '20px',
                        borderRadius: '8px',
                        textAlign: 'center'
                    }}>
                        <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.9' }}>Total Deliveries</h3>
                        <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{stats.totalDeliveryPayments}</p>
                    </div>
                    <div className="stat-card" style={{
                        background: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
                        color: 'white',
                        padding: '20px',
                        borderRadius: '8px',
                        textAlign: 'center'
                    }}>
                        <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.9' }}>Total Revenue</h3>
                        <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{formatAmount(stats.totalDeliveryRevenue, 'PKR')}</p>
                    </div>
                    <div className="stat-card" style={{
                        background: 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)',
                        color: 'white',
                        padding: '20px',
                        borderRadius: '8px',
                        textAlign: 'center'
                    }}>
                        <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.9' }}>Platform Commission</h3>
                        <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{formatAmount(stats.totalCommission, 'PKR')}</p>
                    </div>
                    <div className="stat-card" style={{
                        background: 'linear-gradient(135deg, #fa709a 0%, #fee140 100%)',
                        color: 'white',
                        padding: '20px',
                        borderRadius: '8px',
                        textAlign: 'center'
                    }}>
                        <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.9' }}>Delivery Partner Pay</h3>
                        <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{formatAmount(stats.totalDeliveryPersonPayments, 'PKR')}</p>
                    </div>
                    <div className="stat-card" style={{
                        background: 'linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%)',
                        color: 'white',
                        padding: '20px',
                        borderRadius: '8px',
                        textAlign: 'center'
                    }}>
                        <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.9' }}>Avg Distance</h3>
                        <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{stats.averageDistance?.toFixed(1)} km</p>
                    </div>
                    <div className="stat-card" style={{
                        background: 'linear-gradient(135deg, #a8edea 0%, #fed6e3 100%)',
                        color: '#2c3e50',
                        padding: '20px',
                        borderRadius: '8px',
                        textAlign: 'center'
                    }}>
                        <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.8' }}>Commission Rate</h3>
                        <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{stats.commissionPercentage}%</p>
                    </div>
                </div>
            )}

            {/* Filter Controls */}
            <div className="filter-controls" style={{ flexDirection: 'column', gap: '15px' }}>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '15px', alignItems: 'center' }}>
                    <div className="filter-group">
                        <label>Status:</label>
                        <select
                            value={filter}
                            onChange={(e) => setFilter(e.target.value)}
                            className="filter-select"
                        >
                            <option value="all">All Payments</option>
                            <option value="completed">Completed</option>
                            <option value="pending">Pending</option>
                            <option value="failed">Failed</option>
                        </select>
                    </div>

                    <div className="filter-group">
                        <label>From:</label>
                        <input
                            type="date"
                            value={dateFilter.from}
                            onChange={(e) => handleDateFilterChange('from', e.target.value)}
                            className="filter-select"
                        />
                    </div>

                    <div className="filter-group">
                        <label>To:</label>
                        <input
                            type="date"
                            value={dateFilter.to}
                            onChange={(e) => handleDateFilterChange('to', e.target.value)}
                            className="filter-select"
                        />
                    </div>

                    <div className="filter-group">
                        <label>Search:</label>
                        <input
                            type="text"
                            placeholder="Name, email, payment ID..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="filter-select"
                            style={{ minWidth: '200px' }}
                        />
                    </div>
                </div>

                <div style={{ display: 'flex', gap: '10px' }}>
                    <button onClick={fetchDeliveryPayments} className="refresh-btn">
                        🔄 Refresh
                    </button>
                    <button onClick={clearFilters} className="refresh-btn" style={{ background: '#95a5a6' }}>
                        🗑️ Clear Filters
                    </button>
                </div>
            </div>

            {/* Delivery Payments Table */}
            <div className="payments-table-container">
                {deliveryPayments.length === 0 ? (
                    <div className="no-payments">
                        <p>📋 No delivery payments found for the selected filters.</p>
                        <p style={{ fontSize: '14px', color: '#95a5a6' }}>
                            Try adjusting your filters or check back later for new delivery payments.
                        </p>
                    </div>
                ) : (
                    <table className="payments-table">
                        <thead>
                            <tr>
                                <th>User</th>
                                <th>Email</th>
                                <th>Total Amount</th>
                                <th>Delivery Charges</th>
                                <th>Commission (10%)</th>
                                <th>Partner Payment (90%)</th>
                                <th>Distance</th>
                                <th>Status</th>
                                <th>Date</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {deliveryPayments.map((payment) => (
                                <tr key={payment._id}>
                                    <td>
                                        <div className="user-info">
                                            <strong>{payment.user?.name || 'Unknown User'}</strong>
                                            <small>ID: {payment.user?._id || 'N/A'}</small>
                                            <small style={{ display: 'block', color: '#3498db' }}>
                                                Role: {payment.user?.role || 'N/A'}
                                            </small>
                                        </div>
                                    </td>
                                    <td>{payment.user?.email || 'N/A'}</td>
                                    <td className="amount">
                                        {formatAmount(payment.amount, 'PKR')}
                                    </td>
                                    <td className="amount" style={{ color: '#27ae60' }}>
                                        {formatAmount(payment.deliveryCharges, 'PKR')}
                                    </td>
                                    <td className="amount" style={{ color: '#e74c3c', fontWeight: 'bold' }}>
                                        {formatAmount(payment.commission, 'PKR')}
                                    </td>
                                    <td className="amount" style={{ color: '#3498db' }}>
                                        {formatAmount(payment.deliveryPersonPayment, 'PKR')}
                                    </td>
                                    <td>
                                        <span style={{
                                            background: '#ecf0f1',
                                            padding: '2px 6px',
                                            borderRadius: '4px',
                                            fontSize: '12px'
                                        }}>
                                            {payment.distance?.toFixed(1)} km
                                        </span>
                                    </td>
                                    <td>{getStatusBadge(payment.status)}</td>
                                    <td>{formatDate(payment.createdAt)}</td>
                                    <td>
                                        <button
                                            onClick={() => handleViewDetails(payment)}
                                            className="action-btn view-btn"
                                            disabled={actionLoading}
                                        >
                                            👁️ View Details
                                        </button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>

            {/* Payment Details Modal */}
            {showModal && selectedPayment && (
                <div className="modal-overlay">
                    <div className="modal-content">
                        <div className="modal-header">
                            <h2>🚚 Delivery Payment Details</h2>
                            <button
                                onClick={() => setShowModal(false)}
                                className="close-btn"
                            >
                                ×
                            </button>
                        </div>

                        <div className="modal-body">
                            <div className="payment-details">
                                <div className="detail-group">
                                    <h3>👤 User Information</h3>
                                    <p><strong>Name:</strong> {selectedPayment.user?.name || 'Unknown'}</p>
                                    <p><strong>Email:</strong> {selectedPayment.user?.email || 'N/A'}</p>
                                    <p><strong>Role:</strong> {selectedPayment.user?.role || 'N/A'}</p>
                                    <p><strong>Phone:</strong> {selectedPayment.user?.phone || 'N/A'}</p>
                                </div>

                                <div className="detail-group">
                                    <h3>🚚 Delivery Information</h3>
                                    <p><strong>Distance:</strong> {selectedPayment.distance?.toFixed(2)} km</p>
                                    <p><strong>Delivery Charges:</strong> {formatAmount(selectedPayment.deliveryCharges, 'PKR')}</p>
                                    <p><strong>Platform Commission ({selectedPayment.commissionPercentage}%):</strong>
                                        <span style={{ color: '#e74c3c', fontWeight: 'bold', marginLeft: '5px' }}>
                                            {formatAmount(selectedPayment.commission, 'PKR')}
                                        </span>
                                    </p>
                                    <p><strong>Delivery Partner Payment (90%):</strong>
                                        <span style={{ color: '#27ae60', fontWeight: 'bold', marginLeft: '5px' }}>
                                            {formatAmount(selectedPayment.deliveryPersonPayment, 'PKR')}
                                        </span>
                                    </p>
                                </div>

                                <div className="detail-group">
                                    <h3>💰 Payment Information</h3>
                                    <p><strong>Total Amount:</strong> {formatAmount(selectedPayment.amount, 'PKR')}</p>
                                    <p><strong>Status:</strong> {getStatusBadge(selectedPayment.status)}</p>
                                    <p><strong>Payment Intent ID:</strong> <code>{selectedPayment.stripePaymentIntentId || 'N/A'}</code></p>
                                    <p><strong>Payment Date:</strong> {formatDate(selectedPayment.createdAt)}</p>
                                    {selectedPayment.completedAt && (
                                        <p><strong>Completed At:</strong> {formatDate(selectedPayment.completedAt)}</p>
                                    )}
                                </div>

                                {selectedPayment.description && (
                                    <div className="detail-group">
                                        <h3>📝 Description</h3>
                                        <p>{selectedPayment.description}</p>
                                    </div>
                                )}
                            </div>
                        </div>

                        <div className="modal-footer">
                            <button
                                onClick={() => setShowModal(false)}
                                className="cancel-btn"
                            >
                                Close
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default DeliveryPaymentManagement;
