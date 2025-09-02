import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { useAuth } from '../contexts/AuthContext';
import { useAdventure } from '../contexts/AdventureContext';
import { userApi } from '../api/userApi';
import toast from 'react-hot-toast';

const AdventureGenerator = () => {
  const { user } = useAuth();
  const { generateAdventure, loading, userLocation } = useAdventure();
  const navigate = useNavigate();

  const [formData, setFormData] = useState({
    interests: [],
    duration: 60,
    maxDistance: 5000,
    socialMode: 'solo',
    friends: [],
    startTime: null
  });

  const [availableFriends, setAvailableFriends] = useState([]);
  const [isGenerating, setIsGenerating] = useState(false);

  const interestOptions = [
    { id: 'bars', label: 'Bars & Nightlife', icon: '🍻', color: 'bg-purple-100 text-purple-700' },
    { id: 'music', label: 'Music & Concerts', icon: '🎵', color: 'bg-pink-100 text-pink-700' },
    { id: 'food', label: 'Food & Dining', icon: '🍽️', color: 'bg-orange-100 text-orange-700' },
    { id: 'outdoors', label: 'Outdoor Activities', icon: '🌲', color: 'bg-green-100 text-green-700' },
    { id: 'art', label: 'Art & Culture', icon: '🎨', color: 'bg-blue-100 text-blue-700' },
    { id: 'sports', label: 'Sports & Fitness', icon: '⚽', color: 'bg-red-100 text-red-700' },
    { id: 'social', label: 'Social Events', icon: '👥', color: 'bg-indigo-100 text-indigo-700' },
    { id: 'nightlife', label: 'Nightlife', icon: '🌃', color: 'bg-gray-100 text-gray-700' },
    { id: 'culture', label: 'Cultural Events', icon: '🎭', color: 'bg-yellow-100 text-yellow-700' }
  ];

  useEffect(() => {
    loadFriends();
    if (user?.preferences) {
      setFormData(prev => ({
        ...prev,
        interests: user.preferences.interests || [],
        duration: user.preferences.preferredDuration || 60,
        maxDistance: user.preferences.maxDistance || 5000,
        socialMode: user.preferences.socialMode || 'solo'
      }));
    }
  }, [user]);

  const loadFriends = async () => {
    try {
      const response = await userApi.getFriends();
      if (response.success) {
        setAvailableFriends(response.data);
      }
    } catch (error) {
      console.error('Failed to load friends:', error);
    }
  };

  const handleInterestToggle = (interestId) => {
    setFormData(prev => ({
      ...prev,
      interests: prev.interests.includes(interestId)
        ? prev.interests.filter(id => id !== interestId)
        : [...prev.interests, interestId]
    }));
  };

  const handleFriendToggle = (friendId) => {
    setFormData(prev => ({
      ...prev,
      friends: prev.friends.includes(friendId)
        ? prev.friends.filter(id => id !== friendId)
        : [...prev.friends, friendId]
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (formData.interests.length === 0) {
      toast.error('Please select at least one interest');
      return;
    }

    setIsGenerating(true);
    
    try {
      const result = await generateAdventure(formData);
      if (result.success) {
        navigate(`/adventure/${result.adventure._id}`);
      }
    } catch (error) {
      console.error('Adventure generation failed:', error);
    } finally {
      setIsGenerating(false);
    }
  };

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          className="text-center mb-8"
        >
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Generate Your Adventure
          </h1>
          <p className="text-xl text-gray-600">
            {getGreeting()}, {user?.name}! Let's create your perfect adventure.
          </p>
          {userLocation && (
            <p className="text-sm text-gray-500 mt-2">
              📍 Location detected: {userLocation.lat.toFixed(4)}, {userLocation.lng.toFixed(4)}
            </p>
          )}
        </motion.div>

        <motion.form
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.2 }}
          onSubmit={handleSubmit}
          className="bg-white rounded-xl shadow-lg p-8"
        >
          {/* Interests Section */}
          <div className="mb-8">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">
              What interests you? ✨
            </h2>
            <p className="text-gray-600 mb-6">
              Select all that apply to help us create the perfect adventure for you.
            </p>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
              {interestOptions.map((interest) => (
                <motion.button
                  key={interest.id}
                  type="button"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => handleInterestToggle(interest.id)}
                  className={`p-4 rounded-lg border-2 transition-all duration-200 ${
                    formData.interests.includes(interest.id)
                      ? `${interest.color} border-current`
                      : 'border-gray-200 hover:border-gray-300 bg-white'
                  }`}
                >
                  <div className="text-center">
                    <div className="text-3xl mb-2">{interest.icon}</div>
                    <div className="font-medium">{interest.label}</div>
                  </div>
                </motion.button>
              ))}
            </div>
          </div>

          {/* Duration & Distance */}
          <div className="grid md:grid-cols-2 gap-6 mb-8">
            <div>
              <label className="block text-lg font-semibold text-gray-900 mb-3">
                Adventure Duration ⏰
              </label>
              <div className="space-y-3">
                {[30, 45, 60, 75, 90].map((duration) => (
                  <label key={duration} className="flex items-center">
                    <input
                      type="radio"
                      name="duration"
                      value={duration}
                      checked={formData.duration === duration}
                      onChange={(e) => setFormData(prev => ({ ...prev, duration: parseInt(e.target.value) }))}
                      className="mr-3 text-blue-600"
                    />
                    <span className="text-gray-700">{duration} minutes</span>
                  </label>
                ))}
              </div>
            </div>

            <div>
              <label className="block text-lg font-semibold text-gray-900 mb-3">
                Max Distance 🚶‍♂️
              </label>
              <div className="space-y-3">
                {[
                  { value: 1000, label: '1 km (15 min walk)' },
                  { value: 2500, label: '2.5 km (30 min walk)' },
                  { value: 5000, label: '5 km (1 hour walk)' },
                  { value: 10000, label: '10 km (2 hour walk)' }
                ].map((option) => (
                  <label key={option.value} className="flex items-center">
                    <input
                      type="radio"
                      name="maxDistance"
                      value={option.value}
                      checked={formData.maxDistance === option.value}
                      onChange={(e) => setFormData(prev => ({ ...prev, maxDistance: parseInt(e.target.value) }))}
                      className="mr-3 text-blue-600"
                    />
                    <span className="text-gray-700">{option.label}</span>
                  </label>
                ))}
              </div>
            </div>
          </div>

          {/* Social Mode */}
          <div className="mb-8">
            <label className="block text-lg font-semibold text-gray-900 mb-3">
              Social Preference 👥
            </label>
            <div className="grid md:grid-cols-3 gap-4">
              {[
                { value: 'solo', label: 'Solo Adventure', icon: '🚶‍♂️', description: 'Explore on your own' },
                { value: 'friends', label: 'With Friends', icon: '👥', description: 'Invite your friends' },
                { value: 'meet_new_people', label: 'Meet New People', icon: '🤝', description: 'Join community events' }
              ].map((mode) => (
                <label key={mode.value} className="flex items-center p-4 border-2 rounded-lg cursor-pointer transition-all duration-200 hover:bg-gray-50">
                  <input
                    type="radio"
                    name="socialMode"
                    value={mode.value}
                    checked={formData.socialMode === mode.value}
                    onChange={(e) => setFormData(prev => ({ ...prev, socialMode: e.target.value }))}
                    className="mr-3 text-blue-600"
                  />
                  <div>
                    <div className="flex items-center">
                      <span className="text-2xl mr-2">{mode.icon}</span>
                      <span className="font-medium text-gray-900">{mode.label}</span>
                    </div>
                    <p className="text-sm text-gray-600">{mode.description}</p>
                  </div>
                </label>
              ))}
            </div>
          </div>

          {/* Friends Selection */}
          {formData.socialMode === 'friends' && availableFriends.length > 0 && (
            <div className="mb-8">
              <label className="block text-lg font-semibold text-gray-900 mb-3">
                Invite Friends 👫
              </label>
              <div className="grid md:grid-cols-2 gap-3">
                {availableFriends.map((friend) => (
                  <label key={friend._id} className="flex items-center p-3 border rounded-lg cursor-pointer transition-all duration-200 hover:bg-gray-50">
                    <input
                      type="checkbox"
                      checked={formData.friends.includes(friend._id)}
                      onChange={() => handleFriendToggle(friend._id)}
                      className="mr-3 text-blue-600"
                    />
                    <div className="flex items-center">
                      <div className="w-8 h-8 bg-gradient-to-r from-blue-600 to-purple-600 rounded-full flex items-center justify-center mr-3">
                        <span className="text-white text-sm font-semibold">
                          {friend.name.charAt(0).toUpperCase()}
                        </span>
                      </div>
                      <span className="text-gray-900">{friend.name}</span>
                    </div>
                  </label>
                ))}
              </div>
            </div>
          )}

          {/* Generate Button */}
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            type="submit"
            disabled={isGenerating || formData.interests.length === 0}
            className="w-full bg-gradient-to-r from-blue-600 to-purple-600 text-white py-4 px-6 rounded-lg text-lg font-semibold shadow-lg hover:shadow-xl transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isGenerating ? (
              <div className="flex items-center justify-center">
                <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-white mr-3"></div>
                Generating your adventure...
              </div>
            ) : (
              <div className="flex items-center justify-center">
                <span className="mr-2">🎯</span>
                Generate Adventure
              </div>
            )}
          </motion.button>

          {formData.interests.length === 0 && (
            <p className="text-center text-red-500 mt-4">
              Please select at least one interest to continue
            </p>
          )}
        </motion.form>

        {/* Quick Tips */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.4 }}
          className="mt-8 bg-blue-50 rounded-lg p-6"
        >
          <h3 className="text-lg font-semibold text-blue-900 mb-3">
            💡 Pro Tips
          </h3>
          <ul className="space-y-2 text-blue-800">
            <li>• Select multiple interests for more diverse adventures</li>
            <li>• Shorter durations work great for quick breaks</li>
            <li>• Invite friends to make it a social experience</li>
            <li>• Our AI considers weather and local events automatically</li>
          </ul>
        </motion.div>
      </div>
    </div>
  );
};

export default AdventureGenerator;
