import axios from "axios";

export const API_BASE_URL =
  process.env.REACT_APP_API_BASE_URL ||
  "https://nexora-api-ix2q.onrender.com";

const normalizedBaseUrl = API_BASE_URL.replace(/\/+$/, "");

export const createApiUrl = (path = "") => {
  const normalizedPath = path.replace(/^\/+/, "");
  return `${normalizedBaseUrl}/${normalizedPath}`;
};

export const createWebSocketUrl = (path = "") => {
  const socketBase = normalizedBaseUrl.replace(/^http/, "ws");
  const normalizedPath = path.replace(/^\/+/, "");
  return `${socketBase}/${normalizedPath}`;
};

const API = axios.create({
  baseURL: normalizedBaseUrl,
});

API.interceptors.request.use(
  (request) => {
    const token = localStorage.getItem("token");

    if (token) {
      request.headers.Authorization = `Bearer ${token}`;
    }

    return request;
  },
  (error) => Promise.reject(error)
);

API.interceptors.response.use(
  (response) => response,
  (error) => Promise.reject(error)
);

export default API;
