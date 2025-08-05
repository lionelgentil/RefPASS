//
//  Soccer Referee App - Complete Professional League Management Version
//  Complete league management with match scheduling, team repository, and server sync
//

import SwiftUI
import PhotosUI
import Foundation

// MARK: - Data Models

struct League: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var lastModified: Date = Date()
    
    init(name: String, id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.lastModified = Date()
    }
}

extension League: Equatable {
    static func == (lhs: League, rhs: League) -> Bool {
        lhs.id == rhs.id
    }
}

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
    var leagueId: UUID?
    var lastModified: Date = Date()
    
    init(name: String, color: Color, leagueId: UUID? = nil) {
        self.name = name
        self.color = color
        self.players = []
        self.colorData = Self.colorToData(color)
        self.leagueId = leagueId
    }
    
    enum CodingKeys: CodingKey {
        case id, name, players, colorData, leagueId, lastModified
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let players = try container.decode([Player].self, forKey: .players)
        let colorData = try container.decode(Data.self, forKey: .colorData)
        let leagueId = try container.decodeIfPresent(UUID.self, forKey: .leagueId)
        let lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        
        self.name = name
        self.players = players
        self.colorData = colorData
        self.color = Self.dataToColor(colorData)
        self.leagueId = leagueId
        self.lastModified = lastModified
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(players, forKey: .players)
        try container.encode(colorData, forKey: .colorData)
        try container.encodeIfPresent(leagueId, forKey: .leagueId)
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
    @Published var leagues: [League] = []
    @Published var teams: [Team] = []
    @Published var matchDays: [MatchDay] = []
    @Published var currentMatchDay: MatchDay?
    @Published var syncStatus: String = ""
    @Published var lastSyncDate: Date?
    
    private let serverURL = "http://localhost:3001/api"  // Updated to match running server
    private let teamsKey = "SavedTeams"
    private let matchDaysKey = "SavedMatchDays"
    private let leaguesKey = "SavedLeagues"
    private var refreshTimer: Timer?
    
    init() {
        // Initialize default leagues
        initializeDefaultLeagues()
        
        // Load data from server on app start
        Task {
            await loadDataFromServer()
        }
        
        // Start periodic refresh for real-time sync
        startPeriodicRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    private func initializeDefaultLeagues() {
        // Initialize with default leagues if none exist
        if leagues.isEmpty {
            // Create leagues with specific IDs that match the team data
            let over30League = League(
                name: "Over 30",
                id: UUID(uuidString: "78E07FBD-352D-46A0-87F7-F3F119E08FC6")!
            )
            
            let over40League = League(
                name: "Over 40",
                id: UUID(uuidString: "364C47E0-D393-4945-9A26-E16E3B18E4A0")!
            )
            
            leagues = [over30League, over40League]
            
            print("🏆 Initialized leagues with matching IDs:")
            for league in leagues {
                print("  - \(league.name): \(league.id)")
            }
        }
    }
    
    private func loadDataFromServer() async {
        await MainActor.run {
            self.syncStatus = "Loading data from server..."
        }
        
        // Load teams from server FIRST - this is critical for match display
        if let serverTeams = await fetchTeamsFromServer() {
            await MainActor.run {
                self.teams = serverTeams
                print("📥 Loaded \(serverTeams.count) teams from server")
                for team in serverTeams {
                    print("  - Team: \(team.name) (ID: \(team.id))")
                }
            }
        }
        
        // Load match days from server AFTER teams are loaded
        if let serverMatchDays = await fetchMatchDaysFromServer() {
            await MainActor.run {
                self.matchDays = serverMatchDays.sorted { $0.date < $1.date }
                print("📥 Loaded \(serverMatchDays.count) match days from server")
                
                // REFERENTIAL INTEGRITY: Enforce data consistency after loading
                // Temporarily disabled to prevent data loss during league ID changes
                // self.enforceReferentialIntegrity()
                print("🔗 Referential integrity check skipped during initialization")
                
                self.syncStatus = "Data loaded from server"
            }
        }
        
        // If no data on server, create sample data
        if teams.isEmpty && matchDays.isEmpty {
            await setupSampleDataOnServer()
        }
    }
    
    // Remove local storage methods - everything goes to server immediately
    private func saveTeams() {
        // No longer save locally - data is always on server
    }
    
    private func saveMatchDays() {
        // No longer save locally - data is always on server
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
            print("📤 Uploading \(teams.count) teams to server...")
            for team in teams {
                print("  - \(team.name): \(team.players.count) players, modified: \(team.lastModified)")
            }
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(teams)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (_, response) = try await URLSession.shared.data(for: request)
            let success = (response as? HTTPURLResponse)?.statusCode == 200
            print("📤 Upload result: \(success ? "SUCCESS" : "FAILED")")
            return success
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
        
        // Upload local data to server - this ensures server has our latest data
        let uploadSuccess = await uploadToSeparateEndpoints(SyncData(teams: teams, matchDays: matchDays))
        
        if uploadSuccess {
            DispatchQueue.main.async {
                self.lastSyncDate = Date()
                self.syncStatus = "Sync complete: Data uploaded to server"
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
    
    func downloadFromServer() async {
        await MainActor.run {
            self.syncStatus = "Downloading from server..."
        }
        
        // Download teams and replace local data completely
        if let downloadedTeams = await fetchTeamsFromServer() {
            await MainActor.run {
                // Remove duplicates by ID in case server has duplicates
                let uniqueTeams = Array(Dictionary(grouping: downloadedTeams, by: { $0.id }).compactMapValues { $0.first }.values)
                self.teams = uniqueTeams
                self.syncStatus = "Teams downloaded - \(uniqueTeams.count) teams received"
                
                // Force UI update by triggering objectWillChange
                self.objectWillChange.send()
            }
        } else {
            await MainActor.run {
                self.syncStatus = "Failed to download teams from server"
            }
            return
        }
        
        // Download match days and replace local data completely
        if let downloadedMatchDays = await fetchMatchDaysFromServer() {
            await MainActor.run {
                // Remove duplicates by ID in case server has duplicates
                let uniqueMatchDays = Array(Dictionary(grouping: downloadedMatchDays, by: { $0.id }).compactMapValues { $0.first }.values)
                self.matchDays = uniqueMatchDays.sorted { $0.date < $1.date }
                self.syncStatus = "Download complete - \(self.teams.count) teams, \(uniqueMatchDays.count) match days received"
                self.lastSyncDate = Date()
                
                // Force UI update by triggering objectWillChange
                self.objectWillChange.send()
            }
        } else {
            await MainActor.run {
                self.syncStatus = "Failed to download match days from server"
            }
            return
        }
        
        // Data is now stored on server only - no local save needed
    }
    
    // MARK: - League Management
    
    func addLeague(_ league: League) {
        leagues.append(league)
        // Note: Leagues are stored locally for now, could be extended to server storage
    }
    
    func removeLeague(at index: Int) {
        guard index < leagues.count else { return }
        let leagueToDelete = leagues[index]
        
        // Remove league assignment from all teams in this league
        for teamIndex in teams.indices {
            if teams[teamIndex].leagueId == leagueToDelete.id {
                teams[teamIndex].leagueId = nil
                teams[teamIndex].lastModified = Date()
            }
        }
        
        leagues.remove(at: index)
        
        // Update teams on server since we modified their league assignments
        Task {
            await uploadTeamsToServer(teams)
        }
    }
    
    func updateLeague(_ league: League) {
        if let index = leagues.firstIndex(where: { $0.id == league.id }) {
            leagues[index] = league
        }
    }
    
    func getLeague(by id: UUID) -> League? {
        return leagues.first { $0.id == id }
    }
    
    func getTeams(for leagueId: UUID) -> [Team] {
        return teams.filter { $0.leagueId == leagueId }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    func getTeamsWithoutLeague() -> [Team] {
        return teams.filter { $0.leagueId == nil }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Team Management
    
    func addTeam(_ team: Team) {
        teams.append(team)
        Task {
            await uploadTeamsToServer(teams)
        }
    }
    
    func removeTeam(at index: Int) {
        guard index < teams.count else { return }
        let teamToDelete = teams[index]
        
        // REFERENTIAL INTEGRITY: Handle cascade deletion
        let affectedMatches = findMatchesReferencingTeam(teamToDelete.id)
        if !affectedMatches.isEmpty {
            print("🔗 Team deletion cascade: Found \(affectedMatches.count) matches referencing team '\(teamToDelete.name)'")
            removeMatchesReferencingTeam(teamToDelete.id)
        }
        
        // Remove the team
        teams.remove(at: index)
        
        // Save both teams and matchdays atomically
        Task {
            async let teamsUpload = uploadTeamsToServer(teams)
            async let matchdaysUpload = uploadMatchDaysToServer(matchDays)
            
            let (teamsSuccess, matchdaysSuccess) = await (teamsUpload, matchdaysUpload)
            
            await MainActor.run {
                if teamsSuccess && matchdaysSuccess {
                    print("✅ Team deletion with cascade completed successfully")
                    self.syncStatus = "Team and related matches deleted"
                } else {
                    print("❌ Failed to complete team deletion cascade")
                    self.syncStatus = "Failed to delete team completely"
                }
            }
        }
    }
    
    func updateTeam(_ team: Team) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            // Update the team's lastModified timestamp
            team.lastModified = Date()
            teams[index] = team
            
            // Force UI update immediately
            objectWillChange.send()
            
            // Upload to server immediately and wait for completion
            Task {
                let success = await uploadTeamsToServer(teams)
                await MainActor.run {
                    if success {
                        print("✅ Team update uploaded successfully")
                        self.syncStatus = "Team updated on server"
                    } else {
                        print("❌ Failed to upload team update")
                        self.syncStatus = "Failed to update team on server"
                    }
                }
            }
        }
    }
    
    func addMatchDay(_ matchDay: MatchDay) {
        matchDays.append(matchDay)
        matchDays.sort { $0.date < $1.date }
        
        // Force UI update immediately
        objectWillChange.send()
        
        // Upload to server immediately and wait for completion
        Task {
            let success = await uploadMatchDaysToServer(matchDays)
            await MainActor.run {
                if success {
                    print("✅ Match day added and uploaded successfully")
                    self.syncStatus = "Match day saved to server"
                } else {
                    print("❌ Failed to upload match day")
                    self.syncStatus = "Failed to save match day to server"
                }
            }
        }
    }
    
    func removeMatchDay(at index: Int) {
        guard index < matchDays.count else { return }
        matchDays.remove(at: index)
        
        // Force UI update immediately
        objectWillChange.send()
        
        // Upload to server immediately
        Task {
            let success = await uploadMatchDaysToServer(matchDays)
            await MainActor.run {
                if success {
                    print("✅ Match day removed and uploaded successfully")
                    self.syncStatus = "Match day deleted from server"
                } else {
                    print("❌ Failed to upload match day deletion")
                    self.syncStatus = "Failed to delete match day from server"
                }
            }
        }
    }
    
    func updateMatchDay(_ matchDay: MatchDay) {
        if let index = matchDays.firstIndex(where: { $0.id == matchDay.id }) {
            var updatedMatchDay = matchDay
            updatedMatchDay.lastModified = Date()
            
            // REFERENTIAL INTEGRITY: Validate all matches in the updated matchday
            let validTeamIds = Set(teams.map { $0.id })
            let invalidMatches = updatedMatchDay.matches.filter { match in
                !validTeamIds.contains(match.homeTeamId) || !validTeamIds.contains(match.awayTeamId)
            }
            
            if !invalidMatches.isEmpty {
                print("❌ Cannot update matchday: Contains \(invalidMatches.count) matches with invalid team references")
                syncStatus = "Failed to update matchday: Invalid team references"
                return
            }
            
            matchDays[index] = updatedMatchDay
            
            // Force UI update immediately
            objectWillChange.send()
            
            // Upload to server immediately
            Task {
                let success = await uploadMatchDaysToServer(matchDays)
                await MainActor.run {
                    if success {
                        print("✅ Match day updated and uploaded successfully")
                        self.syncStatus = "Match day updated on server"
                    } else {
                        print("❌ Failed to upload match day update")
                        self.syncStatus = "Failed to update match day on server"
                    }
                }
            }
        }
    }
    
    func addMatchToMatchDay(_ match: Match, to matchDayId: UUID) {
        print("🎯 addMatchToMatchDay called:")
        print("   - Match ID: \(match.id)")
        print("   - Home Team ID: \(match.homeTeamId)")
        print("   - Away Team ID: \(match.awayTeamId)")
        print("   - Target MatchDay ID: \(matchDayId)")
        print("   - Available MatchDays: \(matchDays.count)")
        for (index, md) in matchDays.enumerated() {
            print("     [\(index)] \(md.name) (\(md.id)) - \(md.matches.count) matches")
        }
        
        // REFERENTIAL INTEGRITY: Validate team references before adding match
        guard validateTeamReferences(homeTeamId: match.homeTeamId, awayTeamId: match.awayTeamId) else {
            print("❌ Cannot add match: Invalid team references")
            syncStatus = "Failed to add match: Invalid team references"
            return
        }
        
        if let index = matchDays.firstIndex(where: { $0.id == matchDayId }) {
            print("✅ Found target matchday at index \(index): '\(matchDays[index].name)'")
            matchDays[index].matches.append(match)
            matchDays[index].lastModified = Date()
            
            print("📊 Match added - MatchDay now has \(matchDays[index].matches.count) matches")
            
            // Force UI update immediately
            objectWillChange.send()
            
            // Upload to server immediately
            Task {
                print("📤 Uploading matchdays to server...")
                let success = await uploadMatchDaysToServer(matchDays)
                await MainActor.run {
                    if success {
                        print("✅ Match added to match day and uploaded successfully")
                        self.syncStatus = "Match added and saved to server"
                    } else {
                        print("❌ Failed to upload match addition")
                        self.syncStatus = "Failed to save match to server"
                    }
                }
            }
        } else {
            print("❌ Could not find matchday with ID: \(matchDayId)")
            print("🔧 Attempting to recover by creating a new matchday...")
            
            // RECOVERY: Create a new matchday if the target doesn't exist
            // This handles the case where matchdays were cleaned up due to invalid data
            let newMatchDay = MatchDay(date: Date(), name: "Recovered Match Day")
            matchDays.append(newMatchDay)
            
            // Add the match to the new matchday
            if let newIndex = matchDays.firstIndex(where: { $0.id == newMatchDay.id }) {
                matchDays[newIndex].matches.append(match)
                matchDays[newIndex].lastModified = Date()
                
                print("✅ Created new matchday and added match: '\(newMatchDay.name)' (\(newMatchDay.id))")
                print("📊 New matchday has \(matchDays[newIndex].matches.count) matches")
                
                // Force UI update immediately
                objectWillChange.send()
                
                // Upload to server immediately
                Task {
                    print("📤 Uploading recovered matchdays to server...")
                    let success = await uploadMatchDaysToServer(matchDays)
                    await MainActor.run {
                        if success {
                            print("✅ Recovered matchday and match uploaded successfully")
                            self.syncStatus = "Match saved to new matchday"
                        } else {
                            print("❌ Failed to upload recovered matchday")
                            self.syncStatus = "Failed to save recovered match"
                        }
                    }
                }
            } else {
                print("❌ Failed to create recovery matchday")
                syncStatus = "Failed to recover: Could not create matchday"
            }
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
                    
                    // Update lastModified timestamp for the match day
                    matchDays[matchDayIndex].lastModified = Date()
                    
                    // Force UI update immediately
                    objectWillChange.send()
                    
                    // Save to server immediately
                    Task {
                        let success = await uploadMatchDaysToServer(matchDays)
                        await MainActor.run {
                            if success {
                                print("✅ Player presence updated and uploaded successfully")
                                self.syncStatus = "Player check-in saved to server"
                            } else {
                                print("❌ Failed to upload player presence update")
                                self.syncStatus = "Failed to save player check-in to server"
                            }
                        }
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
                    
                    // Force UI update immediately
                    objectWillChange.send()
                    
                    Task {
                        let success = await uploadMatchDaysToServer(matchDays)
                        await MainActor.run {
                            if success {
                                print("✅ Match score updated and uploaded successfully")
                                self.syncStatus = "Match score saved to server"
                            } else {
                                print("❌ Failed to upload match score update")
                                self.syncStatus = "Failed to save match score to server"
                            }
                        }
                    }
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
                    
                    // Force UI update immediately
                    objectWillChange.send()
                    
                    Task {
                        let success = await uploadMatchDaysToServer(matchDays)
                        await MainActor.run {
                            if success {
                                print("✅ Match status updated and uploaded successfully")
                                self.syncStatus = "Match status saved to server"
                            } else {
                                print("❌ Failed to upload match status update")
                                self.syncStatus = "Failed to save match status to server"
                            }
                        }
                    }
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
                    
                    // Force UI update immediately
                    objectWillChange.send()
                    
                    Task {
                        let success = await uploadMatchDaysToServer(matchDays)
                        await MainActor.run {
                            if success {
                                print("✅ Match presence updated and uploaded successfully")
                                self.syncStatus = "Match presence saved to server"
                            } else {
                                print("❌ Failed to upload match presence update")
                                self.syncStatus = "Failed to save match presence to server"
                            }
                        }
                    }
                    return
                }
            }
        }
    }
    
    enum TeamSide {
        case home, away
    }
    
    private func setupSampleDataOnServer() async {
        // Create sample teams
        let team1 = Team(name: "Lions FC", color: .blue)
        team1.addPlayer(Player(name: "John Smith", jerseyNumber: 1))
        team1.addPlayer(Player(name: "Mike Johnson", jerseyNumber: 2))
        
        let team2 = Team(name: "Eagles United", color: .red)
        team2.addPlayer(Player(name: "Alex Brown", jerseyNumber: 1))
        team2.addPlayer(Player(name: "Chris Davis", jerseyNumber: 2))
        
        let team3 = Team(name: "Tigers SC", color: .green)
        team3.addPlayer(Player(name: "Sam Wilson", jerseyNumber: 1))
        team3.addPlayer(Player(name: "Tom Miller", jerseyNumber: 2))
        
        let sampleTeams = [team1, team2, team3]
        
        // Upload teams to server
        if await uploadTeamsToServer(sampleTeams) {
            await MainActor.run {
                self.teams = sampleTeams
            }
        }
        
        // Create sample match day
        let nextSunday = getNextSunday()
        var sampleMatchDay = MatchDay(date: nextSunday, name: "Week 1 - League Games")
        
        let match1 = Match(
            homeTeamId: team1.id,
            awayTeamId: team2.id,
            scheduledTime: nextSunday.addingTimeInterval(2 * 3600),
            field: "Field A"
        )
        sampleMatchDay.matches.append(match1)
        
        let match2 = Match(
            homeTeamId: team3.id,
            awayTeamId: team1.id,
            scheduledTime: nextSunday.addingTimeInterval(4 * 3600),
            field: "Field B"
        )
        sampleMatchDay.matches.append(match2)
        
        let sampleMatchDays = [sampleMatchDay]
        
        // Upload match days to server
        if await uploadMatchDaysToServer(sampleMatchDays) {
            await MainActor.run {
                self.matchDays = sampleMatchDays
                self.syncStatus = "Sample data created on server"
            }
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
    
    // MARK: - Real-time Sync Methods
    
    private func startPeriodicRefresh() {
        // DISABLED: Periodic refresh is causing sync storms and breaking UI
        // The continuous sync is changing team IDs constantly, breaking Picker validation
        // TODO: Implement smarter sync that preserves UI state
        print("⏸️ Periodic refresh disabled to prevent sync storms")
        
        // Uncomment when sync stability is fixed:
        // refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
        //     Task {
        //         await self.refreshFromServer()
        //     }
        // }
    }
    
    func refreshFromServer() async {
        // Silently refresh data from server without showing sync status
        // IMPORTANT: Load teams FIRST, then matchdays to ensure team references are valid
        
        if let serverTeams = await fetchTeamsFromServer() {
            await MainActor.run {
                // Only update if data has actually changed to avoid unnecessary UI updates
                if !areTeamsEqual(self.teams, serverTeams) {
                    print("🔄 Server teams differ from local teams, updating...")
                    print("Local teams count: \(self.teams.count), Server teams count: \(serverTeams.count)")
                    for team in self.teams {
                        print("Local team: \(team.name) - \(team.players.count) players - modified: \(team.lastModified)")
                    }
                    for team in serverTeams {
                        print("Server team: \(team.name) - \(team.players.count) players - modified: \(team.lastModified)")
                    }
                    self.teams = serverTeams
                    self.objectWillChange.send()
                } else {
                    print("✅ Teams are equal, no update needed")
                }
            }
        }
        
        // Load matchdays AFTER teams are loaded and validated
        if let serverMatchDays = await fetchMatchDaysFromServer() {
            await MainActor.run {
                let sortedMatchDays = serverMatchDays.sorted { $0.date < $1.date }
                if !areMatchDaysEqual(self.matchDays, sortedMatchDays) {
                    print("🔄 Updating match days from server...")
                    
                    // Validate and fix team references before updating
                    let validatedMatchDays = self.validateAndFixTeamReferences(sortedMatchDays)
                    
                    self.matchDays = validatedMatchDays
                    
                    // REFERENTIAL INTEGRITY: Enforce consistency after server sync
                    // Temporarily disabled to prevent data loss
                    // self.enforceReferentialIntegrity()
                    print("🔗 Referential integrity check skipped during server sync")
                    
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    private func validateAndFixTeamReferences(_ matchDays: [MatchDay]) -> [MatchDay] {
        var fixedMatchDays = matchDays
        var hasInvalidReferences = false
        let validTeamIds = Set(self.teams.map { $0.id })
        
        for matchDayIndex in fixedMatchDays.indices {
            let originalMatchCount = fixedMatchDays[matchDayIndex].matches.count
            
            // Filter out matches with invalid team references
            fixedMatchDays[matchDayIndex].matches = fixedMatchDays[matchDayIndex].matches.filter { match in
                let homeTeamExists = validTeamIds.contains(match.homeTeamId)
                let awayTeamExists = validTeamIds.contains(match.awayTeamId)
                
                if !homeTeamExists || !awayTeamExists {
                    print("⚠️ WARNING: Match \(match.id) has invalid team references:")
                    if !homeTeamExists {
                        print("   Home team ID: \(match.homeTeamId) - NOT FOUND")
                    }
                    if !awayTeamExists {
                        print("   Away team ID: \(match.awayTeamId) - NOT FOUND")
                    }
                    print("🗑️ Removing match with invalid team references")
                    hasInvalidReferences = true
                    return false // Remove this match
                }
                return true // Keep this match
            }
            
            let newMatchCount = fixedMatchDays[matchDayIndex].matches.count
            if originalMatchCount != newMatchCount {
                print("📊 Matchday \(matchDayIndex + 1): Removed \(originalMatchCount - newMatchCount) invalid matches")
                fixedMatchDays[matchDayIndex].lastModified = Date()
            }
        }
        
        // Also remove any empty matchdays
        let originalMatchdayCount = fixedMatchDays.count
        fixedMatchDays = fixedMatchDays.filter { !$0.matches.isEmpty }
        let newMatchdayCount = fixedMatchDays.count
        
        if originalMatchdayCount != newMatchdayCount {
            print("📊 Removed \(originalMatchdayCount - newMatchdayCount) empty matchdays")
            hasInvalidReferences = true
        }
        
        // If we fixed any references, save the corrected data back to server
        if hasInvalidReferences {
            print("🔧 Fixed invalid team references, saving corrected data to server...")
            Task {
                await uploadMatchDaysToServer(fixedMatchDays)
            }
            print("✅ Cleanup complete - all invalid matches removed")
        }
        
        return fixedMatchDays
    }
    
    private func areTeamsEqual(_ teams1: [Team], _ teams2: [Team]) -> Bool {
        guard teams1.count == teams2.count else { return false }
        
        for team1 in teams1 {
            guard let team2 = teams2.first(where: { $0.id == team1.id }) else { return false }
            if team1.lastModified != team2.lastModified ||
               team1.name != team2.name ||
               team1.players.count != team2.players.count {
                return false
            }
            
            // Also check if player details have changed
            for (index, player1) in team1.players.enumerated() {
                if index < team2.players.count {
                    let player2 = team2.players[index]
                    if player1.name != player2.name ||
                       player1.jerseyNumber != player2.jerseyNumber ||
                       player1.id != player2.id {
                        return false
                    }
                } else {
                    return false
                }
            }
        }
        return true
    }
    
    private func areMatchDaysEqual(_ matchDays1: [MatchDay], _ matchDays2: [MatchDay]) -> Bool {
        guard matchDays1.count == matchDays2.count else { return false }
        
        for matchDay1 in matchDays1 {
            guard let matchDay2 = matchDays2.first(where: { $0.id == matchDay1.id }) else { return false }
            if matchDay1.lastModified != matchDay2.lastModified ||
               matchDay1.matches.count != matchDay2.matches.count {
                return false
            }
        }
        return true
    }
    
    // MARK: - Referential Integrity Methods
    
    /// Validates that both team IDs exist in the current teams list
    private func validateTeamReferences(homeTeamId: UUID, awayTeamId: UUID) -> Bool {
        let validTeamIds = Set(teams.map { $0.id })
        let homeTeamExists = validTeamIds.contains(homeTeamId)
        let awayTeamExists = validTeamIds.contains(awayTeamId)
        
        if !homeTeamExists {
            print("❌ Validation failed: Home team ID \(homeTeamId) not found")
            print("   Available teams: \(teams.map { "\($0.name) (\($0.id))" })")
        }
        
        if !awayTeamExists {
            print("❌ Validation failed: Away team ID \(awayTeamId) not found")
            print("   Available teams: \(teams.map { "\($0.name) (\($0.id))" })")
        }
        
        return homeTeamExists && awayTeamExists
    }
    
    /// Finds all matches that reference a specific team ID
    private func findMatchesReferencingTeam(_ teamId: UUID) -> [(matchDayIndex: Int, matchIndex: Int, match: Match)] {
        var referencingMatches: [(matchDayIndex: Int, matchIndex: Int, match: Match)] = []
        
        for (matchDayIndex, matchDay) in matchDays.enumerated() {
            for (matchIndex, match) in matchDay.matches.enumerated() {
                if match.homeTeamId == teamId || match.awayTeamId == teamId {
                    referencingMatches.append((matchDayIndex, matchIndex, match))
                }
            }
        }
        
        return referencingMatches
    }
    
    /// Removes all matches that reference a specific team ID (cascade delete)
    private func removeMatchesReferencingTeam(_ teamId: UUID) {
        let teamName = teams.first { $0.id == teamId }?.name ?? "Unknown Team"
        var totalMatchesRemoved = 0
        
        for matchDayIndex in matchDays.indices.reversed() {
            let originalCount = matchDays[matchDayIndex].matches.count
            
            // Remove matches referencing the deleted team
            matchDays[matchDayIndex].matches = matchDays[matchDayIndex].matches.filter { match in
                let shouldKeep = match.homeTeamId != teamId && match.awayTeamId != teamId
                if !shouldKeep {
                    print("🗑️ Cascade delete: Removing match referencing team '\(teamName)'")
                }
                return shouldKeep
            }
            
            let newCount = matchDays[matchDayIndex].matches.count
            let removedCount = originalCount - newCount
            totalMatchesRemoved += removedCount
            
            if removedCount > 0 {
                matchDays[matchDayIndex].lastModified = Date()
                print("📊 Removed \(removedCount) matches from matchday '\(matchDays[matchDayIndex].name)'")
            }
            
            // Remove empty matchdays
            if matchDays[matchDayIndex].matches.isEmpty {
                print("🗑️ Removing empty matchday '\(matchDays[matchDayIndex].name)'")
                matchDays.remove(at: matchDayIndex)
            }
        }
        
        print("✅ Cascade delete complete: Removed \(totalMatchesRemoved) matches referencing team '\(teamName)'")
    }
    
    /// Validates all existing matches have valid team references (used during data loading)
    private func validateAllMatchReferences() -> Bool {
        let validTeamIds = Set(teams.map { $0.id })
        var hasInvalidReferences = false
        
        for matchDay in matchDays {
            for match in matchDay.matches {
                if !validTeamIds.contains(match.homeTeamId) || !validTeamIds.contains(match.awayTeamId) {
                    hasInvalidReferences = true
                    print("⚠️ Found invalid team reference in match \(match.id)")
                }
            }
        }
        
        return !hasInvalidReferences
    }
    
    /// Performs atomic validation and cleanup of all data
    private func enforceReferentialIntegrity() {
        print("🔗 Enforcing referential integrity...")
        
        let validTeamIds = Set(teams.map { $0.id })
        var hasChanges = false
        
        // Clean up invalid matches
        for matchDayIndex in matchDays.indices.reversed() {
            let originalCount = matchDays[matchDayIndex].matches.count
            
            matchDays[matchDayIndex].matches = matchDays[matchDayIndex].matches.filter { match in
                let isValid = validTeamIds.contains(match.homeTeamId) && validTeamIds.contains(match.awayTeamId)
                if !isValid {
                    print("🔗 Integrity enforcement: Removing invalid match \(match.id)")
                }
                return isValid
            }
            
            if matchDays[matchDayIndex].matches.count != originalCount {
                matchDays[matchDayIndex].lastModified = Date()
                hasChanges = true
            }
            
            // Remove empty matchdays
            if matchDays[matchDayIndex].matches.isEmpty {
                print("🔗 Integrity enforcement: Removing empty matchday")
                matchDays.remove(at: matchDayIndex)
                hasChanges = true
            }
        }
        
        if hasChanges {
            print("✅ Referential integrity enforced - saving corrected data")
            Task {
                await uploadMatchDaysToServer(matchDays)
            }
        } else {
            print("✅ Referential integrity verified - no changes needed")
        }
    }
}

// MARK: - Main Views

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.blue.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Soccer ball icon
                Image(systemName: "soccerball")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 15) {
                    Text("Pleasanton Adult Sunday Soccer")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                    
                    Text("Team Check-in App for Referee")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .padding(.top, 20)
            }
            .padding(.horizontal, 40)
        }
    }
}

struct ContentView: View {
    @StateObject private var dataManager = LeagueDataManager()
    @State private var selectedTab = 1
    @State private var isLoading = false
    @State private var showSplashScreen = true
    
    var body: some View {
        if showSplashScreen {
            SplashScreenView()
                .onAppear {
                    // Hide splash screen after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showSplashScreen = false
                        }
                    }
                }
        } else {
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
}

struct TeamsRepositoryView: View {
    @ObservedObject var dataManager: LeagueDataManager
    @State private var showingAddTeam = false
    @State private var showingAddLeague = false
    @State private var showingEditLeague: League?
    
    var body: some View {
        NavigationView {
            List {
                // Show teams organized by leagues
                ForEach(dataManager.leagues) { league in
                    Section(header: LeagueHeaderView(league: league, onEdit: {
                        showingEditLeague = league
                    }, onDelete: {
                        if let index = dataManager.leagues.firstIndex(where: { $0.id == league.id }) {
                            dataManager.removeLeague(at: index)
                        }
                    })) {
                        let leagueTeams = dataManager.getTeams(for: league.id)
                        if leagueTeams.isEmpty {
                            Text("No teams in this league")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(leagueTeams) { team in
                                NavigationLink(destination: TeamDetailView(team: team, dataManager: dataManager)) {
                                    TeamRowView(team: team, league: dataManager.getLeague(by: team.leagueId ?? UUID()))
                                }
                            }
                            .onDelete { offsets in
                                deleteTeamsFromLeague(at: offsets, in: league.id)
                            }
                        }
                    }
                }
                
                // Show teams without a league
                let unassignedTeams = dataManager.getTeamsWithoutLeague()
                if !unassignedTeams.isEmpty {
                    Section("Unassigned Teams") {
                        ForEach(unassignedTeams) { team in
                            NavigationLink(destination: TeamDetailView(team: team, dataManager: dataManager)) {
                                TeamRowView(team: team, league: nil)
                            }
                        }
                        .onDelete { offsets in
                            deleteUnassignedTeams(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("Teams by League")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAddLeague = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
                
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
            AddTeamView(dataManager: dataManager) { name, color, league in
                let newTeam = Team(name: name, color: color, leagueId: league?.id)
                dataManager.addTeam(newTeam)
            }
        }
        .sheet(isPresented: $showingAddLeague) {
            AddLeagueView { name in
                let newLeague = League(name: name)
                dataManager.addLeague(newLeague)
            }
        }
        .sheet(item: $showingEditLeague) { league in
            EditLeagueView(league: league) { updatedLeague in
                dataManager.updateLeague(updatedLeague)
            }
        }
    }
    
    private func deleteTeamsFromLeague(at offsets: IndexSet, in leagueId: UUID) {
        let leagueTeams = dataManager.getTeams(for: leagueId)
        for index in offsets {
            let teamToDelete = leagueTeams[index]
            if let globalIndex = dataManager.teams.firstIndex(where: { $0.id == teamToDelete.id }) {
                dataManager.removeTeam(at: globalIndex)
            }
        }
    }
    
    private func deleteUnassignedTeams(at offsets: IndexSet) {
        let unassignedTeams = dataManager.getTeamsWithoutLeague()
        for index in offsets {
            let teamToDelete = unassignedTeams[index]
            if let globalIndex = dataManager.teams.firstIndex(where: { $0.id == teamToDelete.id }) {
                dataManager.removeTeam(at: globalIndex)
            }
        }
    }
}

struct LeagueHeaderView: View {
    let league: League
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(league.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

struct TeamRowView: View {
    @ObservedObject var team: Team
    let league: League?
    
    init(team: Team, league: League? = nil) {
        self.team = team
        self.league = league
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(team.color)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading) {
                Text(team.name)
                    .font(.headline)
                
                HStack {
                    Text("\(team.totalPlayersCount) players")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let league = league {
                        Text("• \(league.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
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
                ForEach(team.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.indices, id: \.self) { index in
                    let sortedPlayers = team.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    PlayerRowView(
                        player: Binding(
                            get: { sortedPlayers[index] },
                            set: { newValue in
                                if let originalIndex = team.players.firstIndex(where: { $0.id == sortedPlayers[index].id }) {
                                    team.players[originalIndex] = newValue
                                }
                            }
                        ),
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
                print("Adding player: \(name) with jersey \(jerseyNumber) to team: \(team.name)")
                team.addPlayer(newPlayer)
                print("Team now has \(team.players.count) players")
                dataManager.updateTeam(team)
                print("Team updated in data manager")
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
    
    private var homeTeam: Team? {
        dataManager.getTeam(by: match.homeTeamId)
    }
    
    private var awayTeam: Team? {
        dataManager.getTeam(by: match.awayTeamId)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack {
                    Circle()
                        .fill(homeTeam?.color ?? .red)
                        .frame(width: 15, height: 15)
                    Text(homeTeam?.name ?? "⚠️ Team Not Found")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(homeTeam == nil ? .red : .primary)
                }
                
                Text("vs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(awayTeam?.color ?? .red)
                        .frame(width: 15, height: 15)
                    Text(awayTeam?.name ?? "⚠️ Team Not Found")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(awayTeam == nil ? .red : .primary)
                }
                
                Spacer()
            }
            .onAppear {
                // Debug logging for missing teams
                if homeTeam == nil {
                    print("⚠️ Home team not found for match \(match.id): \(match.homeTeamId)")
                    print("Available teams: \(dataManager.teams.map { "\($0.name) (\($0.id))" })")
                }
                if awayTeam == nil {
                    print("⚠️ Away team not found for match \(match.id): \(match.awayTeamId)")
                    print("Available teams: \(dataManager.teams.map { "\($0.name) (\($0.id))" })")
                }
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
                ForEach(team.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.indices, id: \.self) { index in
                    let sortedPlayers = team.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    LocalMatchPlayerCheckInRowView(
                        player: sortedPlayers[index],
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
                ForEach(team.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.indices, id: \.self) { index in
                    let sortedPlayers = team.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    MatchPlayerCheckInRowView(
                        player: sortedPlayers[index],
                        isPresent: isPlayerPresentForMatch(sortedPlayers[index].id),
                        onTogglePresence: {
                            print("Toggling presence for player: \(sortedPlayers[index].name)")
                            dataManager.togglePlayerPresenceForMatch(
                                sortedPlayers[index].id,
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
            ForEach(team.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.indices, id: \.self) { index in
                let sortedPlayers = team.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                PlayerCheckInRowView(
                    player: Binding(
                        get: { sortedPlayers[index] },
                        set: { newValue in
                            if let originalIndex = team.players.firstIndex(where: { $0.id == sortedPlayers[index].id }) {
                                team.players[originalIndex] = newValue
                            }
                        }
                    ),
                    onTogglePresence: {
                        team.togglePlayerPresence(for: sortedPlayers[index].id)
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
    @State private var showingSuccessMessage = false
    
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
                        
                        // Show success message
                        withAnimation {
                            showingSuccessMessage = true
                        }
                        
                        // Clear the form for adding another player
                        playerName = ""
                        jerseyNumber = ""
                        photoData = nil
                        selectedPhoto = nil
                        
                        // Hide success message after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingSuccessMessage = false
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                         Int(jerseyNumber) == nil)
                
                // Success message
                if showingSuccessMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Player added successfully!")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .transition(.opacity)
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
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { newPhoto in
                Task {
                    if let data = try? await newPhoto?.loadTransferable(type: Data.self) {
                        // Compress image to reduce server payload size
                        photoData = compressImageData(data)
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
                        // Compress image to reduce server payload size
                        photoData = compressImageData(data)
                    }
                }
            }
        }
    }
}

struct AddTeamView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataManager: LeagueDataManager
    @State private var teamName = ""
    @State private var selectedColor = Color.blue
    @State private var selectedLeague: League?
    
    let onAddTeam: (String, Color, League?) -> Void
    
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("League")
                        .font(.headline)
                    
                    if dataManager.leagues.isEmpty {
                        Text("No leagues available")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Picker("Select League", selection: $selectedLeague) {
                            Text("No League").tag(nil as League?)
                            ForEach(dataManager.leagues) { league in
                                Text(league.name).tag(league as League?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                Button("Add Team") {
                    if !teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onAddTeam(teamName, selectedColor, selectedLeague)
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

struct AddLeagueView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var leagueName = ""
    
    let onAddLeague: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Add New League")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("League Name")
                        .font(.headline)
                    TextField("e.g., Over 50, Youth League", text: $leagueName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                }
                
                Button("Add League") {
                    if !leagueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onAddLeague(leagueName)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(leagueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
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

struct EditLeagueView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var leagueName: String
    
    let onSave: (League) -> Void
    private let league: League
    
    init(league: League, onSave: @escaping (League) -> Void) {
        self.league = league
        self._leagueName = State(initialValue: league.name)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Edit League")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("League Name")
                        .font(.headline)
                    TextField("League name", text: $leagueName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
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
                        if !leagueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let updatedLeague = League(name: leagueName, id: league.id)
                            onSave(updatedLeague)
                            dismiss()
                        }
                    }
                    .disabled(leagueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
    
    @State private var selectedHomeTeamId: UUID?
    @State private var selectedAwayTeamId: UUID?
    @State private var selectedTime = Date()
    @State private var selectedHour = 14
    @State private var selectedMinute = 0
    @State private var fieldName = ""
    @State private var hasValidatedInitialState = false
    
    let allowedMinutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
    
    // Computed property to get valid team IDs
    private var validTeamIds: Set<UUID> {
        Set(dataManager.teams.map { $0.id })
    }
    
    // Safe computed properties that only return valid selections
    private var safeSelectedHomeTeamId: UUID? {
        guard let id = selectedHomeTeamId, validTeamIds.contains(id) else { return nil }
        return id
    }
    
    private var safeSelectedAwayTeamId: UUID? {
        guard let id = selectedAwayTeamId, validTeamIds.contains(id) else { return nil }
        return id
    }
    
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
                    
                    Picker("Home Team", selection: Binding(
                        get: { safeSelectedHomeTeamId },
                        set: { selectedHomeTeamId = $0 }
                    )) {
                        Text("Select Team").tag(nil as UUID?)
                        ForEach(dataManager.teams.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { team in
                            Text(team.name).tag(team.id as UUID?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Away Team")
                        .font(.headline)
                    
                    Picker("Away Team", selection: Binding(
                        get: { safeSelectedAwayTeamId },
                        set: { selectedAwayTeamId = $0 }
                    )) {
                        Text("Select Team").tag(nil as UUID?)
                        ForEach(dataManager.teams.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { team in
                            if team.id != safeSelectedHomeTeamId {
                                Text(team.name).tag(team.id as UUID?)
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
                    print("🎯 Add Match button pressed")
                    print("   - Safe Home Team ID: \(safeSelectedHomeTeamId?.uuidString ?? "nil")")
                    print("   - Safe Away Team ID: \(safeSelectedAwayTeamId?.uuidString ?? "nil")")
                    print("   - Field Name: '\(fieldName)'")
                    print("   - Match Day ID: \(matchDay.id)")
                    
                    if let homeTeamId = safeSelectedHomeTeamId,
                       let awayTeamId = safeSelectedAwayTeamId,
                       !fieldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        
                        let calendar = Calendar.current
                        let gameDateTime = calendar.date(
                            bySettingHour: selectedHour,
                            minute: selectedMinute,
                            second: 0,
                            of: matchDay.date
                        ) ?? matchDay.date
                        
                        let newMatch = Match(
                            homeTeamId: homeTeamId,
                            awayTeamId: awayTeamId,
                            scheduledTime: gameDateTime,
                            field: fieldName
                        )
                        
                        print("✅ Creating match: \(newMatch.id)")
                        print("   - Home Team: \(homeTeamId)")
                        print("   - Away Team: \(awayTeamId)")
                        print("   - Field: \(fieldName)")
                        print("   - Time: \(gameDateTime)")
                        
                        dataManager.addMatchToMatchDay(newMatch, to: matchDay.id)
                        dismiss()
                    } else {
                        print("❌ Cannot create match - validation failed:")
                        print("   - Home team valid: \(safeSelectedHomeTeamId != nil)")
                        print("   - Away team valid: \(safeSelectedAwayTeamId != nil)")
                        print("   - Field name valid: \(!fieldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(safeSelectedHomeTeamId == nil || safeSelectedAwayTeamId == nil ||
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
            .onAppear {
                // Immediate validation on appear
                if !hasValidatedInitialState {
                    validateAndResetSelections()
                    hasValidatedInitialState = true
                }
                
                // Debug: Log current team state
                print("🎯 AddMatchView appeared - Available teams:")
                for team in dataManager.teams {
                    print("   - \(team.name): \(team.id)")
                }
                print("🎯 Current selections: Home=\(selectedHomeTeamId?.uuidString ?? "nil"), Away=\(selectedAwayTeamId?.uuidString ?? "nil")")
            }
            .onChange(of: dataManager.teams) { _ in
                // Validate selections when teams change
                validateAndResetSelections()
                
                // Debug: Log team changes
                print("🔄 Teams changed in AddMatchView - New teams:")
                for team in dataManager.teams {
                    print("   - \(team.name): \(team.id)")
                }
            }
        }
    }
    
    private func validateAndResetSelections() {
        // Reset selections if they reference invalid team IDs
        if let homeId = selectedHomeTeamId, !validTeamIds.contains(homeId) {
            print("🔧 Resetting invalid home team selection: \(homeId)")
            selectedHomeTeamId = nil
        }
        
        if let awayId = selectedAwayTeamId, !validTeamIds.contains(awayId) {
            print("🔧 Resetting invalid away team selection: \(awayId)")
            selectedAwayTeamId = nil
        }
    }
}

struct SettingsView: View {
    @ObservedObject var dataManager: LeagueDataManager
    @Binding var isLoading: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section("Real-time Sync") {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.green)
                        Text("Real-time sync active")
                        Spacer()
                        Text("Every 30s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: forceRefresh) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Force Refresh Now")
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
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
    
    private func forceRefresh() {
        isLoading = true
        Task {
            await dataManager.refreshFromServer()
            await MainActor.run {
                dataManager.syncStatus = "Force refresh completed"
                isLoading = false
            }
        }
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

// MARK: - Image Compression Helper

/// Compresses image data to reduce server payload size
private func compressImageData(_ data: Data) -> Data {
    guard let image = UIImage(data: data) else {
        print("⚠️ Failed to create UIImage from data")
        return data
    }
    
    let originalSize = data.count
    print("📸 Original image size: \(ByteCountFormatter.string(fromByteCount: Int64(originalSize), countStyle: .file))")
    
    // Resize image to reasonable dimensions for profile photos
    let maxDimension: CGFloat = 400
    let resizedImage = resizeImage(image, maxDimension: maxDimension)
    
    // Compress with JPEG at 0.7 quality (good balance of quality vs size)
    guard let compressedData = resizedImage.jpegData(compressionQuality: 0.7) else {
        print("⚠️ Failed to compress image, using original")
        return data
    }
    
    let compressedSize = compressedData.count
    let compressionRatio = Double(originalSize) / Double(compressedSize)
    
    print("📸 Compressed image size: \(ByteCountFormatter.string(fromByteCount: Int64(compressedSize), countStyle: .file))")
    print("📸 Compression ratio: \(String(format: "%.1f", compressionRatio))x smaller")
    
    return compressedData
}

/// Resizes an image to fit within the specified maximum dimension while maintaining aspect ratio
private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size
    
    // If image is already small enough, return original
    if size.width <= maxDimension && size.height <= maxDimension {
        return image
    }
    
    // Calculate new size maintaining aspect ratio
    let aspectRatio = size.width / size.height
    let newSize: CGSize
    
    if size.width > size.height {
        newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
    } else {
        newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
    }
    
    // Create resized image
    UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
    UIGraphicsEndImageContext()
    
    return resizedImage
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

