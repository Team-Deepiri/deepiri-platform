import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { useAuth } from '../contexts/AuthContext';
import { useAdventure } from '../contexts/AdventureContext';
import { eventApi } from '../api/eventApi';
import toast from 'react-hot-toast';

const CreateEvent = () => {
  const navigate = useNavigate();
  const { user } = useAuth();
  const { userLocation } = useAdventure();

  const [formData, setFormData] = useState({
    name: '',
    description: '',
    type: 'user-hosted',
    startTime: '',
    endTime: '',
    maxParticipants: 10,
    location: {
      address: '',
      latitude: 0,
      longitude: 0
    }
  });
  const [loading, setLoading] = useState(false);
  const [locationPermission, setLocationPermission] = useState(null);

  useEffect(() => {
    // Set default location if available
    if (userLocation) {
      setFormData(prev => ({
        ...prev,
        location: {
          ...prev.location,
          latitude: userLocation.latitude,
          longitude: userLocation.longitude
        }
      }));
    }

    // Set default start time to next hour
    const nextHour = new Date();
    nextHour.setHours(nextHour.getHours() + 1, 0, 0, 0);
    setFormData(prev => ({
      ...prev,
      startTime: nextHour.toISOString().slice(0, 16)
    }));
  }, [userLocation]);

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

  const handleLocationSearch = async () => {
    if (!formData.location.address) {
      toast.error('Please enter an address');
      return;
    }

    try {
      // In a real app, you'd use a geocoding service like Google Maps Geocoding API
      // For now, we'll use a mock response
      toast.info('Location search feature coming soon!');
    } catch (error) {
      console.error('Location search error:', error);
      toast.error('Failed to search location');
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!formData.name || !formData.startTime || !formData.location.address) {
      toast.error('Please fill in all required fields');
      return;
    }

    if (formData.endTime && new Date(formData.endTime) <= new Date(formData.startTime)) {
      toast.error('End time must be after start time');
      return;
    }

    setLoading(true);
    try {
      const response = await eventApi.createEvent(formData);
      if (response.success) {
        toast.success('Event created successfully!');
        navigate(`/events/${response.data._id}`);
      } else {
        toast.error(response.message || 'Failed to create event');
      }
    } catch (error) {
      console.error('Failed to create event:', error);
      toast.error('Failed to create event');
    } finally {
      setLoading(false);
    }
  };

  const eventTypes = [
    { value: 'user-hosted', label: 'User Hosted', icon: '🎉', description: 'Your own event' },
    { value: 'meetup', label: 'Meetup', icon: '👥', description: 'Casual gathering' },
    { value: 'bar', label: 'Bar Night', icon: '🍺', description: 'Drinks and socializing' },
    { value: 'pop-up', label: 'Pop-up Event', icon: '🎪', description: 'Temporary event' },
    { value: 'street-fair', label: 'Street Fair', icon: '🎡', description: 'Outdoor festival' }
  ];

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8"
        >
          <div className="flex items-center justify-between mb-6">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">
                Create New Event 🎉
              </h1>
              <p className="text-gray-600 mt-2">
                Organize your own adventure and invite others to join
              </p>
            </div>
            <button
              onClick={() => navigate('/events')}
              className="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors duration-200"
            >
              Back to Events
            </button>
          </div>
        </motion.div>

        {/* Form */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="bg-white rounded-xl shadow-lg p-8"
        >
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Event Name */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Event Name *
              </label>
              <input
                type="text"
                value={formData.name}
                onChange={(e) => handleInputChange('name', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Enter event name"
                required
              />
            </div>

            {/* Event Description */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Description
              </label>
              <textarea
                value={formData.description}
                onChange={(e) => handleInputChange('description', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                rows="3"
                placeholder="Describe your event..."
              />
            </div>

            {/* Event Type */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Event Type *
              </label>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {eventTypes.map((type) => (
                  <button
                    key={type.value}
                    type="button"
                    onClick={() => handleInputChange('type', type.value)}
                    className={`p-4 rounded-lg border-2 transition-all duration-200 ${
                      formData.type === type.value
                        ? 'border-blue-500 bg-blue-50 text-blue-700'
                        : 'border-gray-200 hover:border-gray-300 text-gray-700'
                    }`}
                  >
                    <div className="text-2xl mb-2">{type.icon}</div>
                    <div className="font-semibold">{type.label}</div>
                    <div className="text-sm opacity-75">{type.description}</div>
                  </button>
                ))}
              </div>
            </div>

            {/* Date and Time */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Start Time *
                </label>
                <input
                  type="datetime-local"
                  value={formData.startTime}
                  onChange={(e) => handleInputChange('startTime', e.target.value)}
                  className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  End Time
                </label>
                <input
                  type="datetime-local"
                  value={formData.endTime}
                  onChange={(e) => handleInputChange('endTime', e.target.value)}
                  className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
            </div>

            {/* Location */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Location *
              </label>
              <div className="flex space-x-2">
                <input
                  type="text"
                  value={formData.location.address}
                  onChange={(e) => handleInputChange('location.address', e.target.value)}
                  className="flex-1 p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="Enter event address"
                  required
                />
                <button
                  type="button"
                  onClick={handleLocationSearch}
                  className="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors duration-200"
                >
                  Search
                </button>
              </div>
              {userLocation && (
                <p className="text-sm text-gray-600 mt-2">
                  Current location: {userLocation.latitude.toFixed(4)}, {userLocation.longitude.toFixed(4)}
                </p>
              )}
            </div>

            {/* Max Participants */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Maximum Participants
              </label>
              <input
                type="number"
                min="1"
                max="100"
                value={formData.maxParticipants}
                onChange={(e) => handleInputChange('maxParticipants', parseInt(e.target.value))}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>

            {/* Submit Button */}
            <div className="flex space-x-4">
              <button
                type="button"
                onClick={() => navigate('/events')}
                className="flex-1 px-6 py-3 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors duration-200 font-medium"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={loading}
                className="flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200 font-medium disabled:opacity-50"
              >
                {loading ? 'Creating...' : 'Create Event'}
              </button>
            </div>
          </form>
        </motion.div>

        {/* Tips */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="bg-gradient-to-r from-blue-50 to-purple-50 rounded-xl p-6 mt-8 border border-blue-200"
        >
          <h2 className="text-lg font-bold text-gray-900 mb-4">
            💡 Tips for Creating Great Events
          </h2>
          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <h3 className="font-semibold text-gray-900 mb-2">Event Details:</h3>
              <ul className="text-sm text-gray-700 space-y-1">
                <li>• Choose a clear, descriptive name</li>
                <li>• Provide detailed description</li>
                <li>• Set appropriate participant limits</li>
                <li>• Choose the right event type</li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold text-gray-900 mb-2">Timing & Location:</h3>
              <ul className="text-sm text-gray-700 space-y-1">
                <li>• Give people enough notice</li>
                <li>• Choose accessible locations</li>
                <li>• Consider weather conditions</li>
                <li>• Set realistic timeframes</li>
              </ul>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
};

export default CreateEvent;
