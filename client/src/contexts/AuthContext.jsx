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
  const [loading, setLoading] = useState(true); // Start with loading to check for existing session
  const [token, setToken] = useState(() => {
    // Initialize token from localStorage if it exists
    const storedToken = localStorage.getItem('token');
    return storedToken && storedToken !== 'null' && storedToken !== 'undefined' ? storedToken : null;
  });
  const navigate = useNavigate();

  useEffect(() => {
    // Check for existing session on app load
    initializeAuth();
  }, []);

  const initializeAuth = async () => {
    try {
      // Check if we have a token in localStorage
      const storedToken = localStorage.getItem('token');
      const storedUser = localStorage.getItem('user');
      
      if (storedToken && storedUser) {
        try {
          // Try to parse stored user data
          const userData = JSON.parse(storedUser);
          setUser(userData);
          setToken(storedToken);
          console.log('✅ Session restored from localStorage');
        } catch (parseError) {
          console.warn('Invalid stored user data, clearing session');
          clearSession();
        }
      } else {
        console.log('ℹ️ No existing session found');
      }
    } catch (error) {
      console.error('Error initializing auth:', error);
      clearSession();
    } finally {
      setLoading(false);
    }
  };

  const clearSession = () => {
    setUser(null);
    setToken(null);
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    localStorage.removeItem('refreshToken');
  };

  const tryRefresh = async () => {
    try {
      const res = await authApi.refreshToken();
      if (res.success) {
        const { user, token } = res.data;
        setUser(user);
        setToken(token);
        localStorage.setItem('token', token);
        localStorage.setItem('user', JSON.stringify(user));
        return true;
      }
    } catch (error) {
      console.warn('Token refresh failed:', error.message);
    }
    return false;
  };

  const verifyToken = async () => {
    if (!token) return;
    
    try {
      const response = await authApi.verifyToken();
      if (response.success) {
        setUser(response.data.user);
        localStorage.setItem('user', JSON.stringify(response.data.user));
        return true;
      } else {
        // Try to refresh the token
        const refreshed = await tryRefresh();
        if (!refreshed) {
          clearSession();
        }
        return refreshed;
      }
    } catch (error) {
      console.warn('Token verification failed:', error.message);
      // Try to refresh the token
      const refreshed = await tryRefresh();
      if (!refreshed) {
        clearSession();
      }
      return refreshed;
    }
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
        localStorage.setItem('user', JSON.stringify(user));
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
        localStorage.setItem('user', JSON.stringify(user));
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
    clearSession();
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
    localStorage.setItem('user', JSON.stringify(updatedUser));
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
