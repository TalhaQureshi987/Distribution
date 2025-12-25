// Environment configuration with validation
const path = require("path");

// Load environment variables
require("dotenv").config();

// Validate required environment variables
const requiredEnvVars = ["JWT_SECRET", "MONGO_URI", "PORT"];

const missingEnvVars = requiredEnvVars.filter((envVar) => !process.env[envVar]);
if (missingEnvVars.length > 0) {
  throw new Error(
    `Missing required environment variables: ${missingEnvVars.join(", ")}`
  );
}

// Environment configuration object
const config = {
  // Server Configuration
  port: parseInt(process.env.PORT, 10) || 3001,
  nodeEnv: process.env.NODE_ENV || "development",

  // Database Configuration
  mongoUri: process.env.MONGO_URI,
  redisUrl: process.env.REDIS_URL || "redis://localhost:6379",

  // Authentication
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || "7d",

  // CORS and Frontend
  frontendUrl: process.env.FRONTEND_URL || "http://localhost:3000",
  corsOrigins: process.env.CORS_ORIGINS
    ? process.env.CORS_ORIGINS.split(",").map((origin) => origin.trim())
    : [
        "http://localhost:3000",
        "http://localhost:5173", // Admin panel (Vite default)
        "http://localhost:5174", // Admin panel (current port)
        "http://10.0.2.2:3000", // Android emulator
        "http://192.168.1.100:3000", // Physical device - Your PC IP
      ],

  // Logging
  logLevel: process.env.LOG_LEVEL || "info",
  logFile: process.env.LOG_FILE || "logs/app.log",
  enableRequestLogging: process.env.ENABLE_REQUEST_LOGGING === "true",

  // Socket.IO Configuration
  socket: {
    corsOrigin: process.env.SOCKET_CORS_ORIGIN || "http://localhost:3000",
    pingTimeout: parseInt(process.env.SOCKET_PING_TIMEOUT, 10) || 60000,
    pingInterval: parseInt(process.env.SOCKET_PING_INTERVAL, 10) || 25000,
  },

  // Rate Limiting
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 900000, // 15 minutes
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS, 10) || 100,
  },

  // Chat Configuration
  chat: {
    maxMessageLength: parseInt(process.env.MAX_MESSAGE_LENGTH, 10) || 5000,
    maxRoomParticipants: parseInt(process.env.MAX_ROOM_PARTICIPANTS, 10) || 50,
    messageRetentionDays:
      parseInt(process.env.MESSAGE_RETENTION_DAYS, 10) || 365,
  },

  // Office Location
  office: {
    address: process.env.OFFICE_ADDRESS || "Central Karachi (Office)",
    latitude: parseFloat(process.env.OFFICE_LAT) || 24.8607,
    longitude: parseFloat(process.env.OFFICE_LNG) || 67.0011,
  },

  // Development/Production specific settings
  isDevelopment: process.env.NODE_ENV === "development",
  isProduction: process.env.NODE_ENV === "production",
  isTesting: process.env.NODE_ENV === "test",
};

// Validation functions
const validateConfig = () => {
  // Validate JWT secret length
  if (config.jwtSecret.length < 32) {
    throw new Error("JWT_SECRET must be at least 32 characters long");
  }

  // Validate port range
  if (config.port < 1 || config.port > 65535) {
    throw new Error("PORT must be between 1 and 65535");
  }

  // Validate MongoDB URI format
  if (
    !config.mongoUri.startsWith("mongodb://") &&
    !config.mongoUri.startsWith("mongodb+srv://")
  ) {
    throw new Error("MONGO_URI must be a valid MongoDB connection string");
  }

  // Validate coordinates
  if (config.office.latitude < -90 || config.office.latitude > 90) {
    throw new Error("OFFICE_LAT must be between -90 and 90");
  }

  if (config.office.longitude < -180 || config.office.longitude > 180) {
    throw new Error("OFFICE_LNG must be between -180 and 180");
  }
};

// Run validation
validateConfig();

module.exports = config;
