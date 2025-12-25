export const saveToken = (t) => localStorage.setItem('admin_token', t);
export const getToken = () => localStorage.getItem('admin_token');
export const clearToken = () => localStorage.removeItem('admin_token');