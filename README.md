# Trailblip - Micro-Adventures Generator 2.0 (MAG 2.0)

An AI-powered platform that generates 30–90 minute curated local experiences around the user's location and interests, integrating bars, pop-ups, concerts, street fairs, meetups, and more.

## Features

### Core Features
- **AI-Powered Adventure Generation**: Advanced AI analyzes your preferences, weather, and local events to create personalized itineraries
- **Location-Aware**: Discover hidden gems and popular spots within your preferred distance and travel time
- **Social & Solo Options**: Choose to explore alone, with friends, or meet new people through community events
- **Time-Optimized**: Perfect for busy schedules - get maximum adventure in 30-90 minutes of free time
- **Interest-Based**: From food tours to art walks, nightlife to outdoor adventures - we match your passions
- **Gamified Experience**: Earn points, unlock badges, and track your adventure streak

### Advanced Features
- **Real-time Notifications**: Step-by-step guidance with push notifications
- **Weather Integration**: Dynamic itinerary adjustments based on weather conditions
- **Event Integration**: Connect with local events, concerts, and user-hosted meetups
- **Social Features**: Invite friends, share adventures, and see what others are doing
- **Analytics & Insights**: Track your adventure history and preferences
- **Multi-platform**: Web, mobile-responsive design

## Architecture

### Backend (Node.js/Express)
- **Microservices Architecture**: Modular, scalable design
- **AI Orchestrator**: OpenAI GPT-4 integration with custom planning logic
- **External API Integration**: Google Maps, OpenWeather, Eventbrite, Yelp
- **Real-time Communication**: Socket.IO for live updates
- **Caching Layer**: Redis for performance optimization
- **Database**: MongoDB for flexible data storage

### Frontend (React)
- **Modern React**: Hooks, Context API, React Query
- **Responsive Design**: Mobile-first approach with Tailwind CSS
- **Real-time Updates**: Socket.IO client integration
- **State Management**: Context providers for auth, adventures, and notifications
- **Interactive Maps**: Google Maps integration for route visualization

### AI & Data Processing
- **LLM Integration**: OpenAI GPT-4 for intelligent itinerary generation
- **Constraint Satisfaction**: Duration, distance, weather, and preference optimization
- **External Data Aggregation**: Real-time event and venue data
- **Caching Strategy**: Intelligent caching to reduce API calls and improve performance

## Technology Stack

### Backend
- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **Database**: MongoDB with Mongoose
- **Cache**: Redis
- **AI**: OpenAI GPT-4, LangChain
- **Real-time**: Socket.IO
- **Authentication**: JWT
- **Validation**: Joi
- **Logging**: Winston

### Frontend
- **Framework**: React 18
- **Build Tool**: Vite
- **Styling**: Tailwind CSS
- **State Management**: React Query, Context API
- **Animations**: Framer Motion
- **Maps**: Google Maps API
- **Notifications**: React Hot Toast
- **Forms**: React Hook Form

### External APIs
- **Maps & Places**: Google Maps API, Google Places API
- **Weather**: OpenWeatherMap API
- **Events**: Eventbrite API
- **Businesses**: Yelp API
- **AI**: OpenAI API

### DevOps
- **Containerization**: Docker, Docker Compose
- **Database**: MongoDB, Redis
- **Reverse Proxy**: Nginx
- **Environment**: Development, Production configurations

## Quick Start

### Prerequisites
- Node.js 18+ and npm
- Docker and Docker Compose
- API Keys for external services (see Environment Variables)

### 1. Clone the Repository
```bash
git clone <repository-url>
cd trailblip
```

### 2. Environment Setup
```bash
# Copy environment template
cp env.example .env

# Edit .env with your API keys
nano .env
```

### 3. Install Dependencies
```bash
# Install root dependencies
npm install

# Install backend dependencies
cd server && npm install

# Install frontend dependencies
cd ../client && npm install
```

### 4. Start with Docker Compose (Recommended)
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f
```

### 5. Start Development Servers
```bash
# Start backend (from server directory)
cd server
npm run dev

