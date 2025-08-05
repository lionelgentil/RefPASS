//
//  Soccer Referee Check-in App - Enhanced Version
//  A complete SwiftUI iOS app for managing player attendance with photos and multiple teams
//
//  To use: Create a new iOS App project in Xcode and replace ContentView.swift with this code
//

import SwiftUI
import PhotosUI

// MARK: - Data Models

struct Player: Identifiable, Codable {
    let id = UUID()
    var name: String
    var jerseyNumber: Int
    var isPresent: Bool = false
    var photoData: Data?
    
    init(name: String, jerseyNumber: Int, photoData: Data? = nil) {
        self.name = name
        self.jerseyNumber = jerseyNumber
        self.photoData = photoData
    }
    
    var photo: UIImage? {
        guard let photoData = photoData else { return nil }
        return UIImage(data: photoData)
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
    @Published var color: Color
    
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
    
    func updatePlayer(at index: Int, name: String, jerseyNumber: Int, photoData: Data?) {
        guard index < players.count else { return }
        players[index].name = name
        players[index].jerseyNumber = jerseyNumber
        players[index].photoData = photoData
    }
    
    func resetAllPresence() {
        for index in players.indices {
            players[index].isPresent = false
        }
    }
}

class GameManager: ObservableObject {
    @Published var teams: [Team] = []
    @Published var selectedTeamIndices: [Int] = []
    
    init() {
        setupDefaultTeams()
    }
    
    private func setupDefaultTeams() {
        let homeTeam = Team(name: "Home Team", color: .blue)
        let awayTeam = Team(name: "Away Team", color: .red)
        
        // Add sample players
        homeTeam.addPlayer(Player(name: "John Smith", jerseyNumber: 1))
        homeTeam.addPlayer(Player(name: "Mike Johnson", jerseyNumber: 2))
        homeTeam.addPlayer(Player(name: "David Wilson", jerseyNumber: 3))
        
        awayTeam.addPlayer(Player(name: "Alex Brown", jerseyNumber: 1))
        awayTeam.addPlayer(Player(name: "Chris Davis", jerseyNumber: 2))
        awayTeam.addPlayer(Player(name: "Sam Miller", jerseyNumber: 3))
        
        teams = [homeTeam, awayTeam]
        selectedTeamIndices = [0, 1] // Select first two teams by default
    }
    
    func addTeam(_ team: Team) {
        teams.append(team)
    }
    
    func removeTeam(at index: Int) {
        guard index < teams.count else { return }
        teams.remove(at: index)
        // Update selected indices if needed
        selectedTeamIndices = selectedTeamIndices.compactMap { selectedIndex in
            if selectedIndex == index {
                return nil // Remove this selection
            } else if selectedIndex > index {
                return selectedIndex - 1 // Adjust for removed team
            } else {
                return selectedIndex // Keep as is
            }
        }
    }
    
    var selectedTeams: [Team] {
        selectedTeamIndices.compactMap { index in
            guard index < teams.count else { return nil }
            return teams[index]
        }
    }
    
    func resetAllTeamsPresence() {
        for team in selectedTeams {
            team.resetAllPresence()
        }
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Teams Management Tab
            TeamsManagementView(gameManager: gameManager)
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Teams")
                }
                .tag(0)
            
            // Game View Tabs (Dynamic based on selected teams)
            ForEach(Array(gameManager.selectedTeams.enumerated()), id: \.element.id) { index, team in
                TeamRosterView(team: team)
                    .tabItem {
                        Image(systemName: index == 0 ? "house.fill" : "airplane")
                        Text(team.name)
                    }
                    .tag(index + 1)
            }
            
            // Summary Tab
            if !gameManager.selectedTeams.isEmpty {
                SummaryView(teams: gameManager.selectedTeams, gameManager: gameManager)
                    .tabItem {
                        Image(systemName: "list.clipboard")
                        Text("Summary")
                    }
                    .tag(gameManager.selectedTeams.count + 1)
            }
        }
    }
}

struct TeamsManagementView: View {
    @ObservedObject var gameManager: GameManager
    @State private var showingAddTeam = false
    
    var body: some View {
        NavigationView {
            VStack {
                if gameManager.teams.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "sportscourt")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No teams created yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Tap the + button to add your first team")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("Available Teams") {
                            ForEach(Array(gameManager.teams.enumerated()), id: \.element.id) { index, team in
                                TeamRowView(
                                    team: team,
                                    isSelected: gameManager.selectedTeamIndices.contains(index),
                                    onToggleSelection: {
                                        toggleTeamSelection(at: index)
                                    }
                                )
                            }
                            .onDelete(perform: deleteTeam)
                        }
                        
                        if !gameManager.selectedTeamIndices.isEmpty {
                            Section("Selected for Game") {
                                Text("\(gameManager.selectedTeamIndices.count) team(s) selected")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Teams")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTeam = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTeam) {
            AddTeamView { name, color in
                let newTeam = Team(name: name, color: color)
                gameManager.addTeam(newTeam)
            }
        }
    }
    
    private func toggleTeamSelection(at index: Int) {
        if let selectedIndex = gameManager.selectedTeamIndices.firstIndex(of: index) {
            gameManager.selectedTeamIndices.remove(at: selectedIndex)
        } else {
            gameManager.selectedTeamIndices.append(index)
        }
    }
    
    private func deleteTeam(at offsets: IndexSet) {
        for index in offsets {
            gameManager.removeTeam(at: index)
        }
    }
}

struct TeamRowView: View {
    @ObservedObject var team: Team
    let isSelected: Bool
    let onToggleSelection: () -> Void
    
