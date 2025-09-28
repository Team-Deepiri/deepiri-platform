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

export const userApi = {
  getProfile: async () => {
    try {
      const response = await api.get('/users/profile');
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  updateProfile: async (userData) => {
    try {
      const response = await api.put('/users/profile', userData);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  updatePreferences: async (preferences) => {
    try {
      const response = await api.put('/users/preferences', preferences);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  updateLocation: async (location) => {
    try {
      const response = await api.put('/users/location', location);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  getStats: async () => {
    try {
      const response = await api.get('/users/stats');
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  getFriends: async () => {
    try {
      const response = await api.get('/users/friends');
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  addFriend: async (friendId) => {
    try {
      const response = await api.post('/users/friends', { friendId });
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  removeFriend: async (friendId) => {
    try {
      const response = await api.delete(`/users/friends/${friendId}`);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  searchUsers: async (query, limit = 20) => {
    try {
      const response = await api.get('/users/search', {
        params: { query, limit }
      });
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  getFavoriteVenues: async () => {
    try {
      const response = await api.get('/users/favorite-venues');
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  addFavoriteVenue: async (venueData) => {
    try {
      const response = await api.post('/users/favorite-venues', venueData);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  removeFavoriteVenue: async (venueId) => {
    try {
      const response = await api.delete(`/users/favorite-venues/${venueId}`);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  getLeaderboard: async (timeRange = '30d', limit = 50) => {
    try {
      const response = await api.get('/users/leaderboard', {
        params: { timeRange, limit }
      });
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  getUserById: async (userId) => {
    try {
      const response = await api.get(`/users/${userId}`);
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  },

  deleteAccount: async (password) => {
    try {
      const response = await api.delete('/users/account', { password });
      return response.data;
    } catch (error) {
      throw error.response?.data || error;
    }
  }
};
