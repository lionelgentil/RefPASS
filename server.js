const express = require('express');
const cors = require('cors');
const fs = require('fs').promises;
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' })); // Large limit for player photos
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Serve static files from web-app directory with aggressive no-cache control
app.use(express.static(path.join(__dirname, 'web-app'), {
    setHeaders: (res, path) => {
        // Disable caching for all files without Last-Modified/ETag to prevent conditional requests
        res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate, private');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');
        
        // Additional headers for HTML and JS files
        if (path.endsWith('.js') || path.endsWith('.html')) {
            res.setHeader('X-Content-Type-Options', 'nosniff');
            res.setHeader('Vary', 'Accept-Encoding');
        }
    }
}));

// Data storage paths
const DATA_DIR = path.join(__dirname, 'data');
const TEAMS_FILE = path.join(DATA_DIR, 'teams.json');
const MATCHDAYS_FILE = path.join(DATA_DIR, 'matchdays.json');

// Ensure data directory exists
async function ensureDataDir() {
    try {
        await fs.mkdir(DATA_DIR, { recursive: true });
        console.log(`📁 Data directory ready: ${DATA_DIR}`);
    } catch (error) {
        console.error('Error creating data directory:', error);
    }
}

// Helper function to read JSON file
async function readJSONFile(filePath, defaultValue = []) {
    try {
        const data = await fs.readFile(filePath, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        if (error.code === 'ENOENT') {
            // File doesn't exist, create it with default value
            await writeJSONFile(filePath, defaultValue);
            return defaultValue;
        }
        console.error(`Error reading ${filePath}:`, error);
        return defaultValue;
    }
}

// Helper function to write JSON file
async function writeJSONFile(filePath, data) {
    try {
        await fs.writeFile(filePath, JSON.stringify(data, null, 2));
        return true;
    } catch (error) {
        console.error(`Error writing ${filePath}:`, error);
        return false;
    }
}

// Initialize server data
async function initializeData() {
    await ensureDataDir();
    
    // Initialize empty files if they don't exist
    await readJSONFile(TEAMS_FILE, []);
    await readJSONFile(MATCHDAYS_FILE, []);
    
    console.log('📊 Data files initialized');
}

// API Routes

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        message: 'Soccer Referee Server is running',
        uptime: process.uptime()
    });
});

// Teams endpoints
app.get('/api/teams', async (req, res) => {
    try {
        const teams = await readJSONFile(TEAMS_FILE);
        console.log(`📤 Serving ${teams.length} teams`);
        res.json(teams);
    } catch (error) {
        console.error('Error fetching teams:', error);
        res.status(500).json({ error: 'Failed to fetch teams' });
    }
});

app.post('/api/teams', async (req, res) => {
    try {
        const teams = req.body;
        
        if (!Array.isArray(teams)) {
            return res.status(400).json({ error: 'Teams data must be an array' });
        }
        
        const success = await writeJSONFile(TEAMS_FILE, teams);
        if (success) {
            console.log(`📥 Updated ${teams.length} teams`);
            res.json({ success: true, message: 'Teams updated successfully', count: teams.length });
        } else {
            res.status(500).json({ error: 'Failed to update teams' });
        }
    } catch (error) {
        console.error('Error updating teams:', error);
        res.status(500).json({ error: 'Failed to update teams' });
    }
});

// Individual team endpoint
app.get('/api/teams/:id', async (req, res) => {
    try {
        const teams = await readJSONFile(TEAMS_FILE);
        const team = teams.find(t => t.id === req.params.id);
        
        if (!team) {
            return res.status(404).json({ error: 'Team not found' });
        }
        
        res.json(team);
    } catch (error) {
        console.error('Error reading team:', error);
        res.status(500).json({ error: 'Failed to read team data' });
    }
});

// Match days endpoints
app.get('/api/matchdays', async (req, res) => {
    try {
        const matchDays = await readJSONFile(MATCHDAYS_FILE);
        console.log(`📤 Serving ${matchDays.length} match days`);
        res.json(matchDays);
    } catch (error) {
        console.error('Error fetching match days:', error);
        res.status(500).json({ error: 'Failed to fetch match days' });
    }
});

app.post('/api/matchdays', async (req, res) => {
    try {
        const matchDays = req.body;
        
        if (!Array.isArray(matchDays)) {
            return res.status(400).json({ error: 'Match days data must be an array' });
        }
        
        // Sort by date
        matchDays.sort((a, b) => new Date(a.date) - new Date(b.date));
        
        const success = await writeJSONFile(MATCHDAYS_FILE, matchDays);
        if (success) {
            console.log(`📥 Updated ${matchDays.length} match days`);
            res.json({ success: true, message: 'Match days updated successfully', count: matchDays.length });
        } else {
            res.status(500).json({ error: 'Failed to update match days' });
        }
    } catch (error) {
        console.error('Error updating match days:', error);
        res.status(500).json({ error: 'Failed to update match days' });
    }
});

