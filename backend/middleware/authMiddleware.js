const jwt = require("jsonwebtoken");
const User = require("../models/User");

// Middleware to verify token
const protect = async (req, res, next) => {
    console.log('🔐 AUTH MIDDLEWARE - protect() called');
    console.log('🔐 Authorization header:', req.headers.authorization);
    
    let token;

    // Check if Authorization header exists and starts with Bearer
    if (req.headers.authorization && req.headers.authorization.startsWith("Bearer")) {
        try {
            token = req.headers.authorization.split(" ")[1];
            console.log('🔐 Token extracted:', token ? 'Token present' : 'No token');

            // Verify token
            const decoded = jwt.verify(token, process.env.JWT_SECRET);
            console.log('🔐 Token decoded successfully:', decoded.userId);

            // Find the user by ID without password
            req.user = await User.findById(decoded.userId).select("-password");
            console.log('🔐 User found:', req.user ? req.user.email : 'No user');

            if (!req.user) {
                console.log('❌ User not found in database');
                return res.status(401).json({ message: "User not found" });
            }

            console.log('✅ Authentication successful');
            next();
        } catch (error) {
            console.error('❌ JWT verification error:', error);
            return res.status(401).json({ message: "Not authorized, token failed" });
        }
    } else {
        console.log('❌ No authorization header or invalid format');
        return res.status(401).json({ message: "Not authorized, no token" });
    }
};

// Middleware to check if user is admin
const admin = (req, res, next) => {
    console.log('👑 ADMIN MIDDLEWARE - admin() called');
    console.log('👑 User:', req.user ? req.user.email : 'No user');
    console.log('👑 User role:', req.user ? req.user.role : 'No role');
    console.log('👑 User roles array:', req.user ? req.user.roles : 'No roles array');
    
    if (req.user && (
        (Array.isArray(req.user.roles) && req.user.roles.includes('admin')) ||
        req.user.role === 'admin'
    )) {
        console.log('✅ Admin access granted');
        next();
    } else {
        console.log('❌ Admin access denied');
        res.status(403).json({ message: "Admin access only" });
    }
};

module.exports = { protect, admin };
 
// Require approved and paid user for main features
const requireApprovedAndPaid = (req, res, next) => {
    if (!req.user) return res.status(401).json({ message: 'Unauthorized' });
    const isApproved = req.user.status === 'approved';
    const isPaid = !!req.user.applicationFeePaid;
    if (!isApproved || !isPaid) {
        return res.status(403).json({ message: 'Access requires admin approval and application fee payment' });
    }
    next();
};

module.exports.requireApprovedAndPaid = requireApprovedAndPaid;
