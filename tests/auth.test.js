const request = require('supertest');
const bcrypt = require('bcryptjs');

jest.mock('mysql2/promise', () => ({
  createConnection: jest.fn()
}));

jest.mock('../llm_service', () => ({
  generateMBTIAnalysis: jest.fn(),
  generateDevelopmentSuggestions: jest.fn(),
  generateMBTIFromLogsText: jest.fn()
}));

jest.mock('../nlp_service', () => ({
  extractKeywords: jest.fn()
}));

const mysql = require('mysql2/promise');
const app = require('../simple_server_final');

const SECRET = 'your_jwt_secret_key_here_change_this_in_production';

function createMockConnection(responses = []) {
  const queue = [...responses];
  return {
    execute: jest.fn().mockImplementation(() => {
      if (queue.length === 0) {
        return Promise.resolve([[]]);
      }
      return Promise.resolve(queue.shift());
    }),
    end: jest.fn().mockResolvedValue()
  };
}

function queueConnections(connections) {
  const copies = [...connections];
  mysql.createConnection.mockImplementation(() => {
    if (copies.length === 0) {
      throw new Error('No mocked connections available');
    }
    return Promise.resolve(copies.shift());
  });
}

describe('Auth endpoints', () => {
  beforeEach(() => {
    mysql.createConnection.mockReset();
  });

  test('POST /api/login succeeds with valid credentials', async () => {
    const hashedPassword = bcrypt.hashSync('password123', 10);

    const connection = createMockConnection([
      [[{
        id: 1,
        username: 'demo',
        email: 'demo@example.com',
        password_hash: hashedPassword,
        real_name: 'Demo User',
        phone: '123456789',
        position: 'tester',
        avatar_url: null
      }]]
    ]);

    queueConnections([connection]);

    const response = await request(app)
      .post('/api/login')
      .send({ username: 'demo', password: 'password123' });

    expect(response.status).toBe(200);
    expect(response.body).toEqual(
      expect.objectContaining({
        success: true,
        token: expect.any(String),
        user: expect.objectContaining({
          username: 'demo',
          email: 'demo@example.com'
        })
      })
    );
  });

  test('POST /api/login fails with wrong password', async () => {
    const hashedPassword = bcrypt.hashSync('password123', 10);
    const connection = createMockConnection([
      [[{
        id: 1,
        username: 'demo',
        email: 'demo@example.com',
        password_hash: hashedPassword,
        real_name: 'Demo User',
        phone: '123456789',
        position: 'tester',
        avatar_url: null
      }]]
    ]);

    queueConnections([connection]);

    const response = await request(app)
      .post('/api/login')
      .send({ username: 'demo', password: 'wrong-password' });

    expect(response.status).toBe(401);
    expect(response.body.success).toBe(false);
  });

  test('GET /api/health responds with success payload', async () => {
    const response = await request(app).get('/api/health');
    expect(response.status).toBe(200);
    expect(response.body).toEqual(
      expect.objectContaining({
        success: true,
        message: '服务器运行正常'
      })
    );
  });
});

