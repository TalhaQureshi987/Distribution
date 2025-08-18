// server.js
require("dotenv").config(); // load .env first

const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const morgan = require("morgan");
const Redis = require("ioredis");

// Environment variables
const PORT = process.env.PORT || 3001;
const MONGODB_URI = process.env.MONGO_URI;
const REDIS_URL = process.env.REDIS_URL;
const FRONTEND_URL = process.env.FRONTEND_URL || "http://localhost:3000";
const JWT_SECRET = process.env.JWT_SECRET;

// Check essential env vars
if (!MONGODB_URI) {
  console.error("Error: MONGO_URI is not defined in .env");
  process.exit(1);
}
if (!JWT_SECRET) {
  console.error("Error: JWT_SECRET is not defined in .env");
  process.exit(1);
}

// Initialize Redis
const redisClient = new Redis(REDIS_URL);
redisClient.on("connect", () => console.log("Connected to Redis"));
redisClient.on("error", (err) => console.error("Redis error:", err));

// Initialize Express
const app = express();

// Security
app.use(helmet());
app.use(cors({ origin: FRONTEND_URL, credentials: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  message: "Too many requests from this IP, please try again later.",
});
app.use("/api/", limiter);

// Body parser
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Logging
if (process.env.NODE_ENV === "development") {
  app.use(morgan("dev"));
}

// Connect MongoDB
mongoose
  .connect(MONGODB_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => console.log("Connected to MongoDB"))
  .catch((err) => console.error("MongoDB connection error:", err));

// Import proper auth middleware
const { protect } = require("./middleware/authMiddleware");

// Import routes
const authRoutes = require("./routes/auth");
const userRoutes = require("./routes/users");
const donationRoutes = require("./routes/donations");
const requestRoutes = require("./routes/requests");
const chatRoutes = require("./routes/chat");
const volunteerRoutes = require("./routes/volunteers");
const notificationRoutes = require("./routes/notifications");

app.use("/api", authRoutes);
app.use("/api/users", protect, userRoutes);
app.use("/api/donations", protect, donationRoutes);
app.use("/api/requests", protect, requestRoutes);
app.use("/api/chat", protect, chatRoutes);
app.use("/api/volunteers", volunteerRoutes);
app.use("/api/notifications", notificationRoutes);

// Health check
app.get("/health", (req, res) => {
  res.json({
    status: "OK",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

// 404 handler
app.use("*", (req, res) => {
  res.status(404).json({ message: "Route not found" });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    message: "Something went wrong!",
    error:
      process.env.NODE_ENV === "development"
        ? err.message
        : "Internal server error",
  });
});

// Start server
const server = app.listen(PORT, () =>
  console.log(`Server running on port ${PORT}`)
);

// Socket.IO setup with advanced SocketServer
const SocketServer = require("./socket/socketServer");
const socketServer = new SocketServer(server);
app.locals.io = socketServer.io;

// Graceful shutdown
const shutdown = () => {
  console.log("Shutting down gracefully...");
  server.close(() => {
    mongoose.connection.close();
    redisClient.quit();
    console.log("Process terminated");
    process.exit(0);
  });
};
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);

module.exports = { app, server, redisClient };