// Individual match day endpoint
app.get('/api/matchdays/:id', async (req, res) => {
    try {
        const matchDays = await readJSONFile(MATCHDAYS_FILE);
        const matchDay = matchDays.find(md => md.id === req.params.id);
        
        if (!matchDay) {
            return res.status(404).json({ error: 'Match day not found' });
        }
        
        res.json(matchDay);
    } catch (error) {
        console.error('Error reading match day:', error);
        res.status(500).json({ error: 'Failed to read match day data' });
    }
});

// Unified sync endpoint
app.get('/api/sync', async (req, res) => {
    try {
        const teams = await readJSONFile(TEAMS_FILE);
        const matchDays = await readJSONFile(MATCHDAYS_FILE);
        
        res.json({ teams, matchDays });
    } catch (error) {
        console.error('Error in sync endpoint:', error);
        res.status(500).json({ error: 'Failed to sync data' });
    }
});

app.post('/api/sync', async (req, res) => {
    try {
        const { teams, matchDays } = req.body;
        
        if (!Array.isArray(teams) || !Array.isArray(matchDays)) {
            return res.status(400).json({ error: 'Teams and matchDays must be arrays' });
        }
        
        const teamsSuccess = await writeJSONFile(TEAMS_FILE, teams);
        const matchDaysSuccess = await writeJSONFile(MATCHDAYS_FILE, matchDays);
        
        if (teamsSuccess && matchDaysSuccess) {
            console.log(`🔄 Sync update: ${teams.length} teams, ${matchDays.length} match days`);
            res.json({ 
                success: true, 
                message: 'Data synced successfully',
                teamsCount: teams.length,
                matchDaysCount: matchDays.length
            });
        } else {
            res.status(500).json({ error: 'Failed to sync data' });
        }
    } catch (error) {
        console.error('Error in sync endpoint:', error);
        res.status(500).json({ error: 'Failed to sync data' });
    }
});

// Statistics endpoint
app.get('/api/stats', async (req, res) => {
    try {
        const teams = await readJSONFile(TEAMS_FILE);
        const matchDays = await readJSONFile(MATCHDAYS_FILE);
        
        const totalPlayers = teams.reduce((sum, team) => sum + (team.players?.length || 0), 0);
        const totalMatches = matchDays.reduce((sum, md) => sum + (md.matches?.length || 0), 0);
        
        const stats = {
            totalTeams: teams.length,
            totalPlayers: totalPlayers,
            totalMatchDays: matchDays.length,
            totalMatches: totalMatches,
            lastUpdated: new Date().toISOString()
        };
        
        res.json(stats);
    } catch (error) {
        console.error('Error calculating stats:', error);
        res.status(500).json({ error: 'Failed to calculate statistics' });
    }
});

// Backup endpoint
app.get('/api/backup', async (req, res) => {
    try {
        const teams = await readJSONFile(TEAMS_FILE);
        const matchDays = await readJSONFile(MATCHDAYS_FILE);
        
        const backup = {
            teams,
            matchDays,
            exportDate: new Date().toISOString(),
            version: '1.0.0'
        };
        
        res.setHeader('Content-Disposition', 'attachment; filename=soccer-referee-backup.json');
        res.json(backup);
    } catch (error) {
        console.error('Error creating backup:', error);
        res.status(500).json({ error: 'Failed to create backup' });
    }
});

// Serve the web app with aggressive no-cache headers
app.get('/', (req, res) => {
    // Apply aggressive no-cache headers without Last-Modified/ETag to prevent conditional requests
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate, private');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Vary', 'Accept-Encoding');
    
    res.sendFile(path.join(__dirname, 'web-app', 'index.html'));
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Server error:', error);
    res.status(500).json({ 
        error: 'Internal server error',
        message: error.message 
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ 
        error: 'Endpoint not found',
        path: req.path 
    });
});

// Start server
async function startServer() {
    try {
        await initializeData();
        
        app.listen(PORT, () => {
            console.log(`🚀 Soccer Referee Server running on port ${PORT}`);
            console.log(`📱 Web App: http://localhost:${PORT}`);
            console.log(`🔄 API Base: http://localhost:${PORT}/api/`);
            console.log(`📊 Health Check: http://localhost:${PORT}/api/health`);
            console.log(`📈 Statistics: http://localhost:${PORT}/api/stats`);
            console.log(`💾 Backup: http://localhost:${PORT}/api/backup`);
            console.log(`\n🎯 Available Endpoints:`);
            console.log(`  GET/POST /api/teams      - Teams management`);
            console.log(`  GET/POST /api/matchdays  - Match days management`);
            console.log(`  GET/POST /api/sync       - Unified sync`);
            console.log(`  GET      /api/stats      - Statistics`);
            console.log(`  GET      /api/backup     - Data backup`);
        });
    } catch (error) {
        console.error('Failed to start server:', error);
        process.exit(1);
    }
}

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    process.exit(0);
});

startServer();

module.exports = app;