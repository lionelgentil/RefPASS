# How to Run the Soccer Referee App

Since the Xcode project file had formatting issues, I've created the complete app as a single Swift file that you can easily use in Xcode.

## Option 1: Create New iOS App Project (Recommended)

1. **Open Xcode**
2. **Create a new project:**
   - Choose "iOS" → "App"
   - Product Name: "SoccerRefereeApp"
   - Interface: SwiftUI
   - Language: Swift
   - Click "Next" and choose a location to save

3. **Replace the default code:**
   - Delete the contents of `ContentView.swift`
   - Copy all the code from `SoccerRefereeApp.swift` and paste it into `ContentView.swift`
   - Delete the default `SoccerRefereeAppApp.swift` file (since the code includes the App entry point)

4. **Run the app:**
   - Select your target device or simulator
   - Press Cmd+R to build and run

## Option 2: Swift Playgrounds (iOS Device)

1. Open Swift Playgrounds on your iPad or iPhone
2. Create a new "App" playground
3. Replace the default code with the contents of `SoccerRefereeApp.swift`
4. Tap "Run My App" to test it

## Option 3: Xcode Playgrounds

1. Open Xcode
2. Create a new Playground
3. Choose "iOS" as the platform
4. Replace the default code with the contents of `SoccerRefereeApp.swift`
5. Run the playground

## Features

The app includes:
- ✅ Two team management (Home/Away)
- ✅ Player roster editing (add/remove/edit players)
- ✅ Easy check-in system (tap to toggle presence)
- ✅ Jersey number tracking
- ✅ Team name customization
- ✅ Summary view with attendance counts
- ✅ Reset all check-ins functionality
- ✅ Sample data to get started

## Usage

1. **Home/Away Tabs**: Switch between teams
2. **Add Players**: Tap the "+" button
3. **Check-in Players**: Tap any player row to toggle their presence
4. **Edit Players**: Tap the pencil icon next to a player
5. **Edit Team Names**: Tap the pencil icon next to the team name
6. **Summary Tab**: View overall attendance and reset all check-ins

The app is designed for quick use during pre-game player check-ins with large touch targets and clear visual feedback.