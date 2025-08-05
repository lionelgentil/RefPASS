//
//  Soccer Referee Check-in App
//  A complete SwiftUI iOS app for managing player attendance
//
//  To use: Create a new iOS App project in Xcode and replace ContentView.swift with this code
//

import SwiftUI

// MARK: - Data Models

struct Player: Identifiable, Codable {
    let id = UUID()
    var name: String
    var jerseyNumber: Int
    var isPresent: Bool = false
    
    init(name: String, jerseyNumber: Int) {
        self.name = name
        self.jerseyNumber = jerseyNumber
    }
}

extension Player: Equatable {
    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
    }
}

class Team: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var players: [Player]
    let color: Color
    
    init(name: String, color: Color) {
        self.name = name
        self.color = color
        self.players = []
    }
    
    var presentPlayersCount: Int {
        players.filter { $0.isPresent }.count
    }
    
    var totalPlayersCount: Int {
        players.count
    }
    
    func addPlayer(_ player: Player) {
        players.append(player)
    }
    
    func removePlayer(at index: Int) {
        guard index < players.count else { return }
        players.remove(at: index)
    }
    
    func togglePlayerPresence(for playerId: UUID) {
        if let index = players.firstIndex(where: { $0.id == playerId }) {
            players[index].isPresent.toggle()
        }
    }
    
    func updatePlayer(at index: Int, name: String, jerseyNumber: Int) {
        guard index < players.count else { return }
        players[index].name = name
        players[index].jerseyNumber = jerseyNumber
    }
    
    func resetAllPresence() {
        for index in players.indices {
            players[index].isPresent = false
        }
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var homeTeam = Team(name: "Home Team", color: .blue)
    @StateObject private var awayTeam = Team(name: "Away Team", color: .red)
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Team Tab
            TeamRosterView(team: homeTeam)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            // Away Team Tab
            TeamRosterView(team: awayTeam)
                .tabItem {
                    Image(systemName: "airplane")
                    Text("Away")
                }
                .tag(1)
            
            // Summary Tab
            SummaryView(homeTeam: homeTeam, awayTeam: awayTeam)
                .tabItem {
                    Image(systemName: "list.clipboard")
                    Text("Summary")
                }
                .tag(2)
        }
        .onAppear {
            setupSampleData()
        }
    }
    
    private func setupSampleData() {
        // Add some sample players if teams are empty
        if homeTeam.players.isEmpty {
            homeTeam.addPlayer(Player(name: "John Smith", jerseyNumber: 1))
            homeTeam.addPlayer(Player(name: "Mike Johnson", jerseyNumber: 2))
            homeTeam.addPlayer(Player(name: "David Wilson", jerseyNumber: 3))
        }
        
        if awayTeam.players.isEmpty {
            awayTeam.addPlayer(Player(name: "Alex Brown", jerseyNumber: 1))
            awayTeam.addPlayer(Player(name: "Chris Davis", jerseyNumber: 2))
            awayTeam.addPlayer(Player(name: "Sam Miller", jerseyNumber: 3))
        }
    }
}

struct TeamRosterView: View {
    @ObservedObject var team: Team
    @State private var showingAddPlayer = false
    @State private var showingEditTeamName = false
    @State private var editingTeamName = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Team header with name and stats
                VStack(spacing: 8) {
                    HStack {
                        Text(team.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(team.color)
                        
                        Button {
                            editingTeamName = team.name
                            showingEditTeamName = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("\(team.presentPlayersCount) of \(team.totalPlayersCount) players present")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Players list
                if team.players.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No players added yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Tap the + button to add players to the roster")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(team.players.indices, id: \.self) { index in
                            PlayerRowView(
                                player: $team.players[index],
                                onTogglePresence: {
                                    team.togglePlayerPresence(for: team.players[index].id)
                                },
                                onEdit: { name, jerseyNumber in
                                    team.updatePlayer(at: index, name: name, jerseyNumber: jerseyNumber)
                                }
                            )
                        }
                        .onDelete(perform: deletePlayer)
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddPlayer = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView { name, jerseyNumber in
                let newPlayer = Player(name: name, jerseyNumber: jerseyNumber)
                team.addPlayer(newPlayer)
            }
        }
        .alert("Edit Team Name", isPresented: $showingEditTeamName) {
            TextField("Team Name", text: $editingTeamName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if !editingTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    team.name = editingTeamName
                }
            }
        }
    }
    
    private func deletePlayer(at offsets: IndexSet) {
        for index in offsets {
            team.removePlayer(at: index)
        }
    }
}

struct PlayerRowView: View {
    @Binding var player: Player
    let onTogglePresence: () -> Void
    let onEdit: (String, Int) -> Void
    
    @State private var showingEditPlayer = false
    @State private var editingName = ""
    @State private var editingJerseyNumber = ""
    
    var body: some View {
        HStack(spacing: 15) {
            // Presence checkbox
            Button {
                onTogglePresence()
            } label: {
                Image(systemName: player.isPresent ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(player.isPresent ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Jersey number
            Text("#\(player.jerseyNumber)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(minWidth: 40, alignment: .leading)
            
            // Player name
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(player.isPresent ? "Present" : "Not checked in")
                    .font(.caption)
                    .foregroundColor(player.isPresent ? .green : .secondary)
            }
            
            Spacer()
            
            // Edit button
            Button {
                editingName = player.name
                editingJerseyNumber = String(player.jerseyNumber)
                showingEditPlayer = true
            } label: {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTogglePresence()
        }
        .sheet(isPresented: $showingEditPlayer) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Edit Player")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Player Name")
                            .font(.headline)
                        TextField("Enter player name", text: $editingName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Jersey Number")
                            .font(.headline)
                        TextField("Enter jersey number", text: $editingJerseyNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                    
                    Spacer()
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingEditPlayer = false
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            if let jerseyNumber = Int(editingJerseyNumber),
                               !editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onEdit(editingName, jerseyNumber)
                                showingEditPlayer = false
                            }
                        }
                        .disabled(editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                                Int(editingJerseyNumber) == nil)
                    }
                }
            }
        }
    }
}

struct AddPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playerName = ""
    @State private var jerseyNumber = ""
    
    let onAddPlayer: (String, Int) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Add New Player")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Player Name")
                        .font(.headline)
                    TextField("Enter player name", text: $playerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Jersey Number")
                        .font(.headline)
                    TextField("Enter jersey number", text: $jerseyNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                Button("Add Player") {
                    if let number = Int(jerseyNumber),
                       !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onAddPlayer(playerName, number)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                         Int(jerseyNumber) == nil)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SummaryView: View {
    @ObservedObject var homeTeam: Team
    @ObservedObject var awayTeam: Team
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Game Summary")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                HStack(spacing: 40) {
                    // Home Team Summary
                    VStack {
                        Text(homeTeam.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(homeTeam.color)
                        
                        Text("\(homeTeam.presentPlayersCount)/\(homeTeam.totalPlayersCount)")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Present")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    Text("VS")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    // Away Team Summary
                    VStack {
                        Text(awayTeam.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(awayTeam.color)
                        
                        Text("\(awayTeam.presentPlayersCount)/\(awayTeam.totalPlayersCount)")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Present")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                VStack(spacing: 10) {
                    Button("Reset All Check-ins") {
                        homeTeam.resetAllPresence()
                        awayTeam.resetAllPresence()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Text("This will uncheck all players from both teams")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - App Entry Point

@main
struct SoccerRefereeAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Previews

#Preview {
    ContentView()
}