const express = require('express');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;
const AI_SERVER_URL = 'http://localhost:5000';

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname)));

app.post('/api/ask', async (req, res) => {
    try {
        const response = await fetch(`${AI_SERVER_URL}/api/ask`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(req.body)
        });
        const data = await response.json();
        res.json(data);
    } catch (error) {
        console.error('AI Server error:', error.message);
        res.status(500).json({ 
            error: 'AI server is not running. Please start the Python server first.',
            answer: 'Sorry, the AI server is currently unavailable. Please make sure the Python AI server is running on port 5000.'
        });
    }
});

app.get('/api/health', async (req, res) => {
    try {
        const response = await fetch(`${AI_SERVER_URL}/api/health`);
        const data = await response.json();
        res.json(data);
    } catch (error) {
        res.status(500).json({ status: 'error', message: 'AI server not available' });
    }
});

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'ai_chat.html'));
});

app.listen(PORT, () => {
    console.log(`Node.js server running on http://localhost:${PORT}`);
    console.log(`AI Chat interface: http://localhost:${PORT}`);
    console.log('Make sure the Python AI server is running on port 5000');
});
