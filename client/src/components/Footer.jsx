import React from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';

const Footer = () => {
  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
        delayChildren: 0.2
      }
    }
  };

  const itemVariants = {
    hidden: { y: 20, opacity: 0 },
    visible: {
      y: 0,
      opacity: 1,
      transition: {
        duration: 0.6,
        ease: "easeOut"
      }
    }
  };

  return (
    <motion.footer 
      variants={containerVariants}
      initial="hidden"
      whileInView="visible"
      viewport={{ once: true }}
      className="relative glass-dark backdrop-blur-xl border-t border-white/10"
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-12">
          {/* Brand */}
          <motion.div variants={itemVariants} className="col-span-1 md:col-span-2">
            <div className="flex items-center space-x-3 mb-6">
              <motion.div
                className="text-4xl"
                animate={{ rotate: [0, 10, -10, 0] }}
                transition={{ duration: 2, repeat: Infinity, repeatDelay: 3 }}
              >
                🗺️
              </motion.div>
              <div>
                <span className="text-2xl font-bold gradient-text">tripblip</span>
                <br />
                <span className="text-sm gradient-text-secondary font-medium">MAG 2.0</span>
              </div>
            </div>
            <p className="text-gray-300 mb-6 leading-relaxed max-w-md">
              Your AI-powered adventure companion. Discover extraordinary experiences, 
              connect with fellow explorers, and create memories that last forever.
            </p>
            <div className="flex space-x-4">
              {[
                { icon: '📧', label: 'Email', href: 'mailto:hello@tripblip.com' },
                { icon: '📘', label: 'Facebook', href: '#' },
                { icon: '🐦', label: 'Twitter', href: '#' },
                { icon: '📷', label: 'Instagram', href: '#' },
                { icon: '💼', label: 'LinkedIn', href: '#' }
              ].map((social, index) => (
                <motion.a
                  key={social.label}
                  href={social.href}
                  className="w-12 h-12 glass rounded-xl flex items-center justify-center text-xl hover:scale-110 transition-all duration-300 group"
                  whileHover={{ y: -2 }}
                  whileTap={{ scale: 0.95 }}
                  initial={{ opacity: 0, scale: 0 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: index * 0.1 }}
                >
                  <span className="group-hover:scale-110 transition-transform duration-300">
                    {social.icon}
                  </span>
                </motion.a>
              ))}
            </div>
          </motion.div>

          {/* Quick Links */}
          <motion.div variants={itemVariants}>
            <h3 className="text-xl font-bold mb-6 gradient-text">Quick Links</h3>
            <ul className="space-y-3">
              {[
                { to: '/adventure/generate', label: 'Generate Adventure', icon: '✨' },
                { to: '/events', label: 'Browse Events', icon: '🎉' },
                { to: '/friends', label: 'Find Friends', icon: '👥' },
                { to: '/leaderboard', label: 'Leaderboard', icon: '🏆' },
                { to: '/agent', label: 'AI Assistant', icon: '🤖' }
              ].map((link, index) => (
                <motion.li
                  key={link.to}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.05 }}
                >
                  <Link 
                    to={link.to} 
                    className="flex items-center space-x-2 text-gray-300 hover:text-white transition-colors duration-300 group"
                  >
                    <span className="text-sm group-hover:scale-110 transition-transform duration-300">
                      {link.icon}
                    </span>
                    <span>{link.label}</span>
                  </Link>
                </motion.li>
              ))}
            </ul>
          </motion.div>

          {/* Support */}
          <motion.div variants={itemVariants}>
            <h3 className="text-xl font-bold mb-6 gradient-text-secondary">Support</h3>
            <ul className="space-y-3">
              {[
                { label: 'Help Center', icon: '❓', href: '#' },
                { label: 'Contact Us', icon: '📞', href: '#' },
                { label: 'Privacy Policy', icon: '🔒', href: '#' },
                { label: 'Terms of Service', icon: '📋', href: '#' },
                { label: 'Bug Reports', icon: '🐛', href: '#' }
              ].map((item, index) => (
                <motion.li
                  key={item.label}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.05 }}
                >
                  <a 
                    href={item.href} 
                    className="flex items-center space-x-2 text-gray-300 hover:text-white transition-colors duration-300 group"
                  >
                    <span className="text-sm group-hover:scale-110 transition-transform duration-300">
                      {item.icon}
                    </span>
                    <span>{item.label}</span>
                  </a>
                </motion.li>
              ))}
            </ul>
          </motion.div>
        </div>

        {/* Newsletter Signup */}
        <motion.div 
          variants={itemVariants}
          className="mt-16 p-8 glass rounded-2xl border border-white/10"
        >
          <div className="text-center">
            <h3 className="text-2xl font-bold mb-4 gradient-text-accent">
              Stay Updated with New Adventures
            </h3>
            <p className="text-gray-300 mb-6 max-w-2xl mx-auto">
              Get the latest adventure recommendations, exclusive events, and community updates delivered to your inbox.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 max-w-md mx-auto">
              <input
                type="email"
                placeholder="Enter your email"
                className="input-modern flex-1"
              />
              <motion.button
                className="btn-modern btn-primary px-6 py-3 glow"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <span className="mr-2">📧</span>
                Subscribe
              </motion.button>
            </div>
          </div>
        </motion.div>

        {/* Bottom Section */}
        <motion.div 
          variants={itemVariants}
          className="border-t border-white/10 mt-12 pt-8"
        >
          <div className="flex flex-col md:flex-row md:items-center md:justify-between">
            <div className="flex items-center space-x-6 mb-4 md:mb-0">
              <p className="text-gray-400 text-sm">
                © 2024 tripblip MAG 2.0. All rights reserved.
              </p>
              <div className="flex items-center space-x-2 text-sm text-gray-400">
                <span>Made with</span>
                <motion.span
                  animate={{ scale: [1, 1.2, 1] }}
                  transition={{ duration: 1, repeat: Infinity }}
                >
                  ❤️
                </motion.span>
                <span>for adventure seekers</span>
              </div>
            </div>
            
            <div className="flex items-center space-x-6 text-sm text-gray-400">
              <span>🌍 Available worldwide</span>
              <span>🔒 Secure & Private</span>
              <span>⚡ Lightning Fast</span>
            </div>
          </div>
        </motion.div>
      </div>
    </motion.footer>
  );
};

export default Footer;