const request = require('supertest');
const jwt = require('jsonwebtoken');

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
const llmService = require('../llm_service');
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

describe('MBTI analysis endpoints', () => {
  beforeEach(() => {
    mysql.createConnection.mockReset();
    llmService.generateMBTIAnalysis.mockReset();
    llmService.generateMBTIFromLogsText.mockReset();
  });

  test('GET /api/user/mbti-analysis returns analysis when keywords exist', async () => {
    llmService.generateMBTIAnalysis.mockResolvedValue({
      mbti: 'INTJ',
      analysis: 'Test analysis'
    });

    const keywordConnection = createMockConnection([
      [[{ keyword: 'focus', score: 3 }]]
    ]);

    const cacheConnection = createMockConnection([
      [[]], // ensureMbtiCacheTable
      [[]]  // insert cache
    ]);

    queueConnections([keywordConnection, cacheConnection]);

    const token = jwt.sign({ userId: 1, username: 'demo' }, SECRET);

    const response = await request(app)
      .get('/api/user/mbti-analysis?force=true')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data).toEqual(
      expect.objectContaining({
        mbti: 'INTJ',
        analysis: 'Test analysis'
      })
    );
    expect(llmService.generateMBTIAnalysis).toHaveBeenCalledWith(['focus']);
  });
});

