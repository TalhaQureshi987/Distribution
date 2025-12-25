// server.js
const config = require("./config/environment");
const { logger, requestLogger, dbLogger } = require("./utils/logger");
const {
  errorHandler,
  notFound,
  asyncHandler,
} = require("./middleware/errorHandler");

const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const helmet = require("helmet");
const path = require("path");
const multer = require("multer");

// -------------------- Startup Logs --------------------
logger.info("Server Starting", {
  nodeEnv: config.nodeEnv,
  port: config.port,
  logLevel: config.logLevel,
});

// -------------------- Redis Setup --------------------
const { client: redisClient } = require("./config/redisClient");
redisClient.on("connect", () =>
  logger.info("Redis Connected", { url: config.redisUrl })
);
redisClient.on("error", (err) =>
  logger.error("Redis Connection Error", { error: err.message })
);

// -------------------- Express Setup --------------------
const app = express();
app.set("trust proxy", 1);

// Security Middleware
app.use(
  helmet({
    crossOriginEmbedderPolicy: false,
    contentSecurityPolicy: false,
    crossOriginResourcePolicy: { policy: "cross-origin" },
  })
);

// CORS
app.use(
  cors({
    origin: config.corsOrigins,
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

// Request Logger
app.use(requestLogger);

// Body Parser
app.use(
  express.json({
    limit: "10mb",
    verify: (req, res, buf) => (req.rawBody = buf),
  })
);
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// -------------------- Static & Image Routes --------------------
const setCorsHeaders = (res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
  res.setHeader(
    "Access-Control-Allow-Headers",
    "Origin, X-Requested-With, Content-Type, Accept, Authorization"
  );
  res.setHeader(
    "Access-Control-Expose-Headers",
    "Content-Length, Content-Type"
  );
};

app.options("/api/image/:folder/:filename", (req, res) => {
  setCorsHeaders(res);
  res.status(200).end();
});
app.get("/api/image/:folder/:filename", (req, res) => {
  setCorsHeaders(res);
  const { folder, filename } = req.params;
  const imagePath = path.join(__dirname, "uploads", folder, filename);
  if (!require("fs").existsSync(imagePath))
    return res.status(404).json({ error: "Image not found" });
  res.sendFile(imagePath);
});

app.use(["/uploads", "/api/uploads"], (req, res, next) => {
  setCorsHeaders(res);
  if (req.method === "OPTIONS") return res.status(200).end();
  next();
});
app.use(
  ["/uploads", "/api/uploads"],
  express.static(path.join(__dirname, "uploads"))
);

// -------------------- Multer Setup --------------------
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});
app.use("/api/donations", upload.any());

// -------------------- MongoDB Connection --------------------
let mongoRetryCount = 0;
const MAX_RETRIES = 10;
const INITIAL_RETRY_DELAY = 5000; // 5 seconds

const connectMongo = async (retryDelay = INITIAL_RETRY_DELAY) => {
  try {
    // Reset retry count on successful connection
    mongoRetryCount = 0;

    await mongoose.connect(config.mongoUri, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 15000, // Increased from 10s to 15s
      socketTimeoutMS: 45000,
      connectTimeoutMS: 15000, // Increased from 10s to 15s
      tlsAllowInvalidCertificates: config.isDevelopment,
      retryWrites: true,
      w: "majority",
      // Add DNS resolution options
      family: 4, // Force IPv4 (helps with some DNS issues)
    });

    dbLogger.connection("connected", "MongoDB");
    logger.info("MongoDB Connected", {
      uri: config.mongoUri.replace(/\/\/.*@/, "//***:***@"),
      retryCount: mongoRetryCount,
    });
  } catch (err) {
    mongoRetryCount++;
    dbLogger.error("connection", "connect", err);

    // Enhanced error logging with diagnostics
    const errorDetails = {
      error: err.message,
      code: err.code,
      retryAttempt: mongoRetryCount,
      maxRetries: MAX_RETRIES,
      connectionString: config.mongoUri.replace(/\/\/.*@/, "//***:***@"),
    };

    // Check for DNS-related errors
    if (err.message && err.message.includes("ENOTFOUND")) {
      errorDetails.diagnosis = "DNS resolution failed";
      errorDetails.troubleshooting = [
        "1. Check your internet connection",
        "2. Verify DNS settings (try using 8.8.8.8 or 1.1.1.1)",
        "3. Check if firewall/proxy is blocking DNS queries",
        "4. Try using a direct connection string instead of mongodb+srv://",
        "5. Verify MongoDB Atlas cluster is accessible",
      ];
      logger.error("MongoDB DNS Resolution Error", errorDetails);
    } else if (err.message && err.message.includes("ETIMEDOUT")) {
      errorDetails.diagnosis = "Connection timeout";
      errorDetails.troubleshooting = [
        "1. Check network connectivity",
        "2. Verify MongoDB Atlas IP whitelist includes your IP",
        "3. Check firewall settings",
        "4. Try increasing timeout values",
      ];
      logger.error("MongoDB Connection Timeout", errorDetails);
    } else {
      logger.error("MongoDB Connection Failed", errorDetails);
    }

    // Stop retrying after max attempts
    if (mongoRetryCount >= MAX_RETRIES) {
      logger.error("MongoDB Connection Failed - Max Retries Reached", {
        totalAttempts: mongoRetryCount,
        lastError: err.message,
        action:
          "Server will continue running but database operations will fail",
      });
      return; // Stop retrying
    }

    // Exponential backoff: increase delay with each retry (max 60 seconds)
    const nextDelay = Math.min(retryDelay * 1.5, 60000);
    logger.warn(
      `Retrying MongoDB connection in ${Math.round(
        nextDelay / 1000
      )}s... (Attempt ${mongoRetryCount}/${MAX_RETRIES})`
    );
    setTimeout(() => connectMongo(nextDelay), nextDelay);
  }
};

