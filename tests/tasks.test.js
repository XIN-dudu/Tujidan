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

describe('Task endpoints', () => {
  beforeEach(() => {
    mysql.createConnection.mockReset();
  });

  test('PATCH /api/tasks/:id/progress updates progress when requester is assignee', async () => {
    const connection = createMockConnection([
      [[{ id: 1, assignee_id: 1, creator_id: 2 }]],
      [[]],
      [[{
        id: 1,
        task_name: 'Demo Task',
        description: 'Work',
        priority: 'medium',
        status: 'in_progress',
        progress: 60,
        plan_start_time: null,
        due_time: null,
        owner_user_id: 1,
        creator_user_id: 2,
        created_at: '2024-01-01T00:00:00.000Z',
        updated_at: '2024-01-02T00:00:00.000Z'
      }]]
    ]);

    queueConnections([connection]);

    const token = jwt.sign({ userId: 1, username: 'demo' }, SECRET);

    const response = await request(app)
      .patch('/api/tasks/1/progress')
      .set('Authorization', `Bearer ${token}`)
      .send({ progress: 60 });

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.task).toEqual(
      expect.objectContaining({
        id: 1,
        status: 'in_progress',
        progress: 60
      })
    );
  });

  test('PATCH /api/tasks/:id/progress without token returns 401', async () => {
    const response = await request(app)
      .patch('/api/tasks/1/progress')
      .send({ progress: 60 });

    expect(response.status).toBe(401);
  });
});

