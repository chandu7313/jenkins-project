const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;
// Add middleware to parse JSON bodies
app.use(express.json());

app.get('/', async (req, res) => {
    res.send(`
        <h1>Welcome to the app</h1>
        <h2>Name: KAVYASRI</h2>
    `);
});

// Changed from GET to POST to match the test
app.post('/add', async (req, res) => {
    const { num1, num2 } = req.body;

    // Fixed validation - correct way to check if values are numbers
    if (typeof num1 !== 'number' || typeof num2 !== 'number') {
        return res.status(400).json({
            error: "Invalid input. Both num1 and num2 should be numbers."
        });
    }

    return res.json({ result: num1 + num2 });
});

module.exports = app;

if (require.main === module) {
    app.listen(PORT, () => {
        console.log(`Server is running on port ${PORT}`);
    });
}