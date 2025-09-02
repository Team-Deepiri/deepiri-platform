import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { useAuth } from '../contexts/AuthContext';
import { adventureApi } from '../api/adventureApi';
import { eventApi } from '../api/eventApi';
import toast from 'react-hot-toast';

const AdventureDetail = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();

  const [adventure, setAdventure] = useState(null);
  const [loading, setLoading] = useState(true);
  const [currentStep, setCurrentStep] = useState(0);
  const [adventureStatus, setAdventureStatus] = useState('pending');
  const [showFeedback, setShowFeedback] = useState(false);
  const [feedback, setFeedback] = useState('');
  const [rating, setRating] = useState(5);

  useEffect(() => {
    loadAdventure();
  }, [id]);

  const loadAdventure = async () => {
    try {
      setLoading(true);
      const response = await adventureApi.getAdventureById(id);
      if (response.success) {
        setAdventure(response.data);
        setAdventureStatus(response.data.status);
      } else {
        toast.error('Adventure not found');
        navigate('/adventures');
      }
    } catch (error) {
      console.error('Failed to load adventure:', error);
      toast.error('Failed to load adventure');
      navigate('/adventures');
    } finally {
      setLoading(false);
    }
  };

  const handleStartAdventure = async () => {
    try {
      const response = await adventureApi.updateAdventureStatus(id, 'active');
      if (response.success) {
        setAdventureStatus('active');
        toast.success('Adventure started! Have fun!');
      }
    } catch (error) {
      console.error('Failed to start adventure:', error);
      toast.error('Failed to start adventure');
    }
  };

  const handleCompleteAdventure = async () => {
    try {
      const response = await adventureApi.updateAdventureStatus(id, 'completed', feedback, rating);
      if (response.success) {
        setAdventureStatus('completed');
        toast.success('Adventure completed! Great job!');
        setShowFeedback(false);
      }
    } catch (error) {
      console.error('Failed to complete adventure:', error);
      toast.error('Failed to complete adventure');
    }
  };

  const handleCancelAdventure = async () => {
    try {
      const response = await adventureApi.updateAdventureStatus(id, 'canceled');
      if (response.success) {
        setAdventureStatus('canceled');
        toast('Adventure canceled');
      }
    } catch (error) {
      console.error('Failed to cancel adventure:', error);
      toast.error('Failed to cancel adventure');
    }
  };

  const handleCreateEvent = async (step) => {
    try {
      const eventData = {
        name: `${adventure.name} - ${step.name}`,
        description: `Join us for this adventure step: ${step.task || 'Fun activity!'}`,
        location: {
          address: step.address,
          latitude: step.latitude,
          longitude: step.longitude
        },
        type: 'user-hosted',
        startTime: step.startTime,
        endTime: step.endTime,
        maxParticipants: 10
      };

      const response = await eventApi.createEvent(eventData);
      if (response.success) {
        toast.success('Event created successfully!');
      }
    } catch (error) {
      console.error('Failed to create event:', error);
      toast.error('Failed to create event');
    }
  };

  const getStepIcon = (step) => {
    if (step.type === 'travel') return '🚶';
    if (step.type === 'bar') return '🍺';
    if (step.type === 'food') return '🍕';
    if (step.type === 'music') return '🎵';
    if (step.type === 'art') return '🎨';
    if (step.type === 'nature') return '🌿';
    if (step.type === 'entertainment') return '🎭';
    return '📍';
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'completed': return 'bg-green-100 text-green-800';
      case 'active': return 'bg-blue-100 text-blue-800';
      case 'canceled': return 'bg-red-100 text-red-800';
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

  if (!adventure) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">Adventure not found</h1>
          <button
            onClick={() => navigate('/adventures')}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            Back to Adventures
          </button>
        </div>
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
          className="bg-white rounded-xl shadow-lg p-6 mb-8"
        >
          <div className="flex items-center justify-between mb-4">
            <button
              onClick={() => navigate('/adventures')}
              className="text-blue-600 hover:text-blue-700 font-medium"
            >
              ← Back to Adventures
            </button>
            <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(adventureStatus)}`}>
              {adventureStatus}
            </span>
          </div>

          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            {adventure.name}
          </h1>
          <p className="text-gray-600">
            {adventure.totalDuration} minutes • {adventure.steps.length} stops
          </p>
        </motion.div>

        <div className="grid lg:grid-cols-3 gap-8">
          {/* Adventure Steps */}
          <div className="lg:col-span-2">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
              className="bg-white rounded-xl shadow-lg p-6"
            >
              <h2 className="text-2xl font-bold text-gray-900 mb-6">
                Adventure Steps 🗺️
              </h2>

              <div className="space-y-6">
                {adventure.steps.map((step, index) => (
                  <motion.div
                    key={index}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: index * 0.1 }}
                    className={`p-6 rounded-lg border-2 transition-all duration-200 ${
                      index === currentStep && adventureStatus === 'active'
                        ? 'border-blue-500 bg-blue-50'
                        : index < currentStep
                        ? 'border-green-500 bg-green-50'
                        : 'border-gray-200 bg-white'
                    }`}
                  >
                    <div className="flex items-start space-x-4">
                      <div className="flex-shrink-0">
                        <div className={`w-12 h-12 rounded-full flex items-center justify-center text-2xl ${
                          index === currentStep && adventureStatus === 'active'
                            ? 'bg-blue-100'
                            : index < currentStep
                            ? 'bg-green-100'
                            : 'bg-gray-100'
                        }`}>
                          {index < currentStep ? '✅' : getStepIcon(step)}
                        </div>
                      </div>

                      <div className="flex-1">
                        <div className="flex items-center justify-between mb-2">
                          <h3 className="text-lg font-semibold text-gray-900">
                            {step.name}
                          </h3>
                          <span className="text-sm text-gray-500">
                            {new Date(step.startTime).toLocaleTimeString([], { 
                              hour: '2-digit', 
                              minute: '2-digit' 
                            })}
                          </span>
                        </div>

                        <p className="text-gray-600 mb-3">
                          {step.address}
                        </p>

                        {step.task && (
                          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 mb-3">
                            <p className="text-yellow-800 text-sm">
                              <span className="font-medium">Task:</span> {step.task}
                            </p>
                          </div>
                        )}

                        {step.type === 'travel' && (
                          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-3">
                            <p className="text-blue-800 text-sm">
                              <span className="font-medium">Travel:</span> {step.travelMethod} • {step.travelDurationMin} minutes
                            </p>
                          </div>
                        )}

                        {adventureStatus === 'active' && index === currentStep && (
                          <div className="flex space-x-2">
                            <button
                              onClick={() => setCurrentStep(prev => prev + 1)}
                              className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 text-sm"
                            >
                              Complete Step
                            </button>
                            {adventure.socialOption === 'host_event' && (
                              <button
                                onClick={() => handleCreateEvent(step)}
                                className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 text-sm"
                              >
                                Create Event
                              </button>
                            )}
                          </div>
                        )}
                      </div>
                    </div>
                  </motion.div>
                ))}
              </div>
            </motion.div>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Adventure Info */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="bg-white rounded-xl shadow-lg p-6"
            >
              <h3 className="text-lg font-bold text-gray-900 mb-4">
                Adventure Details 📋
              </h3>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-gray-600">Duration:</span>
                  <span className="font-medium">{adventure.totalDuration} min</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Stops:</span>
                  <span className="font-medium">{adventure.steps.length}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Style:</span>
                  <span className="font-medium capitalize">
                    {adventure.socialOption.replace('_', ' ')}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Level:</span>
                  <span className="font-medium capitalize">{adventure.skillLevel}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Created:</span>
                  <span className="font-medium">
                    {new Date(adventure.metadata.generatedAt).toLocaleDateString()}
                  </span>
                </div>
              </div>
            </motion.div>

            {/* Actions */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
              className="bg-white rounded-xl shadow-lg p-6"
            >
              <h3 className="text-lg font-bold text-gray-900 mb-4">
                Actions 🎯
              </h3>
              <div className="space-y-3">
                {adventureStatus === 'pending' && (
                  <button
                    onClick={handleStartAdventure}
                    className="w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors duration-200"
                  >
                    Start Adventure
                  </button>
                )}

                {adventureStatus === 'active' && (
                  <button
                    onClick={() => setShowFeedback(true)}
                    className="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200"
                  >
                    Complete Adventure
                  </button>
                )}

                {adventureStatus !== 'completed' && adventureStatus !== 'canceled' && (
                  <button
                    onClick={handleCancelAdventure}
                    className="w-full px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors duration-200"
                  >
                    Cancel Adventure
                  </button>
                )}

                <button
                  onClick={() => navigate('/adventures')}
                  className="w-full px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors duration-200"
                >
                  Back to Adventures
                </button>
              </div>
            </motion.div>

            {/* Weather */}
            {adventure.weather && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.5 }}
                className="bg-white rounded-xl shadow-lg p-6"
              >
                <h3 className="text-lg font-bold text-gray-900 mb-4">
                  Weather 🌤️
                </h3>
                <div className="text-center">
                  <div className="text-3xl mb-2">
                    {adventure.weather.condition === 'Clear' ? '☀️' : 
                     adventure.weather.condition === 'Clouds' ? '☁️' : 
                     adventure.weather.condition === 'Rain' ? '🌧️' : '🌤️'}
                  </div>
                  <div className="text-2xl font-bold text-gray-900">
                    {adventure.weather.temperature}°F
                  </div>
                  <div className="text-gray-600">
                    {adventure.weather.condition}
                  </div>
                </div>
              </motion.div>
            )}
          </div>
        </div>

        {/* Feedback Modal */}
        {showFeedback && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              className="bg-white rounded-xl p-6 max-w-md w-full mx-4"
            >
              <h3 className="text-xl font-bold text-gray-900 mb-4">
                Complete Adventure 🎉
              </h3>
              <p className="text-gray-600 mb-4">
                How was your adventure? Share your experience!
              </p>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Rating
                  </label>
                  <div className="flex space-x-1">
                    {[1, 2, 3, 4, 5].map((star) => (
                      <button
                        key={star}
                        onClick={() => setRating(star)}
                        className={`text-2xl ${
                          star <= rating ? 'text-yellow-400' : 'text-gray-300'
                        }`}
                      >
                        ⭐
                      </button>
                    ))}
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Feedback (optional)
                  </label>
                  <textarea
                    value={feedback}
                    onChange={(e) => setFeedback(e.target.value)}
                    className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    rows="3"
                    placeholder="Tell us about your adventure..."
                  />
                </div>
              </div>

              <div className="flex space-x-3 mt-6">
                <button
                  onClick={() => setShowFeedback(false)}
                  className="flex-1 px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors duration-200"
                >
                  Cancel
                </button>
                <button
                  onClick={handleCompleteAdventure}
                  className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors duration-200"
                >
                  Complete
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </div>
    </div>
  );
};

export default AdventureDetail;
