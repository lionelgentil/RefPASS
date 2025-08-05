//
//  Soccer Referee App - Professional League Management Version
//  Complete league management with match scheduling, team repository, and server sync
//
//  Features:
//  - Persistent team repository
//  - Match day scheduling
//  - Server synchronization
//  - League management
//

import SwiftUI
import PhotosUI
import Foundation

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

class Team: ObservableObject, Identifiable, Codable {
    let id = UUID()
    @Published var name: String
    @Published var players: [Player]
    @Published var color: Color
    var colorData: Data // For Codable support
    
    init(name: String, color: Color) {
        self.name = name
        self.color = color
        self.players = []
        self.colorData = Self.colorToData(color)
    }
    
    // Codable support
    enum CodingKeys: CodingKey {
        case id, name, players, colorData
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let players = try container.decode([Player].self, forKey: .players)
        let colorData = try container.decode(Data.self, forKey: .colorData)
        
        self.name = name
        self.players = players
        self.colorData = colorData
        self.color = Self.dataToColor(colorData)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(players, forKey: .players)
        try container.encode(colorData, forKey: .colorData)
    }
    
    static func colorToData(_ color: Color) -> Data {
        let uiColor = UIColor(color)
        return try! NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false)
    }
    
    static func dataToColor(_ data: Data) -> Color {
        if let uiColor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? UIColor {
            return Color(uiColor)
        }
        return .blue
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

struct Match: Identifiable, Codable {
    let id = UUID()
    var homeTeamId: UUID
    var awayTeamId: UUID
    var scheduledTime: Date
    var field: String
    var status: MatchStatus = .scheduled
    var homeTeamPresent: Int = 0
    var awayTeamPresent: Int = 0
    
    enum MatchStatus: String, CaseIterable, Codable {
        case scheduled = "Scheduled"
        case inProgress = "In Progress"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }
}

struct MatchDay: Identifiable, Codable {
    let id = UUID()
    var date: Date
    var name: String
    var matches: [Match]
    var notes: String = ""
    
    init(date: Date, name: String) {
        self.date = date
        self.name = name
        self.matches = []
    }
}

// MARK: - Data Manager

class LeagueDataManager: ObservableObject {
    @Published var teams: [Team] = []
    @Published var matchDays: [MatchDay] = []
    @Published var currentMatchDay: MatchDay?
    
    private let serverURL = "https://your-server.com/api" // Replace with your server URL
    private let teamsKey = "SavedTeams"
    private let matchDaysKey = "SavedMatchDays"
    
    init() {
        loadLocalData()
        setupSampleData()
    }
    
    // MARK: - Local Storage
    
    private func loadLocalData() {
        loadTeams()
        loadMatchDays()
    }
    
    private func loadTeams() {
        if let data = UserDefaults.standard.data(forKey: teamsKey),
           let decodedTeams = try? JSONDecoder().decode([Team].self, from: data) {
            self.teams = decodedTeams
        }
    }
    
    private func saveTeams() {
        if let encoded = try? JSONEncoder().encode(teams) {
            UserDefaults.standard.set(encoded, forKey: teamsKey)
        }
    }
    
    private func loadMatchDays() {
        if let data = UserDefaults.standard.data(forKey: matchDaysKey),
           let decodedMatchDays = try? JSONDecoder().decode([MatchDay].self, from: data) {
            self.matchDays = decodedMatchDays
        }
    }
    
    private func saveMatchDays() {
        if let encoded = try? JSONEncoder().encode(matchDays) {
            UserDefaults.standard.set(encoded, forKey: matchDaysKey)
        }
    }
    
    // MARK: - Server Sync
    
    func syncWithServer() async {
        await uploadTeamsToServer()
        await downloadTeamsFromServer()
        await uploadMatchDaysToServer()
        await downloadMatchDaysFromServer()
    }
    
    private func uploadTeamsToServer() async {
        guard let url = URL(string: "\(serverURL)/teams") else { return }
        
        do {
            let data = try JSONEncoder().encode(teams)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (_, _) = try await URLSession.shared.data(for: request)
            print("Teams uploaded successfully")
        } catch {
            print("Failed to upload teams: \(error)")
        }
    }
    
    private func downloadTeamsFromServer() async {
        guard let url = URL(string: "\(serverURL)/teams") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let serverTeams = try JSONDecoder().decode([Team].self, from: data)
            
            await MainActor.run {
                // Merge server teams with local teams
                for serverTeam in serverTeams {
                    if !teams.contains(where: { $0.id == serverTeam.id }) {
                        teams.append(serverTeam)
                    }
                }
                saveTeams()
            }
        } catch {
            print("Failed to download teams: \(error)")
        }
    }
    
    private func uploadMatchDaysToServer() async {
        guard let url = URL(string: "\(serverURL)/matchdays") else { return }
        
        do {
            let data = try JSONEncoder().encode(matchDays)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (_, _) = try await URLSession.shared.data(for: request)
            print("Match days uploaded successfully")
        } catch {
            print("Failed to upload match days: \(error)")
        }
    }
    
    private func downloadMatchDaysFromServer() async {
        guard let url = URL(string: "\(serverURL)/matchdays") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let serverMatchDays = try JSONDecoder().decode([MatchDay].self, from: data)
            
            await MainActor.run {
                // Merge server match days with local match days
                for serverMatchDay in serverMatchDays {
                    if !matchDays.contains(where: { $0.id == serverMatchDay.id }) {
                        matchDays.append(serverMatchDay)
                    }
                }
                saveMatchDays()
            }
        } catch {
            print("Failed to download match days: \(error)")
        }
    }
    
    // MARK: - Team Management
    
    func addTeam(_ team: Team) {
        teams.append(team)
        saveTeams()
    }
    
    func removeTeam(at index: Int) {
        guard index < teams.count else { return }
        teams.remove(at: index)
        saveTeams()
    }
    
    func updateTeam(_ team: Team) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index] = team
            saveTeams()
        }
    }
    
    // MARK: - Match Day Management
    
    func addMatchDay(_ matchDay: MatchDay) {
        matchDays.append(matchDay)
        matchDays.sort { $0.date < $1.date }
        saveMatchDays()
    }
    
    func removeMatchDay(at index: Int) {
        guard index < matchDays.count else { return }
        matchDays.remove(at: index)
        saveMatchDays()
    }
    
    func updateMatchDay(_ matchDay: MatchDay) {
        if let index = matchDays.firstIndex(where: { $0.id == matchDay.id }) {
            matchDays[index] = matchDay
            saveMatchDays()
        }
    }
    
    func addMatchToMatchDay(_ match: Match, to matchDayId: UUID) {
        if let index = matchDays.firstIndex(where: { $0.id == matchDayId }) {
            matchDays[index].matches.append(match)
            saveMatchDays()
        }
    }
    
    func getTeam(by id: UUID) -> Team? {
        return teams.first { $0.id == id }
    }
    
    func getUpcomingMatchDays() -> [MatchDay] {
        let now = Date()
        return matchDays.filter { $0.date >= now }.sorted { $0.date < $1.date }
    }
    
    func getPastMatchDays() -> [MatchDay] {
        let now = Date()
        return matchDays.filter { $0.date < now }.sorted { $0.date > $1.date }
    }
    
    // MARK: - Sample Data
    
    private func setupSampleData() {
        if teams.isEmpty {
            let team1 = Team(name: "Lions FC", color: .blue)
            team1.addPlayer(Player(name: "John Smith", jerseyNumber: 1))
            team1.addPlayer(Player(name: "Mike Johnson", jerseyNumber: 2))
            
            let team2 = Team(name: "Eagles United", color: .red)
            team2.addPlayer(Player(name: "Alex Brown", jerseyNumber: 1))
            team2.addPlayer(Player(name: "Chris Davis", jerseyNumber: 2))
            
            let team3 = Team(name: "Tigers SC", color: .green)
            team3.addPlayer(Player(name: "Sam Wilson", jerseyNumber: 1))
            team3.addPlayer(Player(name: "Tom Miller", jerseyNumber: 2))
            
            teams = [team1, team2, team3]
            saveTeams()
        }
        
        if matchDays.isEmpty {
            // Create sample match day for next Sunday
            let nextSunday = getNextSunday()
            var sampleMatchDay = MatchDay(date: nextSunday, name: "Week 1 - League Games")
            
            if teams.count >= 2 {
                let match1 = Match(
                    homeTeamId: teams[0].id,
                    awayTeamId: teams[1].id,
                    scheduledTime: nextSunday.addingTimeInterval(2 * 3600), // 2 PM
                    field: "Field A"
                )
                sampleMatchDay.matches.append(match1)
                
                if teams.count >= 3 {
                    let match2 = Match(
                        homeTeamId: teams[2].id,
                        awayTeamId: teams[0].id,
                        scheduledTime: nextSunday.addingTimeInterval(4 * 3600), // 4 PM
                        field: "Field B"
                    )
                    sampleMatchDay.matches.append(match2)
                }
            }
            
            matchDays.append(sampleMatchDay)
            saveMatchDays()
        }
    }
    
    private func getNextSunday() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilSunday = (8 - weekday) % 7
        let nextSunday = calendar.date(byAdding: .day, value: daysUntilSunday == 0 ? 7 : daysUntilSunday, to: today)!
        return calendar.date(bySettingHour: 14, minute: 0, second: 0, of: nextSunday)!
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var dataManager = LeagueDataManager()
    @State private var selectedTab = 0
    @State private var isLoading = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Teams Repository Tab
            TeamsRepositoryView(dataManager: dataManager)
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Teams")
                }
                .tag(0)
            
            // Match Days Tab
            MatchDaysView(dataManager: dataManager)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Match Days")
                }
                .tag(1)
            
            // Current Match Day Tab
            if let currentMatchDay = dataManager.currentMatchDay {
                CurrentMatchDayView(matchDay: currentMatchDay, dataManager: dataManager)
                    .tabItem {
                        Image(systemName: "sportscourt")
                        Text("Today's Games")
                    }
                    .tag(2)
            }
            
            // Settings Tab
            SettingsView(dataManager: dataManager, isLoading: $isLoading)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .overlay(
            Group {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Syncing with server...")
                            .padding(.top)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
            }
        )
    }
}

