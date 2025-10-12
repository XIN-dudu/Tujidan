const express = require('express');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;

// 中间件
app.use(cors());
app.use(express.json());

// 数据库配置（优化连接）
const dbConfig = {
  host: '117.72.181.99',
  user: 'tu',
  password: 'tu123',
  database: 'tujidan',
  port: 3306,
  charset: 'utf8mb4',
  connectTimeout: 60000,    // 增加到60秒
  keepAliveInitialDelay: 0,
  enableKeepAlive: true,
};

const JWT_SECRET = 'your_jwt_secret_key_here_change_this_in_production';

// 工具: 规范化前端传来的时间为 MySQL DATETIME 格式
function toMySQLDateTime(value) {
  if (value === undefined || value === null || value === '') return null;
  try {
    const d = new Date(value);
    if (isNaN(d.getTime())) return null;
    // 转成 UTC 的 'YYYY-MM-DD HH:MM:SS'
    const iso = d.toISOString().slice(0, 19); // YYYY-MM-DDTHH:MM:SS
    return iso.replace('T', ' ');
  } catch (e) {
    return null;
  }
}

// 鉴权中间件
async function auth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return res.status(401).json({ success: false, message: '未提供token' });
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = { id: decoded.userId, username: decoded.username };
    return next();
  } catch (e) {
    return res.status(401).json({ success: false, message: 'token无效' });
  }
}

// 权限检查中间件
function checkPermission(permission) {
  return async (req, res, next) => {
    try {
      const connection = await getConn();
      
      // 获取用户的所有权限
      const [permissions] = await connection.execute(`
        SELECT DISTINCT p.perm_key 
        FROM permissions p
        JOIN role_permissions rp ON p.id = rp.permission_id
        JOIN user_roles ur ON rp.role_id = ur.role_id
        WHERE ur.user_id = ?
      `, [req.user.id]);
      
      await connection.end();
      
      const userPermissions = permissions.map(p => p.perm_key);
      
      // 检查是否有指定权限
      if (!userPermissions.includes(permission)) {
        return res.status(403).json({ 
          success: false, 
          message: '权限不足' 
        });
      }
      
      next();
    } catch (e) {
      console.error('权限检查失败:', e);
      return res.status(500).json({ 
        success: false, 
        message: '权限检查失败' 
      });
    }
  };
}

// 获取数据库连接
async function getConn() {
  return mysql.createConnection(dbConfig);
}

// 检查用户是否有指定权限的辅助函数
async function checkUserPermission(userId, permission) {
  try {
    const connection = await getConn();
    
    const [permissions] = await connection.execute(`
      SELECT DISTINCT p.perm_key 
      FROM permissions p
      JOIN role_permissions rp ON p.id = rp.permission_id
      JOIN user_roles ur ON rp.role_id = ur.role_id
      WHERE ur.user_id = ? AND p.perm_key = ?
    `, [userId, permission]);
    
    await connection.end();
    return permissions.length > 0;
  } catch (e) {
    console.error('检查用户权限失败:', e);
    return false;
  }
}

// 测试数据库连接（带重试）
async function testConnection(retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      console.log(`🔄 尝试连接数据库... (${i + 1}/${retries})`);
      const connection = await mysql.createConnection(dbConfig);
      console.log('✅ 数据库连接成功');
      await connection.end();
      return;
    } catch (error) {
      console.error(`❌ 数据库连接失败 (尝试 ${i + 1}/${retries}):`, error.message);
      if (i < retries - 1) {
        console.log('⏳ 等待3秒后重试...');
        await new Promise(resolve => setTimeout(resolve, 3000));
      }
    }
  }
  console.error('❌ 数据库连接最终失败，请检查网络和配置');
}

