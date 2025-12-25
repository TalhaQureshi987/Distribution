import React, { useState, useEffect } from 'react';
import api from '../api';

const CompanyPayments = () => {
    const [payments, setPayments] = useState([]);
    const [stats, setStats] = useState({});
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [selectedPayment, setSelectedPayment] = useState(null);
    const [filter, setFilter] = useState('all');

    useEffect(() => {
        fetchCompanyPayments();
        fetchCompanyStats();
    }, [filter]);

    const fetchCompanyPayments = async () => {
        try {
            setLoading(true);
            const response = await api.get(`/payments/admin/company-payments?filter=${filter}`);
            setPayments(response.data.payments || []);
        } catch (error) {
            console.error('Error fetching company payments:', error);
            setError('Failed to load company payments');
        } finally {
            setLoading(false);
        }
    };

    const fetchCompanyStats = async () => {
        try {
            const response = await api.get('/payments/admin/company-stats');
            setStats(response.data || {});
        } catch (error) {
            console.error('Error fetching company stats:', error);
        }
    };

    const formatAmount = (amount) => {
        return `PKR ${amount?.toLocaleString() || 0}`;
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

    const getPaymentTypeBadge = (type) => {
        const typeConfig = {
            registration: { color: 'blue', text: 'Registration Fee', icon: '📝' },
            commission: { color: 'green', text: 'Commission', icon: '💰' },
            request_fee: { color: 'purple', text: 'Request Fee', icon: '📋' },
            penalty: { color: 'red', text: 'Penalty', icon: '⚠️' },
        };

        const config = typeConfig[type] || { color: 'gray', text: type, icon: '💳' };

        return (
            <span className={`payment-type-badge type-${config.color}`}>
                {config.icon} {config.text}
            </span>
        );
    };

    const getStatusBadge = (status) => {
        const statusConfig = {
            completed: { color: 'green', text: 'Completed' },
            pending: { color: 'orange', text: 'Pending' },
            failed: { color: 'red', text: 'Failed' },
            refunded: { color: 'purple', text: 'Refunded' },
        };

        const config = statusConfig[status] || { color: 'gray', text: status };

        return (
            <span className={`status-badge status-${config.color}`}>
                {config.text}
            </span>
        );
    };

    if (loading) {
        return (
            <div className="company-payments">
                <div className="loading-container">
                    <div className="loading-spinner"></div>
                    <p>Loading company payments...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="company-payments">
            <div className="page-header">
                <h1>💰 Company Payments</h1>
                <p>Registration fees, commissions, and company revenue</p>
            </div>

            {error && (
                <div className="error-message">
                    <span>⚠️ {error}</span>
                    <button onClick={fetchCompanyPayments}>Retry</button>
                </div>
            )}

            {/* Stats Cards */}
            <div className="stats-grid">
                <div className="stat-card">
                    <div className="stat-icon">📝</div>
                    <div className="stat-content">
                        <div className="stat-number">{formatAmount(stats.totalRegistrationFees)}</div>
                        <div className="stat-label">Registration Fees</div>
                    </div>
                </div>
                <div className="stat-card">
                    <div className="stat-icon">💰</div>
                    <div className="stat-content">
                        <div className="stat-number">{formatAmount(stats.totalCommissions)}</div>
                        <div className="stat-label">Total Commissions</div>
                    </div>
                </div>
                <div className="stat-card">
                    <div className="stat-icon">📊</div>
                    <div className="stat-content">
                        <div className="stat-number">{formatAmount(stats.totalRevenue)}</div>
                        <div className="stat-label">Total Revenue</div>
                    </div>
                </div>
                <div className="stat-card">
                    <div className="stat-icon">📈</div>
                    <div className="stat-content">
                        <div className="stat-number">{stats.totalTransactions || 0}</div>
                        <div className="stat-label">Total Transactions</div>
                    </div>
                </div>
                <div className="stat-card">
                    <div className="stat-icon">📋</div>
                    <div className="stat-content">
                        <div className="stat-number">{formatAmount(stats.totalRequestFees)}</div>
                        <div className="stat-label">Total Request Fees</div>
                    </div>
                </div>
            </div>

            {/* Filters */}
            <div className="filters">
                <select
                    value={filter}
                    onChange={(e) => setFilter(e.target.value)}
                    className="filter-select"
                >
                    <option value="all">All Payments</option>
                    <option value="registration">Registration Fees</option>
                    <option value="commission">Commissions</option>
                    <option value="request_fee">Request Fees</option>
                    <option value="completed">Completed</option>
                    <option value="pending">Pending</option>
                </select>
            </div>

            {/* Payments Table */}
            <div className="payments-container">
                {payments.length === 0 ? (
                    <div className="empty-state">
                        <div className="empty-icon">💳</div>
                        <h3>No Company Payments</h3>
                        <p>No company payments found for the selected filter</p>
                    </div>
                ) : (
                    <div className="payments-table">
                        <table>
                            <thead>
                                <tr>
                                    <th>Date</th>
                                    <th>User</th>
                                    <th>Type</th>
                                    <th>Amount</th>
                                    <th>Status</th>
                                    <th>Description</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {payments.map((payment) => (
                                    <tr key={payment._id}>
                                        <td>{formatDate(payment.createdAt)}</td>
                                        <td>
                                            <div className="user-info">
                                                <div className="user-name">{payment.userId?.name || 'Unknown'}</div>
                                                <div className="user-email">{payment.userId?.email || 'N/A'}</div>
                                            </div>
                                        </td>
                                        <td>{getPaymentTypeBadge(payment.type)}</td>
                                        <td className="amount">{formatAmount(payment.amount)}</td>
                                        <td>{getStatusBadge(payment.status)}</td>
                                        <td className="description">{payment.description || 'N/A'}</td>
                                        <td>
                                            <button
                                                className="btn btn-primary btn-sm"
                                                onClick={() => setSelectedPayment(payment)}
                                            >
                                                View Details
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>

            {/* Payment Details Modal */}
            {selectedPayment && (
                <div className="modal-overlay">
                    <div className="modal-content">
                        <div className="modal-header">
                            <h2>Payment Details</h2>
                            <button
                                className="close-btn"
                                onClick={() => setSelectedPayment(null)}
                            >
                                ✕
                            </button>
                        </div>

                        <div className="modal-body">
                            <div className="payment-details">
                                <div className="detail-row">
                                    <span className="label">Payment ID:</span>
                                    <span className="value">{selectedPayment._id}</span>
                                </div>
                                <div className="detail-row">
                                    <span className="label">User:</span>
                                    <span className="value">{selectedPayment.userId?.name} ({selectedPayment.userId?.email})</span>
                                </div>
                                <div className="detail-row">
                                    <span className="label">Type:</span>
                                    <span className="value">{getPaymentTypeBadge(selectedPayment.type)}</span>
                                </div>
                                <div className="detail-row">
                                    <span className="label">Amount:</span>
                                    <span className="value amount-large">{formatAmount(selectedPayment.amount)}</span>
                                </div>
                                <div className="detail-row">
                                    <span className="label">Status:</span>
                                    <span className="value">{getStatusBadge(selectedPayment.status)}</span>
                                </div>
                                <div className="detail-row">
                                    <span className="label">Date:</span>
                                    <span className="value">{formatDate(selectedPayment.createdAt)}</span>
                                </div>
                                <div className="detail-row">
                                    <span className="label">Description:</span>
                                    <span className="value">{selectedPayment.description || 'N/A'}</span>
                                </div>
                                {selectedPayment.stripePaymentIntentId && (
                                    <div className="detail-row">
                                        <span className="label">Stripe ID:</span>
                                        <span className="value">{selectedPayment.stripePaymentIntentId}</span>
                                    </div>
                                )}
                            </div>
                        </div>

                        <div className="modal-actions">
                            <button
                                className="btn btn-secondary"
                                onClick={() => setSelectedPayment(null)}
                            >
                                Close
                            </button>
                        </div>
                    </div>
                </div>
            )}

            <style jsx>{`
                .company-payments {
                    padding: 20px;
                    max-width: 1400px;
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

                .stats-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                    gap: 20px;
                    margin-bottom: 30px;
                }

                .stat-card {
                    background: white;
                    border-radius: 12px;
                    padding: 20px;
                    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
                    border: 1px solid #ecf0f1;
                    display: flex;
                    align-items: center;
                    gap: 15px;
                }

                .stat-icon {
                    font-size: 2rem;
                    background: #f8f9fa;
                    padding: 15px;
                    border-radius: 50%;
                }

                .stat-number {
                    font-size: 1.5rem;
                    font-weight: 700;
                    color: #2c3e50;
                    margin-bottom: 5px;
                }

                .stat-label {
                    color: #7f8c8d;
                    font-size: 0.9rem;
                }

                .filters {
                    margin-bottom: 20px;
                    display: flex;
                    gap: 15px;
                    align-items: center;
                }

                .filter-select {
                    padding: 8px 12px;
                    border: 1px solid #ddd;
                    border-radius: 6px;
                    font-size: 14px;
                }

                .payments-table {
                    background: white;
                    border-radius: 12px;
                    overflow: hidden;
                    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
                }

                .payments-table table {
                    width: 100%;
                    border-collapse: collapse;
                }

                .payments-table th,
                .payments-table td {
                    padding: 12px;
                    text-align: left;
                    border-bottom: 1px solid #ecf0f1;
                }

                .payments-table th {
                    background: #f8f9fa;
                    font-weight: 600;
                    color: #2c3e50;
                }

                .user-info {
                    display: flex;
                    flex-direction: column;
                }

                .user-name {
                    font-weight: 500;
                    color: #2c3e50;
                }

                .user-email {
                    font-size: 0.85rem;
                    color: #7f8c8d;
                }

                .payment-type-badge {
                    padding: 4px 8px;
                    border-radius: 12px;
                    font-size: 0.75rem;
                    font-weight: 500;
                }

                .type-blue {
                    background: #e3f2fd;
                    color: #1976d2;
                }

                .type-green {
                    background: #e8f5e8;
                    color: #2e7d32;
                }

                .type-red {
                    background: #ffebee;
                    color: #c62828;
                }

                .type-purple {
                    background: #e1bee7;
                    color: #4a148c;
                }

                .status-badge {
                    padding: 4px 8px;
                    border-radius: 12px;
                    font-size: 0.75rem;
                    font-weight: 500;
                }

                .status-green {
                    background: #d4edda;
                    color: #155724;
                }

                .status-orange {
                    background: #fff3cd;
                    color: #856404;
                }

                .status-red {
                    background: #f8d7da;
                    color: #721c24;
                }

                .status-purple {
                    background: #e1bee7;
                    color: #4a148c;
                }

                .amount {
                    font-weight: 600;
                    color: #27ae60;
                }

                .amount-large {
                    font-size: 1.2rem;
                    font-weight: 700;
                    color: #27ae60;
                }

                .description {
                    max-width: 200px;
                    overflow: hidden;
                    text-overflow: ellipsis;
                    white-space: nowrap;
                }

                .btn {
                    padding: 6px 12px;
                    border: none;
                    border-radius: 6px;
                    font-size: 12px;
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

                .btn-secondary {
                    background: #95a5a6;
                    color: white;
                }

                .btn-secondary:hover {
                    background: #7f8c8d;
                }

                .btn-sm {
                    padding: 4px 8px;
                    font-size: 11px;
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

                .modal-content {
                    background: white;
                    border-radius: 12px;
                    padding: 30px;
                    max-width: 600px;
                    width: 90%;
                    max-height: 80vh;
                    overflow-y: auto;
                }

                .modal-header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 20px;
                }

                .modal-header h2 {
                    color: #2c3e50;
                    margin: 0;
                }

                .close-btn {
                    background: none;
                    border: none;
                    font-size: 1.5rem;
                    cursor: pointer;
                    color: #7f8c8d;
                }

                .close-btn:hover {
                    color: #2c3e50;
                }

                .payment-details {
                    margin-bottom: 20px;
                }

                .detail-row {
                    display: flex;
                    justify-content: space-between;
                    margin-bottom: 12px;
                    padding-bottom: 8px;
                    border-bottom: 1px solid #ecf0f1;
                }

                .detail-row:last-child {
                    border-bottom: none;
                }

                .label {
                    font-weight: 600;
                    color: #2c3e50;
                }

                .value {
                    color: #7f8c8d;
                }

                .modal-actions {
                    display: flex;
                    justify-content: flex-end;
                    gap: 10px;
                }

                .empty-state {
                    text-align: center;
                    padding: 60px 20px;
                    color: #7f8c8d;
                }

                .empty-icon {
                    font-size: 3rem;
                    margin-bottom: 20px;
                }

                .empty-state h3 {
                    margin-bottom: 10px;
                    color: #2c3e50;
                }

                .error-message {
                    background: #f8d7da;
                    color: #721c24;
                    padding: 15px;
                    border-radius: 8px;
                    margin-bottom: 20px;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                }

                .loading-container {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    padding: 60px 20px;
                }

                .loading-spinner {
                    width: 40px;
                    height: 40px;
                    border: 4px solid #ecf0f1;
                    border-top: 4px solid #3498db;
                    border-radius: 50%;
                    animation: spin 1s linear infinite;
                    margin-bottom: 20px;
                }

                @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                }
            `}</style>
        </div>
    );
};

export default CompanyPayments;