struct TeamsRepositoryView: View {
    @ObservedObject var dataManager: LeagueDataManager
    @State private var showingAddTeam = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.teams) { team in
                    NavigationLink(destination: TeamDetailView(team: team, dataManager: dataManager)) {
                        TeamRowView(team: team)
                    }
                }
                .onDelete(perform: deleteTeam)
            }
            .navigationTitle("Teams Repository")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTeam = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTeam) {
            AddTeamView { name, color in
                let newTeam = Team(name: name, color: color)
                dataManager.addTeam(newTeam)
            }
        }
    }
    
    private func deleteTeam(at offsets: IndexSet) {
        for index in offsets {
            dataManager.removeTeam(at: index)
        }
    }
}

struct TeamRowView: View {
    @ObservedObject var team: Team
    
    var body: some View {
        HStack {
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
    }
}

struct MatchDaysView: View {
    @ObservedObject var dataManager: LeagueDataManager
    @State private var showingAddMatchDay = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Upcoming Match Days") {
                    ForEach(dataManager.getUpcomingMatchDays()) { matchDay in
                        NavigationLink(destination: MatchDayDetailView(matchDay: matchDay, dataManager: dataManager)) {
                            MatchDayRowView(matchDay: matchDay, dataManager: dataManager)
                        }
                    }
                }
                
