//
//  Soccer Referee App - Complete Professional League Management Version
//  Complete league management with match scheduling, team repository, and server sync
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

class Team: ObservableObject, Identifiable, Codable, Hashable {
    let id = UUID()
    @Published var name: String
    @Published var players: [Player]
    @Published var color: Color
    var colorData: Data
    var lastModified: Date = Date()
    
    init(name: String, color: Color) {
        self.name = name
        self.color = color
        self.players = []
        self.colorData = Self.colorToData(color)
    }
    
    enum CodingKeys: CodingKey {
        case id, name, players, colorData, lastModified
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let players = try container.decode([Player].self, forKey: .players)
        let colorData = try container.decode(Data.self, forKey: .colorData)
        let lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        
        self.name = name
        self.players = players
        self.colorData = colorData
        self.color = Self.dataToColor(colorData)
        self.lastModified = lastModified
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(players, forKey: .players)
        try container.encode(colorData, forKey: .colorData)
        try container.encode(lastModified, forKey: .lastModified)
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
        lastModified = Date()
    }
    
    func removePlayer(at index: Int) {
        guard index < players.count else { return }
        players.remove(at: index)
        lastModified = Date()
    }
    
    func togglePlayerPresence(for playerId: UUID) {
        if let index = players.firstIndex(where: { $0.id == playerId }) {
            players[index].isPresent.toggle()
            lastModified = Date()
        }
    }
    
    func updatePlayer(at index: Int, name: String, jerseyNumber: Int, photoData: Data?) {
        guard index < players.count else { return }
        players[index].name = name
        players[index].jerseyNumber = jerseyNumber
        players[index].photoData = photoData
        lastModified = Date()
    }
    
    func resetAllPresence() {
        for index in players.indices {
            players[index].isPresent = false
        }
        lastModified = Date()
    }
    
    // MARK: - Hashable Conformance
    
    static func == (lhs: Team, rhs: Team) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
    
    // Match-specific player presence tracking
    var homeTeamPresentPlayers: Set<UUID> = []
    var awayTeamPresentPlayers: Set<UUID> = []
    
    // Score tracking
    var homeTeamScore: Int?
    var awayTeamScore: Int?
    
    enum MatchStatus: String, CaseIterable, Codable {
        case scheduled = "Scheduled"
        case inProgress = "In Progress"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }
    
    var hasScore: Bool {
        homeTeamScore != nil && awayTeamScore != nil
    }
    
    var scoreDisplay: String {
        if let homeScore = homeTeamScore, let awayScore = awayTeamScore {
            return "\(homeScore) - \(awayScore)"
        }
        return "No score"
    }
}

struct MatchDay: Identifiable, Codable {
    let id = UUID()
    var date: Date
    var name: String
    var matches: [Match]
    var notes: String = ""
    var lastModified: Date = Date()
    
    init(date: Date, name: String) {
        self.date = date
        self.name = name
        self.matches = []
        self.lastModified = Date()
    }
}

// MARK: - Sync Data Structure

struct SyncData: Codable {
    let teams: [Team]
    let matchDays: [MatchDay]
}

// MARK: - Data Manager

class LeagueDataManager: ObservableObject {
    @Published var teams: [Team] = []
    @Published var matchDays: [MatchDay] = []
    @Published var currentMatchDay: MatchDay?
    @Published var syncStatus: String = ""
    @Published var lastSyncDate: Date?
    
    private let serverURL = "http://localhost:3000/api"  // Change this to your actual server URL
    private let teamsKey = "SavedTeams"
    private let matchDaysKey = "SavedMatchDays"
    
    init() {
        loadLocalData()
        setupSampleData()
    }
    
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
    
    // MARK: - Smart Sync Methods
    
    private func fetchServerData() async -> SyncData? {
        // Try the unified sync endpoint first
        if let syncData = await fetchFromSyncEndpoint() {
            return syncData
        }
        
        // Fallback to separate endpoints
        return await fetchFromSeparateEndpoints()
    }
    
