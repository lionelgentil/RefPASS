// Soccer Referee Web App - Main JavaScript File
class SoccerRefereeApp {
    constructor() {
        this.serverURL = window.location.origin + '/api';
        this.data = {
            leagues: [
                { id: '78E07FBD-352D-46A0-87F7-F3F119E08FC6', name: 'Over 30' },
                { id: '364C47E0-D393-4945-9A26-E16E3B18E4A0', name: 'Over 40' }
            ],
            teams: [],
            matchDays: []
        };
        this.currentView = 'matchdays';
        this.syncStatus = '';
        this.lastSyncDate = null;
        
        this.init();
    }

    async init() {
        // Show splash screen for 3 seconds
        setTimeout(() => {
            this.hideSplashScreen();
        }, 3000);

        // Initialize event listeners
        this.initEventListeners();
        
        // Load data from server
        await this.loadDataFromServer();
        
        // Start periodic sync
        this.startPeriodicSync();
        
        // Update UI
        this.updateUI();
    }

    hideSplashScreen() {
        const splashScreen = document.getElementById('splash-screen');
        const mainApp = document.getElementById('main-app');
        
        splashScreen.style.opacity = '0';
        setTimeout(() => {
            splashScreen.classList.add('hidden');
            mainApp.classList.remove('hidden');
        }, 500);
    }

