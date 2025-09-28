import axiosInstance from './axiosInstance';

export const pythonApi = {
  // GET /api/python/weather?lat=..&lng=..&units=imperial|metric
  getWeather: async (params) => {
    try {
      const { latitude, longitude, units = 'imperial' } = params || {};
      const response = await axiosInstance.get('/python/weather', {
        params: { lat: latitude, lng: longitude, units }
      });
      return { success: true, data: response.data };
    } catch (error) {
      return {
        success: false,
        message: error.response?.data?.message || 'Failed to fetch weather',
        error
      };
    }
  },

  // POST /api/python/directions { origin, destination, mode }
  getDirections: async ({ origin, destination, mode = 'driving' }) => {
    try {
      const response = await axiosInstance.post('/python/directions', {
        origin,
        destination,
        mode
      });
      return { success: true, data: response.data };
    } catch (error) {
      return {
        success: false,
        message: error.response?.data?.message || 'Failed to fetch directions',
        error
      };
    }
  },

  // GET /api/python/adventure-data?lat=..&lng=..&radius=..&interests=a,b
  getAdventureData: async ({ latitude, longitude, radius = 5000, interests = [] }) => {
    try {
      const response = await axiosInstance.get('/python/adventure-data', {
        params: {
          lat: latitude,
          lng: longitude,
          radius,
          interests: Array.isArray(interests) ? interests.join(',') : interests
        }
      });
      return { success: true, data: response.data };
    } catch (error) {
      return {
        success: false,
        message: error.response?.data?.message || 'Failed to fetch adventure data',
        error
      };
    }
  }
};


