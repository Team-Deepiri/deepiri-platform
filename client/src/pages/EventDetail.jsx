import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { useAuth } from '../contexts/AuthContext';
import { eventApi } from '../api/eventApi';
import toast from 'react-hot-toast';

const EventDetail = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();

  const [event, setEvent] = useState(null);
  const [loading, setLoading] = useState(true);
  const [rsvpLoading, setRsvpLoading] = useState(false);

  useEffect(() => {
    loadEvent();
  }, [id]);

  const loadEvent = async () => {
    try {
      setLoading(true);
      const response = await eventApi.getEventById(id);
      if (response.success) {
        setEvent(response.data);
      } else {
        toast.error('Event not found');
        navigate('/events');
      }
    } catch (error) {
      console.error('Failed to load event:', error);
      toast.error('Failed to load event');
      navigate('/events');
    } finally {
      setLoading(false);
    }
  };

  const handleRsvp = async () => {
    try {
      setRsvpLoading(true);
      const response = await eventApi.rsvpToEvent(id);
      if (response.success) {
        toast.success('RSVP successful!');
        setEvent(response.data);
      } else {
        toast.error(response.message || 'Failed to RSVP');
      }
    } catch (error) {
      console.error('RSVP error:', error);
      toast.error('Failed to RSVP to event');
    } finally {
      setRsvpLoading(false);
    }
  };

  const handleCancelRsvp = async () => {
    try {
      setRsvpLoading(true);
      const response = await eventApi.cancelRsvp(id);
      if (response.success) {
        toast.success('RSVP canceled');
        setEvent(response.data);
      } else {
        toast.error(response.message || 'Failed to cancel RSVP');
      }
    } catch (error) {
      console.error('Cancel RSVP error:', error);
      toast.error('Failed to cancel RSVP');
    } finally {
      setRsvpLoading(false);
    }
  };

  const getEventIcon = (type) => {
    switch (type) {
      case 'bar': return '🍺';
      case 'pop-up': return '🎪';
      case 'concert': return '🎵';
      case 'street-fair': return '🎡';
      case 'meetup': return '👥';
      case 'user-hosted': return '🎉';
      default: return '📅';
    }
  };

  const getEventTypeColor = (type) => {
    switch (type) {
      case 'bar': return 'bg-blue-100 text-blue-800';
      case 'pop-up': return 'bg-purple-100 text-purple-800';
      case 'concert': return 'bg-pink-100 text-pink-800';
      case 'street-fair': return 'bg-yellow-100 text-yellow-800';
      case 'meetup': return 'bg-green-100 text-green-800';
      case 'user-hosted': return 'bg-orange-100 text-orange-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const isUserRsvped = () => {
    return event?.participants?.some(p => p._id === user?.id || p === user?.id);
  };

  const isEventFull = () => {
    return event?.maxParticipants && event.participants?.length >= event.maxParticipants;
  };

  const isEventPast = () => {
    return new Date(event?.startTime) < new Date();
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!event) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">Event not found</h1>
          <button
            onClick={() => navigate('/events')}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            Back to Events
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
              onClick={() => navigate('/events')}
              className="text-blue-600 hover:text-blue-700 font-medium"
            >
              ← Back to Events
            </button>
            <span className={`px-3 py-1 rounded-full text-sm font-medium ${getEventTypeColor(event.type)}`}>
              {getEventIcon(event.type)} {event.type.replace('-', ' ')}
            </span>
          </div>

          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            {event.name}
          </h1>
          {event.description && (
            <p className="text-gray-600 text-lg">
              {event.description}
            </p>
          )}
        </motion.div>

        <div className="grid lg:grid-cols-3 gap-8">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-8">
            {/* Event Details */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
              className="bg-white rounded-xl shadow-lg p-6"
            >
              <h2 className="text-2xl font-bold text-gray-900 mb-6">
                Event Details 📋
              </h2>

              <div className="space-y-6">
                <div className="flex items-start space-x-4">
                  <div className="text-2xl">📍</div>
                  <div>
                    <h3 className="font-semibold text-gray-900">Location</h3>
                    <p className="text-gray-600">{event.location.address}</p>
                  </div>
                </div>

                <div className="flex items-start space-x-4">
                  <div className="text-2xl">🕐</div>
                  <div>
                    <h3 className="font-semibold text-gray-900">Date & Time</h3>
                    <p className="text-gray-600">
                      {new Date(event.startTime).toLocaleDateString('en-US', {
                        weekday: 'long',
                        year: 'numeric',
                        month: 'long',
                        day: 'numeric'
                      })}
                    </p>
                    <p className="text-gray-600">
                      {new Date(event.startTime).toLocaleTimeString([], { 
                        hour: '2-digit', 
                        minute: '2-digit' 
                      })}
                      {event.endTime && (
                        <span>
                          {' - '}
                          {new Date(event.endTime).toLocaleTimeString([], { 
                            hour: '2-digit', 
                            minute: '2-digit' 
                          })}
                        </span>
                      )}
                    </p>
                  </div>
                </div>

                {event.maxParticipants && (
                  <div className="flex items-start space-x-4">
                    <div className="text-2xl">👥</div>
                    <div>
                      <h3 className="font-semibold text-gray-900">Participants</h3>
                      <p className="text-gray-600">
                        {event.participants?.length || 0} / {event.maxParticipants} people
                      </p>
                      <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
                        <div
                          className="bg-blue-600 h-2 rounded-full"
                          style={{
                            width: `${((event.participants?.length || 0) / event.maxParticipants) * 100}%`
                          }}
                        />
                      </div>
                    </div>
                  </div>
                )}

                {event.hostUserId && (
                  <div className="flex items-start space-x-4">
                    <div className="text-2xl">👤</div>
                    <div>
                      <h3 className="font-semibold text-gray-900">Host</h3>
                      <p className="text-gray-600">
                        {event.hostUserId.name || 'Event Host'}
                      </p>
                    </div>
                  </div>
                )}
              </div>
            </motion.div>

            {/* Participants */}
            {event.participants && event.participants.length > 0 && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.4 }}
                className="bg-white rounded-xl shadow-lg p-6"
              >
                <h2 className="text-2xl font-bold text-gray-900 mb-6">
                  Participants 👥
                </h2>

                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  {event.participants.map((participant, index) => (
                    <div
                      key={participant._id || participant.id || index}
                      className="flex items-center space-x-3 p-3 bg-gray-50 rounded-lg"
                    >
                      <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                        <span className="text-blue-600 font-medium">
                          {(participant.name || 'User').charAt(0).toUpperCase()}
                        </span>
                      </div>
                      <div>
                        <p className="font-medium text-gray-900">
                          {participant.name || 'Anonymous User'}
                        </p>
                        {participant.email && (
                          <p className="text-sm text-gray-600">
                            {participant.email}
                          </p>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </motion.div>
            )}
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* RSVP Actions */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="bg-white rounded-xl shadow-lg p-6"
            >
              <h3 className="text-lg font-bold text-gray-900 mb-4">
                Join This Event 🎯
              </h3>

              {isEventPast() ? (
                <div className="text-center py-4">
                  <p className="text-gray-600">This event has already passed.</p>
                </div>
              ) : isEventFull() ? (
                <div className="text-center py-4">
                  <p className="text-gray-600">This event is full.</p>
                </div>
              ) : isUserRsvped() ? (
                <div className="space-y-3">
                  <div className="text-center py-4">
                    <div className="text-2xl mb-2">✅</div>
                    <p className="text-green-600 font-medium">You're going!</p>
                  </div>
                  <button
                    onClick={handleCancelRsvp}
                    disabled={rsvpLoading}
                    className="w-full px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors duration-200 disabled:opacity-50"
                  >
                    {rsvpLoading ? 'Canceling...' : 'Cancel RSVP'}
                  </button>
                </div>
              ) : (
                <div className="space-y-3">
                  <button
                    onClick={handleRsvp}
                    disabled={rsvpLoading}
                    className="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200 disabled:opacity-50"
                  >
                    {rsvpLoading ? 'RSVPing...' : 'RSVP to Event'}
                  </button>
                  <p className="text-sm text-gray-600 text-center">
                    Join {event.participants?.length || 0} other participants
                  </p>
                </div>
              )}
            </motion.div>

            {/* Event Info */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
              className="bg-white rounded-xl shadow-lg p-6"
            >
              <h3 className="text-lg font-bold text-gray-900 mb-4">
                Event Info ℹ️
              </h3>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-gray-600">Type:</span>
                  <span className="font-medium capitalize">
                    {event.type.replace('-', ' ')}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Created:</span>
                  <span className="font-medium">
                    {new Date(event.createdAt).toLocaleDateString()}
                  </span>
                </div>
                {event.externalSource && (
                  <div className="flex justify-between">
                    <span className="text-gray-600">Source:</span>
                    <span className="font-medium">
                      {event.externalSource}
                    </span>
                  </div>
                )}
              </div>
            </motion.div>

            {/* Share Event */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.5 }}
              className="bg-white rounded-xl shadow-lg p-6"
            >
              <h3 className="text-lg font-bold text-gray-900 mb-4">
                Share Event 📤
              </h3>
              <div className="space-y-3">
                <button
                  onClick={() => {
                    navigator.clipboard.writeText(window.location.href);
                    toast.success('Event link copied to clipboard!');
                  }}
                  className="w-full px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors duration-200"
                >
                  Copy Link
                </button>
                <button
                  onClick={() => {
                    const text = `Check out this event: ${event.name}`;
                    const url = window.location.href;
                    window.open(`https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}`);
                  }}
                  className="w-full px-4 py-2 bg-blue-400 text-white rounded-lg hover:bg-blue-500 transition-colors duration-200"
                >
                  Share on Twitter
                </button>
              </div>
            </motion.div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default EventDetail;