// 注册接口
app.post('/api/register', async (req, res) => {
  try {
    const { username, password, email, realName, phone, position } = req.body;

    if (!username || !password || !realName) {
      return res.status(400).json({ 
        success: false, 
        message: '用户名、密码和真实姓名不能为空' 
      });
    }

    if (password.length < 6) {
      return res.status(400).json({ 
        success: false, 
        message: '密码至少6位' 
      });
    }

    const connection = await mysql.createConnection(dbConfig);

    // 检查用户名是否已存在
    const [existingUsername] = await connection.execute(
      'SELECT id FROM users WHERE username = ?',
      [username]
    );

    if (existingUsername.length > 0) {
      await connection.end();
      return res.status(400).json({ 
        success: false, 
        message: '该用户名已被注册' 
      });
    }

    // 检查邮箱是否已存在（如果提供了邮箱）
    if (email) {
      const [existingEmail] = await connection.execute(
        'SELECT id FROM users WHERE email = ?',
        [email]
      );

      if (existingEmail.length > 0) {
        await connection.end();
        return res.status(400).json({ 
          success: false, 
          message: '该邮箱已被注册' 
        });
      }
    }

    // 加密密码
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // 创建用户
    const [result] = await connection.execute(
      'INSERT INTO users (username, password_hash, email, real_name, phone, position, status) VALUES (?, ?, ?, ?, ?, ?, 1)',
      [username, hashedPassword, email || null, realName, phone || null, position || null]
    );

    await connection.end();

    // 生成JWT token
    const token = jwt.sign(
      { userId: result.insertId, username },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      success: true,
      message: '注册成功',
      token,
      user: { 
        id: result.insertId, 
        username, 
        email, 
        realName, 
        phone, 
        position 
      }
    });

  } catch (error) {
    console.error('注册失败:', error);
    res.status(500).json({ 
      success: false, 
      message: '服务器内部错误' 
    });
  }
});

// 登录接口
app.post('/api/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ 
        success: false, 
        message: '用户名和密码不能为空' 
      });
    }

    const connection = await mysql.createConnection(dbConfig);

    // 查找用户（支持用户名或邮箱登录）
    const [users] = await connection.execute(
      'SELECT * FROM users WHERE (username = ? OR email = ?) AND status = 1',
      [username, username]
    );

    await connection.end();

    if (users.length === 0) {
      return res.status(401).json({ 
        success: false, 
        message: '用户名或密码错误' 
      });
    }

    const user = users[0];

    // 验证密码
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({ 
        success: false, 
        message: '用户名或密码错误' 
      });
    }

    // 生成JWT token
    const token = jwt.sign(
      { userId: user.id, username: user.username },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      success: true,
      message: '登录成功',
      token,
      user: { 
        id: user.id, 
        username: user.username, 
        email: user.email,
        realName: user.real_name,
        phone: user.phone,
        position: user.position,
        avatarUrl: user.avatar_url
      }
    });

  } catch (error) {
    console.error('登录失败:', error);
    res.status(500).json({ 
      success: false, 
      message: '服务器内部错误' 
    });
  }
});

// 验证token接口
app.get('/api/verify', async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ 
        success: false, 
        message: '未提供token' 
      });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    const connection = await mysql.createConnection(dbConfig);

    const [users] = await connection.execute(
      'SELECT id, username, email, real_name, phone, position, avatar_url, status FROM users WHERE id = ? AND status = 1',
      [decoded.userId]
    );

    await connection.end();

    if (users.length === 0) {
      return res.status(401).json({ 
        success: false, 
        message: '用户不存在或已被禁用' 
      });
    }

    const user = users[0];
    res.json({
      success: true,
      user: { 
        id: user.id, 
        username: user.username,
        email: user.email,
        realName: user.real_name,
        phone: user.phone,
        position: user.position,
        avatarUrl: user.avatar_url
      }
    });

  } catch (error) {
    console.error('验证token失败:', error);
    res.status(401).json({ 
      success: false, 
      message: 'token无效' 
    });
  }
});

