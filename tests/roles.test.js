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

describe('Role & permission endpoints', () => {
  const token = jwt.sign({ userId: 1, username: 'admin' }, SECRET);

  beforeEach(() => {
    mysql.createConnection.mockReset();
  });

  test('GET /api/roles returns role list when user has role:view', async () => {
    const permissionConnection = createMockConnection([
      [[{ perm_key: 'role:view' }]]
    ]);
    const rolesConnection = createMockConnection([
      [[{
        id: 1,
        role_name: 'Admin',
        description: 'System administrator',
        created_at: '2024-01-01 00:00:00',
        user_count: 3
      }]]
    ]);

    queueConnections([permissionConnection, rolesConnection]);

    const response = await request(app)
      .get('/api/roles')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.roles).toHaveLength(1);
    expect(permissionConnection.execute).toHaveBeenCalledWith(
      expect.stringContaining('SELECT DISTINCT p.perm_key'),
      [1]
    );
    expect(rolesConnection.execute).toHaveBeenCalledWith(
      expect.stringContaining('SELECT r.id, r.role_name')
    );
  });

  test('GET /api/roles denies access without role:view permission', async () => {
    const permissionConnection = createMockConnection([
      [[]]
    ]);

    queueConnections([permissionConnection]);

    const response = await request(app)
      .get('/api/roles')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(403);
    expect(response.body.success).toBe(false);
  });

  test('GET /api/roles/:roleId/permissions returns entries when permitted', async () => {
    const permissionConnection = createMockConnection([
      [[{ perm_key: 'role:view' }]]
    ]);
    const dataConnection = createMockConnection([
      [[{
        id: 7,
        perm_key: 'task:edit',
        name: 'Edit task',
        module: 'task',
        description: 'Edit task details'
      }]]
    ]);

    queueConnections([permissionConnection, dataConnection]);

    const response = await request(app)
      .get('/api/roles/2/permissions')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.permissions).toEqual([
      expect.objectContaining({ perm_key: 'task:edit' })
    ]);
  });

  test('POST /api/users/:userId/roles assigns roles when permitted', async () => {
    const permissionConnection = createMockConnection([
      [[{ perm_key: 'user:assign_role' }]]
    ]);
    const assignConnection = createMockConnection([
      [[{ affectedRows: 1 }]],
      [[{ affectedRows: 1 }]],
      [[{ affectedRows: 1 }]]
    ]);

    queueConnections([permissionConnection, assignConnection]);

    const response = await request(app)
      .post('/api/users/5/roles')
      .set('Authorization', `Bearer ${token}`)
      .send({ roleIds: [2, 3] });

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(assignConnection.execute).toHaveBeenCalledWith(
      'DELETE FROM user_roles WHERE user_id = ?',
      [5]
    );
    expect(assignConnection.execute).toHaveBeenCalledWith(
      'INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)',
      [5, 2]
    );
    expect(assignConnection.execute).toHaveBeenCalledWith(
      'INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)',
      [5, 3]
    );
  });

  test('POST /api/users/:userId/roles validates request body', async () => {
    const permissionConnection = createMockConnection([
      [[{ perm_key: 'user:assign_role' }]]
    ]);

    queueConnections([permissionConnection]);

    const response = await request(app)
      .post('/api/users/5/roles')
      .set('Authorization', `Bearer ${token}`)
      .send({ roleIds: 'not-an-array' });

    expect(response.status).toBe(400);
    expect(response.body.success).toBe(false);
    expect(mysql.createConnection).toHaveBeenCalledTimes(1);
  });

  test('POST /api/roles/:roleId/permissions assigns permissions when permitted', async () => {
    const permissionConnection = createMockConnection([
      [[{ perm_key: 'role:assign_permission' }]]
    ]);
    const updateConnection = createMockConnection([
      [[{ affectedRows: 1 }]],
      [[{ affectedRows: 1 }]],
      [[{ affectedRows: 1 }]]
    ]);

    queueConnections([permissionConnection, updateConnection]);

    const response = await request(app)
      .post('/api/roles/4/permissions')
      .set('Authorization', `Bearer ${token}`)
      .send({ permissionIds: [7, 8] });

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(updateConnection.execute).toHaveBeenCalledWith(
      'DELETE FROM role_permissions WHERE role_id = ?',
      [4]
    );
    expect(updateConnection.execute).toHaveBeenCalledWith(
      'INSERT INTO role_permissions (role_id, permission_id) VALUES (?, ?)',
      [4, 7]
    );
    expect(updateConnection.execute).toHaveBeenCalledWith(
      'INSERT INTO role_permissions (role_id, permission_id) VALUES (?, ?)',
      [4, 8]
    );
  });
});

