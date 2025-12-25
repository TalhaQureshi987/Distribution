import { useEffect, useState } from 'react';
import api from '../api';

export default function PendingUsers() {
  const [items, setItems] = useState([]);
  const [err, setErr] = useState('');

  const load = async () => {
    setErr('');
    try {
      const { data } = await api.get('/auth/admin/users/pending');
      setItems(data.users || []);
    } catch (e) {
      setErr(e?.response?.data?.message || e.message || 'Failed to load');
    }
  };

  useEffect(() => { load(); }, []);

  const approve = async (id) => {
    try {
      await api.patch(`/auth/admin/users/${id}/approve`);
      await load();
    } catch (e) {
      alert(e?.response?.data?.message || e.message);
    }
  };

  const rejectUser = async (id) => {
    try {
      await api.patch(`/auth/admin/users/${id}/reject`);
      await load();
    } catch (e) {
      alert(e?.response?.data?.message || e.message);
    }
  };

  return (
    <div style={{ padding: 20 }}>
      <h3>Pending Users</h3>
      {err && <p style={{ color:'red' }}>{err}</p>}
      <table border="1" cellPadding="8">
        <thead>
          <tr><th>Name</th><th>Email</th><th>Roles</th><th>Status</th><th>Fee Paid</th><th>Actions</th></tr>
        </thead>
        <tbody>
          {items.map(u => (
            <tr key={u._id}>
              <td>{u.name}</td>
              <td>{u.email}</td>
              <td>{(u.roles||[]).join(', ')}</td>
              <td>{u.status}</td>
              <td>{u.applicationFeePaid ? 'Yes' : 'No'}</td>
              <td>
                <button onClick={()=>approve(u._id)} disabled={!u.applicationFeePaid}>Approve</button>
                <button onClick={()=>rejectUser(u._id)} style={{ marginLeft: 8 }}>Reject</button>
              </td>
            </tr>
          ))}
          {!items.length && <tr><td colSpan="6">No pending users</td></tr>}
        </tbody>
      </table>
    </div>
  );
}