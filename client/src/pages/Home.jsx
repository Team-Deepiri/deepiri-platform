import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { useAuth } from '../contexts/AuthContext';

const Home = () => {
  const { isAuthenticated } = useAuth();
  const [mousePosition, setMousePosition] = useState({ x: 0, y: 0 });

  useEffect(() => {
    const handleMouseMove = (e) => {
      setMousePosition({ x: e.clientX, y: e.clientY });
    };

    window.addEventListener('mousemove', handleMouseMove);
    return () => window.removeEventListener('mousemove', handleMouseMove);
  }, []);

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
        delayChildren: 0.3
      }
    }
  };

  const itemVariants = {
    hidden: { y: 20, opacity: 0 },
    visible: {
      y: 0,
      opacity: 1,
      transition: {
        duration: 0.8,
        ease: "easeOut"
      }
    }
  };

  return (
    <div className="min-h-screen relative overflow-hidden">
      {/* Animated Background */}
      <div className="fixed inset-0 animated-bg opacity-90" />
      
      {/* Floating Particles */}
      <div className="fixed inset-0 pointer-events-none">
        {[...Array(20)].map((_, i) => (
          <motion.div
            key={i}
            className="absolute w-2 h-2 bg-white rounded-full opacity-20"
            style={{
              left: `${Math.random() * 100}%`,
              top: `${Math.random() * 100}%`,
            }}
            animate={{
              y: [0, -30, 0],
              opacity: [0.2, 0.8, 0.2],
            }}
            transition={{
              duration: 3 + Math.random() * 2,
              repeat: Infinity,
              delay: Math.random() * 2,
            }}
          />
        ))}
      </div>

      {/* Mouse Follower */}
      <motion.div
        className="fixed w-6 h-6 bg-gradient-to-r from-purple-400 to-pink-400 rounded-full pointer-events-none z-10 mix-blend-difference"
        animate={{
          x: mousePosition.x - 12,
          y: mousePosition.y - 12,
        }}
        transition={{
          type: "spring",
          stiffness: 500,
          damping: 28
        }}
      />

      <motion.div
        variants={containerVariants}
        initial="hidden"
        animate="visible"
        className="relative z-20"
      >
        {/* Hero Section */}
        <section className="relative min-h-screen flex items-center justify-center px-4 sm:px-6 lg:px-8">
          <div className="max-w-7xl mx-auto text-center">
            <motion.div variants={itemVariants} className="mb-8">
              <motion.h1 
                className="text-6xl md:text-8xl font-bold mb-6"
                initial={{ scale: 0.8 }}
                animate={{ scale: 1 }}
                transition={{ duration: 1, ease: "easeOut" }}
              >
                <span className="gradient-text">tripblip</span>
                <br />
                <span className="gradient-text-secondary">MAG 2.0</span>
              </motion.h1>
              
              <motion.p 
                className="text-xl md:text-2xl text-gray-300 mb-12 max-w-4xl mx-auto leading-relaxed"
                variants={itemVariants}
              >
                Your AI-powered adventure companion. Discover extraordinary experiences, 
                connect with fellow explorers, and create memories that last forever.
              </motion.p>
            </motion.div>

            <motion.div 
              variants={itemVariants}
              className="flex flex-col sm:flex-row gap-6 justify-center items-center mb-16"
            >
              {isAuthenticated ? (
                <>
                  <Link
                    to="/adventure/generate"
                    className="btn-modern btn-primary text-lg px-8 py-4 glow"
                  >
                    <span className="text-2xl mr-2">✨</span>
                    Generate Adventure
                  </Link>
                  <Link
                    to="/dashboard"
                    className="btn-modern btn-glass text-lg px-8 py-4"
                  >
                    <span className="text-2xl mr-2">🚀</span>
                    Go to Dashboard
                  </Link>
                </>
              ) : (
                <>
                  <Link
                    to="/register"
                    className="btn-modern btn-primary text-lg px-8 py-4 glow"
                  >
                    <span className="text-2xl mr-2">🌟</span>
                    Start Your Journey
                  </Link>
                  <Link
                    to="/login"
                    className="btn-modern btn-glass text-lg px-8 py-4"
                  >
                    <span className="text-2xl mr-2">🔑</span>
                    Sign In
                  </Link>
                </>
              )}
            </motion.div>

            {/* Floating Feature Cards */}
            <motion.div 
              variants={itemVariants}
              className="grid md:grid-cols-3 gap-8 max-w-6xl mx-auto"
            >
              {[
                {
                  icon: '🤖',
                  title: 'AI-Powered',
                  description: 'Personalized adventures crafted by advanced AI',
                  gradient: 'from-blue-500 to-purple-500'
                },
                {
                  icon: '🌍',
                  title: 'Global Discovery',
                  description: 'Explore hidden gems around the world',
                  gradient: 'from-green-500 to-blue-500'
                },
                {
                  icon: '👥',
                  title: 'Social Adventure',
                  description: 'Connect and adventure with friends',
                  gradient: 'from-pink-500 to-red-500'
                }
              ].map((feature, index) => (
                <motion.div
                  key={index}
                  variants={itemVariants}
                  className="card-modern text-center group"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                >
                  <motion.div 
                    className={`text-6xl mb-4 float`}
                    style={{ animationDelay: `${index * 0.5}s` }}
                  >
                    {feature.icon}
                  </motion.div>
                  <h3 className="text-2xl font-bold mb-4 gradient-text">{feature.title}</h3>
                  <p className="text-gray-300 leading-relaxed">{feature.description}</p>
                  
                  {/* Hover Effect */}
                  <div className={`absolute inset-0 bg-gradient-to-r ${feature.gradient} opacity-0 group-hover:opacity-10 rounded-2xl transition-opacity duration-300`} />
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* Features Section */}
        <section className="py-32 relative">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <motion.div
              variants={itemVariants}
              className="text-center mb-20"
            >
              <h2 className="text-5xl md:text-6xl font-bold mb-8">
                <span className="gradient-text-accent">Why Choose</span>
                <br />
                <span className="gradient-text-secondary">tripblip?</span>
              </h2>
              <p className="text-xl text-gray-300 max-w-4xl mx-auto leading-relaxed">
                Experience the future of adventure planning with cutting-edge technology, 
                real-time updates, and a vibrant community of explorers.
              </p>
            </motion.div>

            <div className="grid lg:grid-cols-2 gap-12 items-center">
              <motion.div variants={itemVariants} className="space-y-8">
                {[
                  {
                    icon: '🎯',
                    title: 'Precision Planning',
                    description: 'AI algorithms analyze your preferences, weather, and local events to create the perfect itinerary.'
                  },
                  {
                    icon: '⚡',
                    title: 'Real-Time Updates',
                    description: 'Get instant notifications about weather changes, event updates, and adventure progress.'
                  },
                  {
                    icon: '🎨',
                    title: 'Personalized Experience',
                    description: 'Every adventure is uniquely tailored to your interests, budget, and available time.'
                  },
                  {
                    icon: '🏆',
                    title: 'Achievement System',
                    description: 'Earn badges, climb leaderboards, and unlock exclusive adventures as you explore.'
                  }
                ].map((feature, index) => (
                  <motion.div
                    key={index}
                    variants={itemVariants}
                    className="flex items-start space-x-4 group"
                    whileHover={{ x: 10 }}
                  >
                    <div className="text-4xl group-hover:scale-110 transition-transform duration-300">
                      {feature.icon}
                    </div>
                    <div>
                      <h3 className="text-xl font-bold mb-2 gradient-text">{feature.title}</h3>
                      <p className="text-gray-300 leading-relaxed">{feature.description}</p>
                    </div>
                  </motion.div>
                ))}
              </motion.div>

              <motion.div 
                variants={itemVariants}
                className="relative"
              >
                <div className="card-modern p-8 float">
                  <div className="text-center">
                    <div className="text-8xl mb-4">🗺️</div>
                    <h3 className="text-2xl font-bold mb-4 gradient-text">Interactive Map</h3>
                    <p className="text-gray-300 mb-6">
                      Explore your adventure route with our interactive 3D map interface
                    </p>
                    <div className="grid grid-cols-2 gap-4">
                      <div className="card-modern p-4 text-center">
                        <div className="text-2xl mb-2">📍</div>
                        <div className="text-sm font-semibold">Locations</div>
                      </div>
                      <div className="card-modern p-4 text-center">
                        <div className="text-2xl mb-2">⏰</div>
                        <div className="text-sm font-semibold">Timeline</div>
                      </div>
                      <div className="card-modern p-4 text-center">
                        <div className="text-2xl mb-2">🌤️</div>
                        <div className="text-sm font-semibold">Weather</div>
                      </div>
                      <div className="card-modern p-4 text-center">
                        <div className="text-2xl mb-2">👥</div>
                        <div className="text-sm font-semibold">Friends</div>
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            </div>
          </div>
        </section>

        {/* CTA Section */}
        <section className="py-32 relative">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
            <motion.div variants={itemVariants}>
              <h2 className="text-5xl md:text-6xl font-bold mb-8">
                <span className="gradient-text">Ready to</span>
                <br />
                <span className="gradient-text-secondary">Explore?</span>
              </h2>
              <p className="text-xl text-gray-300 mb-12 max-w-4xl mx-auto leading-relaxed">
                Join thousands of adventurers who are already discovering their cities 
                with AI-powered recommendations and creating unforgettable memories.
              </p>
              
              {!isAuthenticated && (
                <motion.div
                  variants={itemVariants}
                  className="flex flex-col sm:flex-row gap-6 justify-center items-center"
                >
                  <Link
                    to="/register"
                    className="btn-modern btn-primary text-xl px-12 py-6 glow-secondary pulse"
                  >
                    <span className="text-3xl mr-3">🚀</span>
                    Start Your Adventure Now
                  </Link>
                  <div className="text-gray-400 text-sm">
                    ✨ Free to join • 🎯 Instant setup • 🌍 Global community
                  </div>
                </motion.div>
              )}
            </motion.div>
          </div>
        </section>
      </motion.div>
    </div>
  );
};

export default Home;