import React, { useState, useEffect } from 'react';
import api from '../api';
import './PaymentManagement.css';

const PaymentManagement = () => {
  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedPayment, setSelectedPayment] = useState(null);
  const [showModal, setShowModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [editFormData, setEditFormData] = useState({});
  const [filter, setFilter] = useState('all'); // all, completed, pending, failed
  const [stats, setStats] = useState(null);
  const [dateFilter, setDateFilter] = useState({
    from: '',
    to: ''
  });
  const [searchTerm, setSearchTerm] = useState('');
  const [paymentType, setPaymentType] = useState('all_payments'); // deliveries or all_payments
  const [activeTab, setActiveTab] = useState('payments'); // payments or revenue
  const [paymentStatusView, setPaymentStatusView] = useState('all'); // all, pending, completed
  const [deliveryPayments, setDeliveryPayments] = useState([]);
  const [loadingDelivery, setLoadingDelivery] = useState(false);

  useEffect(() => {
    fetchPayments();
    fetchPaymentStats();
    if (paymentType === 'deliveries') {
      fetchDeliveryPayments();
    }
  }, [filter, dateFilter, paymentType]);

  const fetchPayments = async () => {
    try {
      setLoading(true);
      let url = `/payments/unified?type=${paymentType}&filter=${filter}`;

      if (dateFilter.from) url += `&dateFrom=${dateFilter.from}`;
      if (dateFilter.to) url += `&dateTo=${dateFilter.to}`;

      const response = await api.get(url);

      let fetchedPayments = response.data.payments || [];

      // Apply search filter on frontend
      if (searchTerm.trim()) {
        fetchedPayments = fetchedPayments.filter(payment =>
          payment.user?.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
          payment.user?.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
          payment.stripePaymentIntentId?.toLowerCase().includes(searchTerm.toLowerCase()) ||
          payment.description?.toLowerCase().includes(searchTerm.toLowerCase())
        );
      }

      setPayments(fetchedPayments);
    } catch (error) {
      console.error('Error fetching payments:', error);
      setPayments([]);
    } finally {
      setLoading(false);
    }
  };

  const fetchPaymentStats = async () => {
    try {
      const token = localStorage.getItem('admin_token');

      // Fetch both general payment stats and commission-specific stats
      const [generalResponse, commissionResponse, revenueResponse] = await Promise.all([
        fetch(`http://localhost:3001/api/payments/admin/stats`, {
          headers: { 'Authorization': `Bearer ${token}` }
        }),
        fetch(`http://localhost:3001/api/payments/admin/commission-stats`, {
          headers: { 'Authorization': `Bearer ${token}` }
        }),
        fetch(`http://localhost:3001/api/payments/admin/revenue-analytics`, {
          headers: { 'Authorization': `Bearer ${token}` }
        })
      ]);

      if (generalResponse.ok) {
        const generalData = await generalResponse.json();
        console.log('📊 General payment stats:', generalData);

        let combinedStats = { ...generalData.stats };

        if (commissionResponse.ok) {
          const commissionData = await commissionResponse.json();
          console.log('💰 Commission stats:', commissionData);

          // Combine stats with commission data
          combinedStats = {
            ...combinedStats,
            commissionFees: commissionData.stats?.totalCommission || 0,
            totalCommissionPayments: commissionData.stats?.totalPayments || 0,
            avgCommission: commissionData.stats?.avgCommission || 0
          };
        } else {
          console.warn('⚠️ Commission stats failed, using general stats only');
          combinedStats = {
            ...combinedStats,
            commissionFees: 0,
            totalCommissionPayments: 0,
            avgCommission: 0
          };
        }

        // Add revenue analytics data if available
        if (revenueResponse.ok) {
          const revenueData = await revenueResponse.json();
          console.log('💵 Revenue analytics:', revenueData);
          combinedStats = {
            ...combinedStats,
            ...revenueData.stats
          };
        } else {
          console.warn('⚠️ Revenue analytics failed');
        }

        setStats(combinedStats);
      }
    } catch (error) {
      console.error('❌ Error fetching payment stats:', error);
      setError('Failed to load payment statistics');
    }
  };

  const fetchDeliveryPayments = async () => {
    try {
      setLoadingDelivery(true);
      const token = localStorage.getItem('admin_token');

      let url = `/payments/admin/delivery-payments?`;
      if (dateFilter.from) url += `dateFrom=${dateFilter.from}&`;
      if (dateFilter.to) url += `dateTo=${dateFilter.to}&`;
      if (filter !== 'all') url += `status=${filter}&`;

      const response = await fetch(`http://localhost:3001/api${url}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (response.ok) {
        const data = await response.json();
        setDeliveryPayments(data.deliveries || []);
      } else {
        console.error('Failed to fetch delivery payments');
        setDeliveryPayments([]);
      }
    } catch (error) {
      console.error('Error fetching delivery payments:', error);
      setDeliveryPayments([]);
    } finally {
      setLoadingDelivery(false);
    }
  };

  const handleViewDetails = async (payment) => {
    try {
      setActionLoading(true);
      const response = await api.get(`/payments/admin/${payment._id}`);
      setSelectedPayment(response.data.payment);
      setShowModal(true);
    } catch (error) {
      console.error('Error fetching payment details:', error);
      alert('Error fetching payment details: ' + (error.response?.data?.message || error.message));
    } finally {
      setActionLoading(false);
    }
  };

  const handleEdit = (payment) => {
    setSelectedPayment(payment);
    setShowEditModal(true);
    setEditFormData({
      amount: payment.amount,
      status: payment.status,
      description: payment.description || ''
    });
  };

  const handleDelete = async (paymentId) => {
    if (!window.confirm('Are you sure you want to delete this payment? This will mark it as deleted but preserve the record for audit purposes.')) {
      return;
    }

    try {
      setActionLoading(true);
      await api.delete(`/payments/admin/${paymentId}`);

      // Update payments list
      setPayments(payments.filter(p => p._id !== paymentId));
      alert('Payment deleted successfully! (Soft delete - record preserved for audit)');

      // Refresh stats
      fetchPaymentStats();
    } catch (error) {
      console.error('Error deleting payment:', error);
      alert('Error deleting payment: ' + (error.response?.data?.message || error.message));
    } finally {
      setActionLoading(false);
    }
  };

  const handleUpdate = async () => {
    try {
      setActionLoading(true);
      const response = await api.put(`/payments/admin/${selectedPayment._id}`, editFormData);

      // Update payments list
      const updatedPayments = payments.map(p =>
        p._id === selectedPayment._id
          ? { ...p, ...editFormData, updatedAt: new Date().toISOString() }
          : p
      );
      setPayments(updatedPayments);

      setShowEditModal(false);
      setShowModal(false);
      alert('Payment updated successfully!');

      // Refresh stats
      fetchPaymentStats();
    } catch (error) {
      console.error('Error updating payment:', error);
      alert('Error updating payment: ' + (error.response?.data?.message || error.message));
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

  const getCurrentStats = () => {
    if (!stats) return null;

    if (paymentType === 'deliveries') {
      return stats.deliveryStats;
    } else if (paymentType === 'all_payments') {
      return stats.companyStats;
    }
    return stats.combined;
  };

  const currentStats = getCurrentStats();

  const getFilteredPayments = () => {
    if (paymentStatusView === 'all') return payments;

    return payments.filter(payment => payment.status === paymentStatusView);
  };

  if (loading) {
    return (
      <div className="payment-management">
        <div className="loading-container">
          <div className="loading-spinner"></div>
          <p>Loading payments...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="payment-management">
      <style jsx>{`
                .payment-management {
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

                .payment-type-toggle {
                    display: flex;
                    justify-content: center;
                    margin-bottom: 30px;
                    gap: 10px;
                }

                .toggle-btn {
                    padding: 12px 24px;
                    border: 2px solid #3498db;
                    background: white;
                    color: #3498db;
                    border-radius: 25px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.3s ease;
                    font-size: 14px;
                }

                .toggle-btn:hover {
                    background: #ecf0f1;
                    transform: translateY(-2px);
                }

                .toggle-btn.active {
                    background: #3498db;
                    color: white;
                    box-shadow: 0 4px 12px rgba(52, 152, 219, 0.3);
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

                .tab-navigation {
                    display: flex;
                    justify-content: center;
                    margin-bottom: 30px;
                    border-bottom: 2px solid #ecf0f1;
                }

                .tab-btn {
                    padding: 15px 30px;
                    border: none;
                    background: transparent;
                    color: #7f8c8d;
                    font-weight: 600;
                    font-size: 16px;
                    cursor: pointer;
                    transition: all 0.3s ease;
                    border-bottom: 3px solid transparent;
                }

                .tab-btn:hover {
                    color: #3498db;
                    background: #f8f9fa;
                }

                .tab-btn.active {
                    color: #3498db;
                    border-bottom-color: #3498db;
                    background: #f8f9fa;
                }

                .payment-status-tabs {
                    display: flex;
                    justify-content: center;
                    margin-bottom: 20px;
                    gap: 10px;
                }

                .status-tab-btn {
                    padding: 10px 20px;
                    border: 2px solid #ecf0f1;
                    background: white;
                    color: #7f8c8d;
                    border-radius: 25px;
                    font-weight: 500;
                    cursor: pointer;
                    transition: all 0.3s ease;
                }

                .status-tab-btn:hover {
                    border-color: #3498db;
                    color: #3498db;
                }

                .status-tab-btn.active {
                    background: #3498db;
                    color: white;
                    border-color: #3498db;
                }

                .revenue-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                    gap: 25px;
                    margin-bottom: 30px;
                }

                .revenue-card {
                    background: white;
                    border-radius: 15px;
                    padding: 25px;
                    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
                    border: 1px solid #ecf0f1;
                }

                .revenue-card h3 {
                    color: #2c3e50;
                    margin-bottom: 20px;
                    font-size: 18px;
                    display: flex;
                    align-items: center;
                    gap: 10px;
                }

                .revenue-item {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 12px 0;
                    border-bottom: 1px solid #ecf0f1;
                }

                .revenue-item:last-child {
                    border-bottom: none;
                }

                .revenue-label {
                    color: #7f8c8d;
                    font-weight: 500;
                }

                .revenue-amount {
                    font-weight: 700;
                    font-size: 16px;
                    color: #27ae60;
                }

                .revenue-total {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 20px;
                    border-radius: 10px;
                    text-align: center;
                    margin-top: 20px;
                }
            `}</style>

      <div className="page-header">
        <h1>💰 Payment Management System</h1>
        <p>Comprehensive payment tracking and revenue analytics</p>
      </div>

      {/* Tab Navigation */}
      <div className="tab-navigation">
        <button
          className={`tab-btn ${activeTab === 'payments' ? 'active' : ''}`}
          onClick={() => setActiveTab('payments')}
        >
          📊 Payment Management
        </button>
        <button
          className={`tab-btn ${activeTab === 'revenue' ? 'active' : ''}`}
          onClick={() => setActiveTab('revenue')}
        >
          💵 Revenue Analytics
        </button>
      </div>

      {activeTab === 'payments' && (
        <>
          {/* Payment Status View Tabs */}
          <div className="payment-status-tabs">
            <button
              className={`status-tab-btn ${paymentStatusView === 'all' ? 'active' : ''}`}
              onClick={() => setPaymentStatusView('all')}
            >
              📈 All Payments ({payments.length})
            </button>
            <button
              className={`status-tab-btn ${paymentStatusView === 'pending' ? 'active' : ''}`}
              onClick={() => setPaymentStatusView('pending')}
            >
              ⏳ Pending ({payments.filter(p => p.status === 'pending' || p.status === 'processing').length})
            </button>
            <button
              className={`status-tab-btn ${paymentStatusView === 'completed' ? 'active' : ''}`}
              onClick={() => setPaymentStatusView('completed')}
            >
              ✅ Completed ({payments.filter(p => p.status === 'completed' || p.status === 'paid').length})
            </button>
          </div>

          {/* Payment Type Toggle */}
          <div className="payment-type-toggle">
            <button
              className={`toggle-btn ${paymentType === 'deliveries' ? 'active' : ''}`}
              onClick={() => setPaymentType('deliveries')}
            >
              🚚 Deliveries
            </button>
            <button
              className={`toggle-btn ${paymentType === 'all_payments' ? 'active' : ''}`}
              onClick={() => setPaymentType('all_payments')}
            >
              � All Payments (Non-Delivery)
            </button>
          </div>

          {/* Payment Statistics */}
          {currentStats && (
            <div className="stats-grid">
              <div className="stat-card" style={{
                background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                color: 'white',
                padding: '20px',
                borderRadius: '8px',
                textAlign: 'center'
              }}>
                <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.9' }}>Total Payments</h3>
                <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{currentStats.totalPayments || 0}</p>
              </div>
              <div className="stat-card" style={{
                background: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
                color: 'white',
                padding: '20px',
                borderRadius: '8px',
                textAlign: 'center'
              }}>
                <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.9' }}>Total Revenue</h3>
                <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{formatAmount(currentStats.totalRevenue || 0, 'PKR')}</p>
              </div>
              <div className="stat-card" style={{
                background: 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)',
                color: 'white',
                padding: '20px',
                borderRadius: '8px',
                textAlign: 'center'
              }}>
                <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.9' }}>Completed</h3>
                <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{currentStats.completedPayments || 0}</p>
              </div>
              <div className="stat-card" style={{
                background: 'linear-gradient(135deg, #fa709a 0%, #fee140 100%)',
                color: 'white',
                padding: '20px',
                borderRadius: '8px',
                textAlign: 'center'
              }}>
                <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.9' }}>Pending</h3>
                <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{currentStats.pendingPayments || 0}</p>
              </div>

              {/* Company-specific stats */}
              {paymentType === 'all_payments' && (
                <>
                  <div className="stat-card" style={{
                    background: 'linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%)',
                    color: 'white',
                    padding: '20px',
                    borderRadius: '8px',
                    textAlign: 'center'
                  }}>
                    <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.9' }}>Registration Fees</h3>
                    <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{formatAmount(currentStats.registrationFees || 0, 'PKR')}</p>
                  </div>
                  <div className="stat-card" style={{
                    background: 'linear-gradient(135deg, #a8edea 0%, #fed6e3 100%)',
                    color: '#2c3e50',
                    padding: '20px',
                    borderRadius: '8px',
                    textAlign: 'center'
                  }}>
                    <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.8' }}>Commission Fees</h3>
                    <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{formatAmount(currentStats.commissionFees || 0, 'PKR')}</p>
                  </div>
                </>
              )}

              {/* Delivery-specific stats */}
              {paymentType === 'deliveries' && (
                <>
                  <div className="stat-card" style={{
                    background: 'linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%)',
                    color: 'white',
                    padding: '20px',
                    borderRadius: '8px',
                    textAlign: 'center'
                  }}>
                    <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.9' }}>Total Commission</h3>
                    <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{formatAmount(currentStats.totalCommission || 0, 'PKR')}</p>
                  </div>
                  <div className="stat-card" style={{
                    background: 'linear-gradient(135deg, #a8edea 0%, #fed6e3 100%)',
                    color: '#2c3e50',
                    padding: '20px',
                    borderRadius: '8px',
                    textAlign: 'center'
                  }}>
                    <h3 style={{ margin: '0 0 5px 0', fontSize: '14px', opacity: '0.8' }}>Delivery Amount (After Commission)</h3>
                    <p style={{ margin: '0', fontSize: '24px', fontWeight: 'bold' }}>{formatAmount(currentStats.totalDeliveryAmount || 0, 'PKR')}</p>
                  </div>
                </>
              )}
            </div>
          )}

          {/* Enhanced Filter Controls */}
          <div className="filters" style={{ flexDirection: 'column', gap: '15px' }}>
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
                  {paymentType === 'all_payments' && (
                    <>
                      <option value="registration">Registration Fees</option>
                      <option value="commissions">Commission Fees</option>
                    </>
                  )}
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
                  placeholder="Name, email, transaction ID..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="filter-select"
                  style={{ minWidth: '200px' }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', gap: '10px' }}>
              <button onClick={fetchPayments} className="refresh-btn">
                Refresh
              </button>
              <button onClick={clearFilters} className="refresh-btn" style={{ background: '#95a5a6' }}>
                Clear Filters
              </button>
            </div>
          </div>

          {/* Payments Table */}
          <div className="payments-table-container">
            {paymentType === 'deliveries' ? (
              // Delivery payments table
              loadingDelivery ? (
                <div className="loading-container">
                  <div className="loading-spinner"></div>
                  <p>Loading delivery payments...</p>
                </div>
              ) : deliveryPayments.length === 0 ? (
                <div className="empty-state">
                  <p>No delivery payments found for the selected filters.</p>
                  <p style={{ fontSize: '14px', color: '#95a5a6' }}>
                    Try adjusting your filters or check back later for new delivery payments.
                  </p>
                </div>
              ) : (
                <table className="payments-table">
                  <thead>
                    <tr>
                      <th>Delivery Person</th>
                      <th>Contact</th>
                      <th>Delivery Amount</th>
                      <th>Company Commission</th>
                      <th>Net Earning</th>
                      <th>Commission Rate</th>
                      <th>Status</th>
                      <th>Delivery Date</th>
                      <th>Donor</th>
                      <th>Requester</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {deliveryPayments.map((delivery) => (
                      <tr key={delivery._id}>
                        <td>
                          <div className="user-info">
                            <strong>{delivery.deliveryPerson?.name || 'Unknown'}</strong>
                            <small>ID: {delivery.deliveryPerson?._id || 'N/A'}</small>
                          </div>
                        </td>
                        <td>
                          <div>
                            <div>{delivery.deliveryPerson?.email || 'N/A'}</div>
                            <small>{delivery.deliveryPerson?.phone || 'N/A'}</small>
                          </div>
                        </td>
                        <td className="amount">
                          {formatAmount(delivery.totalAmount || 0, 'PKR')}
                        </td>
                        <td className="amount" style={{ color: '#e74c3c', fontWeight: 'bold' }}>
                          {formatAmount(delivery.companyCommission || 0, 'PKR')}
                        </td>
                        <td className="amount" style={{ color: '#27ae60', fontWeight: 'bold' }}>
                          {formatAmount(delivery.netEarning || 0, 'PKR')}
                        </td>
                        <td>
                          <span className="commission-rate">
                            {((delivery.commissionRate || 0.15) * 100).toFixed(1)}%
                          </span>
                        </td>
                        <td>{getStatusBadge(delivery.status || 'pending')}</td>
                        <td>{formatDate(delivery.createdAt)}</td>
                        <td>
                          <div className="user-info">
                            <strong>{delivery.donor?.name || 'N/A'}</strong>
                            <small>{delivery.donor?.email || 'N/A'}</small>
                          </div>
                        </td>
                        <td>
                          <div className="user-info">
                            <strong>{delivery.requester?.name || 'N/A'}</strong>
                            <small>{delivery.requester?.email || 'N/A'}</small>
                          </div>
                        </td>
                        <td>
                          <button
                            onClick={() => handleViewDeliveryDetails(delivery)}
                            className="action-btn view-btn"
                            disabled={actionLoading}
                          >
                            View Details
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )
            ) : (
              // Regular payments table
              getFilteredPayments().length === 0 ? (
                <div className="empty-state">
                  <p>No {paymentStatusView} {paymentType} payments found for the selected filters.</p>
                  <p style={{ fontSize: '14px', color: '#95a5a6' }}>
                    Try adjusting your filters or check back later for new payments.
                  </p>
                </div>
              ) : (
                <table className="payments-table">
                  <thead>
                    <tr>
                      <th>User</th>
                      <th>Email</th>
                      <th>Amount</th>
                      {paymentType === 'deliveries' && <th>After Commission</th>}
                      <th>Commission</th>
                      <th>Status</th>
                      <th>Payment Date</th>
                      <th>Type</th>
                      <th>Transaction ID</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {getFilteredPayments().map((payment) => (
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
                          {formatAmount(payment.amount, payment.currency)}
                        </td>
                        {paymentType === 'deliveries' && (
                          <td className="amount" style={{ color: '#27ae60', fontWeight: 'bold' }}>
                            {formatAmount(payment.deliveryAmount, payment.currency)}
                          </td>
                        )}
                        <td className="commission">
                          {payment.commission?.amount ? (
                            <div style={{ fontSize: '12px' }}>
                              <div style={{ fontWeight: 'bold', color: '#e74c3c' }}>
                                {formatAmount(payment.commission.amount, payment.currency)}
                              </div>
                              <div style={{ color: '#7f8c8d' }}>
                                {payment.commission.percentage}% • {payment.commission.type?.replace('_', ' ') || 'N/A'}
                              </div>
                            </div>
                          ) : (
                            <span style={{ color: '#95a5a6', fontSize: '12px' }}>No Commission</span>
                          )}
                        </td>
                        <td>{getStatusBadge(payment.status)}</td>
                        <td>{formatDate(payment.createdAt)}</td>
                        <td>
                          <span className={`payment-type-badge ${paymentType === 'deliveries' ? 'type-green' : 'type-blue'}`}>
                            {payment.metadata?.type?.replace('_', ' ').toUpperCase() || paymentType.toUpperCase()}
                          </span>
                        </td>
                        <td>
                          <code style={{
                            fontSize: '11px',
                            background: '#f8f9fa',
                            padding: '2px 4px',
                            borderRadius: '3px'
                          }}>
                            {payment.stripePaymentIntentId ?
                              payment.stripePaymentIntentId.substring(0, 20) + '...' :
                              'N/A'
                            }
                          </code>
                        </td>
                        <td>
                          <button
                            onClick={() => handleViewDetails(payment)}
                            className="action-btn view-btn"
                            disabled={actionLoading}
                          >
                            View Details
                          </button>
                          <button
                            onClick={() => handleEdit(payment)}
                            className="action-btn edit-btn"
                            disabled={actionLoading}
                          >
                            Edit
                          </button>
                          <button
                            onClick={() => handleDelete(payment._id)}
                            className="action-btn delete-btn"
                            disabled={actionLoading}
                          >
                            Delete
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )
            )}
          </div>
        </>
      )}

      {activeTab === 'revenue' && (
        <div className="revenue-section">
          <div className="revenue-grid">
            {/* Registration Revenue */}
            <div className="revenue-card">
              <h3>
                🎫 Registration Revenue
              </h3>
              <div className="revenue-item">
                <span className="revenue-label">Total Registrations</span>
                <span className="revenue-amount">{stats?.registrationStats?.totalRegistrations || 0}</span>
              </div>
              <div className="revenue-item">
                <span className="revenue-label">Registration Fee per User</span>
                <span className="revenue-amount">{formatAmount(stats?.registrationStats?.feePerUser || 500, 'PKR')}</span>
              </div>
              <div className="revenue-item">
                <span className="revenue-label">This Month</span>
                <span className="revenue-amount">{formatAmount(stats?.registrationStats?.thisMonth || 0, 'PKR')}</span>
              </div>
              <div className="revenue-total">
                <h4 style={{ margin: '0 0 10px 0' }}>Total Registration Revenue</h4>
                <div style={{ fontSize: '28px', fontWeight: 'bold' }}>
                  {formatAmount(stats?.registrationStats?.totalRevenue || 0, 'PKR')}
                </div>
              </div>
            </div>

            {/* Request/Delivery Revenue */}
            <div className="revenue-card">
              <h3>
                🚚 Delivery Commission Revenue
              </h3>
              <div className="revenue-item">
                <span className="revenue-label">Total Deliveries</span>
                <span className="revenue-amount">{stats?.deliveryStats?.totalDeliveries || 0}</span>
              </div>
              <div className="revenue-item">
                <span className="revenue-label">Average Commission</span>
                <span className="revenue-amount">{stats?.deliveryStats?.avgCommission || 0}%</span>
              </div>
              <div className="revenue-item">
                <span className="revenue-label">This Month</span>
                <span className="revenue-amount">{formatAmount(stats?.deliveryStats?.thisMonth || 0, 'PKR')}</span>
              </div>
              <div className="revenue-total">
                <h4 style={{ margin: '0 0 10px 0' }}>Total Commission Revenue</h4>
                <div style={{ fontSize: '28px', fontWeight: 'bold' }}>
                  {formatAmount(stats?.deliveryStats?.totalCommission || 0, 'PKR')}
                </div>
              </div>
            </div>

            {/* Request Fee Revenue */}
            <div className="revenue-card">
              <h3>
                📋 Request Fee Revenue
              </h3>
              <div className="revenue-item">
                <span className="revenue-label">Total Requests</span>
                <span className="revenue-amount">{stats?.requestStats?.totalRequests || 0}</span>
              </div>
              <div className="revenue-item">
                <span className="revenue-label">Request Fee per Item</span>
                <span className="revenue-amount">{formatAmount(stats?.requestStats?.feePerRequest || 50, 'PKR')}</span>
              </div>
              <div className="revenue-item">
                <span className="revenue-label">This Month</span>
                <span className="revenue-amount">{formatAmount(stats?.requestStats?.thisMonth || 0, 'PKR')}</span>
              </div>
              <div className="revenue-total">
                <h4 style={{ margin: '0 0 10px 0' }}>Total Request Revenue</h4>
                <div style={{ fontSize: '28px', fontWeight: 'bold' }}>
                  {formatAmount(stats?.requestStats?.totalRevenue || 0, 'PKR')}
                </div>
              </div>
            </div>

            {/* Overall Revenue Summary */}
            <div className="revenue-card" style={{
              background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
              color: 'white'
            }}>
              <h3 style={{ color: 'white' }}>
                💰 Total Platform Revenue
              </h3>
              <div className="revenue-item" style={{ borderBottomColor: 'rgba(255,255,255,0.2)' }}>
                <span className="revenue-label" style={{ color: 'rgba(255,255,255,0.9)' }}>Registration Revenue</span>
                <span className="revenue-amount" style={{ color: 'white' }}>
                  {formatAmount(stats?.registrationStats?.totalRevenue || 0, 'PKR')}
                </span>
              </div>
              <div className="revenue-item" style={{ borderBottomColor: 'rgba(255,255,255,0.2)' }}>
                <span className="revenue-label" style={{ color: 'rgba(255,255,255,0.9)' }}>Commission Revenue</span>
                <span className="revenue-amount" style={{ color: 'white' }}>
                  {formatAmount(stats?.deliveryStats?.totalCommission || 0, 'PKR')}
                </span>
              </div>
              <div className="revenue-item" style={{ borderBottomColor: 'rgba(255,255,255,0.2)' }}>
                <span className="revenue-label" style={{ color: 'rgba(255,255,255,0.9)' }}>Request Revenue</span>
                <span className="revenue-amount" style={{ color: 'white' }}>
                  {formatAmount(stats?.requestStats?.totalRevenue || 0, 'PKR')}
                </span>
              </div>
              <div className="revenue-total" style={{
                background: 'rgba(255,255,255,0.2)',
                backdropFilter: 'blur(10px)'
              }}>
                <h4 style={{ margin: '0 0 10px 0', color: 'white' }}>Total Platform Revenue</h4>
                <div style={{ fontSize: '32px', fontWeight: 'bold', color: 'white' }}>
                  {formatAmount(
                    (stats?.registrationStats?.totalRevenue || 0) +
                    (stats?.deliveryStats?.totalCommission || 0) +
                    (stats?.requestStats?.totalRevenue || 0),
                    'PKR'
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Enhanced Payment Details Modal */}
      {showModal && selectedPayment && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h2>{paymentType === 'deliveries' ? 'Delivery' : 'Company'} Payment Details</h2>
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
                  <h3>User Information</h3>
                  <p><strong>Name:</strong> {selectedPayment.user?.name || 'Unknown'}</p>
                  <p><strong>Email:</strong> {selectedPayment.user?.email || 'N/A'}</p>
                  <p><strong>Role:</strong> {selectedPayment.user?.role || 'N/A'}</p>
                  <p><strong>Phone:</strong> {selectedPayment.user?.phone || 'N/A'}</p>
                  <p><strong>Address:</strong> {selectedPayment.user?.address || 'N/A'}</p>
                </div>

                <div className="detail-group">
                  <h3>Payment Information</h3>
                  <p><strong>Amount:</strong> {formatAmount(selectedPayment.amount, selectedPayment.currency)}</p>
                  {paymentType === 'deliveries' && selectedPayment.deliveryAmount && (
                    <p><strong>Delivery Amount (After Commission):</strong>
                      <span style={{ color: '#27ae60', fontWeight: 'bold', marginLeft: '5px' }}>
                        {formatAmount(selectedPayment.deliveryAmount, selectedPayment.currency)}
                      </span>
                    </p>
                  )}
                  <p><strong>Status:</strong> {getStatusBadge(selectedPayment.status)}</p>
                  <p><strong>Payment Method:</strong> {selectedPayment.paymentMethod || 'Stripe'}</p>
                  <p><strong>Transaction ID:</strong> <code>{selectedPayment.stripePaymentIntentId || 'N/A'}</code></p>
                  <p><strong>Payment Date:</strong> {formatDate(selectedPayment.createdAt)}</p>
                  {selectedPayment.completedAt && (
                    <p><strong>Completed At:</strong> {formatDate(selectedPayment.completedAt)}</p>
                  )}
                </div>

                {selectedPayment.commission?.amount > 0 && (
                  <div className="detail-group">
                    <h3>Commission Information</h3>
                    <p><strong>Commission Amount:</strong> {formatAmount(selectedPayment.commission.amount, selectedPayment.currency)}</p>
                    <p><strong>Commission Percentage:</strong> {selectedPayment.commission.percentage}%</p>
                    <p><strong>Commission Type:</strong> {selectedPayment.commission.type?.replace('_', ' ') || 'N/A'}</p>
                    <p><strong>Calculated At:</strong> {formatDate(selectedPayment.commission.calculatedAt)}</p>
                  </div>
                )}

                {selectedPayment.breakdown && (selectedPayment.breakdown.deliveryCharges > 0 || selectedPayment.breakdown.serviceFee > 0 || selectedPayment.breakdown.platformFee > 0) && (
                  <div className="detail-group">
                    <h3>Payment Breakdown</h3>
                    {selectedPayment.breakdown.deliveryCharges > 0 && (
                      <p><strong>Delivery Charges:</strong> {formatAmount(selectedPayment.breakdown.deliveryCharges, selectedPayment.currency)}</p>
                    )}
                    {selectedPayment.breakdown.serviceFee > 0 && (
                      <p><strong>Service Fee:</strong> {formatAmount(selectedPayment.breakdown.serviceFee, selectedPayment.currency)}</p>
                    )}
                    {selectedPayment.breakdown.platformFee > 0 && (
                      <p><strong>Platform Fee:</strong> {formatAmount(selectedPayment.breakdown.platformFee, selectedPayment.currency)}</p>
                    )}
                    {selectedPayment.breakdown.totalAmount > 0 && (
                      <p><strong>Total Amount:</strong> {formatAmount(selectedPayment.breakdown.totalAmount, selectedPayment.currency)}</p>
                    )}
                  </div>
                )}

                {selectedPayment.description && (
                  <div className="detail-group">
                    <h3>Description</h3>
                    <p>{selectedPayment.description}</p>
                  </div>
                )}

                {selectedPayment.metadata && Object.keys(selectedPayment.metadata).length > 0 && (
                  <div className="detail-group">
                    <h3>Metadata</h3>
                    <pre style={{
                      background: '#f8f9fa',
                      padding: '10px',
                      borderRadius: '4px',
                      fontSize: '12px',
                      overflow: 'auto'
                    }}>
                      {JSON.stringify(selectedPayment.metadata, null, 2)}
                    </pre>
                  </div>
                )}
              </div>

              {/* Edit Section */}
              {showEditModal && (
                <div className="edit-section">
                  <h3>Edit Payment</h3>
                  <form onSubmit={(e) => { e.preventDefault(); handleUpdate(); }}>
                    <div style={{ marginBottom: '15px' }}>
                      <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                        Amount (PKR):
                      </label>
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        value={editFormData.amount || ''}
                        onChange={(e) => setEditFormData(prev => ({ ...prev, amount: parseFloat(e.target.value) || 0 }))}
                        style={{
                          width: '100%',
                          padding: '8px',
                          border: '1px solid #ddd',
                          borderRadius: '4px'
                        }}
                        required
                      />
                    </div>
                    <div style={{ marginBottom: '15px' }}>
                      <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                        Status:
                      </label>
                      <select
                        value={editFormData.status || ''}
                        onChange={(e) => setEditFormData(prev => ({ ...prev, status: e.target.value }))}
                        style={{
                          width: '100%',
                          padding: '8px',
                          border: '1px solid #ddd',
                          borderRadius: '4px'
                        }}
                        required
                      >
                        <option value="completed">Completed</option>
                        <option value="pending">Pending</option>
                        <option value="failed">Failed</option>
                        <option value="processing">Processing</option>
                      </select>
                    </div>
                    <div style={{ marginBottom: '15px' }}>
                      <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                        Description:
                      </label>
                      <textarea
                        value={editFormData.description || ''}
                        onChange={(e) => setEditFormData(prev => ({ ...prev, description: e.target.value }))}
                        style={{
                          width: '100%',
                          padding: '8px',
                          border: '1px solid #ddd',
                          borderRadius: '4px',
                          minHeight: '60px',
                          resize: 'vertical'
                        }}
                        placeholder="Payment description..."
                      />
                    </div>
                    <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
                      <button
                        type="button"
                        onClick={() => setShowEditModal(false)}
                        className="cancel-btn"
                        style={{
                          padding: '8px 16px',
                          background: '#95a5a6',
                          color: 'white',
                          border: 'none',
                          borderRadius: '4px',
                          cursor: 'pointer'
                        }}
                      >
                        Cancel
                      </button>
                      <button
                        type="submit"
                        disabled={actionLoading}
                        className="update-btn"
                        style={{
                          padding: '8px 16px',
                          background: '#3498db',
                          color: 'white',
                          border: 'none',
                          borderRadius: '4px',
                          cursor: actionLoading ? 'not-allowed' : 'pointer',
                          opacity: actionLoading ? 0.6 : 1
                        }}
                      >
                        {actionLoading ? 'Updating...' : 'Update Payment'}
                      </button>
                    </div>
                  </form>
                </div>
              )}
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

export default PaymentManagement;
