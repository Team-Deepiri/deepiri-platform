import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useAuth } from '../contexts/AuthContext';
import { userApi } from '../api/userApi';
import toast from 'react-hot-toast';

const Leaderboard = () => {
  const { user } = useAuth();
  const [leaderboard, setLeaderboard] = useState([]);
  const [userRank, setUserRank] = useState(null);
  const [loading, setLoading] = useState(true);
  const [timeframe, setTimeframe] = useState('all'); // all, week, month
  const [category, setCategory] = useState('points'); // points, adventures, streak

  useEffect(() => {
    loadLeaderboard();
  }, [timeframe, category]);

  const loadLeaderboard = async () => {
    try {
      setLoading(true);
      const response = await userApi.getLeaderboard(timeframe, category);
      if (response.success) {
        setLeaderboard(response.data.leaderboard);
        setUserRank(response.data.userRank);
      } else {
        toast.error('Failed to load leaderboard');
      }
    } catch (error) {
      console.error('Failed to load leaderboard:', error);
      toast.error('Failed to load leaderboard');
    } finally {
      setLoading(false);
    }
  };

  const getRankIcon = (rank) => {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return `#${rank}`;
    }
  };

  const getRankColor = (rank) => {
    switch (rank) {
      case 1: return 'bg-yellow-100 text-yellow-800';
      case 2: return 'bg-gray-100 text-gray-800';
      case 3: return 'bg-orange-100 text-orange-800';
      default: return 'bg-blue-100 text-blue-800';
    }
  };

  const getCategoryIcon = (cat) => {
    switch (cat) {
      case 'points': return '⭐';
      case 'adventures': return '🗺️';
      case 'streak': return '🔥';
      default: return '🏆';
    }
  };

  const getCategoryLabel = (cat) => {
    switch (cat) {
      case 'points': return 'Total Points';
      case 'adventures': return 'Adventures Completed';
      case 'streak': return 'Current Streak';
      default: return 'Overall';
    }
  };

  const getTimeframeLabel = (tf) => {
    switch (tf) {
      case 'week': return 'This Week';
      case 'month': return 'This Month';
      default: return 'All Time';
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8"
        >
          <div className="text-center mb-8">
            <h1 className="text-4xl font-bold text-gray-900 mb-4">
              Leaderboard 🏆
            </h1>
            <p className="text-gray-600 text-lg">
              See how you stack up against other adventurers!
            </p>
          </div>

          {/* Filters */}
          <div className="bg-white rounded-xl shadow-lg p-6 mb-8">
            <div className="flex flex-col md:flex-row md:items-center md:justify-between space-y-4 md:space-y-0">
              <div className="flex items-center space-x-4">
                <label className="text-sm font-medium text-gray-700">Category:</label>
                <select
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="points">Total Points</option>
                  <option value="adventures">Adventures Completed</option>
                  <option value="streak">Current Streak</option>
                </select>
              </div>
              <div className="flex items-center space-x-4">
                <label className="text-sm font-medium text-gray-700">Timeframe:</label>
                <select
                  value={timeframe}
                  onChange={(e) => setTimeframe(e.target.value)}
                  className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="all">All Time</option>
                  <option value="month">This Month</option>
                  <option value="week">This Week</option>
                </select>
              </div>
            </div>
          </div>

          {/* User Rank */}
          {userRank && (
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
              className="bg-gradient-to-r from-blue-600 to-purple-600 rounded-xl p-6 text-white mb-8"
            >
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-2xl font-bold mb-2">Your Rank</h2>
                  <p className="text-blue-100">
                    You're ranked #{userRank.rank} in {getCategoryLabel(category).toLowerCase()} for {getTimeframeLabel(timeframe).toLowerCase()}
                  </p>
                </div>
                <div className="text-right">
                  <div className="text-3xl font-bold">
                    {getCategoryIcon(category)} {userRank.value}
                  </div>
                  <div className="text-blue-100">
                    {getCategoryLabel(category)}
                  </div>
                </div>
              </div>
            </motion.div>
          )}
        </motion.div>

        {/* Leaderboard */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="bg-white rounded-xl shadow-lg overflow-hidden"
        >
          <div className="p-6 border-b border-gray-200">
            <h2 className="text-2xl font-bold text-gray-900">
              {getCategoryIcon(category)} {getCategoryLabel(category)} - {getTimeframeLabel(timeframe)}
            </h2>
          </div>

          <div className="divide-y divide-gray-200">
            {leaderboard.length > 0 ? (
              leaderboard.map((entry, index) => (
                <motion.div
                  key={entry._id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.1 }}
                  className={`p-6 flex items-center justify-between ${
                    entry._id === user?.id ? 'bg-blue-50' : 'hover:bg-gray-50'
                  } transition-colors duration-200`}
                >
                  <div className="flex items-center space-x-4">
                    <div className={`w-12 h-12 rounded-full flex items-center justify-center font-bold text-lg ${getRankColor(entry.rank)}`}>
                      {getRankIcon(entry.rank)}
                    </div>
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900">
                        {entry.name}
                        {entry._id === user?.id && (
                          <span className="ml-2 text-sm text-blue-600">(You)</span>
                        )}
                      </h3>
                      <p className="text-sm text-gray-600">{entry.email}</p>
                    </div>
                  </div>

                  <div className="text-right">
                    <div className="text-2xl font-bold text-gray-900">
                      {getCategoryIcon(category)} {entry.value}
                    </div>
                    <div className="text-sm text-gray-600">
                      {getCategoryLabel(category)}
                    </div>
                  </div>
                </motion.div>
              ))
            ) : (
              <div className="p-12 text-center">
                <div className="text-6xl mb-4">🏆</div>
                <h3 className="text-xl font-semibold text-gray-900 mb-2">
                  No data available
                </h3>
                <p className="text-gray-600">
                  Start completing adventures to appear on the leaderboard!
                </p>
              </div>
            )}
          </div>
        </motion.div>

        {/* Achievement Badges */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6 }}
          className="bg-white rounded-xl shadow-lg p-6 mt-8"
        >
          <h2 className="text-2xl font-bold text-gray-900 mb-6">
            Achievement Badges 🏅
          </h2>
          
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { name: 'First Adventure', icon: '🎯', description: 'Complete your first adventure' },
              { name: 'Explorer', icon: '🗺️', description: 'Complete 5 adventures' },
              { name: 'Adventure Master', icon: '🏆', description: 'Complete 25 adventures' },
              { name: 'Social Butterfly', icon: '👥', description: 'Make 10 friends' },
              { name: 'Streak Master', icon: '🔥', description: '7-day adventure streak' },
              { name: 'Event Host', icon: '🎉', description: 'Host your first event' },
              { name: 'Night Owl', icon: '🌃', description: 'Complete 10 night adventures' },
              { name: 'Early Bird', icon: '🌅', description: 'Complete 10 morning adventures' }
            ].map((badge, index) => (
              <div
                key={index}
                className="p-4 border border-gray-200 rounded-lg text-center hover:bg-gray-50 transition-colors duration-200"
              >
                <div className="text-3xl mb-2">{badge.icon}</div>
                <h3 className="font-semibold text-gray-900 text-sm mb-1">
                  {badge.name}
                </h3>
                <p className="text-xs text-gray-600">
                  {badge.description}
                </p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Tips */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8 }}
          className="bg-gradient-to-r from-green-50 to-blue-50 rounded-xl p-6 mt-8 border border-green-200"
        >
          <h2 className="text-xl font-bold text-gray-900 mb-4">
            💡 Tips to Climb the Leaderboard
          </h2>
          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <h3 className="font-semibold text-gray-900 mb-2">Earn More Points:</h3>
              <ul className="text-sm text-gray-700 space-y-1">
                <li>• Complete adventures regularly</li>
                <li>• Try different types of activities</li>
                <li>• Invite friends to join you</li>
                <li>• Leave feedback and ratings</li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold text-gray-900 mb-2">Build Your Streak:</h3>
              <ul className="text-sm text-gray-700 space-y-1">
                <li>• Complete at least one adventure daily</li>
                <li>• Set reminders for your adventures</li>
                <li>• Start with shorter adventures</li>
                <li>• Share your progress with friends</li>
              </ul>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
};

export default Leaderboard;
