const request = require('supertest');
const app = require('../index');

describe('test the api', () => {

    test('test get method api', async () => {
        const res = await request(app).get('/');
        expect(res.statusCode).toBe(200);
        expect(res.text.replace(/\s+/g, " ").trim()).toBe(
            "<h1>Welcome to the app</h1> <h2>Name: KAVYASRI</h2>"
        );
    });

    test('test post method api', async () => {
        const res = await request(app)
            .post('/add')
            .send({ num1: 10, num2: 15 });

        expect(res.statusCode).toBe(200);
        expect(res.body.result).toBe(25);
    });

});