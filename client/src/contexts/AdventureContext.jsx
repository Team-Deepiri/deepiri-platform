import React, { createContext, useContext, useState, useEffect } from 'react';
import { useAuth } from './AuthContext';
import { adventureApi } from '../api/adventureApi';
import toast from 'react-hot-toast';

const AdventureContext = createContext();

export const useAdventure = () => {
  const context = useContext(AdventureContext);
  if (!context) {
    throw new Error('useAdventure must be used within an AdventureProvider');
  }
  return context;
};

export const AdventureProvider = ({ children }) => {
  const [currentAdventure, setCurrentAdventure] = useState(null);
  const [adventureHistory, setAdventureHistory] = useState([]);
  const [loading, setLoading] = useState(false);
  const [userLocation, setUserLocation] = useState(null);
  const { user, isAuthenticated } = useAuth();

  useEffect(() => {
    if (isAuthenticated && user) {
      getUserLocation();
      loadAdventureHistory();
    }
  }, [isAuthenticated, user]);

  const getUserLocation = () => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const location = {
            lat: position.coords.latitude,
            lng: position.coords.longitude
          };
          setUserLocation(location);
          console.log('📍 Location obtained:', location);
        },
        (error) => {
          console.warn('Location access denied or failed:', error.message);
          
          // Provide user-friendly feedback based on error type
          switch (error.code) {
            case error.PERMISSION_DENIED:
              console.log('📍 Using default location (New York City) - Location permission denied');
              break;
            case error.POSITION_UNAVAILABLE:
              console.log('📍 Using default location (New York City) - Location unavailable');
              break;
            case error.TIMEOUT:
              console.log('📍 Using default location (New York City) - Location request timeout');
              break;
            default:
              console.log('📍 Using default location (New York City) - Unknown location error');
              break;
          }
          
          // Default to New York City if location access fails
          setUserLocation({ lat: 40.7128, lng: -74.0060 });
        },
        {
          enableHighAccuracy: true,
          timeout: 10000,
          maximumAge: 300000 // 5 minutes
        }
      );
    } else {
      console.log('📍 Geolocation not supported - using default location (New York City)');
      // Default to New York City if geolocation is not supported
      setUserLocation({ lat: 40.7128, lng: -74.0060 });
    }
  };

  const loadAdventureHistory = async () => {
    try {
      const response = await adventureApi.getUserAdventures();
      if (response.success) {
        setAdventureHistory(response.data);
      }
    } catch (error) {
      console.error('Failed to load adventure history:', error);
    }
  };

  const generateAdventure = async (adventureData) => {
    try {
      setLoading(true);
      
      const requestData = {
        location: userLocation,
        interests: adventureData.interests,
        duration: adventureData.duration,
        maxDistance: adventureData.maxDistance,
        socialMode: adventureData.socialMode,
        friends: adventureData.friends
      };

      const response = await adventureApi.generateAdventure(requestData);
      
      if (response.success) {
        const adventure = response.data;
        setCurrentAdventure(adventure);
        setAdventureHistory(prev => [adventure, ...prev]);
        toast.success('Adventure generated successfully!');
        return { success: true, adventure };
      } else {
        toast.error(response.message || 'Failed to generate adventure');
        return { success: false, message: response.message };
      }
    } catch (error) {
      console.error('Adventure generation error:', error);
      toast.error('Failed to generate adventure. Please try again.');
      return { success: false, message: 'Failed to generate adventure. Please try again.' };
    } finally {
      setLoading(false);
    }
  };

  const startAdventure = async (adventureId) => {
    try {
      const response = await adventureApi.startAdventure(adventureId);
      
      if (response.success) {
        const adventure = response.data;
        setCurrentAdventure(adventure);
        toast.success('Adventure started!');
        return { success: true, adventure };
      } else {
        toast.error(response.message || 'Failed to start adventure');
        return { success: false, message: response.message };
      }
    } catch (error) {
      console.error('Start adventure error:', error);
      toast.error('Failed to start adventure. Please try again.');
      return { success: false, message: 'Failed to start adventure. Please try again.' };
    }
  };

  const completeAdventure = async (adventureId, feedback = null) => {
    try {
      const response = await adventureApi.completeAdventure(adventureId, feedback);
      
      if (response.success) {
        const adventure = response.data;
        setCurrentAdventure(null);
        setAdventureHistory(prev => 
          prev.map(a => a._id === adventureId ? adventure : a)
        );
        toast.success('Adventure completed! Great job!');
        return { success: true, adventure };
      } else {
        toast.error(response.message || 'Failed to complete adventure');
        return { success: false, message: response.message };
      }
    } catch (error) {
      console.error('Complete adventure error:', error);
      toast.error('Failed to complete adventure. Please try again.');
      return { success: false, message: 'Failed to complete adventure. Please try again.' };
    }
  };

  const updateAdventureStep = async (adventureId, stepIndex, action) => {
    try {
      const response = await adventureApi.updateAdventureStep(adventureId, stepIndex, action);
      
      if (response.success) {
        const adventure = response.data;
        setCurrentAdventure(adventure);
        return { success: true, adventure };
      } else {
        toast.error(response.message || 'Failed to update step');
        return { success: false, message: response.message };
      }
    } catch (error) {
      console.error('Update step error:', error);
      toast.error('Failed to update step. Please try again.');
      return { success: false, message: 'Failed to update step. Please try again.' };
    }
  };

  const getAdventure = async (adventureId) => {
    try {
      const response = await adventureApi.getAdventure(adventureId);
      
      if (response.success) {
        return { success: true, adventure: response.data };
      } else {
        return { success: false, message: response.message };
      }
    } catch (error) {
      console.error('Get adventure error:', error);
      return { success: false, message: 'Failed to get adventure.' };
    }
  };

  const shareAdventure = async (adventureId, shareData) => {
    try {
      const response = await adventureApi.shareAdventure(adventureId, shareData);
      
      if (response.success) {
        toast.success('Adventure shared successfully!');
        return { success: true };
      } else {
        toast.error(response.message || 'Failed to share adventure');
        return { success: false, message: response.message };
      }
    } catch (error) {
      console.error('Share adventure error:', error);
      toast.error('Failed to share adventure. Please try again.');
      return { success: false, message: 'Failed to share adventure. Please try again.' };
    }
  };

  const getAdventureRecommendations = async (location, limit = 5) => {
    try {
      const response = await adventureApi.getAdventureRecommendations(location, limit);
      
      if (response.success) {
        return { success: true, recommendations: response.data };
      } else {
        return { success: false, message: response.message };
      }
    } catch (error) {
      console.error('Get recommendations error:', error);
      return { success: false, message: 'Failed to get recommendations.' };
    }
  };

  const getAdventureAnalytics = async (timeRange = '30d') => {
    try {
      const response = await adventureApi.getAdventureAnalytics(timeRange);
      
      if (response.success) {
        return { success: true, analytics: response.data };
      } else {
        return { success: false, message: response.message };
      }
    } catch (error) {
      console.error('Get analytics error:', error);
      return { success: false, message: 'Failed to get analytics.' };
    }
  };

  const value = {
    currentAdventure,
    adventureHistory,
    loading,
    userLocation,
    generateAdventure,
    startAdventure,
    completeAdventure,
    updateAdventureStep,
    getAdventure,
    shareAdventure,
    getAdventureRecommendations,
    getAdventureAnalytics,
    loadAdventureHistory,
    setCurrentAdventure
  };

  return (
    <AdventureContext.Provider value={value}>
      {children}
    </AdventureContext.Provider>
  );
};
