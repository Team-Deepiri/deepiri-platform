import React, { useState, useRef, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import axios from 'axios';

const ProductivityChat = () => {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [activeChallenge, setActiveChallenge] = useState(null);
  const messagesEndRef = useRef(null);
  const { user } = useAuth();

  const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';
  const AI_SERVICE_URL = import.meta.env.VITE_PYAGENT_URL || 'http://localhost:8000';

  useEffect(() => {
    setMessages([{
      id: 1,
      type: 'assistant',
      content: "Hi! I'm your Deepiri productivity assistant. I can help you:\n\n• Create and manage tasks\n• Generate gamified challenges\n• Track your productivity\n• Provide insights and recommendations\n\nWhat would you like to work on today?",
      timestamp: new Date()
    }]);
  }, []);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSend = async (e) => {
    e.preventDefault();
    if (!input.trim() || isLoading) return;

    const userMessage = {
      id: Date.now(),
      type: 'user',
      content: input,
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);

    try {
      const response = await handleMessage(input);
      
      const assistantMessage = {
        id: Date.now() + 1,
        type: 'assistant',
        content: response.content,
        data: response.data,
        timestamp: new Date()
      };

      setMessages(prev => [...prev, assistantMessage]);

      if (response.challenge) {
        setActiveChallenge(response.challenge);
      }
    } catch (error) {
      console.error('Error:', error);
      setMessages(prev => [...prev, {
        id: Date.now() + 1,
        type: 'assistant',
        content: 'Sorry, I encountered an error. Please try again.',
        timestamp: new Date()
      }]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleMessage = async (message) => {
    const lowerMessage = message.toLowerCase();

    if (lowerMessage.includes('task') || lowerMessage.includes('todo') || lowerMessage.includes('create')) {
      return await handleTaskCreation(message);
    } else if (lowerMessage.includes('challenge') || lowerMessage.includes('gamify')) {
      return await handleChallengeGeneration(message);
    } else if (lowerMessage.includes('help') || lowerMessage.includes('what can you do')) {
      return {
        content: "I can help you with:\n\n📝 **Task Management**\n- Create tasks: 'Create a task to write a report'\n- List tasks: 'Show my tasks'\n- Complete tasks: 'Mark task X as done'\n\n🎮 **Challenges**\n- Generate challenge: 'Turn my report task into a challenge'\n- Start challenge: 'Start the coding challenge'\n\n📊 **Productivity**\n- View stats: 'Show my productivity stats'\n- Get insights: 'How am I doing this week?'\n\nJust tell me what you'd like to do!",
        data: null
      };
    } else {
      return await handleGeneralQuery(message);
    }
  };

  const handleTaskCreation = async (message) => {
    try {
      const taskText = message.replace(/create|task|todo|new/gi, '').trim();
      
      const classifyResponse = await axios.post(
        `${AI_SERVICE_URL}/agent/task/classify`,
        { task: taskText },
        { headers: { 'x-api-key': 'change-me' } }
      );

      const classification = classifyResponse.data.classification;

      const taskResponse = await axios.post(
        `${API_URL}/tasks`,
        {
          title: taskText,
          description: `Task created via chat`,
          type: classification.type,
          estimatedDuration: classification.estimated_duration
        },
        {
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('token')}`
          }
        }
      );

      return {
        content: `✅ **Task Created!**\n\n**${taskText}**\n\n📋 Type: ${classification.type}\n⏱️ Estimated: ${classification.estimated_duration} minutes\n🎯 Complexity: ${classification.complexity}\n\nWould you like me to turn this into a gamified challenge?`,
        data: { task: taskResponse.data, classification }
      };
    } catch (error) {
      return {
        content: 'I had trouble creating that task. Could you try rephrasing it?',
        data: null
      };
    }
  };

  const handleChallengeGeneration = async (message) => {
    try {
      const taskText = message.replace(/challenge|gamify|turn into/gi, '').trim();
      
      const challengeResponse = await axios.post(
        `${AI_SERVICE_URL}/agent/challenge/generate`,
        {
          task: {
            title: taskText,
            type: 'manual',
            estimatedDuration: 30
          }
        },
        { headers: { 'x-api-key': 'change-me' } }
      );

      const challenge = challengeResponse.data.data;

      return {
        content: `🎮 **Challenge Generated!**\n\n**${challenge.title}**\n\n${challenge.description}\n\n🎯 Difficulty: ${challenge.difficulty}\n⭐ Points: ${challenge.pointsReward}\n⏱️ Time: ${challenge.configuration?.timeLimit || 'N/A'} minutes\n\nReady to start? Type 'start challenge'!`,
        challenge: challenge,
        data: challenge
      };
    } catch (error) {
      return {
        content: 'I had trouble generating that challenge. Could you provide more details about the task?',
        data: null
      };
    }
  };

  const handleGeneralQuery = async (message) => {
    try {
      const response = await axios.post(
        `${AI_SERVICE_URL}/agent/message`,
        {
          content: message,
          session_id: user?.id || 'default'
        },
        { headers: { 'x-api-key': 'change-me' } }
      );

      return {
        content: response.data.data.message,
        data: null
      };
    } catch (error) {
      return {
        content: "I'm here to help with productivity tasks. Try asking me to create a task or generate a challenge!",
        data: null
      };
    }
  };

  const startChallenge = async () => {
    if (!activeChallenge) return;

    setMessages(prev => [...prev, {
      id: Date.now(),
      type: 'system',
      content: `🎮 Challenge started! Good luck!`,
      timestamp: new Date()
    }]);

    setActiveChallenge(null);
  };

  return (
    <div className="flex flex-col h-screen bg-gray-900">
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((msg) => (
          <div
            key={msg.id}
            className={`flex ${msg.type === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div
              className={`max-w-3xl rounded-lg px-4 py-3 ${
                msg.type === 'user'
                  ? 'bg-blue-600 text-white'
                  : msg.type === 'system'
                  ? 'bg-yellow-600 text-white text-center'
                  : 'bg-gray-800 text-gray-100'
              }`}
            >
              <div className="whitespace-pre-wrap">{msg.content}</div>
              {msg.data && (
                <div className="mt-2 pt-2 border-t border-gray-600">
                  <pre className="text-xs">{JSON.stringify(msg.data, null, 2)}</pre>
                </div>
              )}
            </div>
          </div>
        ))}
        
        {activeChallenge && (
          <div className="bg-purple-900 border border-purple-700 rounded-lg p-4">
            <h3 className="text-lg font-bold mb-2">{activeChallenge.title}</h3>
            <p className="mb-4">{activeChallenge.description}</p>
            <button
              onClick={startChallenge}
              className="bg-purple-600 hover:bg-purple-700 px-4 py-2 rounded"
            >
              Start Challenge
            </button>
          </div>
        )}

        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-gray-800 rounded-lg px-4 py-3">
              <div className="flex space-x-2">
                <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
                <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0.2s' }}></div>
                <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0.4s' }}></div>
              </div>
            </div>
          </div>
        )}
        
        <div ref={messagesEndRef} />
      </div>

      <div className="border-t border-gray-700 p-4 bg-gray-800">
        <form onSubmit={handleSend} className="flex space-x-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Ask me to create a task, generate a challenge, or help with productivity..."
            className="flex-1 bg-gray-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            type="submit"
            disabled={isLoading || !input.trim()}
            className="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 px-6 py-2 rounded-lg text-white font-medium"
          >
            Send
          </button>
        </form>
      </div>
    </div>
  );
};

export default ProductivityChat;

