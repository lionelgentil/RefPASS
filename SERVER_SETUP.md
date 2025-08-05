# Server Setup Guide for Soccer Referee App

This guide will help you set up a simple Node.js server to sync your team and match day data across devices.

## 🚀 **Quick Setup**

### **1. Prerequisites**
- Node.js (version 14 or higher)
- npm (comes with Node.js)

### **2. Server Installation**

**Option A: Local Development Server**
```bash
# Create server directory
mkdir soccer-referee-server
cd soccer-referee-server

# Initialize npm project
npm init -y

# Install dependencies
npm install express cors

# Copy the server code
# Save server-example.js as server.js in this directory

# Start the server
node server.js
```

**Option B: Using package.json**
Create a `package.json` file:
```json
{
  "name": "soccer-referee-server",
  "version": "1.0.0",
  "description": "API server for Soccer Referee App",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

Then run:
```bash
npm install
npm start
```

### **3. Update App Configuration**

In your iOS app, update the server URL in `LeagueDataManager`:

```swift
// For local development
private let serverURL = "http://localhost:3000/api"

// For production (replace with your domain)
private let serverURL = "https://your-domain.com/api"
```

## 🌐 **Production Deployment**

### **Option 1: Heroku**
```bash
# Install Heroku CLI
# Create Heroku app
heroku create your-soccer-referee-api

# Deploy
git init
git add .
git commit -m "Initial commit"
git push heroku main

# Your API will be at: https://your-soccer-referee-api.herokuapp.com/api
```

### **Option 2: Railway**
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway init
railway up

# Your API will be at: https://your-app.railway.app/api
```

### **Option 3: Vercel**
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel

# Your API will be at: https://your-app.vercel.app/api
```

### **Option 4: DigitalOcean App Platform**
1. Create account on DigitalOcean
2. Go to App Platform
3. Connect your GitHub repository
4. Deploy automatically

## 📡 **API Endpoints**

Your server provides these endpoints:

### **Health Check**
- `GET /api/health` - Check if server is running

### **Teams**
- `GET /api/teams` - Get all teams
- `POST /api/teams` - Upload/sync teams
- `GET /api/teams/:id` - Get specific team

### **Match Days**
- `GET /api/matchdays` - Get all match days
- `POST /api/matchdays` - Upload/sync match days
- `GET /api/matchdays/:id` - Get specific match day

### **Statistics**
- `GET /api/stats` - Get league statistics

### **Backup**
- `GET /api/backup` - Download complete data backup

## 🔧 **Testing Your Server**

### **1. Test Health Check**
```bash
curl http://localhost:3000/api/health
```

Expected response:
```json
{
  "status": "OK",
  "timestamp": "2025-01-01T12:00:00.000Z",
  "message": "Soccer Referee API Server is running"
}
```

### **2. Test Teams Endpoint**
```bash
# Get teams (should return empty array initially)
curl http://localhost:3000/api/teams

# Upload test team
curl -X POST http://localhost:3000/api/teams \
  -H "Content-Type: application/json" \
  -d '[{"id":"test-123","name":"Test Team","players":[],"colorData":"..."}]'
```

### **3. Test from iOS Simulator**
If testing locally with iOS Simulator, use:
```swift
private let serverURL = "http://localhost:3000/api"
```

For physical device testing, use your computer's IP:
```swift
private let serverURL = "http://192.168.1.100:3000/api"
```

## 📁 **Data Storage**

The server stores data in JSON files:
- `./data/teams.json` - All team data
- `./data/matchdays.json` - All match day data

### **Data Structure**

**Teams File:**
```json
[
  {
    "id": "uuid-here",
    "name": "Lions FC",
    "players": [...],
    "colorData": "base64-encoded-color"
  }
]
```

**Match Days File:**
```json
[
  {
    "id": "uuid-here",
    "date": "2025-01-05T14:00:00.000Z",
    "name": "Week 1 - League Games",
    "matches": [...],
    "notes": ""
  }
]
```

## 🔒 **Security Considerations**

### **For Production:**

1. **Add Authentication:**
```javascript
// Add API key middleware
app.use('/api', (req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  if (apiKey !== process.env.API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});
```

2. **Use Environment Variables:**
```javascript
const PORT = process.env.PORT || 3000;
const API_KEY = process.env.API_KEY || 'your-secret-key';
```

3. **Add Rate Limiting:**
```bash
npm install express-rate-limit
```

```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/api', limiter);
```

4. **Use HTTPS in Production:**
Ensure your deployment platform provides HTTPS (most do automatically).

## 🔄 **Data Backup**

### **Automatic Backup**
The server provides a backup endpoint:
```bash
curl http://your-server.com/api/backup > backup.json
```

### **Manual Backup**
Copy the data files:
```bash
cp ./data/teams.json ./backups/teams-$(date +%Y%m%d).json
cp ./data/matchdays.json ./backups/matchdays-$(date +%Y%m%d).json
```

## 🐛 **Troubleshooting**

### **Common Issues:**

1. **CORS Errors:**
   - Ensure `cors` middleware is installed and configured
   - Check that your iOS app URL matches the server URL

2. **Connection Refused:**
   - Verify server is running: `curl http://localhost:3000/api/health`
   - Check firewall settings
   - For device testing, use computer's IP address

3. **Data Not Syncing:**
   - Check server logs for errors
   - Verify JSON data format
   - Test endpoints with curl

4. **Large Photo Data:**
   - Server supports up to 50MB requests for player photos
   - Consider image compression in the iOS app

### **Logs:**
Server logs all requests and errors to console. For production, consider using a logging service like Winston or Morgan.

## 📈 **Monitoring**

### **Basic Monitoring:**
```bash
# Check server status
curl http://your-server.com/api/health

# Get statistics
curl http://your-server.com/api/stats
```

### **Production Monitoring:**
Consider using services like:
- **Uptime monitoring**: UptimeRobot, Pingdom
- **Error tracking**: Sentry
- **Performance**: New Relic, DataDog

This server setup provides a robust foundation for your Soccer Referee App with data persistence, backup capabilities, and multi-device synchronization!