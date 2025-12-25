import React, { useState, useEffect } from 'react';
import './AllUsersManagement.css';

const AllUsersManagement = () => {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [searchTerm, setSearchTerm] = useState('');
    const [roleFilter, setRoleFilter] = useState('all');
    const [statusFilter, setStatusFilter] = useState('all');
    const [verificationFilter, setVerificationFilter] = useState('all');
    const [stats, setStats] = useState({
        totalUsers: 0,
        approvedUsers: 0,
        pendingUsers: 0,
        rejectedUsers: 0,
        donors: 0,
        requesters: 0,
        volunteers: 0,
        delivery: 0
    });

    // Fetch users and stats
    useEffect(() => {
        fetchUsers();
        fetchStats();
    }, []);

    const fetchUsers = async () => {
        try {
            setLoading(true);
            const token = localStorage.getItem('admin_token');
            const response = await fetch('http://localhost:3001/auth/admin/users', {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error('Failed to fetch users');
            }

            const data = await response.json();
            setUsers(data.users || []);
        } catch (error) {
            console.error('Error fetching users:', error);
            setError('Failed to load users');
        } finally {
            setLoading(false);
        }
    };

    const fetchStats = async () => {
        try {
            const token = localStorage.getItem('admin_token');
            const response = await fetch('http://localhost:3001/auth/admin/stats', {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error('Failed to fetch stats');
            }

            const data = await response.json();
            setStats(data.stats || {});
        } catch (error) {
            console.error('Error fetching stats:', error);
        }
    };

    // Filter users based on search and filters
    const filteredUsers = users.filter(user => {
        const matchesSearch = user.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
            user.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
            user.phone?.includes(searchTerm);

        const matchesRole = roleFilter === 'all' || user.role === roleFilter;
        const matchesStatus = statusFilter === 'all' || user.status === statusFilter;
        const matchesVerification = verificationFilter === 'all' ||
            user.identityVerificationStatus === verificationFilter;

        return matchesSearch && matchesRole && matchesStatus && matchesVerification;
    });

    const handleApproveUser = async (userId) => {
        try {
            const token = localStorage.getItem('admin_token');
            const response = await fetch(`api.js from API_CONFIG /auth/admin/users/${userId}/approve`, {
                method: 'PATCH',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error('Failed to approve user');
            }

            // Refresh users list
            fetchUsers();
            fetchStats();
        } catch (error) {
            console.error('Error approving user:', error);
            alert('Failed to approve user');
        }
    };

    const handleRejectUser = async (userId) => {
        try {
            const token = localStorage.getItem('admin_token');
            const response = await fetch(`API_CONFIGauth/admin/users/${userId}/reject`, {
                method: 'PATCH',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error('Failed to reject user');
            }

            // Refresh users list
            fetchUsers();
            fetchStats();
        } catch (error) {
            console.error('Error rejecting user:', error);
            alert('Failed to reject user');
        }
    };

    const handleEditUser = (user) => {
        // Implement edit user logic here
        console.log('Edit user:', user);
    };

    const handleDeleteUser = async (userId, userName) => {
        if (window.confirm(`Are you sure you want to delete ${userName}?`)) {
            try {
                const token = localStorage.getItem('admin_token');
                const response = await fetch(`API_CONFIG/auth/admin/users/${userId}`, {
                    method: 'DELETE',
                    headers: {
                        'Authorization': `Bearer ${token}`,
                        'Content-Type': 'application/json'
                    }
                });

                if (!response.ok) {
                    throw new Error('Failed to delete user');
                }

                // Refresh users list
                fetchUsers();
                fetchStats();
            } catch (error) {
                console.error('Error deleting user:', error);
                alert('Failed to delete user');
            }
        }
    };

    const getStatusBadge = (status) => {
        const statusColors = {
            approved: '#28a745',
            pending: '#ffc107',
            rejected: '#dc3545'
        };

        return (
            <span
                className="status-badge"
                style={{ backgroundColor: statusColors[status] || '#6c757d' }}
            >
                {status?.charAt(0).toUpperCase() + status?.slice(1) || 'Unknown'}
            </span>
        );
    };

    const getRoleBadge = (role) => {
        const roleColors = {
            donor: '#007bff',
            requester: '#28a745',
            volunteer: '#17a2b8',
            delivery: '#fd7e14',
            admin: '#6f42c1'
        };

        return (
            <span
                className="role-badge"
                style={{ backgroundColor: roleColors[role] || '#6c757d' }}
            >
                {role?.charAt(0).toUpperCase() + role?.slice(1) || 'Unknown'}
            </span>
        );
    };

    const formatDate = (dateString) => {
        if (!dateString) return 'N/A';
        return new Date(dateString).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    };

    if (loading) {
        return (
            <div className="all-users-management">
                <div className="loading-spinner">
                    <div className="spinner"></div>
                    <p>Loading users...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="all-users-management">
            <div className="page-header">
                <h1>👥 All Users Management</h1>
                <p>Manage all registered users in the system</p>
            </div>

            {/* Statistics Cards */}
            <div className="stats-grid">
                <div className="stat-card">
                    <div className="stat-icon">👥</div>
                    <div className="stat-content">
                        <h3>{stats.totalUsers || 0}</h3>
                        <p>Total Users</p>
                    </div>
                </div>
                <div className="stat-card">
                    <div className="stat-icon">✅</div>
                    <div className="stat-content">
                        <h3>{stats.approvedUsers || 0}</h3>
                        <p>Approved</p>
                    </div>
                </div>
                <div className="stat-card">
                    <div className="stat-icon">⏳</div>
                    <div className="stat-content">
                        <h3>{stats.pendingUsers || 0}</h3>
                        <p>Pending</p>
                    </div>
                </div>
                <div className="stat-card">
                    <div className="stat-icon">❌</div>
                    <div className="stat-content">
                        <h3>{stats.rejectedUsers || 0}</h3>
                        <p>Rejected</p>
                    </div>
                </div>
            </div>

            {/* Role Statistics */}
            <div className="role-stats">
                <div className="role-stat">
                    <span className="role-badge" style={{ backgroundColor: '#007bff' }}>Donors</span>
                    <span className="count">{stats.donors || 0}</span>
                </div>
                <div className="role-stat">
                    <span className="role-badge" style={{ backgroundColor: '#28a745' }}>Requesters</span>
                    <span className="count">{stats.requesters || 0}</span>
                </div>
                <div className="role-stat">
                    <span className="role-badge" style={{ backgroundColor: '#17a2b8' }}>Volunteers</span>
                    <span className="count">{stats.volunteers || 0}</span>
                </div>
                <div className="role-stat">
                    <span className="role-badge" style={{ backgroundColor: '#fd7e14' }}>Delivery</span>
                    <span className="count">{stats.delivery || 0}</span>
                </div>
            </div>

            {/* Filters and Search */}
            <div className="filters-section">
                <div className="search-box">
                    <input
                        type="text"
                        placeholder="Search by name, email, or phone..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="search-input"
                    />
                </div>

                <div className="filters">
                    <select
                        value={roleFilter}
                        onChange={(e) => setRoleFilter(e.target.value)}
                        className="filter-select"
                    >
                        <option value="all">All Roles</option>
                        <option value="donor">Donors</option>
                        <option value="requester">Requesters</option>
                        <option value="volunteer">Volunteers</option>
                        <option value="delivery">Delivery</option>
                        <option value="admin">Admins</option>
                    </select>

                    <select
                        value={statusFilter}
                        onChange={(e) => setStatusFilter(e.target.value)}
                        className="filter-select"
                    >
                        <option value="all">All Status</option>
                        <option value="approved">Approved</option>
                        <option value="pending">Pending</option>
                        <option value="rejected">Rejected</option>
                    </select>

                    <select
                        value={verificationFilter}
                        onChange={(e) => setVerificationFilter(e.target.value)}
                        className="filter-select"
                    >
                        <option value="all">All Verification</option>
                        <option value="approved">Verified</option>
                        <option value="pending">Pending Verification</option>
                        <option value="rejected">Verification Rejected</option>
                    </select>
                </div>
            </div>

            {/* Users Table */}
            <div className="users-table-container">
                <table className="users-table">
                    <thead>
                        <tr>
                            <th>User Info</th>
                            <th>Contact</th>
                            <th>Role</th>
                            <th>Status</th>
                            <th>Verification</th>
                            <th>Payment</th>
                            <th>Joined</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredUsers.length === 0 ? (
                            <tr>
                                <td colSpan="8" className="no-data">
                                    {searchTerm || roleFilter !== 'all' || statusFilter !== 'all' || verificationFilter !== 'all'
                                        ? 'No users match the current filters'
                                        : 'No users found'}
                                </td>
                            </tr>
                        ) : (
                            filteredUsers.map(user => (
                                <tr key={user._id}>
                                    <td>
                                        <div className="user-info">
                                            <strong>{user.name || 'N/A'}</strong>
                                            <small>{user.email || 'N/A'}</small>
                                        </div>
                                    </td>
                                    <td>
                                        <div className="contact-info">
                                            <div>{user.phone || 'N/A'}</div>
                                            <small>{user.address || 'No address'}</small>
                                        </div>
                                    </td>
                                    <td>{getRoleBadge(user.role)}</td>
                                    <td>{getStatusBadge(user.status)}</td>
                                    <td>
                                        <span className={`verification-status ${user.identityVerificationStatus}`}>
                                            {user.identityVerificationStatus === 'approved' ? '✅ Verified' :
                                                user.identityVerificationStatus === 'pending' ? '⏳ Pending' :
                                                    user.identityVerificationStatus === 'rejected' ? '❌ Rejected' : '⚪ Not Started'}
                                        </span>
                                    </td>
                                    <td>
                                        <span className={`payment-status ${user.paymentStatus}`}>
                                            {user.paymentStatus === 'paid' ? '✅ Paid' :
                                                user.applicationFeePaid ? '✅ Paid' : '❌ Unpaid'}
                                        </span>
                                    </td>
                                    <td>{formatDate(user.createdAt)}</td>
                                    <td>
                                        <div className="action-buttons">
                                            {user.status === 'pending' && (
                                                <>
                                                    <button
                                                        className="approve-btn"
                                                        onClick={() => handleApproveUser(user._id)}
                                                        title="Approve User"
                                                    >
                                                        ✅
                                                    </button>
                                                    <button
                                                        className="reject-btn"
                                                        onClick={() => handleRejectUser(user._id)}
                                                        title="Reject User"
                                                    >
                                                        ❌
                                                    </button>
                                                </>
                                            )}
                                            <button
                                                className="edit-btn"
                                                onClick={() => handleEditUser(user)}
                                                title="Edit User"
                                            >
                                                ✏️
                                            </button>
                                            <button
                                                className="delete-btn"
                                                onClick={() => handleDeleteUser(user._id, user.name)}
                                                title="Delete User"
                                            >
                                                🗑️
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>

            {/* Results Summary */}
            <div className="results-summary">
                <p>Showing {filteredUsers.length} of {users.length} users</p>
            </div>
        </div>
    );
};

export default AllUsersManagement;