connectMongo();

// MongoDB Event Handlers
mongoose.connection.on("disconnected", () => {
  dbLogger.connection("disconnected", "MongoDB");
  logger.warn("MongoDB Disconnected - Attempting reconnect...");
  // Reset retry count for reconnection attempts
  if (mongoRetryCount < MAX_RETRIES) {
    setTimeout(() => connectMongo(INITIAL_RETRY_DELAY), INITIAL_RETRY_DELAY);
  }
});
mongoose.connection.on("reconnected", () => {
  mongoRetryCount = 0; // Reset on successful reconnection
  logger.info("MongoDB Reconnected Successfully");
});
mongoose.connection.on("error", (err) => {
  logger.error("MongoDB Runtime Error", {
    error: err.message,
    code: err.code,
    stack: err.stack,
  });
});

// -------------------- Routes --------------------
const { protect } = require("./middleware/authMiddleware");

app.use("/api/auth", require("./routes/auth"));
app.use("/api/donations", protect, require("./routes/donations"));
app.use("/api/requests", protect, require("./routes/requests"));
app.use("/api/chat", require("./routes/chat"));
app.use("/api/volunteers", require("./routes/volunteers"));
app.use("/api/delivery-offers", require("./routes/deliveryOffers"));
app.use("/api/notifications", require("./routes/notifications"));
app.use("/api/payments", require("./routes/payments"));
app.use("/api/activity", protect, require("./routes/activity"));
app.use("/api/support", protect, require("./routes/support"));
app.use("/api/profile", require("./routes/profile"));
app.use("/api/identity-verification", require("./routes/identityVerification"));

// Admin
app.use("/api/admin/requests", require("./routes/requestVerification"));
app.use("/api/admin/payments", require("./routes/adminPayments"));

// 404 & Global Error
app.use("*", notFound);
app.use(errorHandler);

// -------------------- Server & Socket.IO --------------------
const server = app.listen(config.port, "0.0.0.0", () =>
  logger.info("Server Started", { port: config.port, pid: process.pid })
);

const { initSocket } = require("./logic/socket");
const adminSocketManager = require("./logic/adminSocket");
const io = initSocket(server);
adminSocketManager.initialize(io);
global.adminSocketManager = adminSocketManager;
app.locals.io = io;

// Services
app.locals.userStatusService = require("./services/userStatusService");
app.locals.typingService = require("./services/typingService");
app.locals.readReceiptService = require("./services/readReceiptService");

// -------------------- Health & Status --------------------
app.get(
  "/health",
  asyncHandler(async (req, res) => {
    const { getSocketStats } = require("./logic/socket");
    res.json({
      status: "OK",
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: config.nodeEnv,
      version: process.env.npm_package_version || "1.0.0",
      database: {
        mongodb:
          mongoose.connection.readyState === 1 ? "connected" : "disconnected",
        redis: redisClient.status === "ready" ? "connected" : "disconnected",
      },
      socket: getSocketStats(),
      memory: {
        used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + "MB",
        total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + "MB",
      },
    });
  })
);

app.get(
  "/api/status",
  protect,
  asyncHandler(async (req, res) => {
    const onlineUsers = app.locals.userStatusService.getOnlineUsers();
    res.json({
      status: "operational",
      onlineUsers: onlineUsers.length,
      timestamp: new Date().toISOString(),
    });
  })
);

// -------------------- Graceful Shutdown --------------------
const shutdown = async (signal) => {
  logger.info("Shutdown Signal Received", { signal });
  server.close(async () => {
    try {
      await mongoose.connection.close();
      logger.info("MongoDB connection closed");
      await redisClient.quit();
      logger.info("Redis connection closed");
      logger.info("Server shutdown complete");
      process.exit(0);
    } catch (error) {
      logger.error("Error during shutdown", { error: error.message });
      process.exit(1);
    }
  });
  setTimeout(() => {
    logger.error("Forced shutdown after timeout");
    process.exit(1);
  }, 10000);
};

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("uncaughtException", (error) => {
  logger.error("Uncaught Exception", {
    error: error.message,
    stack: error.stack,
  });
  shutdown("uncaughtException");
});
process.on("unhandledRejection", (reason, promise) => {
  logger.error("Unhandled Rejection", {
    reason: reason?.message || reason?.toString() || "Unknown reason",
    stack: reason?.stack || "No stack trace",
    promise: promise?.toString() || "Unknown promise",
    timestamp: new Date().toISOString(),
  });

  // Don't shutdown in development to prevent constant restarts
  if (process.env.NODE_ENV === "production") {
    shutdown("unhandledRejection");
  } else {
    logger.warn(
      "Unhandled rejection detected but continuing in development mode"
    );
  }
});
module.exports = { app, server, redisClient, io };
