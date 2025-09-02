import axiosInstance from './axiosInstance';

export const notificationApi = {
  // Get all notifications for the user
  getNotifications: async () => {
    try {
      const response = await axiosInstance.get('/notifications');
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to get notifications',
        error 
      };
    }
  },

  // Mark notification as read
  markAsRead: async (notificationId) => {
    try {
      const response = await axiosInstance.patch(`/notifications/${notificationId}/read`);
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to mark notification as read',
        error 
      };
    }
  },

  // Mark all notifications as read
  markAllAsRead: async () => {
    try {
      const response = await axiosInstance.patch('/notifications/mark-all-read');
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to mark all notifications as read',
        error 
      };
    }
  },

  // Delete notification
  deleteNotification: async (notificationId) => {
    try {
      const response = await axiosInstance.delete(`/notifications/${notificationId}`);
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to delete notification',
        error 
      };
    }
  },

  // Get notification settings
  getSettings: async () => {
    try {
      const response = await axiosInstance.get('/notifications/settings');
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to get notification settings',
        error 
      };
    }
  },

  // Update notification settings
  updateSettings: async (settings) => {
    try {
      const response = await axiosInstance.patch('/notifications/settings', settings);
      return { success: true, data: response.data };
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Failed to update notification settings',
        error 
      };
    }
  }
};