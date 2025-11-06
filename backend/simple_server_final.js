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

// 工具: 将前端传来的任务状态映射为数据库允许的取值
function normalizeTaskStatus(input) {
  const s = (input || '').toString().toLowerCase();
  switch (s) {
    case 'pending_assignment':
    case 'pendingassignment':
    case 'to_be_assigned':
    case 'tobeassigned':
      return 'pending_assignment';
    case 'pending':
    case 'not_started':
      return 'not_started';
    case 'inprogress':
    case 'in_progress':
    case 'doing':
      return 'in_progress';
    case 'paused':
      return 'paused';
    case 'completed':
    case 'done':
      return 'completed';
    case 'closed':
      return 'closed';
    case 'cancelled':
    case 'canceled':
      return 'cancelled';
    default:
      return 'not_started';
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

// 数据库迁移：确保log_status字段存在
async function migrateDatabase() {
  try {
    console.log('🔄 检查数据库结构...');
    const connection = await mysql.createConnection(dbConfig);
    
    // 检查logs表是否有log_status字段
    const [columns] = await connection.execute(`
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'logs' AND COLUMN_NAME = 'log_status'
    `, [dbConfig.database]);
    
    if (columns.length === 0) {
      console.log('📝 添加log_status字段到logs表...');
      await connection.execute(`
        ALTER TABLE logs 
        ADD COLUMN log_status VARCHAR(20) DEFAULT 'pending' 
        COMMENT '日志状态: pending(进行中), completed(已完成), cancelled(已取消)'
      `);
      
      // 更新现有记录的默认状态
      await connection.execute(`
        UPDATE logs SET log_status = 'pending' WHERE log_status IS NULL OR log_status = ''
      `);
      console.log('✅ log_status字段添加成功');
    } else {
      console.log('✅ log_status字段已存在，正在修正其定义...');
      try {
        // 强制将列类型从 ENUM (或任何其他类型) 更改为 VARCHAR，并设置默认值
        await connection.execute(
          `ALTER TABLE logs CHANGE COLUMN log_status log_status VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'pending'`
        );
        console.log('✅ log_status 字段类型修正成功。');

        // 将所有旧的状态值统一为 'pending'
        console.log('🔄 统一旧的状态值...');
        await connection.execute(
          `UPDATE logs SET log_status = 'pending' WHERE log_status IN ('in_progress', 'not_start', 'paused')`
        );
        console.log('✅ 旧状态值统一完成。');
      } catch (error) {
        console.error('❌ 修正 log_status 字段时出错:', error.message);
      }
    }
    
    // 检查tasks表的status字段类型
    const [taskStatusColumns] = await connection.execute(`
      SELECT COLUMN_NAME, COLUMN_TYPE, COLUMN_DEFAULT
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'tasks' AND COLUMN_NAME = 'status'
    `, [dbConfig.database]);
    
    if (taskStatusColumns.length > 0) {
      const columnType = taskStatusColumns[0].COLUMN_TYPE;
      console.log('📋 tasks.status字段类型:', columnType);
      
      // 如果是ENUM类型，需要修改ENUM定义以包含新状态
      if (columnType.includes('enum')) {
        console.log('📝 修改tasks.status的ENUM定义以支持新状态...');
        try {
          await connection.execute(`
            ALTER TABLE tasks 
            MODIFY COLUMN status ENUM(
              'pending_assignment',
              'not_started',
              'in_progress',
              'paused',
              'completed',
              'closed',
              'cancelled'
            ) DEFAULT 'not_started'
            COMMENT '任务状态: pending_assignment(待分配), not_started(未开始), in_progress(进行中), paused(已暂停), completed(已完成), closed(已关闭), cancelled(已取消)'
          `);
          console.log('✅ tasks.status ENUM定义更新成功');
        } catch (error) {
          console.error('❌ 更新tasks.status ENUM定义失败:', error.message);
          // 如果ENUM修改失败，尝试转换为VARCHAR
          console.log('🔄 尝试将status字段转换为VARCHAR类型...');
          try {
            await connection.execute(`
              ALTER TABLE tasks 
              MODIFY COLUMN status VARCHAR(50) DEFAULT 'not_started'
              COMMENT '任务状态: pending_assignment(待分配), not_started(未开始), in_progress(进行中), paused(已暂停), completed(已完成), closed(已关闭), cancelled(已取消)'
            `);
            console.log('✅ tasks.status字段已转换为VARCHAR类型');
          } catch (varcharError) {
            console.error('❌ 转换VARCHAR类型失败:', varcharError.message);
          }
        }
      } else if (columnType.includes('varchar')) {
        // 如果是VARCHAR类型，检查长度是否足够
        const varcharLength = parseInt(columnType.match(/varchar\((\d+)\)/i)?.[1] || '20');
        if (varcharLength < 50) {
          console.log(`📝 扩展tasks.status字段长度从${varcharLength}到50...`);
          try {
            await connection.execute(`
              ALTER TABLE tasks 
              MODIFY COLUMN status VARCHAR(50) DEFAULT 'not_started'
              COMMENT '任务状态: pending_assignment(待分配), not_started(未开始), in_progress(进行中), paused(已暂停), completed(已完成), closed(已关闭), cancelled(已取消)'
            `);
            console.log('✅ tasks.status字段长度扩展成功');
          } catch (error) {
            console.error('❌ 扩展status字段长度失败:', error.message);
          }
        } else {
          console.log('✅ tasks.status字段类型和长度已满足要求');
        }
      } else {
        console.log('⚠️  tasks.status字段类型不是ENUM或VARCHAR，可能需要手动修改');
      }
    } else {
      console.log('⚠️  未找到tasks表的status字段');
    }
    
    await connection.end();
  } catch (error) {
    console.error('❌ 数据库迁移失败:', error.message);
  }
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

// ---- Users（用户搜索） ----

// 获取用户列表
app.get('/api/users', auth, async (req, res) => {
  try {
    const connection = await getConn();
    const [rows] = await connection.execute(
      'SELECT id, username, avatar_url, created_at, updated_at FROM users ORDER BY created_at DESC'
    );
    
    // 格式化用户数据以匹配前端期望
    const formattedUsers = rows.map(user => ({
      id: user.id.toString(),
      username: user.username,
      avatar_url: user.avatar_url,
      created_at: user.created_at,
      updated_at: user.updated_at
    }));
    
    await connection.end();
    res.json({ success: true, users: formattedUsers });
  } catch (e) {
    console.error('获取用户列表失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});
// 获取单个任务详情
app.get('/api/tasks/:id', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const connection = await getConn();
    
    // 获取用户角色
    const [roles] = await connection.execute(`
      SELECT r.role_name 
      FROM roles r
      JOIN user_roles ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `, [req.user.id]);
    
    const userRoles = roles.map(r => r.role_name);
    const isFounderOrAdmin = userRoles.includes('admin') || userRoles.includes('founder');
    const isDeptHead = userRoles.includes('dept_head');
    const isStaff = userRoles.includes('staff');
    
    // 获取任务基本信息
    const [taskRows] = await connection.execute(
      'SELECT id, task_name AS name, description, priority, status, progress, ' +
      'plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, ' +
      'creator_id AS creator_user_id, created_at, updated_at ' +
      'FROM tasks WHERE id = ? LIMIT 1',
      [id]
    );

    if (taskRows.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '任务不存在' });
    }
    
    const task = taskRows[0];
    
    // 检查查看权限
    if (!isFounderOrAdmin) {
      if (isDeptHead) {
        // dept_head只能查看自己创建的任务
        if (task.creator_user_id != req.user.id) {
          await connection.end();
          return res.status(403).json({ success: false, message: '只能查看自己创建的任务' });
        }
      } else if (isStaff) {
        // staff只能查看分配给自己的任务，且必须是已分配状态
        if (task.owner_user_id != req.user.id) {
          await connection.end();
          return res.status(403).json({ success: false, message: '只能查看分配给自己的任务' });
        }
        if (task.status == 'pending_assignment') {
          await connection.end();
          return res.status(403).json({ success: false, message: '任务尚未分配，无法查看' });
        }
      } else {
        // 其他角色或无角色，不能查看
        await connection.end();
        return res.status(403).json({ success: false, message: '无权查看此任务' });
      }
    }

    // 获取任务的相关日志
    const [logRows] = await connection.execute(
      'SELECT * FROM logs WHERE task_id = ? ORDER BY created_at DESC LIMIT 10',
      [id]
    );

    task.logs = logRows;

    await connection.end();
    res.json({ success: true, data: task });
  } catch (e) {
    console.error('获取任务详情失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

app.get('/api/users/search', auth, async (req, res) => {
  try {
    const connection = await getConn();
    const keyword = (req.query.keyword || '').toString().trim();
    let sql, params;
    if (keyword) {
      // 有关键词时，模糊搜索用户名和姓名（仅返回活跃用户）
      sql = 'SELECT id, username, real_name, email, avatar_url FROM users WHERE status = 1 AND (username LIKE ? OR real_name LIKE ?) ORDER BY id DESC LIMIT 20';
      params = [`%${keyword}%`, `%${keyword}%`];
    } else {
      // 没有关键词时，返回所有活跃用户（限制50个）
      sql = 'SELECT id, username, real_name, email, avatar_url FROM users WHERE status = 1 ORDER BY id DESC LIMIT 50';
      params = [];
    }
    // 新增：服务端日志输出，便于定位命中的是用户搜索处理器
    console.log('[GET /api/users/search] keyword =', keyword);
    console.log('[GET /api/users/search] sql =', sql);
    console.log('[GET /api/users/search] params =', params);

    const [userRows] = await connection.execute(sql, params);
    console.log('[GET /api/users/search] rows.length =', userRows.length);
    if (userRows.length > 0) {
      console.log('[GET /api/users/search] sample row =', userRows[0]);
    }

    await connection.end();
    return res.json({ success: true, users: userRows });
  } catch (e) {
    console.error('查询用户失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
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
    
    // 获取用户角色
    const [roles] = await connection.execute(`
      SELECT r.role_name 
      FROM roles r
      JOIN user_roles ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `, [req.user.id]);
    
    const userRoles = roles.map(r => r.role_name);
    // founder和admin权限完全一致，可以看到所有任务
    const isFounderOrAdmin = userRoles.includes('admin') || userRoles.includes('founder');
    const isDeptHead = userRoles.includes('dept_head');
    const isStaff = userRoles.includes('staff');
    
    let sql = 'SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id, created_at, updated_at FROM tasks';
    const params = [];
    let whereConditions = [];
    
    if (isFounderOrAdmin) {
      // founder/admin可以看到所有任务
      // 不需要额外条件
    } else if (isDeptHead) {
      // dept_head只能看到自己创建的任务
      whereConditions.push('creator_id = ?');
      params.push(req.user.id);
    } else if (isStaff) {
      // staff只能看到分配给自己的任务，且必须是已分配状态（不是pending_assignment）
      whereConditions.push('assignee_id = ?');
      whereConditions.push('status != ?');
      params.push(req.user.id, 'pending_assignment');
    } else {
      // 其他角色或无角色，默认看不到任何任务
      whereConditions.push('1 = 0'); // 永远为false，不返回任何结果
    }
    
    // 添加关键词搜索
    if (keyword) {
      whereConditions.push('task_name LIKE ?');
      params.push(`%${keyword}%`);
    }
    
    // 组合WHERE条件
    if (whereConditions.length > 0) {
      sql += ' WHERE ' + whereConditions.join(' AND ');
    }
    
    sql += ` ORDER BY updated_at DESC LIMIT ${limit}`;

    const [rows] = await connection.execute(sql, params);

    await connection.end();

    // 格式化任务数据以匹配前端期望
    const formattedTasks = rows.map(task => ({
      id: task.id.toString(),
      name: task.name,
      description: task.description,
      owner_user_id: task.owner_user_id?.toString() ?? '',
      creator_user_id: task.creator_user_id?.toString() ?? '',
      due_time: task.due_time,
      plan_start_time: task.plan_start_time,
      priority: task.priority,
      status: task.status,
      progress: task.progress,
      created_at: task.created_at,
      updated_at: task.updated_at
    }));

    res.json({ success: true, data: formattedTasks });
  } catch (e) {
    console.error('查询任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

app.post('/api/tasks', auth, async (req, res) => {
  try {
    const { name, description = null, priority = 'low', status = 'not_started', progress = 0, dueTime = null, planStartTime = null, ownerUserId } = req.body;
    if (!name) {
      return res.status(400).json({ success: false, message: '任务名称必填' });
    }
    if (typeof name !== 'string' || name.length > 64) {
      return res.status(400).json({ success: false, message: '任务名称长度超限' });
    }
    const connection = await getConn();
    
    // 获取用户角色
    const [roles] = await connection.execute(`
      SELECT r.role_name 
      FROM roles r
      JOIN user_roles ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `, [req.user.id]);
    
    const userRoles = roles.map(r => r.role_name);
    const isFounderOrAdmin = userRoles.includes('admin') || userRoles.includes('founder');
    const isDeptHead = userRoles.includes('dept_head');
    const isStaff = userRoles.includes('staff');
    
    // staff不能创建任务
    if (isStaff) {
      await connection.end();
      return res.status(403).json({ success: false, message: '普通员工不能创建任务' });
    }
    
    // founder/admin和dept_head可以创建任务
    // 唯一性：同创建者下不重名
    const [dup] = await connection.execute(
      'SELECT id FROM tasks WHERE task_name = ? AND creator_id = ? LIMIT 1',
      [name, req.user.id]
    );
    if (dup.length > 0) {
      await connection.end();
      return res.status(409).json({ success: false, message: '任务名称不能重复' });
    }
    // 转换日期时间格式
    const planStartDt = toMySQLDateTime(planStartTime);
    const dueDt = toMySQLDateTime(dueTime);
    
    // 确定任务状态和分配逻辑
    let finalAssigneeId = ownerUserId || req.user.id;
    let taskStatus;
    
    if (ownerUserId && ownerUserId !== req.user.id) {
      // 创建时指定了负责人（创建并分配）→ 状态为待处理
      taskStatus = 'not_started';
    } else {
      // 创建时未指定负责人或指定自己 → 状态为待分配
      taskStatus = 'pending_assignment';
      // 如果是待分配状态，assignee_id应该为NULL或创建者自己
      finalAssigneeId = req.user.id; // 临时设置为创建者，实际应该为NULL，但数据库不允许NULL
    }
    
    const [result] = await connection.execute(
      'INSERT INTO tasks (task_name, description, priority, status, progress, plan_start_time, plan_end_time, assignee_id, creator_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [name, description, priority, taskStatus, Math.min(Math.max(progress, 0), 100), planStartDt, dueDt, finalAssigneeId, req.user.id]
    );
    const [rows] = await connection.execute(
      'SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?',
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
    const { name, description, priority, status, progress, dueTime, planStartTime, ownerUserId } = req.body;
    const connection = await getConn();
    
    // 获取用户角色
    const [roles] = await connection.execute(`
      SELECT r.role_name 
      FROM roles r
      JOIN user_roles ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `, [req.user.id]);
    
    const userRoles = roles.map(r => r.role_name);
    const isFounderOrAdmin = userRoles.includes('admin') || userRoles.includes('founder');
    const isDeptHead = userRoles.includes('dept_head');
    const isStaff = userRoles.includes('staff');
    
    // 检查任务是否存在
    const [exists] = await connection.execute('SELECT id, creator_id, assignee_id FROM tasks WHERE id = ? LIMIT 1', [id]);
    if (exists.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '任务不存在' });
    }
    
    const task = exists[0];
    
    // 检查编辑权限
    if (isFounderOrAdmin) {
      // founder/admin可以编辑任何任务
    } else if (isDeptHead) {
      // dept_head只能编辑自己创建的任务
      if (task.creator_id !== req.user.id) {
        await connection.end();
        return res.status(403).json({ success: false, message: '只能编辑自己创建的任务' });
      }
    } else if (isStaff) {
      // staff只能编辑分配给自己的任务（仅限进度、状态等有限字段）
      if (task.assignee_id !== req.user.id) {
        await connection.end();
        return res.status(403).json({ success: false, message: '只能编辑分配给自己的任务' });
      }
      // 限制可编辑字段：staff不能修改分配、优先级等
      if (ownerUserId !== undefined && ownerUserId !== task.assignee_id) {
        await connection.end();
        return res.status(403).json({ success: false, message: '普通员工不能修改任务分配' });
      }
    } else {
      await connection.end();
      return res.status(403).json({ success: false, message: '无权编辑此任务' });
    }
    // 转换日期时间格式
    const planStartDt = toMySQLDateTime(planStartTime);
    const dueDt = toMySQLDateTime(dueTime);
    await connection.execute(
      'UPDATE tasks SET task_name = COALESCE(?, task_name), description = COALESCE(?, description), priority = COALESCE(?, priority), status = COALESCE(?, status), progress = COALESCE(?, progress), plan_start_time = COALESCE(?, plan_start_time), plan_end_time = COALESCE(?, plan_end_time), assignee_id = COALESCE(?, assignee_id) WHERE id = ?',
      [name, description, priority, normalizeTaskStatus(status), progress, planStartDt, dueDt, ownerUserId, id]
    );
    const [rows] = await connection.execute('SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?', [id]);
    await connection.end();
    res.json({ success: true, task: rows[0] });
  } catch (e) {
    console.error('更新任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 根据进度决定任务状态
function getTaskStatusFromProgress(progress) {
  if (progress <= 0) {
    return 'not_started';
  } else if (progress > 0 && progress < 100) {
    return 'in_progress';
  } else {
    return 'completed';
  }
}

// 更新任务进度
app.patch('/api/tasks/:id/progress', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { progress } = req.body;

    if (typeof progress !== 'number' || progress < 0 || progress > 100) {
      return res.status(400).json({ success: false, message: '进度值必须是0-100的数字' });
    }

    const connection = await getConn();

    // 检查任务是否存在以及用户是否有权限更新
    const [tasks] = await connection.execute('SELECT id, assignee_id, creator_id FROM tasks WHERE id = ?', [id]);
    if (tasks.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '任务不存在' });
    }

    const task = tasks[0];
    // 只有负责人或创建者可以更新进度
    if (task.assignee_id !== req.user.id && task.creator_id !== req.user.id) {
      await connection.end();
      return res.status(403).json({ success: false, message: '无权更新此任务的进度' });
    }

    const newStatus = getTaskStatusFromProgress(progress);

    await connection.execute(
      'UPDATE tasks SET progress = ?, status = ? WHERE id = ?',
      [progress, newStatus, id]
    );

    const [rows] = await connection.execute('SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?', [id]);
    await connection.end();

    res.json({ success: true, task: rows[0] });
  } catch (e) {
    console.error('更新任务进度失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 根据进度决定任务状态
function getTaskStatusFromProgress(progress) {
  if (progress <= 0) {
    return 'not_started';
  } else if (progress > 0 && progress < 100) {
    return 'in_progress';
  } else {
    return 'completed';
  }
}

// 更新任务进度
app.patch('/api/tasks/:id/progress', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { progress } = req.body;

    if (typeof progress !== 'number' || progress < 0 || progress > 100) {
      return res.status(400).json({ success: false, message: '进度值必须是0-100的数字' });
    }

    const connection = await getConn();

    // 检查任务是否存在以及用户是否有权限更新
    const [tasks] = await connection.execute('SELECT id, assignee_id, creator_id FROM tasks WHERE id = ?', [id]);
    if (tasks.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '任务不存在' });
    }

    const task = tasks[0];
    // 只有负责人或创建者可以更新进度
    if (task.assignee_id !== req.user.id && task.creator_id !== req.user.id) {
      await connection.end();
      return res.status(403).json({ success: false, message: '无权更新此任务的进度' });
    }

    const newStatus = getTaskStatusFromProgress(progress);

    await connection.execute(
      'UPDATE tasks SET progress = ?, status = ? WHERE id = ?',
      [progress, newStatus, id]
    );

    const [rows] = await connection.execute('SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?', [id]);
    await connection.end();

    res.json({ success: true, task: rows[0] });
  } catch (e) {
    console.error('更新任务进度失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

app.delete('/api/tasks/:id', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const connection = await getConn();
    
    // 获取用户角色
    const [roles] = await connection.execute(`
      SELECT r.role_name 
      FROM roles r
      JOIN user_roles ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `, [req.user.id]);
    
    const userRoles = roles.map(r => r.role_name);
    const isFounderOrAdmin = userRoles.includes('admin') || userRoles.includes('founder');
    const isDeptHead = userRoles.includes('dept_head');
    const isStaff = userRoles.includes('staff');
    
    // 检查任务是否存在
    const [tasks] = await connection.execute('SELECT id, creator_id FROM tasks WHERE id = ?', [id]);
    if (tasks.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '任务不存在' });
    }
    
    const task = tasks[0];
    
    // staff不能删除任务
    if (isStaff) {
      await connection.end();
      return res.status(403).json({ success: false, message: '普通员工不能删除任务' });
    }
    
    // dept_head只能删除自己创建的任务
    if (isDeptHead && task.creator_id !== req.user.id) {
      await connection.end();
      return res.status(403).json({ success: false, message: '只能删除自己创建的任务' });
    }
    
    // founder/admin可以删除任何任务，dept_head可以删除自己创建的任务
    await connection.execute('DELETE FROM tasks WHERE id = ?', [id]);
    await connection.end();
    res.json({ success: true });
  } catch (e) {
    console.error('删除任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 任务发布（指定负责人并置为未开始）
app.post('/api/tasks/:id/publish', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { ownerUserId } = req.body;
    const connection = await getConn();
    
    // 获取用户角色
    const [roles] = await connection.execute(`
      SELECT r.role_name 
      FROM roles r
      JOIN user_roles ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `, [req.user.id]);
    
    const userRoles = roles.map(r => r.role_name);
    const isFounderOrAdmin = userRoles.includes('admin') || userRoles.includes('founder');
    const isDeptHead = userRoles.includes('dept_head');
    const isStaff = userRoles.includes('staff');
    
    // staff不能分配任务
    if (isStaff) {
      await connection.end();
      return res.status(403).json({ success: false, message: '普通员工不能分配任务' });
    }
    
    // 检查任务是否存在
    const [exists] = await connection.execute('SELECT id, assignee_id, status, creator_id FROM tasks WHERE id = ? LIMIT 1', [id]);
    if (exists.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '任务不存在' });
    }
    
    const task = exists[0];
    
    // dept_head只能分配自己创建的任务
    if (isDeptHead && task.creator_id !== req.user.id) {
      await connection.end();
      return res.status(403).json({ success: false, message: '只能分配自己创建的任务' });
    }
    
    // 判断是否应该撤回分配：任务已分配（status='not_started'且assignee_id已分配）
    const isAssigned = task.status == 'not_started' && task.assignee_id != null;
    
    if (isAssigned) {
      // 撤回分配：将status改回pending_assignment，assignee_id设置为创建者
      await connection.execute('UPDATE tasks SET assignee_id = ?, status = ? WHERE id = ?', [req.user.id, 'pending_assignment', id]);
    } else {
      // 分配任务：设置assignee_id和status（从pending_assignment变为not_started）
      // 如果ownerUserId为空，则设置为创建者（避免assignee_id为NULL）
      const finalAssigneeId = ownerUserId || req.user.id;
      await connection.execute('UPDATE tasks SET assignee_id = ?, status = ? WHERE id = ?', [finalAssigneeId, 'not_started', id]);
    }
    const [rows] = await connection.execute('SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?', [id]);
    await connection.end();
    res.json({ success: true, task: rows[0] });
  } catch (e) {
    console.error('发布/撤回任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 接收任务（接单/接受）
app.post('/api/tasks/:id/accept', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const connection = await getConn();
    
    // 获取用户角色
    const [roles] = await connection.execute(`
      SELECT r.role_name 
      FROM roles r
      JOIN user_roles ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `, [req.user.id]);
    
    const userRoles = roles.map(r => r.role_name);
    const isFounderOrAdmin = userRoles.includes('admin') || userRoles.includes('founder');
    const isDeptHead = userRoles.includes('dept_head');
    const isStaff = userRoles.includes('staff');
    
    const [taskInfo] = await connection.execute('SELECT id, assignee_id, status, creator_id FROM tasks WHERE id = ? LIMIT 1', [id]);
    if (taskInfo.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '任务不存在' });
    }
    
    const task = taskInfo[0];
    
    // staff只能接收分配给自己的任务，且必须是已分配状态
    if (isStaff) {
      if (task.assignee_id != req.user.id) {
        await connection.end();
        return res.status(403).json({ success: false, message: '只能接收分配给自己的任务' });
      }
      if (task.status == 'pending_assignment') {
        await connection.end();
        return res.status(403).json({ success: false, message: '任务尚未分配，无法接收' });
      }
    }
    
    // dept_head只能接收自己创建的任务
    if (isDeptHead && task.creator_id !== req.user.id) {
      await connection.end();
      return res.status(403).json({ success: false, message: '只能接收自己创建的任务' });
    }
    
    // 只有负责人能接收任务（founder/admin可以接收任意任务）
    if (!isFounderOrAdmin && task.assignee_id != req.user.id) {
      await connection.end();
      return res.status(403).json({ success: false, message: '只有任务负责人才能接收任务' });
    }
    
    // 只有状态为not_started的任务才能接收
    if (task.status != 'not_started') {
      await connection.end();
      return res.status(400).json({ success: false, message: '只有待开始的任务才能接收' });
    }
    await connection.execute('UPDATE tasks SET status = ? WHERE id = ?', ['in_progress', id]);
    const [rows] = await connection.execute('SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?', [id]);
    await connection.end();
    res.json({ success: true, task: rows[0] });
  } catch (e) {
    console.error('接收任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 取消接收任务（将状态改回待开始）
app.post('/api/tasks/:id/cancel-accept', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const connection = await getConn();
    const [taskInfo] = await connection.execute('SELECT id, assignee_id, status FROM tasks WHERE id = ? LIMIT 1', [id]);
    if (taskInfo.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '任务不存在' });
    }
    const task = taskInfo[0];
    // 检查当前用户是否是任务接收者
    if (task.assignee_id != req.user.id) {
      await connection.end();
      return res.status(403).json({ success: false, message: '只有任务接收者可以取消接收' });
    }
    // 将状态改回待开始，不清空负责人（保留分配记录）
    await connection.execute('UPDATE tasks SET status = ? WHERE id = ?', ['not_started', id]);
    const [rows] = await connection.execute('SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?', [id]);
    await connection.end();
    res.json({ success: true, task: rows[0] });
  } catch (e) {
    console.error('取消接收任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// ---- Logs ----
app.post('/api/logs', auth, async (req, res) => {
  try {
    const {
      title = null,
      content,
      priority = 'low',
      progress = 0,
      type = null,
      timeFrom = null,
      timeTo = null,
      taskId = null,
      createNewTask = null,
      syncTaskProgress = false,
      logStatus = 'pending',
    } = req.body;
    if (!content || typeof content !== 'string') {
      return res.status(400).json({ success: false, message: '日志内容不能为空' });
    }
    const connection = await getConn();
    let finalTaskId = taskId;
    if (!finalTaskId && createNewTask && createNewTask.name) {
      const { name, priority: tPriority = 'low', progress: tProgress = 0, dueTime = null, ownerUserId = req.user.id } = createNewTask;
      const [dup] = await connection.execute('SELECT id FROM tasks WHERE task_name = ? AND creator_id = ? LIMIT 1', [name, req.user.id]);
      if (dup.length > 0) {
        await connection.end();
        return res.status(409).json({ success: false, message: '任务名称不能重复' });
      }
      const dueDt = toMySQLDateTime(dueTime);
      const [tRes] = await connection.execute(
        'INSERT INTO tasks (task_name, priority, progress, plan_end_time, assignee_id, creator_id) VALUES (?, ?, ?, ?, ?, ?)',
        [name, tPriority, Math.min(Math.max(tProgress, 0), 100), dueDt, ownerUserId, req.user.id]
      );
      finalTaskId = tRes.insertId;
    }

    const startDt = toMySQLDateTime(timeFrom);
    const endDt = toMySQLDateTime(timeTo);

    const [lRes] = await connection.execute(
      'INSERT INTO logs (author_user_id, title, content, log_type, priority, progress, time_from, time_to, task_id, log_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [req.user.id, title, content, type, priority, Math.min(Math.max(progress, 0), 100), startDt, endDt, finalTaskId, logStatus || 'pending']
    );

    if (syncTaskProgress && finalTaskId) {
      await connection.execute('UPDATE tasks SET progress = ?, priority = ? WHERE id = ?', [Math.min(Math.max(progress, 0), 100), priority, finalTaskId]);
    }

    const [logRows] = await connection.execute('SELECT * FROM logs WHERE id = ?', [lRes.insertId]);
    let taskRow = null;
    if (finalTaskId) {
      const [tRows] = await connection.execute('SELECT id, task_name AS name, priority, progress, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?', [finalTaskId]);
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
    console.log('📋 收到日志查询请求:', req.query);
    console.log('👤 当前用户:', req.user);
    
    const connection = await getConn();
    const { type, q, startDate, endDate, startTime, endTime } = req.query;

    // 日志始终只显示当前用户自己的
    console.log('🔐 权限策略: 仅显示用户自己的日志');
    
    const params = [req.user.id];
    let sql = 'SELECT * FROM logs WHERE author_user_id = ?';

    // 类型过滤
    if (type && ['work', 'study', 'life', 'other'].includes(type)) {
      sql += ' AND log_type = ?';
      params.push(type);
    }

    // 时间范围过滤（优先使用 time_from；兼容 startTime/startDate 参数名）
    const rangeStart = startTime || startDate;
    const rangeEnd = endTime || endDate;
    if (rangeStart && rangeEnd) {
      sql += ' AND time_from BETWEEN ? AND ?';
      params.push(rangeStart, rangeEnd);
      console.log('📅 时间范围:', rangeStart, '至', rangeEnd);
    }

    // 搜索关键词过滤
    if (q && q.trim() !== '') {
      sql += ' AND content LIKE ?';
      params.push(`%${q.trim()}%`);
    }

    // 时间倒序，限制100条
    sql += ' ORDER BY created_at DESC LIMIT 100';

    console.log('🔍 执行SQL:', sql);
    console.log('📝 参数:', params);

    const [rows] = await connection.execute(sql, params);
    await connection.end();

    console.log(`✅ 查询成功，找到 ${rows.length} 条日志`);

    // 返回前端固定结构
    res.json({
      success: true,
      message: '获取日志成功',
      data: rows.map(row => ({
        id: row.id,
        userId: row.author_user_id,
        title: row.title,
        content: row.content,
        type: row.log_type,
        priority: row.priority,
        // 关键修复：使用 time_from/time_to
        startTime: row.time_from,
        endTime: row.time_to,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        taskId: row.task_id,
        logStatus: row.log_status, // 关键修复：返回日志状态
      })),
      code: 200,
    });
  } catch (e) {
    console.error('❌ 查询日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message, code: 500 });
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

app.patch('/api/logs/:id', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { title, content, type, priority, progress, timeFrom, timeTo, taskId, syncTaskProgress = false, logStatus } = req.body;
    
    console.log(`📝 更新日志 ${id}:`, {
      logStatus,
      title,
      content,
      type,
      priority,
      timeFrom,
      timeTo,
      taskId
    });
    const connection = await getConn();
    const [exists] = await connection.execute('SELECT id, task_id FROM logs WHERE id = ? AND author_user_id = ? LIMIT 1', [id, req.user.id]);
    if (exists.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '日志不存在' });
    }
    const toNull = (v) => (v === undefined ? null : v);
    
    // 构建动态更新语句
    const updates = [];
    const params = [];
    
    if (title !== undefined) {
      updates.push('title = ?');
      params.push(title);
    }
    if (content !== undefined) {
      updates.push('content = ?');
      params.push(content);
    }
    if (type !== undefined) {
      updates.push('log_type = ?');
      params.push(type);
    }
    if (priority !== undefined) {
      updates.push('priority = ?');
      params.push(priority);
    }
    if (progress !== undefined) {
      updates.push('progress = ?');
      params.push(Math.min(Math.max(progress, 0), 100));
    }
    if (timeFrom !== undefined) {
      updates.push('time_from = ?');
      params.push(toMySQLDateTime(timeFrom));
    }
    if (timeTo !== undefined) {
      updates.push('time_to = ?');
      params.push(toMySQLDateTime(timeTo));
    }
    if (taskId !== undefined) {
      updates.push('task_id = ?');
      params.push(taskId);
    }
    if (logStatus !== undefined) {
      const validStatus = ['pending', 'completed', 'cancelled'];
      let newStatus = logStatus.toLowerCase();
      if (newStatus === 'in_progress') {
        newStatus = 'pending';
      }
      if (validStatus.includes(newStatus)) {
        updates.push('log_status = ?');
        params.push(newStatus);
      }
    }
    
    if (updates.length > 0) {
      params.push(id);
      await connection.execute(
        `UPDATE logs SET ${updates.join(', ')} WHERE id = ?`,
        params
      );
    }
    if (syncTaskProgress && (taskId || exists[0].task_id)) {
      const targetTaskId = taskId || exists[0].task_id;
      if (typeof progress === 'number') { // 只在 progress 是数字时才更新
        await connection.execute('UPDATE tasks SET progress = COALESCE(?, progress) WHERE id = ?', [progress, targetTaskId]);
      }
    }
    const [rows] = await connection.execute('SELECT * FROM logs WHERE id = ?', [id]);
    await connection.end();
    
    console.log(`✅ 日志 ${id} 更新完成:`, {
      log_status: rows[0]?.log_status,
      title: rows[0]?.title
    });
    
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
app.listen(PORT, async () => {
  console.log(`🚀 服务器运行在 http://localhost:${PORT}`);
  console.log(`📊 健康检查: http://localhost:${PORT}/api/health`);
  await testConnection();
  await migrateDatabase();
});
