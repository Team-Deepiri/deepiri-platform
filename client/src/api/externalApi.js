import axiosInstance from './axiosInstance';

export const externalApi = {
  pyAgentMessage: async (content, sessionId = null) => {
    try {
      const base = import.meta.env.VITE_PYAGENT_URL || 'http://localhost:8000';
      const res = await fetch(`${base}/agent/message`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content, session_id: sessionId })
      });
      if (!res.ok) throw await res.json();
      return await res.json();
    } catch (error) {
      throw error;
    }
  },
  // Get current weather for location
  getCurrentWeather: async (location) => {
    try {
      const params = {
        latitude: location.latitude,
        longitude: location.longitude
      };
      const response = await axiosInstance.get('/external/weather', { params });
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to get weather data',
        error 
      };
    }
  },

  // Get nearby events from external sources
  getNearbyEvents: async (location, radius = 5000, interests = []) => {
    try {
      const params = {
        latitude: location.latitude,
        longitude: location.longitude,
        radius,
        interests: interests.join(',')
      };
      const response = await axiosInstance.get('/external/events/nearby', { params });
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to get external events',
        error 
      };
    }
  },

  // Get travel directions
  getDirections: async (origin, destination, mode = 'walking') => {
    try {
      const params = {
        origin: `${origin.latitude},${origin.longitude}`,
        destination: `${destination.latitude},${destination.longitude}`,
        mode
      };
      const response = await axiosInstance.get('/external/directions', { params });
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to get directions',
        error 
      };
    }
  },

  // Geocode address to coordinates
  geocodeAddress: async (address) => {
    try {
      const params = { address };
      const response = await axiosInstance.get('/external/geocode', { params });
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to geocode address',
        error 
      };
    }
  },

  // Reverse geocode coordinates to address
  reverseGeocode: async (latitude, longitude) => {
    try {
      const params = { latitude, longitude };
      const response = await axiosInstance.get('/external/reverse-geocode', { params });
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to reverse geocode',
        error 
      };
    }
  }
};