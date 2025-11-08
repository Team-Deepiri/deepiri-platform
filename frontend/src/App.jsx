import React, { useEffect } from 'react';
import { Routes, Route, useLocation } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from 'react-query';
import { Toaster } from 'react-hot-toast';
import { AuthProvider } from './contexts/AuthContext';
import { SocketProvider } from './contexts/SocketContext';
import { AdventureProvider } from './contexts/AdventureContext';
import ProtectedRoute from './components/ProtectedRoute';
import ErrorBoundary from './components/ErrorBoundary';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import HMRStatus from './components/HMRStatus';
import { setupGlobalErrorHandling, setupPerformanceMonitoring } from './utils/logger';

// Pages
import Home from './pages/Home';
import Login from './pages/Login';
import Register from './pages/Register';
import Dashboard from './pages/Dashboard';
import AdventureGenerator from './pages/AdventureGenerator';
import AdventureDetail from './pages/AdventureDetail';
import AdventureHistory from './pages/AdventureHistory';
import Events from './pages/Events';
import EventDetail from './pages/EventDetail';
import CreateEvent from './pages/CreateEvent';
import Profile from './pages/Profile';
import Friends from './pages/Friends';
import Leaderboard from './pages/Leaderboard';
import TaskManagement from './pages/TaskManagement';
import Challenges from './pages/Challenges';
import GamificationDashboard from './pages/GamificationDashboard';
import AnalyticsDashboard from './pages/AnalyticsDashboard';
import Notifications from './pages/Notifications';
import AgentChat from './pages/AgentChat';
import ProductivityChat from './pages/ProductivityChat';
import PythonTools from './pages/PythonTools';
import UserInventory from './pages/UserInventory';



// Create a client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

function App() {
  const location = useLocation();
  const pathname = location?.pathname || '/';
  const isAuthRoute = pathname === '/login' || pathname === '/register';
  useEffect(() => {
    // Setup global error handling and performance monitoring
    setupGlobalErrorHandling();
    setupPerformanceMonitoring();
  }, []);

  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <AuthProvider>
          <SocketProvider>
            <AdventureProvider>
                <div className="min-h-screen relative overflow-hidden bg-gray-900">
                  {/* Animated Background Layer */}
                  <div className="fixed inset-0 animated-bg opacity-30" />
                  {/* Subtle pattern overlay */}
                  <div className="fixed inset-0 bg-[url('data:image/svg+xml,%3Csvg width=%2260%22 height=%2260%22 viewBox=%220 0 60 60%22 xmlns=%22http://www.w3.org/2000/svg%22%3E%3Cg fill=%22none%22 fill-rule=%22evenodd%22%3E%3Cg fill=%22%239C92AC%22 fill-opacity=%220.05%22%3E%3Ccircle cx=%2230%22 cy=%2230%22 r=%222%22/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')] opacity-10" />
                  {/* Gradient Orbs */}
                  <div className="fixed top-[-4rem] left-1/4 w-96 h-96 bg-purple-400 rounded-full mix-blend-multiply filter blur-2xl opacity-20 animate-pulse" />
                  <div className="fixed top-[10%] right-1/5 w-96 h-96 bg-cyan-400 rounded-full mix-blend-multiply filter blur-2xl opacity-20 animate-pulse" style={{ animationDelay: '2s' }} />
                  <div className="fixed bottom-[-4rem] left-1/2 w-96 h-96 bg-purple-500 rounded-full mix-blend-multiply filter blur-2xl opacity-20 animate-pulse" style={{ animationDelay: '4s' }} />
                  
                  <Navbar />
                  <main className={`${isAuthRoute ? 'pt-0 pb-0' : 'pt-20 pb-20'} relative z-10`}>
                    <div className="site-container">
                      <Routes>
                    {/* Public Routes */}
                    <Route path="/" element={<Home />} />
                    <Route path="/home" element={<Home />} />
                    <Route path="/login" element={<Login />} />
                    <Route path="/register" element={<Register />} />
                    
                    {/* Protected Routes */}
                    <Route path="/dashboard" element={
                      <ProtectedRoute>
                        <Dashboard />
                      </ProtectedRoute>
                    } />
                    <Route path="/adventure/generate" element={
                      <ProtectedRoute>
                        <AdventureGenerator />
                      </ProtectedRoute>
                    } />
                    <Route path="/adventure/:id" element={
                      <ProtectedRoute>
                        <AdventureDetail />
                      </ProtectedRoute>
                    } />
                    <Route path="/adventures" element={
                      <ProtectedRoute>
                        <AdventureHistory />
                      </ProtectedRoute>
                    } />
                    <Route path="/events" element={
                      <ProtectedRoute>
                        <Events />
                      </ProtectedRoute>
                    } />
                    <Route path="/events/:id" element={
                      <ProtectedRoute>
                        <EventDetail />
                      </ProtectedRoute>
                    } />
                    <Route path="/events/create" element={
                      <ProtectedRoute>
                        <CreateEvent />
                      </ProtectedRoute>
                    } />
                    <Route path="/profile" element={
                      <ProtectedRoute>
                        <Profile />
                      </ProtectedRoute>
                    } />
                    <Route path="/friends" element={
                      <ProtectedRoute>
                        <Friends />
                      </ProtectedRoute>
                    } />
                    <Route path="/leaderboard" element={
                      <ProtectedRoute>
                        <Leaderboard />
                      </ProtectedRoute>
                    } />
                    <Route path="/tasks" element={
                      <ProtectedRoute>
                        <TaskManagement />
                      </ProtectedRoute>
                    } />
                    <Route path="/challenges" element={
                      <ProtectedRoute>
                        <Challenges />
                      </ProtectedRoute>
                    } />
                    <Route path="/gamification" element={
                      <ProtectedRoute>
                        <GamificationDashboard />
                      </ProtectedRoute>
                    } />
                    <Route path="/analytics" element={
                      <ProtectedRoute>
                        <AnalyticsDashboard />
                      </ProtectedRoute>
                    } />
                    <Route path="/notifications" element={
                      <ProtectedRoute>
                        <Notifications />
                      </ProtectedRoute>
                    } />
                    <Route path="/agent" element={
                      <ProtectedRoute>
                        <AgentChat />
                      </ProtectedRoute>
                    } />
                    <Route path="/chat" element={
                      <ProtectedRoute>
                        <ProductivityChat />
                      </ProtectedRoute>
                    } />
                    <Route path="/python-tools" element={
                      <ProtectedRoute>
                        <PythonTools />
                      </ProtectedRoute>
                    } />
                    <Route path="/inventory" element={
                      <ProtectedRoute>
                        <UserInventory />
                      </ProtectedRoute>
                    } />
                      </Routes>
                    </div>
                </main>
                <Footer />
                <Toaster
                  position="top-right"
                  toastOptions={{
                    duration: 4000,
                    style: {
                      background: 'rgba(0, 0, 0, 0.8)',
                      backdropFilter: 'blur(10px)',
                      color: '#fff',
                      border: '1px solid rgba(255, 255, 255, 0.2)',
                      borderRadius: '12px',
                    },
                    success: {
                      duration: 3000,
                      iconTheme: {
                        primary: '#10B981',
                        secondary: '#fff',
                      },
                    },
                    error: {
                      duration: 5000,
                      iconTheme: {
                        primary: '#EF4444',
                        secondary: '#fff',
                      },
                    },
                  }}
                />
                <HMRStatus />
              </div>
          </AdventureProvider>
        </SocketProvider>
      </AuthProvider>
    </QueryClientProvider>
    </ErrorBoundary>
  );
}

export default App;
