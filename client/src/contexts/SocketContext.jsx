import React, { createContext, useContext, useEffect, useState } from 'react';
import { io } from 'socket.io-client';
import { useAuth } from './AuthContext';
import toast from 'react-hot-toast';

const SocketContext = createContext();

export const useSocket = () => {
  const context = useContext(SocketContext);
  if (!context) {
    throw new Error('useSocket must be used within a SocketProvider');
  }
  return context;
};

export const SocketProvider = ({ children }) => {
  const [socket, setSocket] = useState(null);
  const [connected, setConnected] = useState(false);
  const { user, isAuthenticated } = useAuth();

  useEffect(() => {
    if (isAuthenticated && user) {
      // Extract base URL without /api suffix for Socket.IO
      const baseUrl = (import.meta.env.VITE_API_URL || 'http://localhost:5000/api').replace('/api', '');
      const newSocket = io(baseUrl, {
        auth: {
          userId: user._id
        },
        transports: ['websocket', 'polling'],
        timeout: 20000,
        forceNew: true
      });

      newSocket.on('connect', () => {
        console.log('Socket connected');
        setConnected(true);
        newSocket.emit('join_user_room', user._id);
      });

      newSocket.on('disconnect', () => {
        console.log('Socket disconnected');
        setConnected(false);
      });

      newSocket.on('connect_error', (error) => {
        console.warn('Socket connection error (backend may not be running):', error.message);
        setConnected(false);
        // Don't show error toast for development - backend might not be running
        if (import.meta.env.PROD) {
          toast.error('Connection to server lost. Please refresh the page.');
        }
      });

      // Adventure notifications
      newSocket.on('adventure_generated', (data) => {
        toast.success(`Adventure "${data.name}" is ready!`);
      });

      newSocket.on('adventure_started', (data) => {
        toast.success(`Adventure "${data.name}" has started!`);
      });

      newSocket.on('adventure_completed', (data) => {
        toast.success(`Adventure completed! You earned ${data.points} points!`);
      });

      newSocket.on('step_updated', (data) => {
        console.log('Step updated:', data);
      });

      // Event notifications
      newSocket.on('event_created', (data) => {
        toast.success(`New event: ${data.name}`);
      });

      newSocket.on('event_updated', (data) => {
        toast.info(`Event "${data.name}" has been updated`);
      });

      newSocket.on('event_cancelled', (data) => {
        toast.error(`Event "${data.name}" has been cancelled`);
      });

      newSocket.on('user_joined', (data) => {
        toast.info('Someone joined the event');
      });

      newSocket.on('user_left', (data) => {
        toast.info('Someone left the event');
      });

      // General notifications
      newSocket.on('notification', (data) => {
        toast(data.message, {
          duration: 5000,
          icon: getNotificationIcon(data.type)
        });
      });

      setSocket(newSocket);

      return () => {
        newSocket.close();
        setSocket(null);
        setConnected(false);
      };
    } else {
      if (socket) {
        socket.close();
        setSocket(null);
        setConnected(false);
      }
    }
  }, [isAuthenticated, user]);

  const joinAdventureRoom = (adventureId) => {
    if (socket && connected) {
      socket.emit('join_adventure_room', adventureId);
    }
  };

  const leaveAdventureRoom = (adventureId) => {
    if (socket && connected) {
      socket.emit('leave_adventure_room', adventureId);
    }
  };

  const joinEventRoom = (eventId) => {
    if (socket && connected) {
      socket.emit('join_event_room', eventId);
    }
  };

  const leaveEventRoom = (eventId) => {
    if (socket && connected) {
      socket.emit('leave_event_room', eventId);
    }
  };

  const value = {
    socket,
    connected,
    joinAdventureRoom,
    leaveAdventureRoom,
    joinEventRoom,
    leaveEventRoom
  };

  return (
    <SocketContext.Provider value={value}>
      {children}
    </SocketContext.Provider>
  );
};

const getNotificationIcon = (type) => {
  switch (type) {
    case 'adventure_generated':
      return '🎯';
    case 'step_reminder':
      return '⏰';
    case 'weather_alert':
      return '🌤️';
    case 'venue_change':
      return '📍';
    case 'friend_joined':
      return '👥';
    case 'badge_earned':
      return '🏆';
    case 'points_earned':
      return '⭐';
    case 'event_reminder':
      return '📅';
    default:
      return '🔔';
  }
};
