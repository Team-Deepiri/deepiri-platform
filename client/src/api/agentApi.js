import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: { 'Content-Type': 'application/json' }
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export const agentApi = {
  createSession: async (title, settings) => {
    const res = await api.post('/agent/sessions', { title, settings });
    return res.data;
  },
  listSessions: async (limit = 20, offset = 0) => {
    const res = await api.get('/agent/sessions', { params: { limit, offset } });
    return res.data;
  },
  sendMessage: async (sessionId, content) => {
    const res = await api.post(`/agent/sessions/${sessionId}/messages`, { content });
    return res.data;
  },
  archiveSession: async (sessionId) => {
    const res = await api.post(`/agent/sessions/${sessionId}/archive`);
    return res.data;
  }
};


