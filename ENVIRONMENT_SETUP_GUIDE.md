# 🔧 Environment Setup Guide

## 📋 **Quick Setup for All Services**

### 1. **Complete Environment (All Services)**
```bash
# Copy the complete environment file
cp env.example.complete .env

# Edit with your actual values
nano .env
```

### 2. **Service-Specific Environments**

#### **Frontend (Client)**
```bash
cd client
cp env.example.client .env.local
# Edit with your frontend-specific values
```

#### **Backend (Server)**
```bash
cd server
cp env.example.server .env
# Edit with your backend-specific values
```

#### **Python Agent**
```bash
cd python_backend
cp env.example.python .env
# Edit with your AI agent-specific values
```

#### **Docker Development**
```bash
# For Docker development with HMR
cp env.example.docker .env.docker
# Edit with your Docker-specific values
```

## 🎯 **Environment Files Overview**

| File | Purpose | Contains |
|------|---------|----------|
| `env.example.complete` | **Master template** | All possible environment variables |
| `client/env.example.client` | **Frontend only** | Vite, Firebase client, feature flags |
| `server/env.example.server` | **Backend only** | Database, APIs, authentication |
| `python_backend/env.example.python` | **AI Agent only** | OpenAI, model configs, caching |
| `env.example.docker` | **Docker setup** | Container configs, volumes, networks |

## 🚀 **Quick Start Scenarios**

### **Scenario 1: Local Development (No Docker)**
```bash
# 1. Frontend
cd client && cp env.example.client .env.local

# 2. Backend  
cd ../server && cp env.example.server .env

# 3. Python Agent
cd ../python_backend && cp env.example.python .env

# 4. Start services individually
cd client && npm run dev:turbo
cd server && npm run dev
cd python_backend && python -m uvicorn app.main:app --reload
```

### **Scenario 2: Docker Development with HMR**
```bash
# 1. Copy Docker environment
cp env.example.docker .env

# 2. Start everything with HMR
./dev-docker.sh start

# 3. Edit code in ./client/ and see instant updates!
```

### **Scenario 3: Production Deployment**
```bash
# 1. Copy and configure production environment
cp env.example.complete .env.prod

# 2. Edit with production values
nano .env.prod

# 3. Deploy with production compose
docker-compose -f docker-compose.yml --env-file .env.prod up -d
```

## 🔑 **Required API Keys**

### **Essential (Core Functionality)**
- `OPENAI_API_KEY` - AI agent functionality
- `MONGODB_URI` - Database (or use Docker MongoDB)
- `JWT_SECRET` - Authentication security

### **Important (Enhanced Features)**
- `GOOGLE_MAPS_API_KEY` - Maps and location services
- `FIREBASE_*` - Authentication and notifications
- `OPENWEATHER_API_KEY` - Weather data

### **Optional (Extended Features)**
- `EVENTBRITE_API_KEY` - Event discovery
- `YELP_API_KEY` - Local business data
- `TWILIO_*` - SMS notifications
- `SENDGRID_API_KEY` - Email services

## 🛠 **Environment Variable Categories**

### **🔒 Security & Authentication**
```bash
JWT_SECRET=your-super-secret-jwt-key-minimum-32-characters-long
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----..."
PYAGENT_API_KEY=secure-pyagent-key-change-in-production
```

### **🗄️ Database Configuration**
```bash
MONGODB_URI=mongodb://admin:password@localhost:27017/tripblip_mag
REDIS_URL=redis://:password@localhost:6379
```

### **🤖 AI Configuration**
```bash
OPENAI_API_KEY=sk-your-openai-api-key-here
OPENAI_MODEL=gpt-4o-mini
AGENT_TEMPERATURE=0.5
```

### **🌐 External APIs**
```bash
GOOGLE_MAPS_API_KEY=your-google-maps-api-key
OPENWEATHER_API_KEY=your-openweather-api-key
EVENTBRITE_API_KEY=your-eventbrite-api-key
```

### **⚙️ Application Settings**
```bash
NODE_ENV=development
CORS_ORIGIN=http://localhost:5173
CLIENT_URL=http://localhost:5173
```

## 🔄 **Environment Validation**

### **Check Required Variables**
```bash
# Backend health check
curl http://localhost:5000/api/health

# Python agent health check
curl http://localhost:8000/health

# Frontend (should load without errors)
open http://localhost:5173
```

### **Common Issues & Solutions**

**Missing OPENAI_API_KEY**
```bash
Error: OpenAI API key not found
Solution: Add OPENAI_API_KEY=sk-... to your environment file
```

**Database Connection Failed**
```bash
Error: MongoDB connection failed
Solution: Check MONGODB_URI or start MongoDB Docker container
```

**CORS Errors**
```bash
Error: CORS policy blocked request
Solution: Set CORS_ORIGIN=http://localhost:5173 in server environment
```

## 📝 **Environment Best Practices**

### **Security**
- ✅ Never commit `.env` files to git
- ✅ Use different secrets for each environment
- ✅ Rotate API keys regularly
- ✅ Use environment-specific database names

### **Development**
- ✅ Use `.env.local` for local overrides
- ✅ Keep development values in example files
- ✅ Document required vs optional variables
- ✅ Use meaningful defaults where possible

### **Production**
- ✅ Use external secret management (AWS Secrets Manager, etc.)
- ✅ Enable proper logging and monitoring
- ✅ Use strong, unique passwords
- ✅ Configure proper CORS origins

## 🆘 **Troubleshooting**

### **Environment Not Loading**
```bash
# Check if file exists
ls -la .env*

# Check file contents (be careful with secrets!)
cat .env | grep -v "SECRET\|KEY\|PASSWORD"

# Restart services after env changes
```

### **Service Communication Issues**
```bash
# Check if services are running
./dev-docker.sh status

# Check service logs
./dev-docker.sh logs backend
./dev-docker.sh logs frontend-dev
```

### **Port Conflicts**
```bash
# Kill processes on specific ports
lsof -ti:5173 | xargs kill -9
lsof -ti:5000 | xargs kill -9
lsof -ti:8000 | xargs kill -9
```

---

## 🎉 **You're All Set!**

Choose your setup scenario above and follow the steps. Your environment will be configured and ready for development with HMR! 🚀
