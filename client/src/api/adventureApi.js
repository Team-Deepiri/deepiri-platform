import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add token to requests
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

export const adventureApi = {
  generateAdventure: async (adventureData) => {
    try {
      const response = await api.post('/adventures/generate', adventureData);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  getAdventure: async (adventureId) => {
    try {
      const response = await api.get(`/adventures/${adventureId}`);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  getUserAdventures: async (status = null, limit = 20, offset = 0) => {
    try {
      const params = { limit, offset };
      if (status) params.status = status;
      
      const response = await api.get('/adventures', { params });
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  startAdventure: async (adventureId) => {
    try {
      const response = await api.post(`/adventures/${adventureId}/start`);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  completeAdventure: async (adventureId, feedback = null) => {
    try {
      const response = await api.post(`/adventures/${adventureId}/complete`, { feedback });
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  updateAdventureStep: async (adventureId, stepIndex, action) => {
    try {
      const response = await api.put(`/adventures/${adventureId}/steps`, {
        stepIndex,
        action
      });
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  shareAdventure: async (adventureId, shareData) => {
    try {
      const response = await api.post(`/adventures/${adventureId}/share`, shareData);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  getAdventureRecommendations: async (location, limit = 5) => {
    try {
      const params = {
        lat: location.lat,
        lng: location.lng,
        limit
      };
      const response = await api.get('/adventures/recommendations', { params });
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  getAdventureAnalytics: async (timeRange = '30d') => {
    try {
      const response = await api.get('/adventures/analytics', {
        params: { timeRange }
      });
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  cancelAdventure: async (adventureId) => {
    try {
      const response = await api.post(`/adventures/${adventureId}/cancel`);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  pauseAdventure: async (adventureId) => {
    try {
      const response = await api.post(`/adventures/${adventureId}/pause`);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  resumeAdventure: async (adventureId) => {
    try {
      const response = await api.post(`/adventures/${adventureId}/resume`);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  getAdventureVariations: async (adventureId) => {
    try {
      const response = await api.get(`/adventures/${adventureId}/variations`);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  }
};
