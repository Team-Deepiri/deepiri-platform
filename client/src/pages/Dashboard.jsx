import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { useAuth } from '../contexts/AuthContext';
import { useAdventure } from '../contexts/AdventureContext';
import { userApi } from '../api/userApi';
import { adventureApi } from '../api/adventureApi';
import { externalApi } from '../api/externalApi';
import InventoryWidget from '../components/InventoryWidget';
import toast from 'react-hot-toast';

const Dashboard = () => {
  const { user } = useAuth();
  const { userLocation } = useAdventure();
  const navigate = useNavigate();

  const [stats, setStats] = useState(null);
  const [recentAdventures, setRecentAdventures] = useState([]);
  const [weather, setWeather] = useState(null);
  const [nearbyEvents, setNearbyEvents] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      
      const [statsResponse, adventuresResponse] = await Promise.all([
        userApi.getStats(),
        adventureApi.getUserAdventures(null, 5, 0)
      ]);

      if (statsResponse.success) {
        setStats(statsResponse.data);
      }

      if (adventuresResponse.success) {
        setRecentAdventures(adventuresResponse.data);
      }

      // Load weather if location is available
      if (userLocation) {
        try {
          const weatherResponse = await externalApi.getCurrentWeather(userLocation);
          if (weatherResponse.success) {
            setWeather(weatherResponse.data);
          }
        } catch (error) {
          console.error('Failed to load weather:', error);
        }
      }

      // Load nearby events
      if (userLocation) {
        try {
          const eventsResponse = await externalApi.getNearbyEvents(userLocation, 5000);
          if (eventsResponse.success) {
            setNearbyEvents(eventsResponse.data.slice(0, 3));
          }
        } catch (error) {
          console.error('Failed to load events:', error);
        }
      }

    } catch (error) {
      console.error('Failed to load dashboard data:', error);
      toast.error('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  };

  const getTimeOfDay = () => {
    const hour = new Date().getHours();
    if (hour < 6) return 'night';
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    if (hour < 22) return 'evening';
    return 'night';
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-vh-100 bg-gray-50">
      <div className="container px-3 py-4">
        {/* Welcome Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          className="mb-8"
        >
          <div className="bg-gradient-to-r from-purple-600 to-emerald-500 header-hero text-white">
            <h1 className="text-3xl font-bold mb-2">
              {getGreeting()}, {user?.name}! 👋
            </h1>
            <p className="text-emerald-100 text-lg">
              Ready for your next adventure? Let's explore what's around you.
            </p>
            {weather && (
              <div className="mt-4 flex items-center space-x-4">
                <span className="text-2xl">
                  {weather.condition === 'Clear' ? '☀️' : 
                   weather.condition === 'Clouds' ? '☁️' : 
                   weather.condition === 'Rain' ? '🌧️' : '🌤️'}
                </span>
                <span className="text-lg">
                  {weather.temperature}°F • {weather.condition}
                </span>
              </div>
            )}
          </div>
        </motion.div>

        <div className="row g-4">
          {/* Main Content */}
          <div className="col-lg-8 d-flex flex-column gap-4">
            {/* Quick Actions */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.2 }}
              className="bg-white rounded-xl shadow-lg p-4"
            >
              <h2 className="text-2xl font-bold text-gray-900 mb-6">
                Quick Actions 🚀
              </h2>
              <div className="row g-3">
                <Link
                  to="/adventure/generate"
                  className="group p-4 bg-gradient-to-r from-blue-500 to-blue-600 rounded-lg text-white transition-all duration-200"
                >
                  <div className="flex items-center space-x-4">
                    <div className="text-3xl">🎯</div>
                    <div>
                      <h3 className="text-lg font-semibold">Generate Adventure</h3>
                      <p className="text-blue-100">Create a new personalized adventure</p>
                    </div>
                  </div>
                </Link>

                <Link
                  to="/events"
                  className="group p-4 bg-gradient-to-r from-purple-500 to-purple-600 rounded-lg text-white transition-all duration-200"
                >
                  <div className="flex items-center space-x-4">
                    <div className="text-3xl">📅</div>
                    <div>
                      <h3 className="text-lg font-semibold">Browse Events</h3>
                      <p className="text-purple-100">Discover local events and meetups</p>
                    </div>
                  </div>
                </Link>

                <Link
                  to="/friends"
                  className="group p-4 bg-gradient-to-r from-green-500 to-green-600 rounded-lg text-white transition-all duration-200"
                >
                  <div className="flex items-center space-x-4">
                    <div className="text-3xl">👥</div>
                    <div>
                      <h3 className="text-lg font-semibold">Connect</h3>
                      <p className="text-green-100">Find and invite friends</p>
                    </div>
                  </div>
                </Link>

                <Link
                  to="/adventures"
                  className="group p-4 bg-gradient-to-r from-orange-500 to-orange-600 rounded-lg text-white transition-all duration-200"
                >
                  <div className="flex items-center space-x-4">
                    <div className="text-3xl">🗺️</div>
                    <div>
                      <h3 className="text-lg font-semibold">My Adventures</h3>
                      <p className="text-orange-100">View your adventure history</p>
                    </div>
                  </div>
                </Link>
              </div>
            </motion.div>

            {/* Recent Adventures */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.4 }}
              className="bg-white rounded-xl shadow-lg p-4 lift"
            >
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-2xl font-bold text-gray-900">
                  Recent Adventures 🗺️
                </h2>
                <Link
                  to="/adventures"
                  className="text-blue-600 hover:text-blue-700 font-medium"
                >
                  View All
                </Link>
              </div>

              {recentAdventures.length > 0 ? (
                <div className="space-y-4">
                  {recentAdventures.map((adventure) => (
                    <div
                      key={adventure._id}
                      className="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors duration-200 cursor-pointer"
                      onClick={() => navigate(`/adventure/${adventure._id}`)}
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <h3 className="font-semibold text-gray-900">
                            {adventure.name}
                          </h3>
                          <p className="text-sm text-gray-600">
                            {adventure.totalDuration} minutes • {adventure.steps.length} stops
                          </p>
                        </div>
                        <div className="text-right">
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                            adventure.status === 'completed' ? 'bg-green-100 text-green-800' :
                            adventure.status === 'active' ? 'bg-blue-100 text-blue-800' :
                            'bg-gray-100 text-gray-800'
                          }`}>
                            {adventure.status}
                          </span>
                          <p className="text-xs text-gray-500 mt-1">
                            {new Date(adventure.metadata.generatedAt).toLocaleDateString()}
                          </p>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8">
                  <div className="text-4xl mb-4">🗺️</div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">
                    No adventures yet
                  </h3>
                  <p className="text-gray-600 mb-4">
                    Generate your first adventure to get started!
                  </p>
                  <Link
                    to="/adventure/generate"
                    className="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200"
                  >
                    Generate Adventure
                  </Link>
                </div>
              )}
            </motion.div>
          </div>

          {/* Sidebar */}
          <div className="col-lg-4 d-flex flex-column gap-4">
            {/* Inventory Widget */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.2 }}
            >
              <InventoryWidget />
            </motion.div>

            {/* Stats */}
            {stats && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.8, delay: 0.3 }}
                className="bg-white rounded-xl shadow-lg p-4"
              >
                <h2 className="text-xl font-bold text-gray-900 mb-4">
                  Your Stats 📊
                </h2>
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-gray-600">Adventures Completed</span>
                    <span className="font-semibold text-gray-900">
                      {stats.adventureStats?.completed || 0}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-600">Total Points</span>
                    <span className="font-semibold text-gray-900">
                      {stats.totalPoints || 0}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-600">Current Streak</span>
                    <span className="font-semibold text-gray-900">
                      {stats.streak || 0} days
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-600">Friends</span>
                    <span className="font-semibold text-gray-900">
                      {stats.friendsCount || 0}
                    </span>
                  </div>
                </div>
              </motion.div>
            )}

            {/* Nearby Events */}
            {nearbyEvents.length > 0 && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.8, delay: 0.5 }}
                className="bg-white rounded-xl shadow-lg p-4"
              >
                <h2 className="text-xl font-bold text-gray-900 mb-4">
                  Nearby Events 📅
                </h2>
                <div className="space-y-4">
                  {nearbyEvents.map((event, index) => (
                    <div key={index} className="p-3 border border-gray-200 rounded-lg">
                      <h3 className="font-semibold text-gray-900 text-sm">
                        {event.name}
                      </h3>
                      <p className="text-xs text-gray-600">
                        {new Date(event.startTime).toLocaleDateString()}
                      </p>
                    </div>
                  ))}
                </div>
                <Link
                  to="/events"
                  className="block text-center mt-4 text-blue-600 hover:text-blue-700 font-medium text-sm"
                >
                  View All Events
                </Link>
              </motion.div>
            )}

            {/* Quick Tips */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.6 }}
              className="bg-gradient-to-r from-yellow-50 to-orange-50 rounded-xl p-4 border border-yellow-200"
            >
              <h2 className="text-xl font-bold text-gray-900 mb-4">
                💡 Pro Tip
              </h2>
              <p className="text-gray-700 text-sm">
                {getTimeOfDay() === 'morning' && "Perfect time for outdoor adventures and coffee shop visits!"}
                {getTimeOfDay() === 'afternoon' && "Great time for food tours and cultural experiences!"}
                {getTimeOfDay() === 'evening' && "Ideal for nightlife, concerts, and social events!"}
                {getTimeOfDay() === 'night' && "Late night adventures await - bars and nightlife are calling!"}
              </p>
            </motion.div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;