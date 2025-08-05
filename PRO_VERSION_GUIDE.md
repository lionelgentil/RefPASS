# Soccer Referee App - Professional League Management Version

This is a complete league management system designed for referees managing multiple teams with weekly Sunday games.

## 🏆 **Key Features**

### **1. Team Repository**
- **Persistent Storage**: Teams and players saved locally with UserDefaults
- **Server Sync**: Upload/download team data to/from your server
- **Player Photos**: Full photo management with PhotosPicker
- **Unlimited Teams**: Create and manage as many teams as needed

### **2. Match Day Scheduling**
- **Weekly Schedule**: Create match days in advance (perfect for Sunday leagues)
- **Multiple Games**: Schedule multiple matches per match day
- **Field Assignment**: Assign specific fields to each match
- **Time Scheduling**: Set specific times for each game

### **3. Server Integration**
- **RESTful API**: Built-in server sync functionality
- **Data Backup**: Automatic backup of all team and match data
- **Multi-Device Sync**: Share data across multiple devices
- **Offline Support**: Works offline, syncs when connected

### **4. League Management**
- **Match Status Tracking**: Scheduled → In Progress → Completed
- **Attendance Tracking**: Real-time player check-ins
- **Historical Data**: View past match days and results
- **Statistics**: Team and player statistics

## 📱 **App Structure**

### **Tab 1: Teams Repository**
- View all teams in your league
- Add/edit/delete teams
- Manage team colors and details
- Access individual team rosters

### **Tab 2: Match Days**
- View upcoming and past match days
- Create new match days
- Schedule multiple games
- Set times, fields, and teams

### **Tab 3: Today's Games** (appears on match days)
- Quick access to current day's matches
- Real-time check-in for all games
- Match status updates

### **Tab 4: Settings**
- Server synchronization
- Data export/import
- League statistics
- App configuration

## 🔧 **Setup Instructions**

### **1. Basic Setup**
1. Create new iOS App project in Xcode
2. Replace `ContentView.swift` with the professional version code
3. Add PhotosUI framework import
4. Set iOS deployment target to 17.0+

### **2. Server Configuration**
Update the server URL in `LeagueDataManager`:
```swift
private let serverURL = "https://your-server.com/api"
```

### **3. Server API Endpoints**
Your server should provide these endpoints:

**Teams:**
- `POST /api/teams` - Upload teams
- `GET /api/teams` - Download teams

**Match Days:**
- `POST /api/matchdays` - Upload match days
- `GET /api/matchdays` - Download match days

### **4. Data Models**
The app uses these main data structures:
- `Player`: Individual player with photo, jersey number, presence status
- `Team`: Collection of players with team info
- `Match`: Individual game between two teams
- `MatchDay`: Collection of matches for a specific date

## 📋 **Usage Workflow**

### **Pre-Season Setup**
1. **Create Teams**: Add all teams in your league
2. **Add Players**: Populate each team with players and photos
3. **Server Sync**: Upload all data to server for backup

### **Weekly Match Day Creation**
1. **Create Match Day**: Set date (e.g., "Sunday, Week 5")
2. **Schedule Games**: Add matches with:
   - Home vs Away teams
   - Game time
   - Field assignment
3. **Save & Sync**: Data automatically saved and synced

### **Game Day Operations**
1. **Access Today's Games**: Tab appears automatically
2. **Check-in Players**: Tap players to mark present/absent
3. **Monitor Attendance**: Real-time counts for each team
4. **Update Match Status**: Mark games as in-progress/completed

### **Post-Game**
1. **Review Results**: Check attendance statistics
2. **Sync Data**: Upload results to server
3. **Plan Next Week**: Create next match day

## 🔄 **Data Persistence**

### **Local Storage**
- Uses `UserDefaults` for local persistence
- Automatic save on all data changes
- Works offline completely

### **Server Sync**
- Manual sync via Settings tab
- Merges local and server data
- Handles conflicts gracefully
- Background sync capability

## 🎯 **Perfect for Sunday Leagues**

This app is specifically designed for:
- **Weekly Sunday Games**: Built-in Sunday scheduling
- **Multiple Teams**: Handle entire league rosters
- **Referee Management**: Easy check-in process
- **Season Planning**: Schedule weeks in advance
- **Data Continuity**: Never lose team/player data

## 📊 **Statistics & Reporting**

The app tracks:
- Total teams and players
- Attendance rates per team
- Match completion status
- Historical match data
- Player participation

## 🔐 **Data Security**

- Local data encrypted in UserDefaults
- HTTPS server communication
- No sensitive data stored in plain text
- Backup and restore capabilities

## 🚀 **Getting Started**

1. **Install the App**: Use the complete professional version code
2. **Add Your Teams**: Start with your league's teams
3. **Configure Server**: Set up your server endpoint
4. **Create First Match Day**: Schedule next Sunday's games
5. **Start Managing**: Use for your next game day!

This professional version transforms the simple check-in app into a complete league management system perfect for referees managing Sunday soccer leagues.