    initEventListeners() {
        // Tab navigation
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const tab = e.currentTarget.dataset.tab;
                this.switchTab(tab);
            });
        });

        // Sync button
        document.getElementById('sync-btn').addEventListener('click', () => {
            this.forceSync();
        });

        // Add buttons
        document.getElementById('add-team-btn').addEventListener('click', () => {
            this.showAddTeamModal();
        });

        document.getElementById('add-league-btn').addEventListener('click', () => {
            this.showAddLeagueModal();
        });

        document.getElementById('add-matchday-btn').addEventListener('click', () => {
            this.showAddMatchDayModal();
        });

        document.getElementById('force-refresh-btn').addEventListener('click', () => {
            this.forceSync();
        });

        // Modal close
        document.getElementById('modal-close').addEventListener('click', () => {
            this.hideModal();
        });

        document.getElementById('modal-overlay').addEventListener('click', (e) => {
            if (e.target === e.currentTarget) {
                this.hideModal();
            }
        });
    }

    switchTab(tabName) {
        // Update tab buttons
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

        // Update tab content
        document.querySelectorAll('.tab-content').forEach(content => {
            content.classList.remove('active');
        });
        document.getElementById(`${tabName}-tab`).classList.add('active');

        // Update page title
        const titles = {
            teams: 'Teams by League',
            matchdays: 'Match Days',
            settings: 'Settings'
        };
        document.getElementById('page-title').textContent = titles[tabName];

        this.currentView = tabName;
        this.updateUI();
    }

    async loadDataFromServer() {
        this.showLoading('Loading data from server...');
        
        try {
            // Load teams
            const teamsResponse = await fetch(`${this.serverURL}/teams`);
            if (teamsResponse.ok) {
                this.data.teams = await teamsResponse.json();
                console.log(`📥 Loaded ${this.data.teams.length} teams from server`);
            }

            // Load match days
            const matchDaysResponse = await fetch(`${this.serverURL}/matchdays`);
            if (matchDaysResponse.ok) {
                this.data.matchDays = await matchDaysResponse.json();
                this.data.matchDays.sort((a, b) => new Date(a.date) - new Date(b.date));
                console.log(`📥 Loaded ${this.data.matchDays.length} match days from server`);
            }

            this.syncStatus = 'Data loaded from server';
            this.lastSyncDate = new Date();
            this.showToast('Data loaded successfully', 'success');
        } catch (error) {
            console.error('Error loading data:', error);
            this.syncStatus = 'Failed to load data from server';
            this.showToast('Failed to load data from server', 'error');
        } finally {
            this.hideLoading();
        }
    }

    async forceSync() {
        const syncBtn = document.getElementById('sync-btn');
        syncBtn.classList.add('syncing');
        
        await this.loadDataFromServer();
        this.updateUI();
        
        syncBtn.classList.remove('syncing');
    }

    startPeriodicSync() {
        // Sync every 30 seconds
        setInterval(() => {
            this.loadDataFromServer();
        }, 30000);
    }

    updateUI() {
        switch (this.currentView) {
            case 'teams':
                this.renderTeams();
                break;
            case 'matchdays':
                this.renderMatchDays();
                break;
            case 'settings':
                this.renderSettings();
                break;
        }
    }

    renderTeams() {
        const teamsList = document.getElementById('teams-list');
        teamsList.innerHTML = '';

        // Group teams by league
        this.data.leagues.forEach(league => {
            const leagueTeams = this.data.teams.filter(team => team.leagueId === league.id);
            
            const leagueSection = document.createElement('div');
            leagueSection.className = 'league-section';
            
            leagueSection.innerHTML = `
                <div class="league-header">
                    <h3 class="league-title">${league.name}</h3>
                    <div class="league-actions">
                        <button class="btn btn-secondary btn-sm" onclick="app.editLeague('${league.id}')">Edit</button>
                        <button class="btn btn-danger btn-sm" onclick="app.deleteLeague('${league.id}')">Delete</button>
                    </div>
                </div>
                <div class="league-teams">
                    ${leagueTeams.length === 0 ? 
                        '<p style="color: #666; font-style: italic; padding: 1rem;">No teams in this league</p>' :
                        leagueTeams.sort((a, b) => a.name.localeCompare(b.name)).map(team => `
                            <div class="team-item">
                                <div class="team-color" style="background-color: ${this.getTeamColor(team)}"></div>
                                <div class="team-info" onclick="app.viewTeam('${team.id}')" style="flex: 1; cursor: pointer;">
                                    <div class="team-name">${team.name}</div>
                                    <div class="team-details">${team.players.length} players</div>
                                </div>
                                <button class="btn btn-secondary btn-sm" onclick="app.editTeam('${team.id}')" style="margin-left: 0.5rem;">Edit</button>
                                <button class="btn btn-danger btn-sm" onclick="app.deleteTeam('${team.id}')" style="margin-left: 0.5rem;">Delete</button>
                            </div>
                        `).join('')
                    }
                </div>
            `;
            
            teamsList.appendChild(leagueSection);
        });

        // Show unassigned teams
        const unassignedTeams = this.data.teams.filter(team => !team.leagueId);
        if (unassignedTeams.length > 0) {
            const unassignedSection = document.createElement('div');
            unassignedSection.className = 'league-section';
            
            unassignedSection.innerHTML = `
                <div class="league-header">
                    <h3 class="league-title">Unassigned Teams</h3>
                </div>
                <div class="league-teams">
                    ${unassignedTeams.sort((a, b) => a.name.localeCompare(b.name)).map(team => `
                        <div class="team-item">
                            <div class="team-color" style="background-color: ${this.getTeamColor(team)}"></div>
                            <div class="team-info" onclick="app.viewTeam('${team.id}')" style="flex: 1; cursor: pointer;">
                                <div class="team-name">${team.name}</div>
                                <div class="team-details">${team.players.length} players</div>
                            </div>
                            <button class="btn btn-secondary btn-sm" onclick="app.editTeam('${team.id}')" style="margin-left: 0.5rem;">Edit</button>
                            <button class="btn btn-danger btn-sm" onclick="app.deleteTeam('${team.id}')" style="margin-left: 0.5rem;">Delete</button>
                        </div>
                    `).join('')}
                </div>
            `;
            
            teamsList.appendChild(unassignedSection);
        }
    }

    renderMatchDays() {
        const now = new Date();
        const upcomingMatchDays = this.data.matchDays.filter(md => new Date(md.date) >= now);
        const pastMatchDays = this.data.matchDays.filter(md => new Date(md.date) < now);

        // Render upcoming match days
        const upcomingContainer = document.getElementById('upcoming-matchdays');
        upcomingContainer.innerHTML = upcomingMatchDays.length === 0 ? 
            '<p style="color: #666; font-style: italic;">No upcoming match days</p>' :
            upcomingMatchDays.map(matchDay => this.renderMatchDayItem(matchDay)).join('');

        // Render past match days
        const pastContainer = document.getElementById('past-matchdays');
        pastContainer.innerHTML = pastMatchDays.length === 0 ? 
            '<p style="color: #666; font-style: italic;">No past match days</p>' :
            pastMatchDays.reverse().map(matchDay => this.renderMatchDayItem(matchDay)).join('');
    }

    renderMatchDayItem(matchDay) {
        const date = new Date(matchDay.date);
        const isToday = this.isToday(date);
        
        return `
            <div class="matchday-item" onclick="app.viewMatchDay('${matchDay.id}')">
                <div class="matchday-header">
                    <div class="matchday-name">${matchDay.name}</div>
                    <div class="matchday-date">${date.toLocaleDateString()}</div>
                </div>
                <div class="matchday-info">${matchDay.matches.length} games scheduled</div>
                ${isToday ? '<div class="today-badge">TODAY</div>' : ''}
            </div>
        `;
    }

    renderSettings() {
        document.getElementById('sync-status').textContent = this.syncStatus;
        document.getElementById('total-teams').textContent = this.data.teams.length;
        document.getElementById('total-players').textContent = 
            this.data.teams.reduce((total, team) => total + team.players.length, 0);
        document.getElementById('scheduled-matchdays').textContent = 
            this.data.matchDays.filter(md => new Date(md.date) >= new Date()).length;
    }

    // Modal functions
    showModal(title, content) {
        document.getElementById('modal-title').textContent = title;
        
        // Split content into body and form actions
        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = content;
        
        // Find form actions
        const formActions = tempDiv.querySelector('.form-actions');
        let bodyContent = content;
        let actionsContent = '';
        
        if (formActions) {
            // Remove form actions from body content
            formActions.remove();
            bodyContent = tempDiv.innerHTML;
            actionsContent = formActions.outerHTML;
        }
        
        document.getElementById('modal-content').innerHTML = `
            <div class="modal-body">
                ${bodyContent}
            </div>
            ${actionsContent}
        `;
        document.getElementById('modal-overlay').classList.remove('hidden');
    }

    hideModal() {
        document.getElementById('modal-overlay').classList.add('hidden');
    }

    showAddTeamModal() {
        const leagueOptions = this.data.leagues.map(league => 
            `<option value="${league.id}">${league.name}</option>`
        ).join('');

        const content = `
            <form id="add-team-form">
                <div class="form-group">
                    <label class="form-label">Team Name</label>
                    <input type="text" class="form-input" id="team-name" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Team Color</label>
                    <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.5rem; margin-top: 0.5rem;">
                        ${['#2196F3', '#F44336', '#4CAF50', '#FF9800', '#9C27B0', '#E91E63', '#FFEB3B', '#00BCD4'].map(color => `
                            <div class="color-option" style="width: 40px; height: 40px; background: ${color}; border-radius: 50%; cursor: pointer; border: 3px solid transparent;" 
                                 onclick="app.selectColor('${color}', this)" data-color="${color}"></div>
                        `).join('')}
                    </div>
                    <input type="hidden" id="selected-color" value="#2196F3">
                </div>
                <div class="form-group">
                    <label class="form-label">League</label>
                    <select class="form-select" id="team-league">
                        <option value="">No League</option>
                        ${leagueOptions}
                    </select>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn btn-secondary" onclick="app.hideModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add Team</button>
                </div>
            </form>
        `;

        this.showModal('Add New Team', content);

        // Set default color selection
        document.querySelector('.color-option').style.border = '3px solid #333';

        // Handle form submission
        document.getElementById('add-team-form').addEventListener('submit', (e) => {
            e.preventDefault();
            this.addTeam();
        });
    }

    showAddLeagueModal() {
        const content = `
            <form id="add-league-form">
                <div class="form-group">
                    <label class="form-label">League Name</label>
                    <input type="text" class="form-input" id="league-name" placeholder="e.g., Over 50, Youth League" required>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn btn-secondary" onclick="app.hideModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add League</button>
                </div>
            </form>
        `;

        this.showModal('Add New League', content);

        document.getElementById('add-league-form').addEventListener('submit', (e) => {
            e.preventDefault();
            this.addLeague();
        });
    }

    showAddMatchDayModal() {
        const content = `
            <form id="add-matchday-form">
                <div class="form-group">
                    <label class="form-label">Match Day Name</label>
                    <input type="text" class="form-input" id="matchday-name" placeholder="e.g., Week 5 - League Games" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Date</label>
                    <input type="date" class="form-input" id="matchday-date" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Notes (Optional)</label>
                    <textarea class="form-input" id="matchday-notes" rows="3" placeholder="Additional notes..."></textarea>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn btn-secondary" onclick="app.hideModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Create Match Day</button>
                </div>
            </form>
        `;

        this.showModal('Create Match Day', content);

        // Set default date to today
        document.getElementById('matchday-date').valueAsDate = new Date();

        document.getElementById('add-matchday-form').addEventListener('submit', (e) => {
            e.preventDefault();
            this.addMatchDay();
        });
    }

    selectColor(color, element) {
        // Remove selection from all color options
        document.querySelectorAll('.color-option').forEach(option => {
            option.style.border = '3px solid transparent';
        });
        
        // Select clicked color
        element.style.border = '3px solid #333';
        document.getElementById('selected-color').value = color;
    }

    async addTeam() {
        const name = document.getElementById('team-name').value.trim();
        const color = document.getElementById('selected-color').value;
        const leagueId = document.getElementById('team-league').value || null;

        if (!name) return;

        const newTeam = {
            id: this.generateUUID(),
            name: name,
            colorData: color,
            leagueId: leagueId,
            players: [],
            lastModified: Date.now() / 1000
        };

        try {
            const response = await fetch(`${this.serverURL}/teams`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify([...this.data.teams, newTeam])
            });

            if (response.ok) {
                this.data.teams.push(newTeam);
                this.hideModal();
                this.updateUI();
                this.showToast('Team added successfully', 'success');
            } else {
                throw new Error('Failed to add team');
            }
        } catch (error) {
            console.error('Error adding team:', error);
            this.showToast('Failed to add team', 'error');
        }
    }

    editTeam(teamId) {
        const team = this.data.teams.find(t => t.id === teamId);
        if (!team) return;

        const leagueOptions = this.data.leagues.map(league =>
            `<option value="${league.id}" ${team.leagueId === league.id ? 'selected' : ''}>${league.name}</option>`
        ).join('');

        const content = `
            <form id="edit-team-form">
                <div class="form-group">
                    <label class="form-label">Team Name</label>
                    <input type="text" class="form-input" id="edit-team-name" value="${team.name}" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Team Color</label>
                    <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.5rem; margin-top: 0.5rem;">
                        ${['#2196F3', '#F44336', '#4CAF50', '#FF9800', '#9C27B0', '#E91E63', '#FFEB3B', '#00BCD4'].map(color => `
                            <div class="color-option" style="width: 40px; height: 40px; background: ${color}; border-radius: 50%; cursor: pointer; border: 3px solid ${team.colorData === color ? '#333' : 'transparent'};"
                                 onclick="app.selectColor('${color}', this)" data-color="${color}"></div>
                        `).join('')}
                    </div>
                    <input type="hidden" id="selected-color" value="${team.colorData || '#2196F3'}">
                </div>
                <div class="form-group">
                    <label class="form-label">League</label>
                    <select class="form-select" id="edit-team-league">
                        <option value="" ${!team.leagueId ? 'selected' : ''}>No League</option>
                        ${leagueOptions}
                    </select>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn btn-secondary" onclick="app.hideModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Save Changes</button>
                </div>
            </form>
        `;

        this.showModal('Edit Team', content);

        // Handle form submission
        document.getElementById('edit-team-form').addEventListener('submit', (e) => {
            e.preventDefault();
            this.saveTeamChanges(teamId);
        });
    }

    async saveTeamChanges(teamId) {
        const team = this.data.teams.find(t => t.id === teamId);
        if (!team) return;

        const name = document.getElementById('edit-team-name').value.trim();
        const color = document.getElementById('selected-color').value;
        const leagueId = document.getElementById('edit-team-league').value || null;

        if (!name) return;

        // Update team properties
        team.name = name;
        team.colorData = color;
        team.leagueId = leagueId;
        team.lastModified = Date.now() / 1000;

        try {
            const response = await fetch(`${this.serverURL}/teams`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(this.data.teams)
            });

            if (response.ok) {
                this.hideModal();
                this.updateUI();
                this.showToast('Team updated successfully', 'success');
            } else {
                throw new Error('Failed to update team');
            }
        } catch (error) {
            console.error('Error updating team:', error);
            this.showToast('Failed to update team', 'error');
        }
    }

    async addLeague() {
        const name = document.getElementById('league-name').value.trim();
        if (!name) return;

        const newLeague = {
            id: this.generateUUID(),
            name: name,
            lastModified: Date.now() / 1000
        };

        this.data.leagues.push(newLeague);
        this.hideModal();
        this.updateUI();
        this.showToast('League added successfully', 'success');
    }

    async deleteTeam(teamId) {
        const team = this.data.teams.find(t => t.id === teamId);
        if (!team) return;

        // Confirm deletion
        if (!confirm(`Are you sure you want to delete "${team.name}"? This action cannot be undone.`)) {
            return;
        }

        try {
            // Remove team from local data
            this.data.teams = this.data.teams.filter(t => t.id !== teamId);

            // Update server
            const response = await fetch(`${this.serverURL}/teams`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(this.data.teams)
            });

            if (response.ok) {
                this.updateUI();
                this.showToast('Team deleted successfully', 'success');
            } else {
                throw new Error('Failed to delete team');
            }
        } catch (error) {
            console.error('Error deleting team:', error);
            this.showToast('Failed to delete team', 'error');
            // Restore team if server update failed
            this.data.teams.push(team);
        }
    }

    async addMatchDay() {
        const name = document.getElementById('matchday-name').value.trim();
        const date = document.getElementById('matchday-date').value;
        const notes = document.getElementById('matchday-notes').value.trim();

        if (!name || !date) return;

        const newMatchDay = {
            id: this.generateUUID(),
            name: name,
            date: new Date(date).toISOString(),
            notes: notes,
            matches: [],
            lastModified: Date.now() / 1000
        };

        try {
            const response = await fetch(`${this.serverURL}/matchdays`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify([...this.data.matchDays, newMatchDay])
            });

            if (response.ok) {
                this.data.matchDays.push(newMatchDay);
                this.data.matchDays.sort((a, b) => new Date(a.date) - new Date(b.date));
                this.hideModal();
                this.updateUI();
                this.showToast('Match day created successfully', 'success');
            } else {
                throw new Error('Failed to create match day');
            }
        } catch (error) {
            console.error('Error creating match day:', error);
            this.showToast('Failed to create match day', 'error');
        }
    }

    viewTeam(teamId) {
        const team = this.data.teams.find(t => t.id === teamId);
        if (!team) return;

        const playersHtml = team.players.length === 0 ? 
            '<p style="color: #666; font-style: italic;">No players in this team</p>' :
            team.players.sort((a, b) => a.name.localeCompare(b.name)).map(player => `
                <div class="player-item" style="display: flex; align-items: center; padding: 0.75rem; border-bottom: 1px solid #f0f0f0;">
                    <div style="width: 40px; height: 40px; background: #f0f0f0; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin-right: 1rem; font-size: 0.8rem; color: #666;">
                        👤
                    </div>
                    <div style="font-weight: bold; margin-right: 1rem; color: #666; min-width: 40px;">
                        #${player.jerseyNumber}
                    </div>
                    <div style="flex: 1;">
                        <div style="font-weight: 500;">${player.name}</div>
                    </div>
                </div>
            `).join('');

        const content = `
            <div style="margin-bottom: 1.5rem;">
                <div style="display: flex; align-items: center; margin-bottom: 1rem;">
                    <div style="width: 30px; height: 30px; background: ${this.getTeamColor(team)}; border-radius: 50%; margin-right: 1rem;"></div>
                    <div>
                        <h3 style="margin: 0; font-size: 1.3rem;">${team.name}</h3>
                        <p style="margin: 0; color: #666;">${team.players.length} players</p>
                    </div>
                </div>
            </div>
            
            <div>
                <h4 style="margin-bottom: 1rem;">Players</h4>
                <div style="border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
                    ${playersHtml}
                </div>
            </div>
            
            <div class="form-actions" style="margin-top: 1.5rem;">
                <button type="button" class="btn btn-secondary" onclick="app.hideModal()">Close</button>
                <button type="button" class="btn btn-primary" onclick="app.addPlayerToTeam('${teamId}')">Add Player</button>
            </div>
        `;

        this.showModal(team.name, content);
    }

    addPlayerToTeam(teamId) {
        const content = `
            <form id="add-player-form">
                <div class="form-group">
                    <label class="form-label">Player Name</label>
                    <input type="text" class="form-input" id="player-name" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Jersey Number</label>
                    <input type="number" class="form-input" id="jersey-number" min="1" max="99" required>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn btn-secondary" onclick="app.hideModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add Player</button>
                </div>
            </form>
        `;

        this.showModal('Add Player', content);

        document.getElementById('add-player-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const name = document.getElementById('player-name').value.trim();
            const jerseyNumber = parseInt(document.getElementById('jersey-number').value);
            
            if (!name || !jerseyNumber) return;

            const team = this.data.teams.find(t => t.id === teamId);
            if (!team) return;

            // Check if jersey number is already taken
            if (team.players.some(p => p.jerseyNumber === jerseyNumber)) {
                this.showToast('Jersey number already taken', 'error');
                return;
            }

            const newPlayer = {
                id: this.generateUUID(),
                name: name,
                jerseyNumber: jerseyNumber,
                isPresent: false
            };

            team.players.push(newPlayer);
            team.players.sort((a, b) => a.name.localeCompare(b.name));

            try {
                const response = await fetch(`${this.serverURL}/teams`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(this.data.teams)
                });

                if (response.ok) {
                    this.hideModal();
                    this.updateUI(); // Refresh the main UI
                    this.viewTeam(teamId); // Refresh team view
                    this.showToast('Player added successfully', 'success');
                } else {
                    throw new Error('Failed to add player');
                }
            } catch (error) {
                console.error('Error adding player:', error);
                this.showToast('Failed to add player', 'error');
            }
        });
    }

    addMatchToMatchDay(matchDayId) {
        console.log('addMatchToMatchDay called with matchDayId:', matchDayId);
        console.log('Available teams:', this.data.teams.length);
        
        if (this.data.teams.length < 2) {
            this.showToast(`Need at least 2 teams to create a match. Currently have ${this.data.teams.length} team(s). Please add more teams first.`, 'error');
            return;
        }

        const teamOptions = this.data.teams.map(team =>
            `<option value="${team.id}">${team.name}</option>`
        ).join('');

        const content = `
            <form id="add-match-form">
                <div class="form-group">
                    <label class="form-label">Home Team</label>
                    <select class="form-select" id="home-team" required>
                        <option value="">Select Home Team</option>
                        ${teamOptions}
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">Away Team</label>
                    <select class="form-select" id="away-team" required>
                        <option value="">Select Away Team</option>
                        ${teamOptions}
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">Scheduled Time</label>
                    <input type="time" class="form-input" id="match-time" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Field</label>
                    <input type="text" class="form-input" id="match-field" placeholder="e.g., Field A" required>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn btn-secondary" onclick="app.hideModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add Match</button>
                </div>
            </form>
        `;

        this.showModal('Add Match', content);

        document.getElementById('add-match-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            console.log('Add match form submitted');
            
            const homeTeamId = document.getElementById('home-team').value;
            const awayTeamId = document.getElementById('away-team').value;
            const matchTime = document.getElementById('match-time').value;
            const field = document.getElementById('match-field').value.trim();
            
            console.log('Form values:', { homeTeamId, awayTeamId, matchTime, field });
            
            if (!homeTeamId || !awayTeamId || !matchTime || !field) {
                console.log('Missing required fields');
                this.showToast('Please fill in all required fields', 'error');
                return;
            }

            if (homeTeamId === awayTeamId) {
                console.log('Same team selected for home and away');
                this.showToast('Home and away teams must be different', 'error');
                return;
            }

            const matchDay = this.data.matchDays.find(md => md.id === matchDayId);
            if (!matchDay) return;

            // Create scheduled time by combining match day date with selected time
            const matchDate = new Date(matchDay.date);
            const [hours, minutes] = matchTime.split(':');
            matchDate.setHours(parseInt(hours), parseInt(minutes), 0, 0);

            const newMatch = {
                id: this.generateUUID(),
                homeTeamId: homeTeamId,
                awayTeamId: awayTeamId,
                scheduledTime: matchDate.toISOString(),
                field: field,
                status: 'Scheduled',
                homeTeamPresent: 0,
                awayTeamPresent: 0,
                homeScore: null,
                awayScore: null
            };

            matchDay.matches.push(newMatch);
            
            // Sort matches by time first, then by field number
            matchDay.matches.sort((a, b) => {
                // First sort by scheduled time
                const timeA = new Date(a.scheduledTime);
                const timeB = new Date(b.scheduledTime);
                if (timeA.getTime() !== timeB.getTime()) {
                    return timeA - timeB;
                }
                
                // If times are equal, sort by field number
                const getFieldNumber = (field) => {
                    const match = field.match(/(\d+)/);
                    return match ? parseInt(match[1]) : field.toLowerCase().charCodeAt(0);
                };
                
                return getFieldNumber(a.field) - getFieldNumber(b.field);
            });

            try {
                console.log('Sending match data to server...');
                const response = await fetch(`${this.serverURL}/matchdays`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(this.data.matchDays)
                });

                console.log('Server response status:', response.status);
                
                if (response.ok) {
                    console.log('Match added successfully');
                    this.hideModal();
                    this.updateUI(); // Refresh the main UI
                    this.viewMatchDay(matchDayId); // Refresh match day view
                    this.showToast('Match added successfully', 'success');
                } else {
                    const errorText = await response.text();
                    console.error('Server error:', response.status, errorText);
                    throw new Error(`Failed to add match: ${response.status} ${errorText}`);
                }
            } catch (error) {
                console.error('Error adding match:', error);
                this.showToast(`Failed to add match: ${error.message}`, 'error');
            }
        });
    }

    viewMatch(matchId, fromMatchDay = null) {
        // Find the match across all match days
        let match = null;
        let matchDay = null;
        
        for (const md of this.data.matchDays) {
            const foundMatch = md.matches.find(m => m.id === matchId);
            if (foundMatch) {
                match = foundMatch;
                matchDay = md;
                break;
            }
        }

        if (!match || !matchDay) return;
        
        // Store the match day ID for navigation back
        this.currentMatchDayId = fromMatchDay || matchDay.id;

        const homeTeam = this.data.teams.find(t => t.id === match.homeTeamId);
        const awayTeam = this.data.teams.find(t => t.id === match.awayTeamId);

        if (!homeTeam || !awayTeam) {
            this.showToast('Team data not found for this match', 'error');
            return;
        }

        const content = `
            <div style="margin-bottom: 1.5rem;">
                <div style="display: flex; align-items: center; justify-content: center; margin-bottom: 1rem;">
                    <div style="display: flex; align-items: center;">
                        <div style="width: 20px; height: 20px; background: ${this.getTeamColor(homeTeam)}; border-radius: 50%; margin-right: 0.5rem;"></div>
                        <span style="font-weight: bold; font-size: 1.1rem;">${homeTeam.name}</span>
                    </div>
                    <span style="margin: 0 1rem; font-size: 1.2rem; color: #666;">vs</span>
                    <div style="display: flex; align-items: center;">
                        <div style="width: 20px; height: 20px; background: ${this.getTeamColor(awayTeam)}; border-radius: 50%; margin-right: 0.5rem;"></div>
                        <span style="font-weight: bold; font-size: 1.1rem;">${awayTeam.name}</span>
                    </div>
                </div>
                <div style="text-align: center; color: #666;">
                    <div>${new Date(match.scheduledTime).toLocaleString()}</div>
                    <div>Field ${match.field}</div>
                    <div style="margin-top: 0.5rem;">
                        <span style="background: #4CAF50; color: white; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.9rem;">
                            ${match.status}
                        </span>
                    </div>
                </div>
            </div>

            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1.5rem;">
                <div style="padding: 1rem; border: 1px solid #e0e0e0; border-radius: 8px;">
                    <div style="font-weight: bold; margin-bottom: 0.5rem; text-align: center;">${homeTeam.name}</div>
                    ${match.homeScore !== null ? `<div style="font-size: 1.5rem; font-weight: bold; color: #4CAF50; margin-bottom: 0.5rem; text-align: center;">${match.homeScore}</div>` : ''}
                    <div style="font-size: 0.9rem; color: #666; margin-bottom: 0.5rem;">Present Players (${homeTeam.players.filter(p => p.isPresent).length}):</div>
                    <div style="max-height: 120px; overflow-y: auto;">
                        ${homeTeam.players.filter(p => p.isPresent).length === 0 ?
                            '<div style="font-style: italic; color: #999; font-size: 0.8rem;">No players checked in</div>' :
                            homeTeam.players.filter(p => p.isPresent).map(player => `
                                <div style="font-size: 0.8rem; padding: 0.2rem 0; border-bottom: 1px solid #f0f0f0;">
                                    #${player.jerseyNumber} ${player.name}
                                </div>
                            `).join('')
                        }
                    </div>
                </div>
                <div style="padding: 1rem; border: 1px solid #e0e0e0; border-radius: 8px;">
                    <div style="font-weight: bold; margin-bottom: 0.5rem; text-align: center;">${awayTeam.name}</div>
                    ${match.awayScore !== null ? `<div style="font-size: 1.5rem; font-weight: bold; color: #4CAF50; margin-bottom: 0.5rem; text-align: center;">${match.awayScore}</div>` : ''}
                    <div style="font-size: 0.9rem; color: #666; margin-bottom: 0.5rem;">Present Players (${awayTeam.players.filter(p => p.isPresent).length}):</div>
                    <div style="max-height: 120px; overflow-y: auto;">
                        ${awayTeam.players.filter(p => p.isPresent).length === 0 ?
                            '<div style="font-style: italic; color: #999; font-size: 0.8rem;">No players checked in</div>' :
                            awayTeam.players.filter(p => p.isPresent).map(player => `
                                <div style="font-size: 0.8rem; padding: 0.2rem 0; border-bottom: 1px solid #f0f0f0;">
                                    #${player.jerseyNumber} ${player.name}
                                </div>
                            `).join('')
                        }
                    </div>
                </div>
            </div>
            
            <div class="form-actions">
                <button type="button" class="btn btn-secondary" onclick="app.viewMatchDay('${this.currentMatchDayId}')">Close</button>
                <button type="button" class="btn btn-primary" onclick="app.checkInMatch('${matchId}')">Check-in Players</button>
                ${match.status === 'Scheduled' || match.status === 'In Progress' ?
                    `<button type="button" class="btn btn-success" onclick="app.enterScore('${matchId}')">Enter Score</button>` :
                    ''
                }
            </div>
        `;

        this.showModal('Match Details', content);
    }

    checkInMatch(matchId) {
        // Find the match
        let match = null;
        for (const md of this.data.matchDays) {
            const foundMatch = md.matches.find(m => m.id === matchId);
            if (foundMatch) {
                match = foundMatch;
                break;
            }
        }

        if (!match) return;

        const homeTeam = this.data.teams.find(t => t.id === match.homeTeamId);
        const awayTeam = this.data.teams.find(t => t.id === match.awayTeamId);

        if (!homeTeam || !awayTeam) return;

        const homePlayersHtml = homeTeam.players.map(player => `
            <div style="display: flex; align-items: center; padding: 0.5rem; border-bottom: 1px solid #f0f0f0;">
                <input type="checkbox" id="home-${player.id}" ${player.isPresent ? 'checked' : ''}
                       onchange="app.togglePlayerPresence('${homeTeam.id}', '${player.id}')">
                <label for="home-${player.id}" style="margin-left: 0.5rem; flex: 1; cursor: pointer;">
                    #${player.jerseyNumber} ${player.name}
                </label>
            </div>
        `).join('');

        const awayPlayersHtml = awayTeam.players.map(player => `
            <div style="display: flex; align-items: center; padding: 0.5rem; border-bottom: 1px solid #f0f0f0;">
                <input type="checkbox" id="away-${player.id}" ${player.isPresent ? 'checked' : ''}
                       onchange="app.togglePlayerPresence('${awayTeam.id}', '${player.id}')">
                <label for="away-${player.id}" style="margin-left: 0.5rem; flex: 1; cursor: pointer;">
                    #${player.jerseyNumber} ${player.name}
                </label>
            </div>
        `).join('');

        const content = `
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                <div>
                    <h4 style="margin-bottom: 1rem; display: flex; align-items: center;">
                        <div style="width: 15px; height: 15px; background: ${this.getTeamColor(homeTeam)}; border-radius: 50%; margin-right: 0.5rem;"></div>
                        ${homeTeam.name}
                    </h4>
                    <div style="border: 1px solid #e0e0e0; border-radius: 8px; max-height: 300px; overflow-y: auto;">
                        ${homePlayersHtml || '<p style="padding: 1rem; color: #666; font-style: italic;">No players</p>'}
                    </div>
                </div>
                <div>
                    <h4 style="margin-bottom: 1rem; display: flex; align-items: center;">
                        <div style="width: 15px; height: 15px; background: ${this.getTeamColor(awayTeam)}; border-radius: 50%; margin-right: 0.5rem;"></div>
                        ${awayTeam.name}
                    </h4>
                    <div style="border: 1px solid #e0e0e0; border-radius: 8px; max-height: 300px; overflow-y: auto;">
                        ${awayPlayersHtml || '<p style="padding: 1rem; color: #666; font-style: italic;">No players</p>'}
                    </div>
                </div>
            </div>
            
            <div class="form-actions" style="margin-top: 1.5rem;">
                <button type="button" class="btn btn-secondary" onclick="app.viewMatch('${matchId}')">Close</button>
                <button type="button" class="btn btn-primary" onclick="app.saveCheckIn('${matchId}')">Save Check-in</button>
            </div>
        `;

        this.showModal('Player Check-in', content);
    }

    async togglePlayerPresence(teamId, playerId) {
        const team = this.data.teams.find(t => t.id === teamId);
        if (!team) return;

        const player = team.players.find(p => p.id === playerId);
        if (!player) return;

        player.isPresent = !player.isPresent;
    }

    async saveCheckIn(matchId) {
        // Find the match
        let match = null;
        for (const md of this.data.matchDays) {
            const foundMatch = md.matches.find(m => m.id === matchId);
            if (foundMatch) {
                match = foundMatch;
                break;
            }
        }

        if (!match) return;

        const homeTeam = this.data.teams.find(t => t.id === match.homeTeamId);
        const awayTeam = this.data.teams.find(t => t.id === match.awayTeamId);

        if (!homeTeam || !awayTeam) return;

        // Update match with present player counts
        match.homeTeamPresent = homeTeam.players.filter(p => p.isPresent).length;
        match.awayTeamPresent = awayTeam.players.filter(p => p.isPresent).length;

        try {
            // Save teams data
            const teamsResponse = await fetch(`${this.serverURL}/teams`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(this.data.teams)
            });

            // Save match days data
            const matchDaysResponse = await fetch(`${this.serverURL}/matchdays`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(this.data.matchDays)
            });

            if (teamsResponse.ok && matchDaysResponse.ok) {
                this.showToast('Check-in saved successfully', 'success');
                // Return to the match details view after saving check-in
                this.viewMatch(matchId);
            } else {
                throw new Error('Failed to save check-in');
            }
        } catch (error) {
            console.error('Error saving check-in:', error);
            this.showToast('Failed to save check-in', 'error');
        }
    }

    enterScore(matchId) {
        // Find the match
        let match = null;
        for (const md of this.data.matchDays) {
            const foundMatch = md.matches.find(m => m.id === matchId);
            if (foundMatch) {
                match = foundMatch;
                break;
            }
        }

        if (!match) return;

        const homeTeam = this.data.teams.find(t => t.id === match.homeTeamId);
        const awayTeam = this.data.teams.find(t => t.id === match.awayTeamId);

        if (!homeTeam || !awayTeam) return;

        const content = `
            <form id="score-form">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1.5rem;">
                    <div style="text-align: center;">
                        <div style="display: flex; align-items: center; justify-content: center; margin-bottom: 1rem;">
                            <div style="width: 20px; height: 20px; background: ${this.getTeamColor(homeTeam)}; border-radius: 50%; margin-right: 0.5rem;"></div>
                            <span style="font-weight: bold;">${homeTeam.name}</span>
                        </div>
                        <input type="number" class="form-input" id="home-score" min="0" max="99"
                               value="${match.homeScore || ''}" placeholder="0" style="text-align: center; font-size: 1.5rem;">
                    </div>
                    <div style="text-align: center;">
                        <div style="display: flex; align-items: center; justify-content: center; margin-bottom: 1rem;">
                            <div style="width: 20px; height: 20px; background: ${this.getTeamColor(awayTeam)}; border-radius: 50%; margin-right: 0.5rem;"></div>
                            <span style="font-weight: bold;">${awayTeam.name}</span>
                        </div>
                        <input type="number" class="form-input" id="away-score" min="0" max="99"
                               value="${match.awayScore || ''}" placeholder="0" style="text-align: center; font-size: 1.5rem;">
                    </div>
                </div>
                
                <div class="form-group">
                    <label class="form-label">Match Status</label>
                    <select class="form-select" id="match-status">
                        <option value="Scheduled" ${match.status === 'Scheduled' ? 'selected' : ''}>Scheduled</option>
                        <option value="In Progress" ${match.status === 'In Progress' ? 'selected' : ''}>In Progress</option>
                        <option value="Completed" ${match.status === 'Completed' ? 'selected' : ''}>Completed</option>
                        <option value="Cancelled" ${match.status === 'Cancelled' ? 'selected' : ''}>Cancelled</option>
                    </select>
                </div>
                
                <div class="form-actions">
                    <button type="button" class="btn btn-secondary" onclick="app.hideModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Save Score</button>
                </div>
            </form>
        `;

        this.showModal('Enter Score', content);

        document.getElementById('score-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const homeScore = document.getElementById('home-score').value;
            const awayScore = document.getElementById('away-score').value;
            const status = document.getElementById('match-status').value;

            match.homeScore = homeScore ? parseInt(homeScore) : null;
            match.awayScore = awayScore ? parseInt(awayScore) : null;
            match.status = status;

            try {
                const response = await fetch(`${this.serverURL}/matchdays`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(this.data.matchDays)
                });

                if (response.ok) {
                    this.hideModal();
                    this.updateUI(); // Refresh the main UI
                    this.showToast('Score saved successfully', 'success');
                } else {
                    throw new Error('Failed to save score');
                }
            } catch (error) {
                console.error('Error saving score:', error);
                this.showToast('Failed to save score', 'error');
            }
        });
    }

    viewMatchDay(matchDayId) {
        const matchDay = this.data.matchDays.find(md => md.id === matchDayId);
        if (!matchDay) return;

        // Sort matches by time first, then by field number
        const sortedMatches = [...matchDay.matches].sort((a, b) => {
            // First sort by scheduled time
            const timeA = new Date(a.scheduledTime);
            const timeB = new Date(b.scheduledTime);
            if (timeA.getTime() !== timeB.getTime()) {
                return timeA - timeB;
            }
            
            // If times are equal, sort by field number
            // Extract numeric part from field names (e.g., "Field 1", "Field A", "1", etc.)
            const getFieldNumber = (field) => {
                const match = field.match(/(\d+)/);
                return match ? parseInt(match[1]) : field.toLowerCase().charCodeAt(0);
            };
            
            return getFieldNumber(a.field) - getFieldNumber(b.field);
        });

        const matchesHtml = sortedMatches.length === 0 ?
            '<p style="color: #666; font-style: italic;">No matches scheduled</p>' :
            sortedMatches.map(match => {
                const homeTeam = this.data.teams.find(t => t.id === match.homeTeamId);
                const awayTeam = this.data.teams.find(t => t.id === match.awayTeamId);
                
                return `
                    <div class="match-item" style="padding: 1rem; border-bottom: 1px solid #f0f0f0; position: relative;">
                        <div style="display: flex; align-items: center; margin-bottom: 0.5rem;">
                            <div style="display: flex; align-items: center; flex: 1; cursor: pointer;" onclick="app.viewMatch('${match.id}', '${matchDay.id}')">
                                <div style="width: 15px; height: 15px; background: ${homeTeam ? this.getTeamColor(homeTeam) : '#ccc'}; border-radius: 50%; margin-right: 0.5rem;"></div>
                                <span style="font-weight: 500;">${homeTeam ? homeTeam.name : '⚠️ Team Not Found'}</span>
                            </div>
                            <span style="color: #666; margin: 0 1rem;">vs</span>
                            <div style="display: flex; align-items: center; flex: 1; cursor: pointer;" onclick="app.viewMatch('${match.id}', '${matchDay.id}')">
                                <div style="width: 15px; height: 15px; background: ${awayTeam ? this.getTeamColor(awayTeam) : '#ccc'}; border-radius: 50%; margin-right: 0.5rem;"></div>
                                <span style="font-weight: 500;">${awayTeam ? awayTeam.name : '⚠️ Team Not Found'}</span>
                            </div>
                            <button class="btn btn-danger btn-sm" onclick="event.stopPropagation(); app.deleteMatch('${match.id}')" style="margin-left: 0.5rem; font-size: 0.7rem; padding: 0.25rem 0.5rem;">Delete</button>
                        </div>
                        <div style="display: flex; align-items: center; font-size: 0.9rem; color: #666; cursor: pointer;" onclick="app.viewMatch('${match.id}', '${matchDay.id}')">
                            <span>${new Date(match.scheduledTime).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}</span>
                            <span style="margin: 0 0.5rem;">•</span>
                            <span>Field ${match.field}</span>
                            <span style="margin-left: auto; background: #4CAF50; color: white; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.8rem;">
                                ${match.status}
                            </span>
                        </div>
                    </div>
                `;
            }).join('');

        const content = `
            <div style="margin-bottom: 1.5rem;">
                <h3 style="margin: 0 0 0.5rem 0; font-size: 1.3rem;">${matchDay.name}</h3>
                <p style="margin: 0; color: #666;">${new Date(matchDay.date).toLocaleDateString()}</p>
                ${matchDay.notes ? `<p style="margin: 0.5rem 0 0 0; color: #666;">${matchDay.notes}</p>` : ''}
            </div>
            
            <div>
                <h4 style="margin-bottom: 1rem;">Scheduled Matches</h4>
                <div style="border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
                    ${matchesHtml}
                </div>
            </div>
            
            <div class="form-actions" style="margin-top: 1.5rem;">
                <button type="button" class="btn btn-secondary" onclick="app.hideModal()">Close</button>
                <button type="button" class="btn btn-danger" onclick="app.deleteMatchDay('${matchDayId}')">Delete Match Day</button>
                <button type="button" class="btn btn-primary" onclick="app.addMatchToMatchDay('${matchDayId}')">Add Match</button>
            </div>
        `;

        this.showModal('Match Day Details', content);
    }

    async deleteMatch(matchId) {
        // Find the match and its match day
        let match = null;
        let matchDay = null;
        
        for (const md of this.data.matchDays) {
            const foundMatch = md.matches.find(m => m.id === matchId);
            if (foundMatch) {
                match = foundMatch;
                matchDay = md;
                break;
            }
        }

        if (!match || !matchDay) return;

        const homeTeam = this.data.teams.find(t => t.id === match.homeTeamId);
        const awayTeam = this.data.teams.find(t => t.id === match.awayTeamId);
        
        const matchDescription = `${homeTeam ? homeTeam.name : 'Unknown Team'} vs ${awayTeam ? awayTeam.name : 'Unknown Team'}`;
        const matchTime = new Date(match.scheduledTime).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
        
        // Confirm deletion
        if (!confirm(`Are you sure you want to delete this match?\n\n${matchDescription}\n${matchTime} - Field ${match.field}\n\nThis action cannot be undone.`)) {
            return;
        }

        try {
            // Remove match from the match day
            matchDay.matches = matchDay.matches.filter(m => m.id !== matchId);
            matchDay.lastModified = Date.now() / 1000;

            // Update server
            const response = await fetch(`${this.serverURL}/matchdays`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(this.data.matchDays)
            });

            if (response.ok) {
                this.updateUI();
                this.viewMatchDay(matchDay.id); // Refresh the match day view
                this.showToast('Match deleted successfully', 'success');
            } else {
                throw new Error('Failed to delete match');
            }
        } catch (error) {
            console.error('Error deleting match:', error);
            this.showToast('Failed to delete match', 'error');
            // Restore match if server update failed
            matchDay.matches.push(match);
        }
    }

    async deleteMatchDay(matchDayId) {
        const matchDay = this.data.matchDays.find(md => md.id === matchDayId);
        if (!matchDay) return;

        // Confirm deletion
        const matchCount = matchDay.matches.length;
        const warningMessage = matchCount > 0
            ? `Are you sure you want to delete "${matchDay.name}"?\n\nThis match day has ${matchCount} scheduled match${matchCount > 1 ? 'es' : ''} that will also be deleted.\n\nThis action cannot be undone.`
            : `Are you sure you want to delete "${matchDay.name}"?\n\nThis action cannot be undone.`;
        
        if (!confirm(warningMessage)) {
            return;
        }

        try {
            // Remove match day from local data
            this.data.matchDays = this.data.matchDays.filter(md => md.id !== matchDayId);

            // Update server
            const response = await fetch(`${this.serverURL}/matchdays`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(this.data.matchDays)
            });

            if (response.ok) {
                this.hideModal();
                this.updateUI();
                this.showToast('Match day deleted successfully', 'success');
            } else {
                throw new Error('Failed to delete match day');
            }
        } catch (error) {
            console.error('Error deleting match day:', error);
            this.showToast('Failed to delete match day', 'error');
            // Restore match day if server update failed
            this.data.matchDays.push(matchDay);
            this.data.matchDays.sort((a, b) => new Date(a.date) - new Date(b.date));
        }
    }

    // Utility functions
    getTeamColor(team) {
        return team.colorData || '#2196F3';
    }

    isToday(date) {
        const today = new Date();
        return date.toDateString() === today.toDateString();
    }

    generateUUID() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            const r = Math.random() * 16 | 0;
            const v = c == 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    showLoading(message = 'Loading...') {
        const overlay = document.getElementById('loading-overlay');
        overlay.querySelector('p').textContent = message;
        overlay.classList.remove('hidden');
    }

    hideLoading() {
        document.getElementById('loading-overlay').classList.add('hidden');
    }

    showToast(message, type = 'info') {
        const container = document.getElementById('toast-container');
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.textContent = message;
        
        container.appendChild(toast);
        
        // Remove toast after 3 seconds
        setTimeout(() => {
            toast.remove();
        }, 3000);
    }
}

// Initialize the app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.app = new SoccerRefereeApp();
});

// Service Worker registration for PWA
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .then(registration => {
                console.log('SW registered: ', registration);
            })
            .catch(registrationError => {
                console.log('SW registration failed: ', registrationError);
            });
    });
}