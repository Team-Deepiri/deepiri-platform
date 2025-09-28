import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { useAuth } from '../contexts/AuthContext';
import logoIcon from '../assets/images/tripblip_navbar_icon.jpg';

const Navbar = () => {
  const { user, isAuthenticated, logout } = useAuth();
  const navigate = useNavigate();
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  const toggleMenu = () => {
    setIsMenuOpen(!isMenuOpen);
  };

  const navVariants = {
    hidden: { y: -100, opacity: 0 },
    visible: { 
      y: 0, 
      opacity: 1,
      transition: {
        duration: 0.6,
        ease: "easeOut"
      }
    }
  };

  const menuVariants = {
    hidden: { 
      opacity: 0,
      height: 0,
      transition: {
        duration: 0.3,
        ease: "easeInOut"
      }
    },
    visible: { 
      opacity: 1,
      height: "auto",
      transition: {
        duration: 0.3,
        ease: "easeInOut"
      }
    }
  };

  return (
    <motion.nav 
      variants={navVariants}
      initial="hidden"
      animate="visible"
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled 
          ? 'glass-dark backdrop-blur-xl' 
          : 'bg-transparent'
      }`}
    >
      <div className="container px-4">
        <div className="d-flex justify-content-between align-items-center" style={{ height: '5rem' }}>
          {/* Logo */}
          <motion.div
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            <Link to="/" className="flex items-center space-x-4 group">
              <motion.div
                className="relative"
                whileHover={{ scale: 1.1 }}
                whileTap={{ scale: 0.95 }}
              >
                <img 
                  src={logoIcon} 
                  alt="TripBlip Logo" 
                  className="w-12 h-12 filter drop-shadow-lg group-hover:drop-shadow-xl transition-all duration-300"
                />
                <div className="absolute inset-0 bg-gradient-to-r from-purple-500 to-pink-500 rounded-full opacity-20 group-hover:opacity-30 transition-opacity duration-300"></div>
              </motion.div>
              <div className="group-hover:translate-x-1 transition-transform duration-300">
                <span className="text-3xl font-bold gradient-text tracking-wide">tripblip</span>
                <br />
                <span className="text-lg gradient-text-secondary font-semibold tracking-widest">MAG 2.0</span>
              </div>
            </Link>
          </motion.div>

          {/* Desktop Navigation */}
          <div className="d-none d-lg-flex align-items-center gap-4">
            {isAuthenticated ? (
              <>
                {[
                  { to: '/dashboard', label: 'Dashboard', icon: '🏠' },
                  { to: '/adventure/generate', label: 'Generate', icon: '✨' },
                  { to: '/inventory', label: 'Inventory', icon: '🎒' },
                  { to: '/events', label: 'Events', icon: '🎉' },
                  { to: '/friends', label: 'Friends', icon: '👥' },
                  { to: '/leaderboard', label: 'Leaderboard', icon: '🏆' }
                ].map((item, index) => (
                  <motion.div
                    key={item.to}
                    initial={{ opacity: 0, y: -20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: index * 0.1 }}
                  >
                    <Link
                      to={item.to}
                      className="flex items-center space-x-2 px-4 py-2 rounded-lg hover:bg-white/10 transition-all duration-300 group"
                    >
                      <span className="text-lg group-hover:scale-110 transition-transform duration-300">
                        {item.icon}
                      </span>
                      <span className="font-semibold text-lg text-white group-hover:text-purple-300 transition-colors duration-300">
                        {item.label}
                      </span>
                    </Link>
                  </motion.div>
                ))}
                
                {/* User Menu */}
                <motion.div 
                  className="position-relative group"
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: 0.6 }}
                >
                  <button className="flex items-center space-x-3 px-4 py-2 rounded-lg hover:bg-white/10 transition-all duration-300 group">
                    <div className="w-10 h-10 bg-gradient-to-r from-purple-500 to-pink-500 rounded-full flex items-center justify-center text-white font-bold text-lg group-hover:scale-110 transition-transform duration-300">
                      {user?.name?.charAt(0).toUpperCase() || 'U'}
                    </div>
                    <div className="text-left">
                      <div className="font-bold text-lg text-gray-100 group-hover:text-purple-300 transition-colors duration-300">
                        {user?.name || 'User'}
                      </div>
                      <div className="text-sm text-gray-300 font-medium">Adventurer</div>
                    </div>
                    <motion.span 
                      className="text-gray-400 group-hover:text-white transition-colors duration-300"
                      animate={{ rotate: isMenuOpen ? 180 : 0 }}
                    >
                      ▼
                    </motion.span>
                  </button>
                  
                  {/* Dropdown Menu */}
                  <motion.div 
                    className="position-absolute end-0 mt-2 w-56 glass rounded-2xl border border-white/20 overflow-hidden"
                    initial={{ opacity: 0, y: -10, scale: 0.95 }}
                    whileHover={{ opacity: 1, y: 0, scale: 1 }}
                    transition={{ duration: 0.2 }}
                  >
                    <div className="py-2">
                      {[
                        { to: '/profile', label: 'Profile', icon: '👤' },
                        { to: '/notifications', label: 'Notifications', icon: '🔔' },
                        { to: '/adventures', label: 'My Adventures', icon: '🗺️' },
                        { to: '/agent', label: 'AI Assistant', icon: '🤖' }
                      ].map((item, index) => (
                        <Link
                          key={item.to}
                          to={item.to}
                          className="flex items-center space-x-3 px-4 py-3 hover:bg-white/10 transition-colors duration-200 group"
                        >
                          <span className="text-xl group-hover:scale-110 transition-transform duration-300">
                            {item.icon}
                          </span>
                          <span className="text-white group-hover:text-purple-300 transition-colors duration-300 font-semibold text-lg">
                            {item.label}
                          </span>
                        </Link>
                      ))}
                      <div className="border-t border-white/10 my-2" />
                      <button
                        onClick={handleLogout}
                        className="flex items-center space-x-3 px-4 py-3 w-full text-left hover:bg-red-500/20 transition-colors duration-200 group"
                      >
                        <span className="text-xl group-hover:scale-110 transition-transform duration-300">🚪</span>
                        <span className="text-red-400 group-hover:text-red-300 transition-colors duration-300 font-semibold text-lg">
                          Sign Out
                        </span>
                      </button>
                    </div>
                  </motion.div>
                </motion.div>
              </>
            ) : (
              <>
                <Link
                  to="/login"
                  className="px-8 py-3 rounded-lg hover:bg-white/10 transition-all duration-300 font-bold text-lg text-white hover:text-purple-300"
                >
                  <span className="text-xl mr-2">🔑</span>
                  Sign In
                </Link>
                <Link
                  to="/register"
                  className="btn-modern btn-primary px-8 py-3 text-lg font-bold glow"
                >
                  <span className="text-2xl mr-3">🌟</span>
                  Get Started
                </Link>
              </>
            )}
          </div>

          {/* Mobile Menu Button */}
          <div className="d-lg-none">
            <motion.button
              onClick={toggleMenu}
              className="p-2 rounded-lg hover:bg-white/10 transition-all duration-300"
              whileTap={{ scale: 0.95 }}
            >
              <motion.span 
                className="text-2xl text-white"
                animate={{ rotate: isMenuOpen ? 90 : 0 }}
                transition={{ duration: 0.3 }}
              >
                ☰
              </motion.span>
            </motion.button>
          </div>
        </div>

        {/* Mobile Navigation */}
        <AnimatePresence>
          {isMenuOpen && (
            <motion.div
              variants={menuVariants}
              initial="hidden"
              animate="visible"
              exit="hidden"
              className="d-lg-none glass rounded-2xl mt-4 mb-4 overflow-hidden"
            >
              <div className="py-4">
                {isAuthenticated ? (
                  <>
                    {/* User Info */}
                    <div className="px-4 py-3 border-b border-white/10 mb-4">
                      <div className="flex items-center space-x-3">
                        <div className="w-12 h-12 bg-gradient-to-r from-purple-500 to-pink-500 rounded-full flex items-center justify-center text-white font-bold text-xl">
                          {user?.name?.charAt(0).toUpperCase() || 'U'}
                        </div>
                        <div>
                          <div className="font-bold text-lg text-gray-100">{user?.name || 'User'}</div>
                          <div className="text-base text-gray-300 font-medium">Adventurer</div>
                        </div>
                      </div>
                    </div>

                    {/* Navigation Links */}
                    {[
                      { to: '/dashboard', label: 'Dashboard', icon: '🏠' },
                      { to: '/adventure/generate', label: 'Generate Adventure', icon: '✨' },
                      { to: '/inventory', label: 'My Inventory', icon: '🎒' },
                      { to: '/events', label: 'Events', icon: '🎉' },
                      { to: '/friends', label: 'Friends', icon: '👥' },
                      { to: '/leaderboard', label: 'Leaderboard', icon: '🏆' },
                      { to: '/profile', label: 'Profile', icon: '👤' },
                      { to: '/notifications', label: 'Notifications', icon: '🔔' },
                      { to: '/adventures', label: 'My Adventures', icon: '🗺️' },
                      { to: '/agent', label: 'AI Assistant', icon: '🤖' }
                    ].map((item, index) => (
                      <motion.div
                        key={item.to}
                        initial={{ opacity: 0, x: -20 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: index * 0.05 }}
                      >
                        <Link
                          to={item.to}
                          className="flex items-center space-x-3 px-4 py-3 hover:bg-white/10 transition-colors duration-200 group"
                          onClick={() => setIsMenuOpen(false)}
                        >
                          <span className="text-2xl group-hover:scale-110 transition-transform duration-300">
                            {item.icon}
                          </span>
                          <span className="text-white group-hover:text-purple-300 transition-colors duration-300 font-semibold text-lg">
                            {item.label}
                          </span>
                        </Link>
                      </motion.div>
                    ))}
                    
                    <div className="border-t border-white/10 my-2" />
                    <button
                      onClick={() => {
                        handleLogout();
                        setIsMenuOpen(false);
                      }}
                      className="flex items-center space-x-3 px-4 py-3 w-full text-left hover:bg-red-500/20 transition-colors duration-200 group"
                    >
                      <span className="text-2xl group-hover:scale-110 transition-transform duration-300">🚪</span>
                      <span className="text-red-400 group-hover:text-red-300 transition-colors duration-300 font-semibold text-lg">
                        Sign Out
                      </span>
                    </button>
                  </>
                ) : (
                  <>
                    <Link
                      to="/login"
                      className="flex items-center space-x-3 px-4 py-3 hover:bg-white/10 transition-colors duration-200 group"
                      onClick={() => setIsMenuOpen(false)}
                    >
                      <span className="text-2xl group-hover:scale-110 transition-transform duration-300">🔑</span>
                      <span className="text-white group-hover:text-purple-300 transition-colors duration-300 font-semibold text-lg">
                        Sign In
                      </span>
                    </Link>
                    <Link
                      to="/register"
                      className="flex items-center space-x-3 px-4 py-3 hover:bg-white/10 transition-colors duration-200 group mx-4 mt-2 btn-modern btn-primary justify-center"
                      onClick={() => setIsMenuOpen(false)}
                    >
                      <span className="text-2xl group-hover:scale-110 transition-transform duration-300">🌟</span>
                      <span className="font-bold text-lg">Get Started</span>
                    </Link>
                  </>
                )}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </motion.nav>
  );
};

export default Navbar;