# Start frontend (from client directory)
cd client
npm run dev
```

### 6. Access the Application
- **Frontend**: http://localhost:5173
- **Backend API**: http://localhost:5000
- **API Documentation**: http://localhost:5000/api-docs

## 🔧 Environment Variables

Create a `.env` file in the root directory with the following variables:

```env
# Database Configuration
DATABASE_URL=postgresql://username:password@localhost:5432/trailblip_mag
REDIS_URL=redis://localhost:6379
MONGODB_URI=mongodb://localhost:27017/trailblip_mag

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-here
JWT_EXPIRES_IN=7d

# OpenAI Configuration
OPENAI_API_KEY=your-openai-api-key-here
OPENAI_MODEL=gpt-4-turbo-preview

# External API Keys
GOOGLE_MAPS_API_KEY=your-google-maps-api-key
GOOGLE_PLACES_API_KEY=your-google-places-api-key
OPENWEATHER_API_KEY=your-openweather-api-key
EVENTBRITE_API_KEY=your-eventbrite-api-key
YELP_API_KEY=your-yelp-api-key

# Server Configuration
PORT=5000
NODE_ENV=development
CORS_ORIGIN=http://localhost:5173

# Notification Services
FCM_SERVER_KEY=your-fcm-server-key
TWILIO_ACCOUNT_SID=your-twilio-account-sid
TWILIO_AUTH_TOKEN=your-twilio-auth-token
TWILIO_PHONE_NUMBER=your-twilio-phone-number
```

## API Documentation

### Authentication Endpoints
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `GET /api/auth/verify` - Token verification
- `POST /api/auth/refresh` - Token refresh

### Adventure Endpoints
- `POST /api/adventures/generate` - Generate new adventure
- `GET /api/adventures/:id` - Get adventure details
- `POST /api/adventures/:id/start` - Start adventure
- `POST /api/adventures/:id/complete` - Complete adventure
- `PUT /api/adventures/:id/steps` - Update adventure step

### User Endpoints
- `GET /api/users/profile` - Get user profile
- `PUT /api/users/profile` - Update user profile
- `PUT /api/users/preferences` - Update user preferences
- `GET /api/users/stats` - Get user statistics

### Event Endpoints
- `GET /api/events/nearby` - Get nearby events
- `POST /api/events` - Create new event
- `POST /api/events/:id/join` - Join event
- `POST /api/events/:id/review` - Review event

### External API Endpoints
- `GET /api/external/places/nearby` - Get nearby places
- `GET /api/external/weather/current` - Get current weather
- `GET /api/external/directions` - Get directions

## Usage Examples

### Generate an Adventure
```javascript
const adventureData = {
  location: { lat: 40.7128, lng: -74.0060 },
  interests: ['bars', 'music', 'food'],
  duration: 60,
  maxDistance: 5000,
  socialMode: 'friends'
};

const response = await fetch('/api/adventures/generate', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(adventureData)
});
```

### Start an Adventure
```javascript
const response = await fetch(`/api/adventures/${adventureId}/start`, {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${token}` }
});
```

## Testing

### Backend Tests
```bash
cd server
npm test
```

### Frontend Tests
```bash
cd client
npm test
```

### Integration Tests
```bash
npm run test:integration
```

## Deployment

### Production Build
```bash
# Build frontend
cd client
npm run build

# Start production server
cd ../server
npm start
```

### Docker Deployment
```bash
# Build and start all services
docker-compose up -d

# Scale services
docker-compose up -d --scale backend=3
```

### Environment-Specific Configurations
- **Development**: Hot reloading, debug logging
- **Staging**: Production-like environment for testing
- **Production**: Optimized builds, error monitoring

## Monitoring & Analytics

### Health Checks
- **Backend Health**: `/api/health`
- **Database Status**: MongoDB connection status
- **Cache Status**: Redis connection status
- **AI Service Status**: OpenAI API availability

### Metrics
- Adventure generation success rate
- User engagement metrics
- API response times
- Error rates and types

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow ESLint configuration
- Write tests for new features
- Update documentation
- Follow conventional commit messages

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.