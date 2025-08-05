# Enhanced Soccer Referee App - Complete Guide

The enhanced version includes **player photos** and **multiple team management**! Here's how to use all the new features.

## 🆕 New Features

### 📸 Player Photos
- Add photos when creating new players
- Edit/change player photos anytime
- Photos display in circular thumbnails next to player names
- Remove photos if needed

### 👥 Multiple Teams Management
- Create unlimited teams with custom names and colors
- Select which teams to use for each game
- Dynamic tabs based on selected teams
- Color-coded team identification

## 📱 How to Use the App

### 1. **Teams Tab** (First Tab)
This is your team management hub:

**Adding Teams:**
1. Tap the "+" button in the top right
2. Enter team name (e.g., "Lions", "Eagles", "Manchester United")
3. Choose a team color from the color grid
4. Tap "Add Team"

**Selecting Teams for Game:**
1. Tap the circle next to teams you want to use
2. Selected teams get a green checkmark
3. These teams will appear as tabs for the game

**Managing Teams:**
- Swipe left on any team to delete it
- Teams show player count

### 2. **Adding Players to Teams**

**Step-by-step:**
1. Go to a team's tab (after selecting teams)
2. Tap the "+" button
3. **Add Photo** (Optional):
   - Tap "Add Photo" button
   - Choose from your photo library
   - Photo will appear in a circle
4. Enter player name
5. Enter jersey number
6. Tap "Add Player"

**Player Photos:**
- Photos are stored with the player data
- Display as circular thumbnails (40x40 points)
- If no photo: shows gray circle with person icon
- Can add/change/remove photos when editing

### 3. **Editing Players**

**To Edit a Player:**
1. Tap the pencil icon next to any player
2. **Change Photo:**
   - Tap "Change Photo" to select new image
   - Tap "Remove Photo" to delete current photo
3. Edit name and jersey number
4. Tap "Save"

### 4. **Checking In Players**
- Tap anywhere on a player row to toggle presence
- Green checkmark = Present
- Gray circle = Not checked in
- Player photos help with quick identification

### 5. **Summary Tab**
- Shows all selected teams in a grid
- Color-coded team identification
- Present/total counts for each team
- "Reset All Check-ins" affects all selected teams

## 🔧 Technical Requirements

**iOS Permissions Needed:**
- Photo Library Access (for player photos)

**iOS Version:**
- iOS 17.0+ (for PhotosPicker)

## 📋 Setup Instructions

### Option 1: New Xcode Project (Recommended)
1. Create new iOS App project in Xcode
2. Replace `ContentView.swift` with `SoccerRefereeAppEnhanced.swift`
3. Add photo library usage description to Info.plist:
   ```xml
   <key>NSPhotoLibraryUsageDescription</key>
   <string>This app needs access to photos to add player pictures</string>
   ```

### Option 2: Update Existing Project
1. Replace your existing code with `SoccerRefereeAppEnhanced.swift`
2. Add PhotosUI import and photo permissions

## 🎯 Usage Tips

**For Referees:**
1. **Pre-Game Setup:**
   - Create teams before the game
   - Add all players with photos for easy identification
   - Select the two teams playing

2. **Game Day:**
   - Use team tabs to check in players
   - Photos help identify players quickly
   - Summary tab shows overall attendance

3. **Multiple Games:**
   - Keep teams saved for future games
   - Select different team combinations as needed
   - Reset check-ins between games

**Photo Tips:**
- Use clear, recent photos of players
- Photos are automatically resized and cropped to circles
- Consider taking team photos for consistent lighting

## 🔄 Data Persistence

**Current Version:**
- Data resets when app closes (in-memory storage)

**For Production:**
- Add Core Data or UserDefaults for persistence
- Photos are stored as Data objects in the player model

## 🎨 Customization

**Team Colors Available:**
- Blue, Red, Green, Orange, Purple, Pink, Yellow, Cyan
- Colors help distinguish teams in tabs and summary

**UI Features:**
- Dynamic tab creation based on selected teams
- Responsive grid layout for team summary
- Consistent color theming throughout app