import React, { createContext, useContext, useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { authApi } from '../api/authApi';
import toast from 'react-hot-toast';

const AuthContext = createContext();

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(false); // CHANGED: Start as false to stop loading
  const [token, setToken] = useState(null); // CHANGED: Force null to clear any token
  const navigate = useNavigate();

  useEffect(() => {
    // EMERGENCY: Clear all tokens and disable everything
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    localStorage.removeItem('refreshToken');
    console.log('🚨 AUTH SYSTEM DISABLED - All tokens cleared');
    setLoading(false);
    setUser(null);
    setToken(null);
  }, []);

  const tryRefresh = async () => {
    // EMERGENCY: Completely disabled to stop infinite loops
    console.log('🚨 tryRefresh() DISABLED');
    return false;
  };

  const verifyToken = async () => {
    // EMERGENCY: Completely disabled to stop infinite loops
    console.log('🚨 verifyToken() DISABLED');
    return;
  };

  const login = async (email, password) => {
    try {
      setLoading(true);
      const response = await authApi.login(email, password);
      
      if (response.success) {
        const { user, token } = response.data;
        setUser(user);
        setToken(token);
        localStorage.setItem('token', token);
        toast.success('Welcome back!');
        navigate('/home');
        return { success: true };
      } else {
        toast.error(response.message || 'Login failed');
        return { success: false, message: response.message };
      }
    } catch (error) {
      console.error('Login error:', error);
      toast.error('Login failed. Please try again.');
      return { success: false, message: 'Login failed. Please try again.' };
    } finally {
      setLoading(false);
    }
  };

  const register = async (nameOrData, email, password) => {
    try {
      setLoading(true);
      const payload = typeof nameOrData === 'object'
        ? nameOrData
        : { name: nameOrData, email, password };
      const response = await authApi.register(payload);
      
      if (response.success) {
        const { user, token } = response.data;
        setUser(user);
        setToken(token);
        localStorage.setItem('token', token);
        toast.success('Account created successfully!');
        navigate('/home');
        return { success: true };
      } else {
        toast.error(response.message || 'Registration failed');
        return { success: false, message: response.message };
      }
    } catch (error) {
      console.error('Registration error:', error);
      toast.error('Registration failed. Please try again.');
      return { success: false, message: 'Registration failed. Please try again.' };
    } finally {
      setLoading(false);
    }
  };

  const logout = () => {
    setUser(null);
    setToken(null);
    localStorage.removeItem('token');
    // Don't navigate on logout if we're already on register/login pages
    const currentPath = window.location.pathname;
    if (!['/login', '/register', '/'].includes(currentPath)) {
      navigate('/');
    }
    // Only show toast if it's an intentional logout (when user exists)
    if (user) {
      toast.success('Logged out successfully');
    }
  };

  const updateUser = (updatedUser) => {
    setUser(updatedUser);
  };

  const value = {
    user,
    token,
    loading,
    login,
    register,
    logout,
    updateUser,
    isAuthenticated: !!user
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
