import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { useAuth } from '../contexts/AuthContext';
import { useAdventure } from '../contexts/AdventureContext';
import { adventureApi } from '../api/adventureApi';
import { externalApi } from '../api/externalApi';
import toast from 'react-hot-toast';

const AdventureGenerator = () => {
  const { user } = useAuth();
  const { userLocation, setUserLocation } = useAdventure();
  const navigate = useNavigate();

  const [step, setStep] = useState(1);
  const [formData, setFormData] = useState({
    interests: [],
    duration: 60,
    socialOption: 'solo',
    skillLevel: 'beginner',
    budget: 'medium',
    transportation: 'walking'
  });
  const [availableInterests, setAvailableInterests] = useState([]);
  const [weather, setWeather] = useState(null);
  const [loading, setLoading] = useState(false);
  const [locationPermission, setLocationPermission] = useState(null);

  useEffect(() => {
    loadInitialData();
  }, []);

  const loadInitialData = async () => {
    try {
      // Load available interests
      const interestsResponse = await adventureApi.getAvailableInterests();
      if (interestsResponse.success) {
        setAvailableInterests(interestsResponse.data);
      }

      // Request location permission
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
          (position) => {
            const location = {
              latitude: position.coords.latitude,
              longitude: position.coords.longitude
            };
            setUserLocation(location);
            setLocationPermission('granted');
            loadWeatherData(location);
          },
          (error) => {
            console.error('Location error:', error);
            setLocationPermission('denied');
          }
        );
      } else {
        setLocationPermission('not-supported');
      }
    } catch (error) {
      console.error('Failed to load initial data:', error);
    }
  };

  const loadWeatherData = async (location) => {
    try {
      const weatherResponse = await externalApi.getCurrentWeather(location);
      if (weatherResponse.success) {
        setWeather(weatherResponse.data);
      }
    } catch (error) {
      console.error('Failed to load weather:', error);
    }
  };

  const handleInterestToggle = (interest) => {
    setFormData(prev => ({
      ...prev,
      interests: prev.interests.includes(interest)
        ? prev.interests.filter(i => i !== interest)
        : [...prev.interests, interest]
    }));
  };

  const handleInputChange = (field, value) => {
    setFormData(prev => ({
      ...prev,
      [field]: value
    }));
  };

  const canProceed = () => {
    switch (step) {
      case 1:
        return formData.interests.length > 0;
      case 2:
        return formData.duration >= 30 && formData.duration <= 90;
      case 3:
        return true; // Social option always has a default
      case 4:
        return true; // Skill level always has a default
      default:
        return true;
    }
  };

  const handleNext = () => {
    if (canProceed()) {
      setStep(prev => prev + 1);
    }
  };

  const handleBack = () => {
    setStep(prev => prev - 1);
  };

  const handleGenerate = async () => {
    if (!userLocation) {
      toast.error('Location is required to generate an adventure');
      return;
    }

    setLoading(true);
    try {
      const requestData = {
        location: userLocation,
        interests: formData.interests,
        duration: formData.duration,
        socialOption: formData.socialOption,
        skillLevel: formData.skillLevel,
        budget: formData.budget,
        transportation: formData.transportation,
        weather: weather
      };

      const response = await adventureApi.generateAdventure(requestData);
      if (response.success) {
        toast.success('Adventure generated successfully!');
        navigate(`/adventure/${response.data._id}`);
      } else {
        toast.error(response.message || 'Failed to generate adventure');
      }
    } catch (error) {
      console.error('Adventure generation error:', error);
      toast.error('Failed to generate adventure. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const renderStep1 = () => (
    <motion.div
      key="step1"
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -20 }}
      className="space-y-6"
    >
      <div className="text-center">
        <h2 className="text-3xl font-bold text-gray-900 mb-4">
          What interests you? 🎯
        </h2>
        <p className="text-gray-600">
          Select your interests to personalize your adventure
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        {availableInterests.map((interest) => (
          <button
            key={interest}
            onClick={() => handleInterestToggle(interest)}
            className={`p-4 rounded-lg border-2 transition-all duration-200 ${
              formData.interests.includes(interest)
                ? 'border-blue-500 bg-blue-50 text-blue-700'
                : 'border-gray-200 hover:border-gray-300 text-gray-700'
            }`}
          >
            <div className="text-2xl mb-2">
              {interest === 'food' ? '🍕' :
               interest === 'music' ? '🎵' :
               interest === 'art' ? '🎨' :
               interest === 'nature' ? '🌿' :
               interest === 'nightlife' ? '🌃' :
               interest === 'culture' ? '🏛️' :
               interest === 'sports' ? '⚽' :
               interest === 'shopping' ? '🛍️' :
               interest === 'entertainment' ? '🎭' :
               '🎯'}
            </div>
            <div className="font-medium capitalize">{interest}</div>
          </button>
        ))}
      </div>

      {formData.interests.length > 0 && (
        <div className="text-center">
          <p className="text-sm text-gray-600">
            Selected: {formData.interests.join(', ')}
          </p>
        </div>
      )}
    </motion.div>
  );

  const renderStep2 = () => (
    <motion.div
      key="step2"
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -20 }}
      className="space-y-6"
    >
      <div className="text-center">
        <h2 className="text-3xl font-bold text-gray-900 mb-4">
          How much time do you have? ⏰
        </h2>
        <p className="text-gray-600">
          Choose your adventure duration
        </p>
      </div>

      <div className="max-w-md mx-auto">
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Duration: {formData.duration} minutes
          </label>
          <input
            type="range"
            min="30"
            max="90"
            step="15"
            value={formData.duration}
            onChange={(e) => handleInputChange('duration', parseInt(e.target.value))}
            className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
          />
          <div className="flex justify-between text-xs text-gray-500 mt-1">
            <span>30 min</span>
            <span>90 min</span>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-4">
          {[30, 45, 60, 75, 90].map((duration) => (
            <button
              key={duration}
              onClick={() => handleInputChange('duration', duration)}
              className={`p-3 rounded-lg border-2 transition-all duration-200 ${
                formData.duration === duration
                  ? 'border-blue-500 bg-blue-50 text-blue-700'
                  : 'border-gray-200 hover:border-gray-300 text-gray-700'
              }`}
            >
              <div className="font-medium">{duration}m</div>
            </button>
          ))}
        </div>
      </div>
    </motion.div>
  );

  const renderStep3 = () => (
    <motion.div
      key="step3"
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -20 }}
      className="space-y-6"
    >
      <div className="text-center">
        <h2 className="text-3xl font-bold text-gray-900 mb-4">
          Adventure style? 👥
        </h2>
        <p className="text-gray-600">
          How would you like to experience this adventure?
        </p>
      </div>

      <div className="grid md:grid-cols-3 gap-4">
        {[
          { value: 'solo', label: 'Solo Adventure', icon: '🚶', desc: 'Explore on your own' },
          { value: 'friends', label: 'With Friends', icon: '👥', desc: 'Invite friends to join' },
          { value: 'host_event', label: 'Host Event', icon: '🎉', desc: 'Create a public event' }
        ].map((option) => (
          <button
            key={option.value}
            onClick={() => handleInputChange('socialOption', option.value)}
            className={`p-6 rounded-lg border-2 transition-all duration-200 ${
              formData.socialOption === option.value
                ? 'border-blue-500 bg-blue-50 text-blue-700'
                : 'border-gray-200 hover:border-gray-300 text-gray-700'
            }`}
          >
            <div className="text-3xl mb-3">{option.icon}</div>
            <div className="font-semibold mb-2">{option.label}</div>
            <div className="text-sm opacity-75">{option.desc}</div>
          </button>
        ))}
      </div>
    </motion.div>
  );

  const renderStep4 = () => (
    <motion.div
      key="step4"
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -20 }}
      className="space-y-6"
    >
      <div className="text-center">
        <h2 className="text-3xl font-bold text-gray-900 mb-4">
          Adventure level? 🎯
        </h2>
        <p className="text-gray-600">
          Choose your comfort level for this adventure
        </p>
      </div>

      <div className="grid md:grid-cols-3 gap-4">
        {[
          { value: 'beginner', label: 'Beginner', icon: '🌱', desc: 'Easy and relaxed' },
          { value: 'intermediate', label: 'Intermediate', icon: '🚀', desc: 'Moderate challenge' },
          { value: 'advanced', label: 'Advanced', icon: '⚡', desc: 'Full adventure mode' }
        ].map((option) => (
          <button
            key={option.value}
            onClick={() => handleInputChange('skillLevel', option.value)}
            className={`p-6 rounded-lg border-2 transition-all duration-200 ${
              formData.skillLevel === option.value
                ? 'border-blue-500 bg-blue-50 text-blue-700'
                : 'border-gray-200 hover:border-gray-300 text-gray-700'
            }`}
          >
            <div className="text-3xl mb-3">{option.icon}</div>
            <div className="font-semibold mb-2">{option.label}</div>
            <div className="text-sm opacity-75">{option.desc}</div>
          </button>
        ))}
      </div>
    </motion.div>
  );

  const renderStep5 = () => (
    <motion.div
      key="step5"
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -20 }}
      className="space-y-6"
    >
      <div className="text-center">
        <h2 className="text-3xl font-bold text-gray-900 mb-4">
          Ready to generate? 🎉
        </h2>
        <p className="text-gray-600">
          Review your preferences and generate your adventure
        </p>
      </div>

      <div className="bg-gray-50 rounded-lg p-6 space-y-4">
        <div className="flex items-center justify-between">
          <span className="text-gray-600">Interests:</span>
          <span className="font-medium">{formData.interests.join(', ')}</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-gray-600">Duration:</span>
          <span className="font-medium">{formData.duration} minutes</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-gray-600">Style:</span>
          <span className="font-medium capitalize">{formData.socialOption.replace('_', ' ')}</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-gray-600">Level:</span>
          <span className="font-medium capitalize">{formData.skillLevel}</span>
        </div>
        {weather && (
          <div className="flex items-center justify-between">
            <span className="text-gray-600">Weather:</span>
            <span className="font-medium">
              {weather.temperature}°F • {weather.condition}
            </span>
          </div>
        )}
      </div>

      {!userLocation && (
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <div className="flex items-center">
            <span className="text-yellow-600 mr-2">⚠️</span>
            <span className="text-yellow-800">
              Location access is required to generate personalized adventures.
            </span>
          </div>
        </div>
      )}
    </motion.div>
  );

  const renderStep = () => {
    switch (step) {
      case 1: return renderStep1();
      case 2: return renderStep2();
      case 3: return renderStep3();
      case 4: return renderStep4();
      case 5: return renderStep5();
      default: return null;
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Progress Bar */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium text-gray-700">
              Step {step} of 5
            </span>
            <span className="text-sm text-gray-500">
              {Math.round((step / 5) * 100)}% Complete
            </span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <motion.div
              className="bg-blue-600 h-2 rounded-full"
              initial={{ width: 0 }}
              animate={{ width: `${(step / 5) * 100}%` }}
              transition={{ duration: 0.3 }}
            />
          </div>
        </div>

        {/* Main Content */}
        <div className="bg-white rounded-xl shadow-lg p-8">
          <AnimatePresence mode="wait">
            {renderStep()}
          </AnimatePresence>

          {/* Navigation */}
          <div className="flex justify-between mt-8">
            <button
              onClick={handleBack}
              disabled={step === 1}
              className={`px-6 py-2 rounded-lg font-medium transition-colors duration-200 ${
                step === 1
                  ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                  : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
              }`}
            >
              Back
            </button>

            {step < 5 ? (
              <button
                onClick={handleNext}
                disabled={!canProceed()}
                className={`px-6 py-2 rounded-lg font-medium transition-colors duration-200 ${
                  canProceed()
                    ? 'bg-blue-600 text-white hover:bg-blue-700'
                    : 'bg-gray-100 text-gray-400 cursor-not-allowed'
                }`}
              >
                Next
              </button>
            ) : (
              <button
                onClick={handleGenerate}
                disabled={loading || !userLocation}
                className={`px-6 py-2 rounded-lg font-medium transition-colors duration-200 ${
                  loading || !userLocation
                    ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                    : 'bg-green-600 text-white hover:bg-green-700'
                }`}
              >
                {loading ? (
                  <div className="flex items-center">
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                    Generating...
                  </div>
                ) : (
                  'Generate Adventure'
                )}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default AdventureGenerator;