    private func fetchFromSyncEndpoint() async -> SyncData? {
        guard let url = URL(string: "\(serverURL)/sync") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return try JSONDecoder().decode(SyncData.self, from: data)
            }
        } catch {
            print("Sync endpoint not available: \(error)")
        }
        return nil
    }
    
    private func fetchFromSeparateEndpoints() async -> SyncData? {
        async let teamsData = fetchTeamsFromServer()
        async let matchDaysData = fetchMatchDaysFromServer()
        
        let (teams, matchDays) = await (teamsData, matchDaysData)
        
        if let teams = teams, let matchDays = matchDays {
            return SyncData(teams: teams, matchDays: matchDays)
        }
        
        // If one endpoint fails, try to get what we can
        let availableTeams = teams ?? []
        let availableMatchDays = matchDays ?? []
        
        // Only return data if we got something from the server
        if !availableTeams.isEmpty || !availableMatchDays.isEmpty {
            return SyncData(teams: availableTeams, matchDays: availableMatchDays)
        }
        
        return nil
    }
    
    private func fetchTeamsFromServer() async -> [Team]? {
        guard let url = URL(string: "\(serverURL)/teams") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    return [] // Server exists but no teams yet
                }
                if httpResponse.statusCode != 200 {
                    return nil
                }
            }
            
            // Check if response is HTML (server error)
            if let responseString = String(data: data, encoding: .utf8),
               responseString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
                return nil
            }
            
            if data.isEmpty {
                return []
            }
            
            return try JSONDecoder().decode([Team].self, from: data)
        } catch {
            print("Error fetching teams: \(error)")
            return nil
        }
    }
    
    private func fetchMatchDaysFromServer() async -> [MatchDay]? {
        guard let url = URL(string: "\(serverURL)/matchdays") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    return [] // Server exists but no match days yet
                }
                if httpResponse.statusCode != 200 {
                    return nil
                }
            }
            
            // Check if response is HTML (server error)
            if let responseString = String(data: data, encoding: .utf8),
               responseString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
                return nil
            }
            
            if data.isEmpty {
                return []
            }
            
            return try JSONDecoder().decode([MatchDay].self, from: data)
        } catch {
            print("Error fetching match days: \(error)")
            return nil
        }
    }
    
    private func uploadDataToServer(_ syncData: SyncData) async -> Bool {
        // Try unified sync endpoint first
        if await uploadToSyncEndpoint(syncData) {
            return true
        }
        
        // Fallback to separate endpoints
        return await uploadToSeparateEndpoints(syncData)
    }
    
    private func uploadToSyncEndpoint(_ syncData: SyncData) async -> Bool {
        guard let url = URL(string: "\(serverURL)/sync") else { return false }
        
        do {
            let jsonData = try JSONEncoder().encode(syncData)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("Sync endpoint upload failed: \(error)")
            return false
        }
    }
    
    private func uploadToSeparateEndpoints(_ syncData: SyncData) async -> Bool {
        async let teamsUpload = uploadTeamsToServer(syncData.teams)
        async let matchDaysUpload = uploadMatchDaysToServer(syncData.matchDays)
        
        let (teamsSuccess, matchDaysSuccess) = await (teamsUpload, matchDaysUpload)
        
        // Consider it successful if at least one upload worked
        return teamsSuccess || matchDaysSuccess
    }
    
    private func uploadTeamsToServer(_ teams: [Team]) async -> Bool {
        guard let url = URL(string: "\(serverURL)/teams") else { return false }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(teams)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("Failed to upload teams: \(error)")
            return false
        }
    }
    
    private func uploadMatchDaysToServer(_ matchDays: [MatchDay]) async -> Bool {
        guard let url = URL(string: "\(serverURL)/matchdays") else { return false }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(matchDays)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("Failed to upload match days: \(error)")
            return false
        }
    }
    
    func smartSync() async {
        DispatchQueue.main.async {
            self.syncStatus = "Starting sync..."
        }
        
        // Simple approach: Try to upload first, then download
        let uploadSuccess = await uploadToSeparateEndpoints(SyncData(teams: teams, matchDays: matchDays))
        
        if uploadSuccess {
            DispatchQueue.main.async {
                self.syncStatus = "Upload successful, checking for updates..."
            }
            
            // Try to get any updates from server
            if let serverData = await fetchFromSeparateEndpoints() {
                DispatchQueue.main.async {
                    // Only update if we got data from server
                    if !serverData.teams.isEmpty || !serverData.matchDays.isEmpty {
                        self.teams = serverData.teams
                        self.matchDays = serverData.matchDays.sorted { $0.date < $1.date }
                        self.saveData()
                    }
                    
                    self.lastSyncDate = Date()
                    self.syncStatus = "Sync complete: Data synchronized with server"
                }
            } else {
                DispatchQueue.main.async {
                    self.lastSyncDate = Date()
                    self.syncStatus = "Upload complete: Data sent to server"
                }
            }
        } else {
            DispatchQueue.main.async {
                self.syncStatus = "Server not available - working offline"
            }
        }
    }
    
    private func compareSyncData(local: SyncData, server: SyncData) -> (localChanges: Int, serverChanges: Int) {
        var localChanges = 0
        var serverChanges = 0
        
        // Count local teams that are newer or don't exist on server
        for localTeam in local.teams {
            if let serverTeam = server.teams.first(where: { $0.id == localTeam.id }) {
                if localTeam.lastModified > serverTeam.lastModified {
                    localChanges += 1
                }
            } else {
                localChanges += 1
            }
        }
        
        // Count local match days that are newer or don't exist on server
        for localMatchDay in local.matchDays {
            if let serverMatchDay = server.matchDays.first(where: { $0.id == localMatchDay.id }) {
                if localMatchDay.lastModified > serverMatchDay.lastModified {
                    localChanges += 1
                }
            } else {
                localChanges += 1
            }
        }
        
        // Count server teams that are newer or don't exist locally
        for serverTeam in server.teams {
            if let localTeam = local.teams.first(where: { $0.id == serverTeam.id }) {
                if serverTeam.lastModified > localTeam.lastModified {
                    serverChanges += 1
                }
            } else {
                serverChanges += 1
            }
        }
        
        // Count server match days that are newer or don't exist locally
        for serverMatchDay in server.matchDays {
            if let localMatchDay = local.matchDays.first(where: { $0.id == serverMatchDay.id }) {
                if serverMatchDay.lastModified > localMatchDay.lastModified {
                    serverChanges += 1
                }
            } else {
                serverChanges += 1
            }
        }
        
        return (localChanges, serverChanges)
    }
    
    private func saveData() {
        saveTeams()
        saveMatchDays()
    }
    
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
            var updatedMatchDay = matchDay
            updatedMatchDay.lastModified = Date()
            matchDays[index] = updatedMatchDay
            saveMatchDays()
        }
    }
    
    func addMatchToMatchDay(_ match: Match, to matchDayId: UUID) {
        if let index = matchDays.firstIndex(where: { $0.id == matchDayId }) {
            matchDays[index].matches.append(match)
            matchDays[index].lastModified = Date()
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
    
    // MARK: - Match-specific player management
    
    func togglePlayerPresenceForMatch(_ playerId: UUID, in matchId: UUID, for team: TeamSide) {
        // Find and update the match directly without triggering immediate @Published updates
        for matchDayIndex in matchDays.indices {
            for matchIndex in matchDays[matchDayIndex].matches.indices {
                if matchDays[matchDayIndex].matches[matchIndex].id == matchId {
                    switch team {
                    case .home:
                        if matchDays[matchDayIndex].matches[matchIndex].homeTeamPresentPlayers.contains(playerId) {
                            matchDays[matchDayIndex].matches[matchIndex].homeTeamPresentPlayers.remove(playerId)
                        } else {
                            matchDays[matchDayIndex].matches[matchIndex].homeTeamPresentPlayers.insert(playerId)
                        }
                    case .away:
                        if matchDays[matchDayIndex].matches[matchIndex].awayTeamPresentPlayers.contains(playerId) {
                            matchDays[matchDayIndex].matches[matchIndex].awayTeamPresentPlayers.remove(playerId)
                        } else {
                            matchDays[matchDayIndex].matches[matchIndex].awayTeamPresentPlayers.insert(playerId)
                        }
                    }
                    
                    // Update the present count
                    matchDays[matchDayIndex].matches[matchIndex].homeTeamPresent = matchDays[matchDayIndex].matches[matchIndex].homeTeamPresentPlayers.count
                    matchDays[matchDayIndex].matches[matchIndex].awayTeamPresent = matchDays[matchDayIndex].matches[matchIndex].awayTeamPresentPlayers.count
                    
                    // Save to UserDefaults but don't trigger @Published update immediately
                    saveMatchDays()
                    
                    // Trigger a minimal UI update after a short delay to refresh display without navigation issues
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.objectWillChange.send()
                    }
                    return
                }
            }
        }
    }
    
    func updateMatchScore(_ matchId: UUID, homeScore: Int, awayScore: Int) {
        for matchDayIndex in matchDays.indices {
            for matchIndex in matchDays[matchDayIndex].matches.indices {
                if matchDays[matchDayIndex].matches[matchIndex].id == matchId {
                    matchDays[matchDayIndex].matches[matchIndex].homeTeamScore = homeScore
                    matchDays[matchDayIndex].matches[matchIndex].awayTeamScore = awayScore
                    
                    // Auto-update status to completed when score is entered
                    if matchDays[matchDayIndex].matches[matchIndex].status == .inProgress {
                        matchDays[matchDayIndex].matches[matchIndex].status = .completed
                    }
                    
                    matchDays[matchDayIndex].lastModified = Date()
                    saveMatchDays()
                    return
                }
            }
        }
    }
    
    func updateMatchStatus(_ matchId: UUID, status: Match.MatchStatus) {
        for matchDayIndex in matchDays.indices {
            for matchIndex in matchDays[matchDayIndex].matches.indices {
                if matchDays[matchDayIndex].matches[matchIndex].id == matchId {
                    matchDays[matchDayIndex].matches[matchIndex].status = status
                    matchDays[matchDayIndex].lastModified = Date()
                    saveMatchDays()
                    return
                }
            }
        }
    }
    
    func updateMatchPresence(matchId: UUID, homePresent: Set<UUID>, awayPresent: Set<UUID>) {
        for matchDayIndex in matchDays.indices {
            for matchIndex in matchDays[matchDayIndex].matches.indices {
                if matchDays[matchDayIndex].matches[matchIndex].id == matchId {
                    matchDays[matchDayIndex].matches[matchIndex].homeTeamPresentPlayers = homePresent
                    matchDays[matchDayIndex].matches[matchIndex].awayTeamPresentPlayers = awayPresent
                    matchDays[matchDayIndex].matches[matchIndex].homeTeamPresent = homePresent.count
                    matchDays[matchDayIndex].matches[matchIndex].awayTeamPresent = awayPresent.count
                    matchDays[matchDayIndex].lastModified = Date()
                    saveMatchDays()
                    return
                }
            }
        }
    }
    
    enum TeamSide {
        case home, away
    }
    
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
            let nextSunday = getNextSunday()
            var sampleMatchDay = MatchDay(date: nextSunday, name: "Week 1 - League Games")
            
            if teams.count >= 2 {
                let match1 = Match(
                    homeTeamId: teams[0].id,
                    awayTeamId: teams[1].id,
                    scheduledTime: nextSunday.addingTimeInterval(2 * 3600),
                    field: "Field A"
                )
                sampleMatchDay.matches.append(match1)
                
                if teams.count >= 3 {
                    let match2 = Match(
                        homeTeamId: teams[2].id,
                        awayTeamId: teams[0].id,
                        scheduledTime: nextSunday.addingTimeInterval(4 * 3600),
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

// MARK: - Main Views

struct ContentView: View {
    @StateObject private var dataManager = LeagueDataManager()
    @State private var selectedTab = 0
    @State private var isLoading = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TeamsRepositoryView(dataManager: dataManager)
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Teams")
                }
                .tag(0)
            
            MatchDaysView(dataManager: dataManager)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Match Days")
                }
                .tag(1)
            
            if let currentMatchDay = dataManager.currentMatchDay {
                CurrentMatchDayView(matchDay: currentMatchDay, dataManager: dataManager)
                    .tabItem {
                        Image(systemName: "sportscourt")
                        Text("Today's Games")
                    }
                    .tag(2)
            }
            
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

struct TeamDetailView: View {
    @ObservedObject var team: Team
    @ObservedObject var dataManager: LeagueDataManager
    @State private var showingAddPlayer = false
    
    var body: some View {
        List {
            Section("Team Info") {
                HStack {
                    Circle()
                        .fill(team.color)
                        .frame(width: 30, height: 30)
                    
                    VStack(alignment: .leading) {
                        Text(team.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(team.totalPlayersCount) players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            Section("Players") {
                ForEach(team.players.indices, id: \.self) { index in
                    PlayerRowView(
                        player: $team.players[index],
                        onEdit: { name, jerseyNumber, photoData in
                            team.updatePlayer(at: index, name: name, jerseyNumber: jerseyNumber, photoData: photoData)
                            dataManager.updateTeam(team)
                        }
                    )
                }
                .onDelete(perform: deletePlayer)
            }
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddPlayer = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView { name, jerseyNumber, photoData in
                let newPlayer = Player(name: name, jerseyNumber: jerseyNumber, photoData: photoData)
                team.addPlayer(newPlayer)
                dataManager.updateTeam(team)
            }
        }
    }
    
    private func deletePlayer(at offsets: IndexSet) {
        for index in offsets {
            team.removePlayer(at: index)
        }
        dataManager.updateTeam(team)
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
                    .onDelete { offsets in
                        deleteUpcomingMatchDays(at: offsets)
                    }
                }
                
                Section("Past Match Days") {
                    ForEach(dataManager.getPastMatchDays()) { matchDay in
                        NavigationLink(destination: MatchDayDetailView(matchDay: matchDay, dataManager: dataManager)) {
                            MatchDayRowView(matchDay: matchDay, dataManager: dataManager)
                        }
                    }
                    .onDelete { offsets in
                        deletePastMatchDays(at: offsets)
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
    
    private func deleteUpcomingMatchDays(at offsets: IndexSet) {
        let upcomingMatchDays = dataManager.getUpcomingMatchDays()
        for index in offsets {
            let matchDayToDelete = upcomingMatchDays[index]
            if let globalIndex = dataManager.matchDays.firstIndex(where: { $0.id == matchDayToDelete.id }) {
                dataManager.removeMatchDay(at: globalIndex)
            }
        }
    }
    
    private func deletePastMatchDays(at offsets: IndexSet) {
        let pastMatchDays = dataManager.getPastMatchDays()
        for index in offsets {
            let matchDayToDelete = pastMatchDays[index]
            if let globalIndex = dataManager.matchDays.firstIndex(where: { $0.id == matchDayToDelete.id }) {
                dataManager.removeMatchDay(at: globalIndex)
            }
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
            
            if abs(matchDay.date.timeIntervalSinceNow) < 86400 {
                Text("TODAY")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

struct MatchDayDetailView: View {
    let matchDay: MatchDay
    @ObservedObject var dataManager: LeagueDataManager
    @State private var showingAddMatch = false
    
    var body: some View {
        List {
            Section("Match Day Info") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(matchDay.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(matchDay.date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !matchDay.notes.isEmpty {
                        Text(matchDay.notes)
                            .font(.body)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("Scheduled Matches") {
                ForEach(matchDay.matches) { match in
                    NavigationLink(destination: StableMatchCheckInView(matchId: match.id, dataManager: dataManager)) {
                        MatchRowView(match: match, dataManager: dataManager)
                    }
                }
                .onDelete(perform: deleteMatches)
            }
        }
        .navigationTitle("Match Day")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddMatch = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddMatch) {
            AddMatchView(matchDay: matchDay, dataManager: dataManager)
        }
    }
    
    private func deleteMatches(at offsets: IndexSet) {
        var updatedMatchDay = matchDay
        for index in offsets.sorted(by: >) {
            updatedMatchDay.matches.remove(at: index)
        }
        dataManager.updateMatchDay(updatedMatchDay)
    }
}

struct MatchRowView: View {
    let match: Match
    @ObservedObject var dataManager: LeagueDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                let homeTeam = dataManager.getTeam(by: match.homeTeamId)
                let awayTeam = dataManager.getTeam(by: match.awayTeamId)
                
                HStack {
                    Circle()
                        .fill(homeTeam?.color ?? .gray)
                        .frame(width: 15, height: 15)
                    Text(homeTeam?.name ?? "Unknown Team")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(homeTeam == nil ? .secondary : .primary)
                }
                
                Text("vs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(awayTeam?.color ?? .gray)
                        .frame(width: 15, height: 15)
                    Text(awayTeam?.name ?? "Unknown Team")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(awayTeam == nil ? .secondary : .primary)
                }
                
                Spacer()
            }
            
            HStack {
                Text(match.scheduledTime, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(match.field)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Show score if available
                if match.hasScore {
                    Text(match.scoreDisplay)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text(match.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor(for: match.status))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            // Show present players count for each team
            if match.homeTeamPresentPlayers.count > 0 || match.awayTeamPresentPlayers.count > 0 {
                HStack {
                    Text("Present players:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Home: \(match.homeTeamPresentPlayers.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Away: \(match.awayTeamPresentPlayers.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(for status: Match.MatchStatus) -> Color {
        switch status {
        case .scheduled: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

struct CurrentMatchDayView: View {
    let matchDay: MatchDay
    @ObservedObject var dataManager: LeagueDataManager
    
    var body: some View {
        NavigationView {
            List {
                ForEach(matchDay.matches) { match in
                    NavigationLink(destination: MatchCheckInView(match: match, dataManager: dataManager)) {
                        MatchRowView(match: match, dataManager: dataManager)
                    }
                }
            }
            .navigationTitle("Today's Games")
        }
    }
}

struct StableMatchCheckInView: View {
    let matchId: UUID
    @ObservedObject var dataManager: LeagueDataManager
    
    private var match: Match? {
        // Always look up the match fresh from the data manager
        for matchDay in dataManager.matchDays {
            if let foundMatch = matchDay.matches.first(where: { $0.id == matchId }) {
                return foundMatch
            }
        }
        return nil
    }
    
    var body: some View {
        Group {
            if let match = match {
                MatchCheckInView(match: match, dataManager: dataManager)
            } else {
                VStack {
                    Text("Match not found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("The match may have been deleted or modified.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .navigationTitle("Match Check-In")
            }
        }
    }
}

struct MatchCheckInView: View {
    let match: Match
    @ObservedObject var dataManager: LeagueDataManager
    @State private var showingScoreEntry = false
    @State private var homeScore = ""
    @State private var awayScore = ""
    @State private var selectedTeam = 0 // 0 = home, 1 = away
    
    // Local state for player presence - doesn't trigger navigation issues
    @State private var localHomeTeamPresentPlayers: Set<UUID> = []
    @State private var localAwayTeamPresentPlayers: Set<UUID> = []
    @State private var hasInitializedLocalState = false
    
    var homeTeam: Team? {
        dataManager.getTeam(by: match.homeTeamId)
    }
    
    var awayTeam: Team? {
        dataManager.getTeam(by: match.awayTeamId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let homeTeam = homeTeam, let awayTeam = awayTeam {
                // Match header with scores
                VStack(spacing: 16) {
                    HStack(spacing: 40) {
                        VStack {
                            Circle()
                                .fill(homeTeam.color)
                                .frame(width: 30, height: 30)
                            
                            Text(homeTeam.name)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text("\(localHomeTeamPresentPlayers.count)/\(homeTeam.totalPlayersCount)")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Present for Match")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            if match.hasScore {
                                Text(match.scoreDisplay)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            } else {
                                Text("VS")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(match.status.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(statusColor(for: match.status))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        
                        VStack {
                            Circle()
                                .fill(awayTeam.color)
                                .frame(width: 30, height: 30)
                            
                            Text(awayTeam.name)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text("\(localAwayTeamPresentPlayers.count)/\(awayTeam.totalPlayersCount)")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Present for Match")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 20) {
                        Button("Start Match") {
                            saveLocalStateToDataManager()
                            dataManager.updateMatchStatus(match.id, status: .inProgress)
                        }
                        .buttonStyle(.bordered)
                        .disabled(match.status != .scheduled)
                        
                        Button("Enter Score") {
                            saveLocalStateToDataManager()
                            homeScore = String(match.homeTeamScore ?? 0)
                            awayScore = String(match.awayTeamScore ?? 0)
                            showingScoreEntry = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(match.status == .scheduled)
                        
                        Button("Complete") {
                            saveLocalStateToDataManager()
                            dataManager.updateMatchStatus(match.id, status: .completed)
                        }
                        .buttonStyle(.bordered)
                        .disabled(match.status != .inProgress)
                    }
                }
                .padding()
                
                // Team selector
                Picker("Select Team", selection: $selectedTeam) {
                    Text(homeTeam.name).tag(0)
                    Text(awayTeam.name).tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Team roster with local state
                if selectedTeam == 0 {
                    LocalMatchTeamCheckInView(
                        team: homeTeam,
                        presentPlayers: $localHomeTeamPresentPlayers
                    )
                } else {
                    LocalMatchTeamCheckInView(
                        team: awayTeam,
                        presentPlayers: $localAwayTeamPresentPlayers
                    )
                }
            }
        }
        .navigationTitle("Match Check-In")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initializeLocalState()
        }
        .onDisappear {
            saveLocalStateToDataManager()
        }
        .sheet(isPresented: $showingScoreEntry) {
            ScoreEntryView(
                homeTeamName: homeTeam?.name ?? "Home",
                awayTeamName: awayTeam?.name ?? "Away",
                homeScore: $homeScore,
                awayScore: $awayScore,
                onSave: { home, away in
                    dataManager.updateMatchScore(match.id, homeScore: home, awayScore: away)
                }
            )
        }
    }
    
    private func initializeLocalState() {
        if !hasInitializedLocalState {
            localHomeTeamPresentPlayers = match.homeTeamPresentPlayers
            localAwayTeamPresentPlayers = match.awayTeamPresentPlayers
            hasInitializedLocalState = true
        }
    }
    
    private func saveLocalStateToDataManager() {
        dataManager.updateMatchPresence(
            matchId: match.id,
            homePresent: localHomeTeamPresentPlayers,
            awayPresent: localAwayTeamPresentPlayers
        )
    }
    
    private func statusColor(for status: Match.MatchStatus) -> Color {
        switch status {
        case .scheduled: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

struct LocalMatchTeamCheckInView: View {
    @ObservedObject var team: Team
    @Binding var presentPlayers: Set<UUID>
    
    var body: some View {
        List {
            Section("Check in players for this match") {
                ForEach(team.players.indices, id: \.self) { index in
                    LocalMatchPlayerCheckInRowView(
                        player: team.players[index],
                        isPresent: presentPlayers.contains(team.players[index].id),
                        onTogglePresence: {
                            if presentPlayers.contains(team.players[index].id) {
                                presentPlayers.remove(team.players[index].id)
                            } else {
                                presentPlayers.insert(team.players[index].id)
                            }
                        }
                    )
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct LocalMatchPlayerCheckInRowView: View {
    let player: Player
    let isPresent: Bool
    let onTogglePresence: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: isPresent ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isPresent ? .green : .gray)
            
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
            
            Text("#\(player.jerseyNumber)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(minWidth: 40, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(isPresent ? "Present for match" : "Not checked in")
                    .font(.caption)
                    .foregroundColor(isPresent ? .green : .secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onTogglePresence()
        }
    }
}

struct MatchTeamCheckInView: View {
    @ObservedObject var team: Team
    @ObservedObject var dataManager: LeagueDataManager
    let matchId: UUID
    let teamSide: LeagueDataManager.TeamSide
    
    private var currentMatch: Match? {
        for matchDay in dataManager.matchDays {
            if let match = matchDay.matches.first(where: { $0.id == matchId }) {
                return match
            }
        }
        return nil
    }
    
    var body: some View {
        List {
            Section("Check in players for this match") {
                ForEach(team.players.indices, id: \.self) { index in
                    MatchPlayerCheckInRowView(
                        player: team.players[index],
                        isPresent: isPlayerPresentForMatch(team.players[index].id),
                        onTogglePresence: {
                            print("Toggling presence for player: \(team.players[index].name)")
                            dataManager.togglePlayerPresenceForMatch(
                                team.players[index].id,
                                in: matchId,
                                for: teamSide
                            )
                        }
                    )
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func isPlayerPresentForMatch(_ playerId: UUID) -> Bool {
        guard let match = currentMatch else { return false }
        switch teamSide {
        case .home:
            return match.homeTeamPresentPlayers.contains(playerId)
        case .away:
            return match.awayTeamPresentPlayers.contains(playerId)
        }
    }
}

struct TeamCheckInView: View {
    @ObservedObject var team: Team
    @ObservedObject var dataManager: LeagueDataManager
    
    var body: some View {
        List {
            ForEach(team.players.indices, id: \.self) { index in
                PlayerCheckInRowView(
                    player: $team.players[index],
                    onTogglePresence: {
                        team.togglePlayerPresence(for: team.players[index].id)
                        dataManager.updateTeam(team)
                    }
                )
            }
        }
    }
}

struct MatchPlayerCheckInRowView: View {
    let player: Player
    let isPresent: Bool
    let onTogglePresence: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: isPresent ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isPresent ? .green : .gray)
            
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
            
            Text("#\(player.jerseyNumber)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(minWidth: 40, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(isPresent ? "Present for match" : "Not checked in")
                    .font(.caption)
                    .foregroundColor(isPresent ? .green : .secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            print("Row tapped for player: \(player.name)")
            onTogglePresence()
        }
    }
}

struct PlayerCheckInRowView: View {
    @Binding var player: Player
    let onTogglePresence: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            Button {
                onTogglePresence()
            } label: {
                Image(systemName: player.isPresent ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(player.isPresent ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
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
            
            Text("#\(player.jerseyNumber)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(minWidth: 40, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(player.isPresent ? "Present" : "Not checked in")
                    .font(.caption)
                    .foregroundColor(player.isPresent ? .green : .secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTogglePresence()
        }
    }
}

// MARK: - Additional Views

struct PlayerRowView: View {
    @Binding var player: Player
    let onEdit: (String, Int, Data?) -> Void
    
    @State private var showingEditPlayer = false
    
    var body: some View {
        HStack(spacing: 15) {
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
            Text(player.name)
                .font(.body)
                .fontWeight(.medium)
            
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

struct AddMatchDayView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataManager: LeagueDataManager
    @State private var matchDayName = ""
    @State private var selectedDate = Date()
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Match Day")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Match Day Name")
                        .font(.headline)
                    TextField("e.g., Week 5 - League Games", text: $matchDayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date")
                        .font(.headline)
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(WheelDatePickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (Optional)")
                        .font(.headline)
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Button("Create Match Day") {
                    if !matchDayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        var newMatchDay = MatchDay(date: selectedDate, name: matchDayName)
                        newMatchDay.notes = notes
                        dataManager.addMatchDay(newMatchDay)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(matchDayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
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

struct AddMatchView: View {
    @Environment(\.dismiss) private var dismiss
    let matchDay: MatchDay
    @ObservedObject var dataManager: LeagueDataManager
    
    @State private var selectedHomeTeam: Team?
    @State private var selectedAwayTeam: Team?
    @State private var selectedTime = Date()
    @State private var selectedHour = 14
    @State private var selectedMinute = 0
    @State private var fieldName = ""
    
    let allowedMinutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Match")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Home Team")
                        .font(.headline)
                    
                    Picker("Home Team", selection: $selectedHomeTeam) {
                        Text("Select Team").tag(nil as Team?)
                        ForEach(dataManager.teams) { team in
                            Text(team.name).tag(team as Team?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Away Team")
                        .font(.headline)
                    
                    Picker("Away Team", selection: $selectedAwayTeam) {
                        Text("Select Team").tag(nil as Team?)
                        ForEach(dataManager.teams) { team in
                            if team.id != selectedHomeTeam?.id {
                                Text(team.name).tag(team as Team?)
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game Time")
                        .font(.headline)
                    
                    HStack {
                        Picker("Hour", selection: $selectedHour) {
                            ForEach(8...22, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 80)
                        
                        Text(":")
                            .font(.title2)
                        
                        Picker("Minute", selection: $selectedMinute) {
                            ForEach(allowedMinutes, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 80)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Field")
                        .font(.headline)
                    TextField("e.g., Field A, Main Field", text: $fieldName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Button("Add Match") {
                    if let homeTeam = selectedHomeTeam,
                       let awayTeam = selectedAwayTeam,
                       !fieldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        
                        let calendar = Calendar.current
                        let gameDateTime = calendar.date(
                            bySettingHour: selectedHour,
                            minute: selectedMinute,
                            second: 0,
                            of: matchDay.date
                        ) ?? matchDay.date
                        
                        let newMatch = Match(
                            homeTeamId: homeTeam.id,
                            awayTeamId: awayTeam.id,
                            scheduledTime: gameDateTime,
                            field: fieldName
                        )
                        
                        dataManager.addMatchToMatchDay(newMatch, to: matchDay.id)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedHomeTeam == nil || selectedAwayTeam == nil ||
                         fieldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
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

struct SettingsView: View {
    @ObservedObject var dataManager: LeagueDataManager
    @Binding var isLoading: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section("Data Management") {
                    Button("Smart Sync with Server") {
                        smartSync()
                    }
                    .disabled(isLoading)
                    
                    if !dataManager.syncStatus.isEmpty {
                        HStack {
                            Image(systemName: dataManager.syncStatus.contains("complete") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(dataManager.syncStatus.contains("complete") ? .green : .orange)
                            Text(dataManager.syncStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let lastSync = dataManager.lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
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
    
    private func smartSync() {
        isLoading = true
        Task {
            await dataManager.smartSync()
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func exportData() {
        print("Export data functionality")
    }
    
    private func importData() {
        print("Import data functionality")
    }
}

struct ScoreEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let homeTeamName: String
    let awayTeamName: String
    @Binding var homeScore: String
    @Binding var awayScore: String
    let onSave: (Int, Int) -> Void
    
    @State private var homeScoreInt: Int = 0
    @State private var awayScoreInt: Int = 0
    
    let scoreOptions = Array(0...20) // 0 to 20 goals should be enough for soccer
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Enter Match Score")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                HStack(spacing: 40) {
                    VStack {
                        Text(homeTeamName)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Picker("Home Score", selection: $homeScoreInt) {
                            ForEach(scoreOptions, id: \.self) { score in
                                Text("\(score)")
                                    .font(.largeTitle)
                                    .tag(score)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 80, height: 120)
                        .clipped()
                    }
                    
                    Text("-")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    VStack {
                        Text(awayTeamName)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Picker("Away Score", selection: $awayScoreInt) {
                            ForEach(scoreOptions, id: \.self) { score in
                                Text("\(score)")
                                    .font(.largeTitle)
                                    .tag(score)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 80, height: 120)
                        .clipped()
                    }
                }
                
                Button("Save Score") {
                    onSave(homeScoreInt, awayScoreInt)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
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
            .onAppear {
                homeScoreInt = Int(homeScore) ?? 0
                awayScoreInt = Int(awayScore) ?? 0
            }
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