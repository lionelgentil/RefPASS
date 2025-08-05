# ⚽ Soccer Referee App

A comprehensive web-based application for soccer referees to manage teams, players, match days, and game check-ins. Built with Node.js and vanilla JavaScript for simplicity and reliability.

![Soccer Referee App](https://img.shields.io/badge/Status-Production%20Ready-green)
![Node.js](https://img.shields.io/badge/Node.js-18%2B-green)
![License](https://img.shields.io/badge/License-MIT-blue)

## 🚀 Features

### 📱 **Progressive Web App (PWA)**
- Works on mobile devices and tablets
- Offline-capable with service worker
- Install as app on home screen

### 👥 **Team Management**
- Create and edit teams with custom colors
- Organize teams by leagues (Over 30, Over 40, etc.)
- Add/remove players with jersey numbers
- Visual team identification with color coding

### 📅 **Match Day Organization**
- Create match days with multiple games
- Schedule matches with specific times and fields
- Smart sorting by time and field number
- Track match status (Scheduled, In Progress, Completed)

### ✅ **Player Check-in System**
- Real-time player attendance tracking
- Visual check-in interface for each match
- Automatic present player counting
- Team-by-team check-in management

### 🏆 **Game Management**
- Score tracking and match results
- Match status updates
- Field and time management
- Delete/edit scheduled matches

### 🔄 **Real-time Sync**
- Automatic data synchronization every 30 seconds
- Manual sync option
- Persistent data storage
- Backup and restore functionality

## 🛠️ Technology Stack

- **Backend**: Node.js with Express
- **Frontend**: Vanilla JavaScript (no frameworks)
- **Storage**: JSON file-based (easily upgradeable to database)
- **Styling**: Custom CSS with responsive design
- **PWA**: Service Worker for offline functionality

## 📦 Installation

### Prerequisites
- Node.js 14+ installed
- npm package manager

### Local Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/soccer-referee-app.git
   cd soccer-referee-app
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Start the server**
   ```bash
   npm start
   ```

4. **Access the app**
   - Open http://localhost:3000 in your browser
   - For mobile testing, use your computer's IP address

### Development Mode
```bash
npm run dev  # Starts with nodemon for auto-reload
```

## 🌐 Deployment

### Recommended Hosting Platforms

#### **Railway** (Recommended)
- Free tier: 500 hours/month
- Paid: $5/month for always-on
- Easy GitHub integration
- Custom domains included

#### **Render**
- Free tier: 750 hours/month
- Paid: $7/month for always-on
- Automatic SSL certificates
- GitHub auto-deploy

#### **DigitalOcean App Platform**
- $5/month for basic apps
- Great performance
- Easy scaling

### Deployment Steps

1. **Push to GitHub**
   ```bash
   git add .
   git commit -m "Initial commit"
   git push origin main
   ```

2. **Connect to hosting platform**
   - Sign up on Railway/Render
   - Connect your GitHub repository
   - Platform auto-detects Node.js app
   - Deploy automatically

3. **Environment Configuration**
   - Set `PORT` environment variable (handled automatically)
   - Data persists in `data/` directory

## 📁 Project Structure

```
SoccerRefereeApp/
├── server.js              # Main server file
├── package.json            # Dependencies and scripts
├── data/                   # JSON data storage
│   ├── teams.json         # Teams and players
│   └── matchdays.json     # Match days and games
├── web-app/               # Frontend files
│   ├── index.html         # Main HTML file
│   ├── app.js             # JavaScript application
│   ├── styles.css         # Styling
│   ├── manifest.json      # PWA manifest
│   └── sw.js              # Service worker
└── README.md              # This file
```

## 🔧 Configuration

### Environment Variables
- `PORT`: Server port (default: 3000)

### Data Storage
- Teams data: `data/teams.json`
- Match days data: `data/matchdays.json`
- Automatic backup via `/api/backup` endpoint

## 📱 Usage

### For Referees
1. **Setup Teams**: Add teams with players and jersey numbers
2. **Create Match Days**: Schedule games with times and fields
3. **Game Day**: Use check-in system to track player attendance
4. **During Games**: Update scores and match status
5. **Post-Game**: Review results and statistics

### For League Administrators
1. **Team Management**: Create leagues and assign teams
2. **Schedule Management**: Plan match days and field assignments
3. **Data Export**: Use backup feature for record keeping

## 🎯 API Endpoints

### Teams
- `GET /api/teams` - Get all teams
- `POST /api/teams` - Update teams
- `GET /api/teams/:id` - Get specific team

### Match Days
- `GET /api/matchdays` - Get all match days
- `POST /api/matchdays` - Update match days
- `GET /api/matchdays/:id` - Get specific match day

### Utilities
- `GET /api/health` - Health check
- `GET /api/stats` - Statistics
- `GET /api/backup` - Data backup
- `GET/POST /api/sync` - Unified sync

## 🔄 Data Management

### Backup
```bash
curl -o backup.json http://localhost:3000/api/backup
```

### Statistics
- Total teams and players
- Scheduled match days
- Game completion rates

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: Report bugs via GitHub Issues
- **Documentation**: Check the `/docs` folder for detailed guides
- **Community**: Join discussions in GitHub Discussions

## 🎉 Acknowledgments

- Built for Pleasanton Adult Sunday Soccer League
- Designed for simplicity and reliability
- Mobile-first responsive design
- Real-time data synchronization

---

**Made with ⚽ for soccer referees everywhere**