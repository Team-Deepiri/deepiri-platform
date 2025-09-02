import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { useAuth } from '../contexts/AuthContext';
import { externalApi } from '../api/externalApi';
import toast from 'react-hot-toast';

const Home = () => {
  const { isAuthenticated, user } = useAuth();
  const navigate = useNavigate();
  const [currentTime, setCurrentTime] = useState(new Date());
  const [weather, setWeather] = useState(null);
  const [location, setLocation] = useState(null);

  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date());
    }, 1000);

    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        async (position) => {
          const userLocation = {
            lat: position.coords.latitude,
            lng: position.coords.longitude
          };
          setLocation(userLocation);
          
          try {
            const weatherResponse = await externalApi.getCurrentWeather(userLocation);
            if (weatherResponse.success) {
              setWeather(weatherResponse.data);
            }
          } catch (error) {
            console.error('Failed to fetch weather:', error);
          }
        },
        (error) => {
          console.error('Error getting location:', error);
        }
      );
    }
  }, []);

  const getGreeting = () => {
    const hour = currentTime.getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  };

  const getTimeOfDay = () => {
    const hour = currentTime.getHours();
    if (hour < 6) return 'night';
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    if (hour < 22) return 'evening';
    return 'night';
  };

  const handleGetStarted = () => {
    if (isAuthenticated) {
      navigate('/adventure/generate');
    } else {
      navigate('/register');
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50">
      {/* Hero Section */}
      <section className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-blue-600/10 to-purple-600/10"></div>
        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
            className="text-center"
          >
            <h1 className="text-5xl md:text-7xl font-bold text-gray-900 mb-6">
              <span className="bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                Trailblip
              </span>
            </h1>
            <p className="text-xl md:text-2xl text-gray-600 mb-8 max-w-3xl mx-auto">
              AI-powered micro-adventures that turn your free time into unforgettable experiences
            </p>
            
            {isAuthenticated && user && (
              <div className="mb-8">
                <p className="text-lg text-gray-700">
                  {getGreeting()}, {user.name}! Ready for your next adventure?
                </p>
                {weather && (
                  <p className="text-sm text-gray-500 mt-2">
                    {weather.condition} • {weather.temperature}°F
                  </p>
                )}
              </div>
            )}

            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={handleGetStarted}
              className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-8 py-4 rounded-full text-lg font-semibold shadow-lg hover:shadow-xl transition-all duration-300"
            >
              {isAuthenticated ? 'Generate Adventure' : 'Get Started'}
            </motion.button>
          </motion.div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
            className="text-center mb-16"
          >
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              Why Choose Trailblip?
            </h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              We use cutting-edge AI to create personalized 30-90 minute adventures 
              that match your interests, location, and schedule.
            </p>
          </motion.div>

          <div className="grid md:grid-cols-3 gap-8">
            {[
              {
                icon: '🤖',
                title: 'AI-Powered Planning',
                description: 'Advanced AI analyzes your preferences, weather, and local events to create the perfect adventure itinerary.'
              },
              {
                icon: '📍',
                title: 'Location-Aware',
                description: 'Discover hidden gems and popular spots within your preferred distance and travel time.'
              },
              {
                icon: '👥',
                title: 'Social & Solo Options',
                description: 'Choose to explore alone, with friends, or meet new people through our community events.'
              },
              {
                icon: '⏰',
                title: 'Time-Optimized',
                description: 'Perfect for busy schedules - get maximum adventure in 30-90 minutes of free time.'
              },
              {
                icon: '🎯',
                title: 'Interest-Based',
                description: 'From food tours to art walks, nightlife to outdoor adventures - we match your passions.'
              },
              {
                icon: '🏆',
                title: 'Gamified Experience',
                description: 'Earn points, unlock badges, and track your adventure streak as you explore your city.'
              }
            ].map((feature, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.8, delay: index * 0.1 }}
                className="text-center p-6 rounded-xl hover:shadow-lg transition-shadow duration-300"
              >
                <div className="text-4xl mb-4">{feature.icon}</div>
                <h3 className="text-xl font-semibold text-gray-900 mb-3">
                  {feature.title}
                </h3>
                <p className="text-gray-600">
                  {feature.description}
                </p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section className="py-20 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
            className="text-center mb-16"
          >
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              How It Works
            </h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              Get your personalized adventure in just a few simple steps
            </p>
          </motion.div>

          <div className="grid md:grid-cols-4 gap-8">
            {[
              {
                step: '1',
                title: 'Set Preferences',
                description: 'Tell us your interests, available time, and location preferences.'
              },
              {
                step: '2',
                title: 'AI Generates Plan',
                description: 'Our AI creates a personalized itinerary with venues, timing, and activities.'
              },
              {
                step: '3',
                title: 'Start Adventure',
                description: 'Follow your step-by-step guide with real-time notifications and updates.'
              },
              {
                step: '4',
                title: 'Share & Earn',
                description: 'Complete challenges, earn points, and share your experiences with friends.'
              }
            ].map((step, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.8, delay: index * 0.1 }}
                className="text-center"
              >
                <div className="w-16 h-16 bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-full flex items-center justify-center text-2xl font-bold mx-auto mb-4">
                  {step.step}
                </div>
                <h3 className="text-xl font-semibold text-gray-900 mb-3">
                  {step.title}
                </h3>
                <p className="text-gray-600">
                  {step.description}
                </p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 bg-gradient-to-r from-blue-600 to-purple-600">
        <div className="max-w-4xl mx-auto text-center px-4 sm:px-6 lg:px-8">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
          >
            <h2 className="text-4xl font-bold text-white mb-6">
              Ready to Start Your Adventure?
            </h2>
            <p className="text-xl text-blue-100 mb-8">
              Join thousands of adventurers who have discovered their city in new and exciting ways.
            </p>
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={handleGetStarted}
              className="bg-white text-blue-600 px-8 py-4 rounded-full text-lg font-semibold shadow-lg hover:shadow-xl transition-all duration-300"
            >
              {isAuthenticated ? 'Generate Your Adventure' : 'Get Started Free'}
            </motion.button>
          </motion.div>
        </div>
      </section>
    </div>
  );
};

export default Home;