// 健康检查接口
app.get('/api/health', (req, res) => {
  res.json({ 
    success: true, 
    message: '服务器运行正常',
    timestamp: new Date().toISOString()
  });
});

// ---- Users（简易搜索，MVP：仅返回当前用户） ----
app.get('/api/users', auth, async (req, res) => {
  try {
    const connection = await getConn();
    const [users] = await connection.execute(
      'SELECT id, username, email, real_name, phone, position, avatar_url FROM users WHERE id = ? AND status = 1 LIMIT 1',
      [req.user.id]
    );
    await connection.end();
    return res.json({ success: true, users });
  } catch (e) {
    console.error('查询用户失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// ---- RBAC 相关接口 ----

// 获取用户角色和权限
app.get('/api/user/permissions', auth, async (req, res) => {
  try {
    const connection = await getConn();
    
    // 获取用户角色
    const [roles] = await connection.execute(`
      SELECT r.id, r.role_name, r.description 
      FROM roles r
      JOIN user_roles ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `, [req.user.id]);
    
    // 获取用户权限
    const [permissions] = await connection.execute(`
      SELECT DISTINCT p.id, p.perm_key, p.name, p.module, p.description
      FROM permissions p
      JOIN role_permissions rp ON p.id = rp.permission_id
      JOIN user_roles ur ON rp.role_id = ur.role_id
      WHERE ur.user_id = ?
      ORDER BY p.module, p.perm_key
    `, [req.user.id]);
    
    await connection.end();
    
    res.json({
      success: true,
      roles,
      permissions
    });
  } catch (e) {
    console.error('获取用户权限失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 获取所有角色
app.get('/api/roles', auth, checkPermission('role:view'), async (req, res) => {
  try {
    const connection = await getConn();
    const [roles] = await connection.execute(`
      SELECT r.id, r.role_name, r.description, r.created_at,
             COUNT(ur.user_id) as user_count
      FROM roles r
      LEFT JOIN user_roles ur ON r.id = ur.role_id
      GROUP BY r.id
      ORDER BY r.created_at DESC
    `);
    await connection.end();
    res.json({ success: true, roles });
  } catch (e) {
    console.error('获取角色列表失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 获取所有权限
app.get('/api/permissions', auth, checkPermission('role:view'), async (req, res) => {
  try {
    const connection = await getConn();
    const [permissions] = await connection.execute(`
      SELECT id, perm_key, name, module, description, created_at
      FROM permissions
      ORDER BY module, perm_key
    `);
    await connection.end();
    res.json({ success: true, permissions });
  } catch (e) {
    console.error('获取权限列表失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 获取角色权限
app.get('/api/roles/:roleId/permissions', auth, checkPermission('role:view'), async (req, res) => {
  try {
    const roleId = parseInt(req.params.roleId, 10);
    const connection = await getConn();
    
    const [permissions] = await connection.execute(`
      SELECT p.id, p.perm_key, p.name, p.module, p.description
      FROM permissions p
      JOIN role_permissions rp ON p.id = rp.permission_id
      WHERE rp.role_id = ?
      ORDER BY p.module, p.perm_key
    `, [roleId]);
    
    await connection.end();
    res.json({ success: true, permissions });
  } catch (e) {
    console.error('获取角色权限失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 为用户分配角色
app.post('/api/users/:userId/roles', auth, checkPermission('user:assign_role'), async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    const { roleIds } = req.body;
    
    if (!Array.isArray(roleIds)) {
      return res.status(400).json({ success: false, message: '角色ID列表格式错误' });
    }
    
    const connection = await getConn();
    
    // 删除用户现有角色
    await connection.execute('DELETE FROM user_roles WHERE user_id = ?', [userId]);
    
    // 添加新角色
    for (const roleId of roleIds) {
      await connection.execute(
        'INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)',
        [userId, roleId]
      );
    }
    
    await connection.end();
    res.json({ success: true, message: '角色分配成功' });
  } catch (e) {
    console.error('分配角色失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 为角色分配权限
app.post('/api/roles/:roleId/permissions', auth, checkPermission('role:assign_permission'), async (req, res) => {
  try {
    const roleId = parseInt(req.params.roleId, 10);
    const { permissionIds } = req.body;
    
    if (!Array.isArray(permissionIds)) {
      return res.status(400).json({ success: false, message: '权限ID列表格式错误' });
    }
    
    const connection = await getConn();
    
    // 删除角色现有权限
    await connection.execute('DELETE FROM role_permissions WHERE role_id = ?', [roleId]);
    
    // 添加新权限
    for (const permissionId of permissionIds) {
      await connection.execute(
        'INSERT INTO role_permissions (role_id, permission_id) VALUES (?, ?)',
        [roleId, permissionId]
      );
    }
    
    await connection.end();
    res.json({ success: true, message: '权限分配成功' });
  } catch (e) {
    console.error('分配权限失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// ---- Tasks ----
app.get('/api/tasks', auth, async (req, res) => {
  try {
    const keyword = (req.query.keyword || '').trim();
    const raw = parseInt(req.query.limit || '20', 10);
    const limit = Number.isFinite(raw) && raw > 0 && raw <= 50 ? raw : 20;
    const connection = await getConn();
    let sql = 'SELECT id, name, priority, progress, due_time, owner_user_id, creator_user_id FROM tasks WHERE creator_user_id = ?';
    const params = [req.user.id];
    if (keyword) {
      sql += ' AND name LIKE ?';
      params.push(`%${keyword}%`);
    }
    sql += ` ORDER BY updated_at DESC LIMIT ${limit}`;
    const [rows] = await connection.execute(sql, params);
    await connection.end();
    res.json({ success: true, tasks: rows });
  } catch (e) {
    console.error('查询任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

app.post('/api/tasks', auth, async (req, res) => {
  try {
    const { name, priority = 'low', progress = 0, dueTime = null, ownerUserId } = req.body;
    if (!name || !ownerUserId) {
      return res.status(400).json({ success: false, message: '任务名称与负责人必填' });
    }
    if (typeof name !== 'string' || name.length > 64) {
      return res.status(400).json({ success: false, message: '任务名称长度超限' });
    }
    const connection = await getConn();
    // 唯一性：同创建者下不重名
    const [dup] = await connection.execute(
      'SELECT id FROM tasks WHERE name = ? AND creator_user_id = ? LIMIT 1',
      [name, req.user.id]
    );
    if (dup.length > 0) {
      await connection.end();
      return res.status(409).json({ success: false, message: '任务名称不能重复' });
    }
    const [result] = await connection.execute(
      'INSERT INTO tasks (name, priority, progress, due_time, owner_user_id, creator_user_id) VALUES (?, ?, ?, ?, ?, ?)',
      [name, priority, Math.min(Math.max(progress, 0), 100), dueTime, ownerUserId, req.user.id]
    );
    const [rows] = await connection.execute(
      'SELECT id, name, priority, progress, due_time, owner_user_id, creator_user_id FROM tasks WHERE id = ?',
      [result.insertId]
    );
    await connection.end();
    res.status(201).json({ success: true, task: rows[0] });
  } catch (e) {
    console.error('创建任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

app.patch('/api/tasks/:id', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { name, priority, progress, dueTime, ownerUserId } = req.body;
    const connection = await getConn();
    // 仅允许任务创建者修改
    const [exists] = await connection.execute('SELECT id FROM tasks WHERE id = ? AND creator_user_id = ? LIMIT 1', [id, req.user.id]);
    if (exists.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '任务不存在' });
    }
    await connection.execute(
      'UPDATE tasks SET name = COALESCE(?, name), priority = COALESCE(?, priority), progress = COALESCE(?, progress), due_time = COALESCE(?, due_time), owner_user_id = COALESCE(?, owner_user_id) WHERE id = ?',
      [name, priority, progress, dueTime, ownerUserId, id]
    );
    const [rows] = await connection.execute('SELECT id, name, priority, progress, due_time, owner_user_id, creator_user_id FROM tasks WHERE id = ?', [id]);
    await connection.end();
    res.json({ success: true, task: rows[0] });
  } catch (e) {
    console.error('更新任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

app.delete('/api/tasks/:id', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const connection = await getConn();
    await connection.execute('DELETE FROM tasks WHERE id = ? AND creator_user_id = ?', [id, req.user.id]);
    await connection.end();
    res.json({ success: true });
  } catch (e) {
    console.error('删除任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// ---- Logs ----
app.post('/api/logs', auth, async (req, res) => {
  try {
    const { content, priority = 'low', progress = 0, timeFrom = null, timeTo = null, taskId = null, createNewTask = null, syncTaskProgress = false } = req.body;
    if (!content || typeof content !== 'string') {
      return res.status(400).json({ success: false, message: '日志内容不能为空' });
    }
    const connection = await getConn();
    let finalTaskId = taskId;
    if (!finalTaskId && createNewTask && createNewTask.name) {
      const { name, priority: tPriority = 'low', progress: tProgress = 0, dueTime = null, ownerUserId = req.user.id } = createNewTask;
      const [dup] = await connection.execute('SELECT id FROM tasks WHERE name = ? AND creator_user_id = ? LIMIT 1', [name, req.user.id]);
      if (dup.length > 0) {
        await connection.end();
        return res.status(409).json({ success: false, message: '任务名称不能重复' });
      }
      const [tRes] = await connection.execute(
        'INSERT INTO tasks (name, priority, progress, due_time, owner_user_id, creator_user_id) VALUES (?, ?, ?, ?, ?, ?)',
        [name, tPriority, Math.min(Math.max(tProgress, 0), 100), dueTime, ownerUserId, req.user.id]
      );
      finalTaskId = tRes.insertId;
    }

    const [lRes] = await connection.execute(
      'INSERT INTO logs (author_user_id, content, priority, progress, time_from, time_to, task_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        req.user.id,
        content,
        priority,
        Math.min(Math.max(progress, 0), 100),
        toMySQLDateTime(timeFrom),
        toMySQLDateTime(timeTo),
        finalTaskId,
      ]
    );

    if (syncTaskProgress && finalTaskId) {
      await connection.execute('UPDATE tasks SET progress = ?, priority = ? WHERE id = ?', [Math.min(Math.max(progress, 0), 100), priority, finalTaskId]);
    }

    const [logRows] = await connection.execute('SELECT * FROM logs WHERE id = ?', [lRes.insertId]);
    let taskRow = null;
    if (finalTaskId) {
      const [tRows] = await connection.execute('SELECT id, name, priority, progress, due_time, owner_user_id, creator_user_id FROM tasks WHERE id = ?', [finalTaskId]);
      taskRow = tRows[0] || null;
    }
    await connection.end();
    res.status(201).json({ success: true, log: logRows[0], task: taskRow });
  } catch (e) {
    console.error('创建日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

app.get('/api/logs', auth, async (req, res) => {
  try {
    const connection = await getConn();
    const { type, q, startDate, endDate } = req.query;

    // 检查用户是否有查看所有日志的权限
    const hasViewAllPermission = await checkUserPermission(req.user.id, 'log:view_all');
    
    const params = hasViewAllPermission ? [] : [req.user.id];
    let sql = hasViewAllPermission ? 'SELECT * FROM logs' : 'SELECT * FROM logs WHERE author_user_id = ?';

    // 类型过滤
    if (type && ['work', 'study', 'life', 'other'].includes(type)) {
      sql += ' AND log_type = ?';
      params.push(type);
    }

    // 时间范围过滤
    if (startDate && endDate) {
      sql += ' AND created_at BETWEEN ? AND ?';
      params.push(startDate, endDate);
    }

    // 搜索关键词过滤
    if (q && q.trim() !== '') {
      sql += ' AND content LIKE ?';
      params.push(`%${q.trim()}%`);
    }

    // 时间倒序，限制100条
    sql += ' ORDER BY created_at DESC LIMIT 100';

    const [rows] = await connection.execute(sql, params);
    await connection.end();

    // 返回前端固定结构
    res.json({
      success: true,
      message: '获取日志成功',
      data: rows.map(row => ({
        id: row.id,
        userId: row.author_user_id, // 修改这里
        title: row.title,
        content: row.content,
        logType: row.log_type,
        priority: row.priority,
        logStatus: row.log_status,
        startTime: row.start_time,
        endTime: row.end_time,
        totalHours: row.total_hours,
        timeTag: row.time_tag,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        taskId: row.task_id,
      })),
      code: 200,
    });
  } catch (e) {
    console.error('查询日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误', code: 500 });
  }
});



app.get('/api/logs/:id', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const connection = await getConn();
    const [rows] = await connection.execute(
      'SELECT * FROM logs WHERE id = ? AND author_user_id = ? LIMIT 1',
      [id, req.user.id]
    );
    await connection.end();
    if (rows.length === 0) return res.status(404).json({ success: false, message: '日志不存在' });
    res.json({ success: true, log: rows[0] });
  } catch (e) {
    console.error('获取日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});


app.get('/api/logs/:id', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const connection = await getConn();
    const [rows] = await connection.execute('SELECT * FROM logs WHERE id = ? AND author_user_id = ? LIMIT 1', [id, req.user.id]);
    await connection.end();
    if (rows.length === 0) return res.status(404).json({ success: false, message: '日志不存在' });
    res.json({ success: true, log: rows[0] });
  } catch (e) {
    console.error('获取日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

app.patch('/api/logs/:id', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { content, priority, progress, timeFrom, timeTo, taskId, syncTaskProgress = false } = req.body;
    const connection = await getConn();
    const [exists] = await connection.execute('SELECT id, task_id FROM logs WHERE id = ? AND author_user_id = ? LIMIT 1', [id, req.user.id]);
    if (exists.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '日志不存在' });
    }
    const toNull = (v) => (v === undefined ? null : v);
    const params = [
      toNull(content),
      toNull(priority),
      toNull(progress),
      toMySQLDateTime(timeFrom),
      toMySQLDateTime(timeTo),
      toNull(taskId),
      id,
    ];
    await connection.execute(
      'UPDATE logs SET content = COALESCE(?, content), priority = COALESCE(?, priority), progress = COALESCE(?, progress), time_from = COALESCE(?, time_from), time_to = COALESCE(?, time_to), task_id = COALESCE(?, task_id) WHERE id = ?',
      params
    );
    if (syncTaskProgress && (taskId || exists[0].task_id)) {
      const targetTaskId = taskId || exists[0].task_id;
      if (typeof progress === 'number' || typeof priority === 'string') {
        await connection.execute('UPDATE tasks SET progress = COALESCE(?, progress), priority = COALESCE(?, priority) WHERE id = ?', [progress, priority, targetTaskId]);
      }
    }
    const [rows] = await connection.execute('SELECT * FROM logs WHERE id = ?', [id]);
    await connection.end();
    res.json({ success: true, log: rows[0] });
  } catch (e) {
    console.error('更新日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

app.delete('/api/logs/:id', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const connection = await getConn();
    await connection.execute('DELETE FROM logs WHERE id = ? AND author_user_id = ?', [id, req.user.id]);
    await connection.end();
    res.json({ success: true });
  } catch (e) {
    console.error('删除日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 启动服务器
app.listen(PORT, () => {
  console.log(`🚀 服务器运行在 http://localhost:${PORT}`);
  console.log(`📊 健康检查: http://localhost:${PORT}/api/health`);
  testConnection();
});
