# Soccer Referee Web App

A mobile-friendly Progressive Web App (PWA) version of the Soccer Referee App, designed to work on both iPhone and Android devices through web browsers.

## Features

- 📱 **Mobile-First Design**: Optimized for smartphones and tablets
- 🔄 **Real-time Sync**: Automatic data synchronization with server
- 📴 **Offline Support**: Works offline with service worker caching
- 🏠 **Installable**: Can be installed as a PWA on home screen
- ⚽ **Complete Functionality**: All features from the iOS app
  - Team management with player rosters
  - Match day scheduling and management
  - Player check-ins and attendance tracking
  - Score entry and match results
  - Data persistence and server synchronization

## Quick Start

### 1. Install Dependencies
```bash
cd SoccerRefereeApp/web-app
npm install
```

### 2. Setup Data Directory
```bash
npm run setup
```

### 3. Generate PWA Icons
Open `create-icons.html` in your browser to generate the required PWA icons:
```bash
open create-icons.html
```
Save the downloaded icons as `icon-192.png` and `icon-512.png` in the web-app folder.

### 4. Start the Server
```bash
npm start
```

The app will be available at `http://localhost:3000`

## Development

For development with auto-restart:
```bash
npm run dev
```

## File Structure

```
web-app/
├── index.html          # Main HTML structure
├── styles.css          # Mobile-first CSS styling
├── app.js             # JavaScript application logic
├── manifest.json      # PWA manifest
├── sw.js             # Service worker for offline support
├── server.js         # Express.js server
├── package.json      # Node.js dependencies
├── create-icons.html # Icon generation utility
├── icon-192.png      # PWA icon (192x192)
├── icon-512.png      # PWA icon (512x512)
└── README.md         # This file
```

## API Endpoints

The server provides RESTful API endpoints:

- `GET /api/teams` - Fetch all teams
- `POST /api/teams` - Update teams data
- `GET /api/matchdays` - Fetch all match days
- `POST /api/matchdays` - Update match days data
- `GET /api/sync` - Fetch all data (teams + match days)
- `POST /api/sync` - Update all data
- `GET /health` - Health check endpoint

## Data Storage

Data is stored in JSON files in the `../server-data/` directory:
- `teams.json` - Team and player data
- `matchdays.json` - Match day and game data

## PWA Installation

### On iPhone (Safari):
1. Open the app in Safari
2. Tap the Share button
3. Select "Add to Home Screen"
4. Tap "Add"

### On Android (Chrome):
1. Open the app in Chrome
2. Tap the menu (three dots)
3. Select "Add to Home screen"
4. Tap "Add"

## Browser Compatibility

- ✅ Safari (iOS 12+)
- ✅ Chrome (Android 6+)
- ✅ Chrome (Desktop)
- ✅ Firefox (Desktop/Mobile)
- ✅ Edge (Desktop/Mobile)

## Features Overview

### Team Management
- Create and edit teams
- Add/remove players from teams
- Alphabetical sorting of teams and players
- Player roster management

### Match Day Management
- Create match days with multiple games
- Schedule games between teams
- Track game status and results
- Real-time updates across devices

### Player Check-ins
- Mark players as present/absent for games
- Track attendance for each match
- Visual indicators for player status

### Score Entry
- Enter scores for completed games
- Track game results and statistics
- Update match status automatically

### Data Synchronization
- Automatic sync every 30 seconds
- Manual sync option available
- Conflict resolution for concurrent edits
- Offline data persistence

## Troubleshooting

### Server Won't Start
- Ensure Node.js is installed (version 14+)
- Run `npm install` to install dependencies
- Check if port 3000 is available

### Icons Not Loading
- Generate icons using `create-icons.html`
- Ensure `icon-192.png` and `icon-512.png` are in the web-app folder
- Clear browser cache and reload

### Data Not Syncing
- Check server console for errors
- Verify `../server-data/` directory exists
- Ensure JSON files have proper permissions

### PWA Not Installing
- Ensure HTTPS is used (or localhost for development)
- Check that all PWA requirements are met
- Verify manifest.json is accessible

## Development Notes

### Adding New Features
1. Update the HTML structure in `index.html`
2. Add styling in `styles.css`
3. Implement functionality in `app.js`
4. Update API endpoints in `server.js` if needed
5. Test on both iPhone and Android devices

### Performance Optimization
- Images are optimized for mobile
- CSS uses mobile-first approach
- JavaScript is minified for production
- Service worker caches resources for offline use

## Deployment

For production deployment:

1. Set environment variables:
   ```bash
   export PORT=80
   export NODE_ENV=production
   ```

2. Use a process manager like PM2:
   ```bash
   npm install -g pm2
   pm2 start server.js --name "soccer-referee-app"
   ```

3. Configure reverse proxy (nginx/Apache) for HTTPS
4. Set up SSL certificate for PWA installation

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Verify browser compatibility
3. Test on multiple devices
4. Check server logs for errors

---

**Note**: This web app provides the same functionality as the iOS Soccer Referee App but runs in web browsers, making it accessible to referees using both iPhone and Android devices.