    var body: some View {
        HStack {
            Button {
                onToggleSelection()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            Circle()
                .fill(team.color)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading) {
                Text(team.name)
                    .font(.headline)
                
                Text("\(team.totalPlayersCount) players")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleSelection()
        }
    }
}

struct AddTeamView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var teamName = ""
    @State private var selectedColor = Color.blue
    
    let onAddTeam: (String, Color) -> Void
    
    let availableColors: [Color] = [.blue, .red, .green, .orange, .purple, .pink, .yellow, .cyan]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Add New Team")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Team Name")
                        .font(.headline)
                    TextField("Enter team name", text: $teamName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Team Color")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(availableColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                }
                
                Button("Add Team") {
                    if !teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onAddTeam(teamName, selectedColor)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
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

struct TeamRosterView: View {
    @ObservedObject var team: Team
    @State private var showingAddPlayer = false
    @State private var showingEditTeamName = false
    @State private var editingTeamName = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Team stats header
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(team.color)
                            .frame(width: 15, height: 15)
                        
                        Text("\(team.presentPlayersCount) of \(team.totalPlayersCount) players present")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button {
                            editingTeamName = team.name
                            showingEditTeamName = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                        }
                    }
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
                                onEdit: { name, jerseyNumber, photoData in
                                    team.updatePlayer(at: index, name: name, jerseyNumber: jerseyNumber, photoData: photoData)
                                }
                            )
                        }
                        .onDelete(perform: deletePlayer)
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            .navigationTitle(team.name)
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
            AddPlayerView { name, jerseyNumber, photoData in
                let newPlayer = Player(name: name, jerseyNumber: jerseyNumber, photoData: photoData)
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
    let onEdit: (String, Int, Data?) -> Void
    
    @State private var showingEditPlayer = false
    
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
            
            // Player photo
            if let photo = player.photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
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
            EditPlayerView(
                player: player,
                onSave: onEdit
            )
        }
    }
}

struct AddPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playerName = ""
    @State private var jerseyNumber = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    
    let onAddPlayer: (String, Int, Data?) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Add New Player")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Photo picker
                VStack {
                    if let photoData = photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.title)
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    PhotosPicker("Add Photo", selection: $selectedPhoto, matching: .images)
                        .buttonStyle(.bordered)
                }
                
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
                        onAddPlayer(playerName, number, photoData)
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
            .onChange(of: selectedPhoto) { newPhoto in
                Task {
                    if let data = try? await newPhoto?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }
}

struct EditPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editingName: String
    @State private var editingJerseyNumber: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    
    let onSave: (String, Int, Data?) -> Void
    
    init(player: Player, onSave: @escaping (String, Int, Data?) -> Void) {
        self._editingName = State(initialValue: player.name)
        self._editingJerseyNumber = State(initialValue: String(player.jerseyNumber))
        self._photoData = State(initialValue: player.photoData)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Edit Player")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Photo picker
                VStack {
                    if let photoData = photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.title)
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    HStack {
                        PhotosPicker("Change Photo", selection: $selectedPhoto, matching: .images)
                            .buttonStyle(.bordered)
                        
                        if photoData != nil {
                            Button("Remove Photo") {
                                photoData = nil
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                    }
                }
                
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
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let jerseyNumber = Int(editingJerseyNumber),
                           !editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSave(editingName, jerseyNumber, photoData)
                            dismiss()
                        }
                    }
                    .disabled(editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                            Int(editingJerseyNumber) == nil)
                }
            }
            .onChange(of: selectedPhoto) { newPhoto in
                Task {
                    if let data = try? await newPhoto?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }
}

struct SummaryView: View {
    let teams: [Team]
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Game Summary")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding()
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(teams.count, 2)), spacing: 20) {
                        ForEach(teams) { team in
                            VStack {
                                HStack {
                                    Circle()
                                        .fill(team.color)
                                        .frame(width: 15, height: 15)
                                    
                                    Text(team.name)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(team.color)
                                }
                                
                                Text("\(team.presentPlayersCount)/\(team.totalPlayersCount)")
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
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 10) {
                        Button("Reset All Check-ins") {
                            gameManager.resetAllTeamsPresence()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Text("This will uncheck all players from all selected teams")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 30)
                    
                    Spacer(minLength: 50)
                }
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