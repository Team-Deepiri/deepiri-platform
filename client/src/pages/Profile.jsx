import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useAuth } from '../contexts/AuthContext';
import { userApi } from '../api/userApi';
import { adventureApi } from '../api/adventureApi';
import toast from 'react-hot-toast';

const Profile = () => {
  const { user } = useAuth();
  const [profile, setProfile] = useState(null);
  const [stats, setStats] = useState(null);
  const [recentAdventures, setRecentAdventures] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    preferences: {
      nightlife: 'medium',
      music: 'medium',
      food: 'medium',
      social: 'medium',
      solo: 'medium'
    }
  });

  useEffect(() => {
    loadProfileData();
  }, []);

  const loadProfileData = async () => {
    try {
      setLoading(true);
      
      const [profileResponse, statsResponse, adventuresResponse] = await Promise.all([
        userApi.getUserProfile(),
        userApi.getStats(),
        adventureApi.getUserAdventures(null, 5, 0)
      ]);

      if (profileResponse.success) {
        setProfile(profileResponse.data);
        setFormData({
          name: profileResponse.data.name,
          email: profileResponse.data.email,
          preferences: profileResponse.data.preferences || {
            nightlife: 'medium',
            music: 'medium',
            food: 'medium',
            social: 'medium',
            solo: 'medium'
          }
        });
      }

      if (statsResponse.success) {
        setStats(statsResponse.data);
      }

      if (adventuresResponse.success) {
        setRecentAdventures(adventuresResponse.data);
      }

    } catch (error) {
      console.error('Failed to load profile data:', error);
      toast.error('Failed to load profile data');
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (field, value) => {
    if (field.includes('.')) {
      const [parent, child] = field.split('.');
      setFormData(prev => ({
        ...prev,
        [parent]: {
          ...prev[parent],
          [child]: value
        }
      }));
    } else {
      setFormData(prev => ({
        ...prev,
        [field]: value
      }));
    }
  };

  const handleSave = async () => {
    try {
      const response = await userApi.updateUserProfile(formData);
      if (response.success) {
        setProfile(response.data);
        setEditing(false);
        toast.success('Profile updated successfully!');
      } else {
        toast.error(response.message || 'Failed to update profile');
      }
    } catch (error) {
      console.error('Failed to update profile:', error);
      toast.error('Failed to update profile');
    }
  };

  const handleCancel = () => {
    setFormData({
      name: profile.name,
      email: profile.email,
      preferences: profile.preferences || {
        nightlife: 'medium',
        music: 'medium',
        food: 'medium',
        social: 'medium',
        solo: 'medium'
      }
    });
    setEditing(false);
  };

  const getPreferenceIcon = (preference) => {
    switch (preference) {
      case 'nightlife': return '🌃';
      case 'music': return '🎵';
      case 'food': return '🍕';
      case 'social': return '👥';
      case 'solo': return '🚶';
      default: return '🎯';
    }
  };

  const getPreferenceColor = (value) => {
    switch (value) {
      case 'low': return 'bg-red-100 text-red-800';
      case 'medium': return 'bg-yellow-100 text-yellow-800';
      case 'high': return 'bg-green-100 text-green-800';
      default: return 'bg-gray-100 text-gray-800';
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
    <div className="min-vh-100 bg-gray-50">
      <div className="container px-3 py-4" style={{ maxWidth: '960px' }}>
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-4 text-white bg-gradient-to-r from-purple-600 to-emerald-500 header-hero"
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <div className="w-20 h-20 bg-white/20 rounded-full flex items-center justify-center">
                <span className="text-2xl font-bold">
                  {profile?.name?.charAt(0).toUpperCase() || 'U'}
                </span>
              </div>
              <div>
                <h1 className="text-3xl font-bold">
                  {profile?.name || 'User'}
                </h1>
                <p className="opacity-90">{profile?.email}</p>
                <p className="text-sm opacity-80">
                  Member since {new Date(profile?.createdAt).toLocaleDateString()}
                </p>
              </div>
            </div>
            <button
              onClick={() => setEditing(!editing)}
              className="px-4 py-2 rounded-lg btn-secondary"
            >
              {editing ? 'Cancel' : 'Edit Profile'}
            </button>
          </div>
        </motion.div>

        <div className="row g-4">
          {/* Main Content */}
          <div className="col-lg-8 d-flex flex-column gap-4">
            {/* Profile Information */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
              className="bg-white rounded-xl shadow-lg p-4 lift"
            >
              <h2 className="text-2xl font-bold text-gray-900 mb-6">
                Profile Information 👤
              </h2>

              <div className="space-y-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Name
                  </label>
                  {editing ? (
                    <input
                      type="text"
                      value={formData.name}
                      onChange={(e) => handleInputChange('name', e.target.value)}
                      className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                  ) : (
                    <p className="text-gray-900 font-medium">{profile?.name}</p>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Email
                  </label>
                  {editing ? (
                    <input
                      type="email"
                      value={formData.email}
                      onChange={(e) => handleInputChange('email', e.target.value)}
                      className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                  ) : (
                    <p className="text-gray-900 font-medium">{profile?.email}</p>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Preferences
                  </label>
                  <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                    {Object.entries(formData.preferences).map(([key, value]) => (
                      <div key={key} className="p-4 border border-gray-200 rounded-lg">
                        <div className="flex items-center space-x-2 mb-2">
                          <span className="text-lg">{getPreferenceIcon(key)}</span>
                          <span className="font-medium capitalize">{key}</span>
                        </div>
                        {editing ? (
                          <select
                            value={value}
                            onChange={(e) => handleInputChange(`preferences.${key}`, e.target.value)}
                            className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                          >
                            <option value="low">Low</option>
                            <option value="medium">Medium</option>
                            <option value="high">High</option>
                          </select>
                        ) : (
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${getPreferenceColor(value)}`}>
                            {value}
                          </span>
                        )}
                      </div>
                    ))}
                  </div>
                </div>

                {editing && (
                  <div className="flex space-x-3">
                    <button
                      onClick={handleSave}
                      className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors duration-200"
                    >
                      Save Changes
                    </button>
                    <button
                      onClick={handleCancel}
                      className="px-6 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors duration-200"
                    >
                      Cancel
                    </button>
                  </div>
                )}
              </div>
            </motion.div>

            {/* Recent Adventures */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
              className="bg-white rounded-xl shadow-lg p-4 lift"
            >
              <h2 className="text-2xl font-bold text-gray-900 mb-6">
                Recent Adventures 🗺️
              </h2>

              {recentAdventures.length > 0 ? (
                <div className="space-y-4">
                  {recentAdventures.map((adventure) => (
                    <div
                      key={adventure._id}
                      className="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors duration-200"
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
                  <p className="text-gray-600">
                    Generate your first adventure to get started!
                  </p>
                </div>
              )}
            </motion.div>
          </div>

          {/* Sidebar */}
          <div className="col-lg-4 d-flex flex-column gap-3">
            {/* Stats */}
            {stats && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.3 }}
                className="bg-white rounded-xl shadow-lg p-4 lift"
              >
                <h3 className="text-lg font-bold text-gray-900 mb-4">
                  Your Stats 📊
                </h3>
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

            {/* Badges */}
            {profile?.badges && profile.badges.length > 0 && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.4 }}
                className="bg-white rounded-xl shadow-lg p-4 lift"
              >
                <h3 className="text-lg font-bold text-gray-900 mb-4">
                  Badges 🏆
                </h3>
                <div className="grid grid-cols-2 gap-3">
                  {profile.badges.map((badge, index) => (
                    <div
                      key={index}
                      className="p-3 bg-yellow-50 border border-yellow-200 rounded-lg text-center"
                    >
                      <div className="text-2xl mb-1">🏆</div>
                      <div className="text-sm font-medium text-yellow-800">
                        {badge}
                      </div>
                    </div>
                  ))}
                </div>
              </motion.div>
            )}

            {/* Quick Actions */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.5 }}
              className="bg-white rounded-xl shadow-lg p-4 lift"
            >
              <h3 className="text-lg font-bold text-gray-900 mb-4">
                Quick Actions 🚀
              </h3>
              <div className="space-y-3">
                <a
                  href="/adventure/generate"
                  className="block w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200 text-center"
                >
                  Generate Adventure
                </a>
                <a
                  href="/events"
                  className="block w-full px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors duration-200 text-center"
                >
                  Browse Events
                </a>
                <a
                  href="/friends"
                  className="block w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors duration-200 text-center"
                >
                  Find Friends
                </a>
              </div>
            </motion.div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Profile;
