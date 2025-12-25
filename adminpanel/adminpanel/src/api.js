import axios from "axios";

// API Configuration
const API_CONFIG = {
  // Use localhost for development, ngrok for external access
  baseURL:
    process.env.NODE_ENV === "production"
      ? "https://bc83bc3f508d.ngrok-free.app/api"
      : "http://localhost:3001/api",
  timeout: 30000, // 30 seconds timeout for real-time data
  headers: {
    "Content-Type": "application/json",
  },
};

const api = axios.create(API_CONFIG);

// Request interceptor for authentication
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem("admin_token");
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }

    // Add timestamp to prevent caching for real-time data
    if (config.method === "get") {
      config.params = {
        ...config.params,
        _t: Date.now(),
      };
    }

    console.log(
      `🌐 API Request: ${config.method?.toUpperCase()} ${config.url}`
    );
    return config;
  },
  (error) => {
    console.error("❌ API Request Error:", error);
    return Promise.reject(error);
  }
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => {
    console.log(
      `✅ API Response: ${response.config.method?.toUpperCase()} ${
        response.config.url
      } - ${response.status}`
    );
    return response;
  },
  async (error) => {
    console.error(
      `❌ API Response Error: ${error.config?.method?.toUpperCase()} ${
        error.config?.url
      }`,
      {
        status: error.response?.status,
        message: error.response?.data?.message || error.message,
        data: error.response?.data,
      }
    );

    // Handle authentication errors
    if (error.response?.status === 401) {
      const originalRequest = error.config;

      // Try to refresh token if this is not a refresh request
      if (
        !originalRequest._retry &&
        !originalRequest.url.includes("/refresh-token")
      ) {
        originalRequest._retry = true;

        try {
          const token = localStorage.getItem("admin_token");
          if (token) {
            console.log("🔄 Attempting token refresh...");
            const refreshResponse = await api.post("/auth/refresh-token", {
              token,
            });

            if (refreshResponse.data.success) {
              console.log("✅ Token refreshed successfully");
              localStorage.setItem("admin_token", refreshResponse.data.token);

              // Retry the original request with new token
              originalRequest.headers.Authorization = `Bearer ${refreshResponse.data.token}`;
              return api(originalRequest);
            }
          }
        } catch (refreshError) {
          console.error("❌ Token refresh failed:", refreshError);
        }
      }

      // If refresh failed or this was a refresh request, redirect to login
      localStorage.removeItem("admin_token");
      window.location.href = "/login";
    }

    return Promise.reject(error);
  }
);

export default api;
