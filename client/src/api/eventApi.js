import axiosInstance from './axiosInstance';

export const eventApi = {
  // Create a new event
  createEvent: async (eventData) => {
    try {
      const response = await axiosInstance.post('/events', eventData);
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to create event',
        error 
      };
    }
  },

  // Get event by ID
  getEventById: async (eventId) => {
    try {
      const response = await axiosInstance.get(`/events/${eventId}`);
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to get event',
        error 
      };
    }
  },

  // Get nearby events
  getNearbyEvents: async (latitude, longitude, radius = 5000, interests = []) => {
    try {
      const params = { 
        latitude, 
        longitude, 
        radius,
        interests: interests.join(',')
      };
      const response = await axiosInstance.get('/events/nearby', { params });
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to get nearby events',
        error 
      };
    }
  },

  // Get user's events
  getUserEvents: async () => {
    try {
      const response = await axiosInstance.get('/events/user');
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to get user events',
        error 
      };
    }
  },

  // RSVP to an event
  rsvpToEvent: async (eventId) => {
    try {
      const response = await axiosInstance.post(`/events/${eventId}/rsvp`);
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to RSVP to event',
        error 
      };
    }
  },

  // Cancel RSVP to an event
  cancelRsvp: async (eventId) => {
    try {
      const response = await axiosInstance.post(`/events/${eventId}/cancel-rsvp`);
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to cancel RSVP',
        error 
      };
    }
  },

  // Update event
  updateEvent: async (eventId, eventData) => {
    try {
      const response = await axiosInstance.patch(`/events/${eventId}`, eventData);
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to update event',
        error 
      };
    }
  },

  // Delete event
  deleteEvent: async (eventId) => {
    try {
      const response = await axiosInstance.delete(`/events/${eventId}`);
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to delete event',
        error 
      };
    }
  }
};