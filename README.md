# TripBlip MAG 2.0 

Welcome to TripBlip MAG 2.0, your AI-powered adventure companion that creates personalized local experiences, connects you with friends, and helps you discover the best your city (or the one you're at currently) has to offer.

## Features

###  AI-Powered Adventure Generation
- **Personalized Recommendations**: AI creates custom adventures based on your interests, location, and preferences
- **Real-time Weather Integration**: Adventures adapt to current weather conditions
- **Smart Scheduling**: Optimal timing based on venue hours and travel time
- **Multi-step Itineraries**: Seamless flow between different locations and activities

###  Social Features
- **Friend Connections**: Connect with friends and adventure together
- **Event Hosting**: Create and host your own events
- **RSVP System**: Join events and manage attendance
- **Adventure Sharing**: Share your experiences and get recommendations

###  Gamification
- **Points & Badges**: Earn rewards for completing adventures
- **Leaderboards**: Compete with friends and the community
- **Streaks**: Maintain adventure streaks for bonus points
- **Achievement System**: Unlock badges for different types of adventures

###  Real-time Features
- **Live Notifications**: Get updates about your adventures and events
- **WebSocket Integration**: Real-time chat and updates
- **Progress Tracking**: Track your adventure progress in real-time

##  Architecture

MAG 2.0 follows a modern microservices architecture:

### Backend (Node.js + Express) and Python Agent (FastAPI)
- **AI Orchestrator**: LangChain-powered adventure generation
- **User Service**: Authentication and profile management
- **Adventure Service**: Adventure creation and management
- **Event Service**: Event management and RSVP system
- **Notification Service**: Real-time notifications
- **External API Service**: Integration with maps, weather, and events
  
### Python Agent (FastAPI)
- **Agent Chat Endpoint**: Lightweight chat interface to OpenAI
- **Training Prep**: Script to convert dataset to JSONL for fine-tune jobs

### Frontend (React + Vite)
- **Modern React 18**: Hooks, Context API, and modern patterns
- **Responsive Design**: Mobile-first design with Tailwind CSS
- **Real-time Updates**: Socket.IO integration
- **Progressive Web App**: Offline support and mobile optimization

### Database & Infrastructure
- **MongoDB**: Primary database for all application data
- **Redis**: Caching layer for improved performance
- **Docker**: Containerized deployment
- **NGINX**: Load balancing and reverse proxy

##  Quick Start

### Prerequisites
- Docker and Docker Compose
- Node.js 18+ (for local development)
- Git

### Using Docker (Recommended)

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd TripBlip
   ```

2. **Run the setup script**
   ```bash
   ./scripts/setup.sh
   ```

3. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your API keys and configuration
   ```

4. **Start the application**
   ```bash
   docker-compose up -d
   ```

5. **Access the application**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:5000
   - Python Agent: http://localhost:8000
   - API Documentation: http://localhost:5000/api-docs

### Local Development

1. **Install dependencies**
   ```bash
   npm run setup
   ```

2. **Start MongoDB and Redis**
   ```bash
   docker-compose up -d mongodb redis
   ```

3. **Start the development servers**
   ```bash
   npm run dev
   ```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure the following:

#### Required API Keys
```bash
# OpenAI for AI-powered adventure generation
OPENAI_API_KEY=your_openai_api_key

# Google Maps for location services
GOOGLE_MAPS_API_KEY=your_google_maps_api_key

# Weather data
OPENWEATHER_API_KEY=your_openweather_api_key

# Event data (optional)
EVENTBRITE_API_KEY=your_eventbrite_api_key
YELP_API_KEY=your_yelp_api_key
```

#### Firebase Configuration
```bash
# Firebase for authentication and notifications
VITE_FIREBASE_API_KEY=your_firebase_api_key
VITE_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=your-project-id
# ... other Firebase config
```

#### Database Configuration
```bash
# MongoDB
MONGO_ROOT_USER=admin
MONGO_ROOT_PASSWORD=your_secure_password

# Redis
REDIS_PASSWORD=your_redis_password

# JWT Secret
JWT_SECRET=your_jwt_secret_key
```

##  API Documentation

The API is fully documented with Swagger/OpenAPI. Once the application is running, visit:
- **Swagger UI**: http://localhost:5000/api-docs

### Main API Endpoints

#### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user

#### Adventures
- `POST /api/adventures/generate` - Generate new adventure
- `GET /api/adventures/user` - Get user's adventures
- `GET /api/adventures/:id` - Get adventure details
- `PATCH /api/adventures/:id/status` - Update adventure status

#### Events
- `POST /api/events` - Create new event
- `GET /api/events/nearby` - Get nearby events
- `POST /api/events/:id/rsvp` - RSVP to event

#### Users
- `GET /api/users/profile` - Get user profile
- `PATCH /api/users/profile` - Update user profile
- `POST /api/users/friends/add` - Add friend

##  Testing

### Backend Tests (Node)
```bash
cd server
npm test
```
### Python Agent Tests
```bash
cd python_backend
pytest -q
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

### Production Deployment with Docker

1. **Set production environment**
   ```bash
   export NODE_ENV=production
   ```

2. **Build and start with production profile**
   ```bash
   docker-compose --profile production up -d
   ```

3. **Enable NGINX reverse proxy**
   The production setup includes NGINX for:
   - SSL termination
   - Load balancing
   - Static file serving
   - API proxying

### Cloud Deployment

The application is designed to be cloud-native and can be deployed on:
- **AWS**: ECS, EKS, or EC2 with Docker
- **Google Cloud**: GKE or Cloud Run
- **Azure**: AKS or Container Instances
- **DigitalOcean**: App Platform or Kubernetes

##  Development

### Adding New Features

1. **Backend Feature**
   - Add model in `server/models/`
   - Create service in `server/services/`
   - Add routes in `server/routes/`
   - Update controllers in `server/controllers/`

2. **Frontend Feature**
   - Create components in `client/src/components/`
   - Add pages in `client/src/pages/`
   - Update API layer in `client/src/api/`
   - Add routing to `client/src/App.jsx`

### Code Style

- **Backend**: ESLint + Prettier
- **Frontend**: ESLint + Prettier
- **Git Hooks**: Husky for pre-commit checks

##  Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Run tests: `npm test`
5. Commit your changes: `git commit -m "Add feature"`
6. Push to the branch: `git push origin feature-name`
7. Submit a pull request

##  License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

##  Support

### Common Issues

**Port already in use**
```bash
# Stop existing containers
docker-compose down
# Or change ports in docker-compose.yml
```

**API key errors**
- Ensure all required API keys are set in `.env`
- Check API key permissions and quotas

**Database connection issues**
- Ensure MongoDB is running: `docker-compose up -d mongodb`
- Check database credentials in `.env`

##  Acknowledgments

- OpenAI for GPT-4 integration
- React and Node.js communities

---