                Section("Past Match Days") {
                    ForEach(dataManager.getPastMatchDays()) { matchDay in
                        NavigationLink(destination: MatchDayDetailView(matchDay: matchDay, dataManager: dataManager)) {
                            MatchDayRowView(matchDay: matchDay, dataManager: dataManager)
                        }
                    }
                }
            }
            .navigationTitle("Match Schedule")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddMatchDay = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMatchDay) {
            AddMatchDayView(dataManager: dataManager)
        }
    }
}

struct MatchDayRowView: View {
    let matchDay: MatchDay
    @ObservedObject var dataManager: LeagueDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(matchDay.name)
                    .font(.headline)
                
                Spacer()
                
                Text(matchDay.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(matchDay.matches.count) games scheduled")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if matchDay.date.timeIntervalSinceNow < 86400 && matchDay.date.timeIntervalSinceNow > -86400 {
                Text("TODAY")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SettingsView: View {
    @ObservedObject var dataManager: LeagueDataManager
    @Binding var isLoading: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section("Data Management") {
                    Button("Sync with Server") {
                        syncData()
                    }
                    .disabled(isLoading)
                    
                    Button("Export Data") {
                        exportData()
                    }
                    
                    Button("Import Data") {
                        importData()
                    }
                }
                
                Section("Statistics") {
                    HStack {
                        Text("Total Teams")
                        Spacer()
                        Text("\(dataManager.teams.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Players")
                        Spacer()
                        Text("\(dataManager.teams.reduce(0) { $0 + $1.totalPlayersCount })")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Scheduled Match Days")
                        Spacer()
                        Text("\(dataManager.getUpcomingMatchDays().count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func syncData() {
        isLoading = true
        Task {
            await dataManager.syncWithServer()
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func exportData() {
        // Implementation for data export
        print("Export data functionality")
    }
    
    private func importData() {
        // Implementation for data import
        print("Import data functionality")
    }
}

// Additional views would continue here...
// (TeamDetailView, MatchDayDetailView, AddMatchDayView, etc.)

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