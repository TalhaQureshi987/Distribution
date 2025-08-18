// controllers/userController.js
const User = require("../models/User");
const jwt = require("jsonwebtoken");
const { client, connectRedis } = require("../config/redisClient");
const bcrypt = require("bcryptjs");

const JWT_SECRET =
  process.env.JWT_SECRET || "JAJHDJKDJKJDFKADJKJAFKJK83789427882479";
const REFRESH_TTL_SECONDS = 60 * 60 * 24 * 7;

// Helper functions
function signAccessToken(user) {
  return jwt.sign(
    { id: user._id, email: user.email, role: user.role },
    JWT_SECRET,
    { expiresIn: "15m" }
  );
}

function signRefreshToken(user) {
  return jwt.sign({ id: user._id }, JWT_SECRET, { expiresIn: "7d" });
}

// Register
const register = async (req, res) => {
  try {
    const { name, email, password, number } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ message: "Missing fields" });

    // Check if email exists
    const exists = await User.findOne({ email });
    if (exists) return res.status(409).json({ message: "User already exists" });

    // Determine role: first user is admin
    let roleToSet = "user";
    const userCount = await User.countDocuments();
    if (userCount === 0) roleToSet = "admin";

    // Create user
    const user = new User({ name, email, password, number, role: roleToSet });
    await user.save();

    // Connect Redis & cache profile
    await connectRedis();
    await client.set(
      `user_profile:${user._id}`,
      JSON.stringify({
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        number: user.number,
      }),
      { EX: 3600 }
    );

    res.status(201).json({
      message: "User created. Please login to receive access tokens.",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        number: user.number,
      },
    });
  } catch (err) {
    console.error("Register error:", err);
    if (err && err.code === 11000) {
      const dupField = Object.keys(err.keyPattern || {}).join(", ");
      return res
        .status(409)
        .json({ message: `Duplicate field: ${dupField || "value"}` });
    }
    if (err && err.name === "ValidationError") {
      return res.status(400).json({ message: err.message });
    }
    res.status(500).json({ message: "Server error" });
  }
};

// Login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password)
      return res.status(400).json({ message: "Missing fields" });

    const user = await User.findOne({ email });
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const accessToken = signAccessToken(user);
    const refreshToken = signRefreshToken(user);

    await connectRedis();
    await client.set(`refresh_${user._id}`, refreshToken, {
      EX: REFRESH_TTL_SECONDS,
    });
    await client.set(
      `user_profile:${user._id}`,
      JSON.stringify({
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        number: user.number,
      }),
      { EX: 3600 }
    );

    res.json({
      accessToken,
      refreshToken,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        number: user.number,
      },
    });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ message: "Server error" });
  }
};

// Update Profile
const updateProfile = async (req, res) => {
  try {
    const { name, email, phone, address } = req.body;

    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    if (name) user.name = name;
    if (email) user.email = email;
    if (phone) user.phone = phone;
    if (address) user.address = address;

    await user.save();

    res.json({
      message: "Profile updated successfully",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        address: user.address,
        role: user.role,
      },
    });
  } catch (error) {
    console.error("Update profile error:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// Change Password
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword)
      return res
        .status(400)
        .json({ message: "Please provide current and new password" });

    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch)
      return res.status(400).json({ message: "Current password is incorrect" });

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);

    await user.save();
    res.json({ message: "Password changed successfully" });
  } catch (error) {
    console.error("Change password error:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// Get Profile
const getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select("-password");
    if (!user) return res.status(404).json({ message: "User not found" });

    res.json({ user });
  } catch (error) {
    console.error("Get profile error:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// Delete Account
const deleteAccount = async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    await User.findByIdAndDelete(req.user.id);
    res.json({ message: "Account deleted successfully" });
  } catch (error) {
    console.error("Delete account error:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// Logout
const logout = async (req, res) => {
  try {
    const token = req.headers["authorization"]?.split(" ")[1];
    await connectRedis();
    await client.del(`refresh_${req.user.id}`);

    if (token) {
      const decoded = jwt.decode(token);
      if (decoded?.exp) {
        const ttl = decoded.exp - Math.floor(Date.now() / 1000);
        if (ttl > 0) {
          await client.set(`bl_${token}`, "1", { EX: ttl });
        }
      }
    }

    res.json({ message: "Logged out" });
  } catch (err) {
    console.error("Logout error:", err);
    res.status(500).json({ message: "Server error" });
  }
};

// Refresh Token
const refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken)
      return res.status(400).json({ message: "refreshToken required" });

    const decoded = jwt.verify(refreshToken, JWT_SECRET);
    await connectRedis();
    const stored = await client.get(`refresh_${decoded.id}`);
    if (!stored || stored !== refreshToken)
      return res.status(401).json({ message: "Invalid refresh token" });

    const user = await User.findById(decoded.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    const newAccess = signAccessToken(user);
    res.json({ accessToken: newAccess });
  } catch (err) {
    console.error("Refresh error:", err);
    res.status(401).json({ message: "Invalid refresh token" });
  }
};

// Export all functions
module.exports = {
  register,
  login,
  updateProfile,
  changePassword,
  getProfile,
  deleteAccount,
  logout,
  refreshToken,
};
