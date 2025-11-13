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
const { extractKeywords } = require('../nlp_service');
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

describe('Log endpoints', () => {
  beforeEach(() => {
    mysql.createConnection.mockReset();
    extractKeywords.mockReset();
  });

  test('POST /api/logs creates a log for the authenticated user', async () => {
    extractKeywords.mockResolvedValue([]);

    const logRow = {
      id: 10,
      author_user_id: 1,
      title: 'Daily Update',
      content: 'Completed module A',
      log_type: 'work',
      priority: 'medium',
      progress: 80,
      time_from: '2024-01-01 09:00:00',
      time_to: '2024-01-01 10:30:00',
      task_id: null,
      log_status: 'completed',
      created_at: '2024-01-01 11:00:00',
      updated_at: '2024-01-01 11:05:00'
    };

    const connection = createMockConnection([
      [{ insertId: 10 }],
      [[logRow]]
    ]);

    queueConnections([connection]);

    const token = jwt.sign({ userId: 1, username: 'demo' }, SECRET);

    const response = await request(app)
      .post('/api/logs')
      .set('Authorization', `Bearer ${token}`)
      .send({
        title: logRow.title,
        content: logRow.content,
        priority: logRow.priority,
        progress: logRow.progress,
        type: logRow.log_type,
        timeFrom: logRow.time_from,
        timeTo: logRow.time_to,
        logStatus: logRow.log_status
      });

    expect(response.status).toBe(201);
    expect(response.body.success).toBe(true);
    expect(response.body.log).toEqual(expect.objectContaining({
      id: logRow.id,
      content: logRow.content,
      log_status: logRow.log_status
    }));
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO logs'),
      expect.arrayContaining([1, logRow.title, logRow.content])
    );
  });

  test('POST /api/logs requires non-empty content', async () => {
    const token = jwt.sign({ userId: 1, username: 'demo' }, SECRET);

    const response = await request(app)
      .post('/api/logs')
      .set('Authorization', `Bearer ${token}`)
      .send({ title: 'No content here' });

    expect(response.status).toBe(400);
    expect(response.body.success).toBe(false);
    expect(mysql.createConnection).not.toHaveBeenCalled();
  });

  test('GET /api/logs returns the user log list', async () => {
    const rows = [{
      id: 5,
      author_user_id: 1,
      title: 'Retro',
      content: 'Reviewed sprint tasks',
      log_type: 'work',
      priority: 'high',
      time_from: '2024-02-01 09:00:00',
      time_to: '2024-02-01 10:00:00',
      created_at: '2024-02-01 10:01:00',
      updated_at: '2024-02-01 10:02:00',
      task_id: null,
      log_status: 'pending'
    }];

    const connection = createMockConnection([
      [rows]
    ]);

    queueConnections([connection]);

    const token = jwt.sign({ userId: 1, username: 'demo' }, SECRET);

    const response = await request(app)
      .get('/api/logs')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data).toHaveLength(1);
    expect(response.body.data[0]).toEqual(expect.objectContaining({
      id: rows[0].id,
      userId: rows[0].author_user_id,
      logStatus: rows[0].log_status
    }));
  });

  test('GET /api/logs/:id/keywords returns keywords when log exists', async () => {
    const connection = createMockConnection([
      [[{ id: 3 }]],
      [[{ keyword: 'focus', score: 0.8 }]]
    ]);

    queueConnections([connection]);

    const token = jwt.sign({ userId: 1, username: 'demo' }, SECRET);

    const response = await request(app)
      .get('/api/logs/3/keywords')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data).toEqual([{ keyword: 'focus', score: 0.8 }]);
  });

  test('GET /api/logs/:id/keywords returns 404 when log missing', async () => {
    const connection = createMockConnection([
      [[]]
    ]);

    queueConnections([connection]);

    const token = jwt.sign({ userId: 1, username: 'demo' }, SECRET);

    const response = await request(app)
      .get('/api/logs/99/keywords')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(404);
    expect(response.body.success).toBe(false);
  });

  test('GET /api/logs/keywords enforces time range', async () => {
    const token = jwt.sign({ userId: 1, username: 'demo' }, SECRET);

    const response = await request(app)
      .get('/api/logs/keywords')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(400);
    expect(response.body.success).toBe(false);
    expect(response.body.message).toMatch(/时间范围/);
    expect(mysql.createConnection).not.toHaveBeenCalled();
  });
});

