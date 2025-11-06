const express = require('express');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3002; // 使用不同端口

// 中间件
app.use(cors({
  origin: ['http://localhost:8000', 'http://127.0.0.1:8000', 'file://', 'http://localhost:3000'],
  credentials: true
}));
app.use(express.json());

// 添加请求日志中间件
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// 数据库配置（与主后端相同）
const dbConfig = {
  host: '117.72.181.99',
  user: 'tu',
  password: 'tu123',
  database: 'tujidan',
  port: 3306,
  charset: 'utf8mb4',
  connectTimeout: 60000,
  waitForConnections: true,
  connectionLimit: 10, // 连接池大小
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
};

const JWT_SECRET = 'your_jwt_secret_key_here_change_this_in_production';

// 创建连接池（性能优化：复用连接而不是每次创建新连接）
const pool = mysql.createPool(dbConfig);

// 获取数据库连接（从连接池获取）
async function getConn() {
  return pool.getConnection();
}

// 权限缓存（减少数据库查询）
const permissionCache = new Map();
const PERMISSION_CACHE_TTL = 5 * 60 * 1000; // 5分钟缓存

// 清除用户权限缓存
function clearPermissionCache(userId) {
  permissionCache.delete(userId);
}

// 获取用户权限（带缓存）
async function getUserPermissions(userId) {
  const cacheKey = `user_${userId}`;
  const cached = permissionCache.get(cacheKey);
  
  if (cached && Date.now() - cached.timestamp < PERMISSION_CACHE_TTL) {
    return cached.permissions;
  }
  
  const connection = await getConn();
  try {
    const [permissions] = await connection.execute(`
      SELECT DISTINCT p.perm_key 
      FROM permissions p
      JOIN role_permissions rp ON p.id = rp.permission_id
      JOIN user_roles ur ON rp.role_id = ur.role_id
      WHERE ur.user_id = ?
    `, [userId]);
    
    const permissionKeys = permissions.map(p => p.perm_key);
    
    // 更新缓存
    permissionCache.set(cacheKey, {
      permissions: permissionKeys,
      timestamp: Date.now()
    });
    
    return permissionKeys;
  } finally {
    connection.release(); // 释放连接回连接池
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

// 权限检查中间件（使用缓存优化）
function checkPermission(permission) {
  return async (req, res, next) => {
    try {
      const userPermissions = await getUserPermissions(req.user.id);
      
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

// 健康检查接口
app.get('/api/health', (req, res) => {
  res.json({ 
    success: true, 
    message: '管理后台服务器运行正常',
    timestamp: new Date().toISOString()
  });
});

// 注册/创建用户接口
app.post('/api/register', auth, async (req, res) => {
  try {
    const { username, password, email, realName, phone, position } = req.body;
    
    console.log('创建用户请求:', { username, realName, email });

    // 验证必填字段
    if (!username || !password || !realName) {
      return res.status(400).json({ 
        success: false, 
        message: '用户名、密码和真实姓名不能为空' 
      });
    }

    const connection = await getConn();

    // 检查用户名是否已存在
    const [existing] = await connection.execute(
      'SELECT id FROM users WHERE username = ?',
      [username]
    );

    if (existing.length > 0) {
      connection.release();
      return res.status(409).json({ 
        success: false, 
        message: '用户名已存在' 
      });
    }

    // 加密密码
    const hashedPassword = await bcrypt.hash(password, 10);

    // 插入新用户
    const [result] = await connection.execute(
      'INSERT INTO users (username, password_hash, email, real_name, phone, position, status, created_at) VALUES (?, ?, ?, ?, ?, ?, 1, NOW())',
      [username, hashedPassword, email || null, realName, phone || null, position || null]
    );

    connection.release();

    console.log('用户创建成功:', username, 'ID:', result.insertId);

    res.status(201).json({
      success: true,
      message: '用户创建成功',
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
    console.error('创建用户失败:', error);
    res.status(500).json({ 
      success: false, 
      message: '服务器内部错误: ' + error.message 
    });
  }
});

// 登录接口（复用主后端的逻辑）
app.post('/api/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ 
        success: false, 
        message: '用户名和密码不能为空' 
      });
    }

    const connection = await getConn();

    // 查找用户（支持用户名或邮箱登录）
    const [users] = await connection.execute(
      'SELECT * FROM users WHERE (username = ? OR email = ?) AND status = 1',
      [username, username]
    );

    if (users.length === 0) {
      connection.release();
      return res.status(401).json({ 
        success: false, 
        message: '用户名或密码错误' 
      });
    }

    const user = users[0];

    // 验证密码
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      connection.release();
      return res.status(401).json({ 
        success: false, 
        message: '用户名或密码错误' 
      });
    }

    // 检查用户是否有权限最高的两个角色（founder 或 admin）
    const [userRoles] = await connection.execute(`
      SELECT r.role_name 
      FROM roles r
      JOIN user_roles ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `, [user.id]);
    
    const roleNames = userRoles.map(r => r.role_name.toLowerCase());
    const allowedRoles = ['founder', 'admin'];
    const hasAllowedRole = roleNames.some(role => allowedRoles.includes(role));

    if (!hasAllowedRole) {
      connection.release();
      return res.status(403).json({ 
        success: false, 
        message: '您没有权限登录管理后台，只有创始人(founder)和管理员(admin)可以登录' 
      });
    }

    connection.release();

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
    const connection = await getConn();

    const [users] = await connection.execute(
      'SELECT id, username, email, real_name, phone, position, avatar_url, status FROM users WHERE id = ? AND status = 1',
      [decoded.userId]
    );

    connection.release();

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

// 管理员获取所有用户
app.get('/api/admin/users', auth, checkPermission('user:view'), async (req, res) => {
  try {
    const connection = await getConn();
    
    // 查询所有用户及其角色信息
    const [users] = await connection.execute(`
      SELECT 
        u.id, 
        u.username, 
        u.email, 
        u.real_name, 
        u.phone, 
        u.position, 
        u.avatar_url, 
        u.status, 
        u.created_at,
        GROUP_CONCAT(r.role_name ORDER BY r.id ASC SEPARATOR ',') as roles,
        GROUP_CONCAT(r.id ORDER BY r.id ASC SEPARATOR ',') as role_ids
      FROM users u
      LEFT JOIN user_roles ur ON u.id = ur.user_id
      LEFT JOIN roles r ON ur.role_id = r.id
      WHERE u.status = 1
      GROUP BY u.id
      ORDER BY u.created_at DESC
    `);
    
    // 处理角色信息，提取权限最高的角色（ID最小的）
    const processedUsers = users.map(user => {
      let primaryRole = null;
      let allRoles = [];
      
      if (user.roles && user.roles.trim() !== '') {
        allRoles = user.roles.split(',').map(r => r.trim()).filter(r => r !== '');
        primaryRole = allRoles.length > 0 ? allRoles[0] : null;
      }
      
      console.log(`用户 ${user.username} 的角色:`, {
        rawRoles: user.roles,
        primaryRole,
        allRoles,
        roleIds: user.role_ids
      });
      
      return {
        id: user.id,
        username: user.username,
        email: user.email,
        real_name: user.real_name,
        phone: user.phone,
        position: user.position,
        avatar_url: user.avatar_url,
        status: user.status,
        created_at: user.created_at,
        primaryRole,
        allRoles,
        roleIds: user.role_ids
      };
    });
    
    connection.release();
    return res.json({ success: true, users: processedUsers });
  } catch (e) {
    console.error('查询所有用户失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 获取单个用户详情
app.get('/api/users/:id', auth, async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const connection = await getConn();
    
    // 检查权限：用户只能查看自己的信息，或者有user:view权限
    const hasViewPermission = await checkUserPermission(req.user.id, 'user:view');
    const canView = (req.user.id === userId) || hasViewPermission;
    
    if (!canView) {
      connection.release();
      return res.status(403).json({ success: false, message: '权限不足' });
    }
    
    const [users] = await connection.execute(
      'SELECT id, username, email, real_name, phone, position, avatar_url, status, created_at FROM users WHERE id = ?',
      [userId]
    );
    connection.release();
    
    if (users.length === 0) {
      return res.status(404).json({ success: false, message: '用户不存在' });
    }
    
    return res.json({ success: true, user: users[0] });
  } catch (e) {
    console.error('查询用户详情失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 检查用户权限的辅助函数（使用缓存优化）
async function checkUserPermission(userId, permission) {
  try {
    const userPermissions = await getUserPermissions(userId);
    return userPermissions.includes(permission);
  } catch (e) {
    console.error('检查用户权限失败:', e);
    return false;
  }
}

// 更新用户信息
app.put('/api/users/:id', auth, async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const { username, realName, email, phone, position, password } = req.body;
    
    const connection = await getConn();
    
    // 检查权限：用户只能修改自己的信息，或者有user:edit权限
    const hasEditPermission = await checkUserPermission(req.user.id, 'user:edit');
    const canEdit = (req.user.id === userId) || hasEditPermission;
    
    if (!canEdit) {
      connection.release();
      return res.status(403).json({ success: false, message: '权限不足' });
    }
    
    // 构建更新字段
    const updateFields = [];
    const updateValues = [];
    
    if (username) {
      updateFields.push('username = ?');
      updateValues.push(username);
    }
    if (realName) {
      updateFields.push('real_name = ?');
      updateValues.push(realName);
    }
    if (email !== undefined) {
      updateFields.push('email = ?');
      updateValues.push(email);
    }
    if (phone !== undefined) {
      updateFields.push('phone = ?');
      updateValues.push(phone);
    }
    if (position !== undefined) {
      updateFields.push('position = ?');
      updateValues.push(position);
    }
    if (password) {
      const hashedPassword = await bcrypt.hash(password, 10);
      updateFields.push('password_hash = ?');
      updateValues.push(hashedPassword);
    }
    
    if (updateFields.length === 0) {
      connection.release();
      return res.status(400).json({ success: false, message: '没有要更新的字段' });
    }
    
    updateValues.push(userId);
    const sql = `UPDATE users SET ${updateFields.join(', ')} WHERE id = ?`;
    
    await connection.execute(sql, updateValues);
    connection.release();
    
    return res.json({ success: true, message: '用户信息更新成功' });
  } catch (e) {
    console.error('更新用户信息失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 删除用户（硬删除）
app.delete('/api/users/:id', auth, async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    
    console.log('删除用户请求:', { userId, currentUserId: req.user.id });
    
    // 检查是否尝试删除自己
    if (req.user.id === userId) {
      return res.status(403).json({ success: false, message: '不能删除自己' });
    }
    
    // 检查权限
    const hasDeletePermission = await checkUserPermission(req.user.id, 'user:delete');
    console.log('用户删除权限检查:', hasDeletePermission);
    
    if (!hasDeletePermission) {
      return res.status(403).json({ success: false, message: '权限不足，需要user:delete权限' });
    }
    
    const connection = await getConn();
    
    try {
      // 开始事务
      await connection.beginTransaction();
      
      // 1. 先删除用户角色关联
      await connection.execute('DELETE FROM user_roles WHERE user_id = ?', [userId]);
      console.log('已删除用户角色关联');
      
      // 2. 处理日志：删除用户相关的日志（因为外键约束不允许设置为NULL）
      // 如果希望保留日志，需要修改数据库外键约束为 ON DELETE SET NULL
      const [logResult] = await connection.execute('DELETE FROM logs WHERE author_user_id = ?', [userId]);
      console.log(`已删除 ${logResult.affectedRows} 条日志记录`);
      
      // 3. 处理任务：将任务的 creator_id 和 assignee_id 设置为 NULL（如果允许）
      // 如果外键约束不允许 NULL，则删除任务
      try {
        await connection.execute('UPDATE tasks SET creator_id = NULL WHERE creator_id = ?', [userId]);
        await connection.execute('UPDATE tasks SET assignee_id = NULL WHERE assignee_id = ?', [userId]);
        console.log('已更新任务关联（设置为NULL）');
      } catch (updateError) {
        // 如果更新失败（外键约束不允许NULL），则删除相关任务
        console.log('无法将任务关联设置为NULL，改为删除任务');
        const [taskResult1] = await connection.execute('DELETE FROM tasks WHERE creator_id = ?', [userId]);
        const [taskResult2] = await connection.execute('DELETE FROM tasks WHERE assignee_id = ?', [userId]);
        console.log(`已删除 ${taskResult1.affectedRows + taskResult2.affectedRows} 个任务`);
      }
      
      // 4. 清除用户权限缓存
      clearPermissionCache(userId);
      
      // 5. 硬删除用户（直接从数据库删除）
      const [result] = await connection.execute('DELETE FROM users WHERE id = ?', [userId]);
      
      if (result.affectedRows === 0) {
        await connection.rollback();
        connection.release();
        return res.status(404).json({ success: false, message: '用户不存在' });
      }
      
      // 提交事务
      await connection.commit();
      connection.release();
      
      console.log('用户硬删除成功:', userId);
      return res.json({ success: true, message: '用户删除成功' });
    } catch (err) {
      // 回滚事务
      await connection.rollback();
      connection.release();
      throw err;
    }
  } catch (e) {
    console.error('删除用户失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 获取用户当前角色
app.get('/api/user-roles/:userId', auth, async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    const connection = await getConn();
    
    const [roles] = await connection.execute(`
      SELECT r.id, r.role_name, r.description
      FROM roles r
      JOIN user_roles ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `, [userId]);
    
    connection.release();
    res.json({ success: true, roles });
  } catch (e) {
    console.error('获取用户角色失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 为用户分配角色
app.post('/api/user-roles/:userId', auth, checkPermission('user:assign_role'), async (req, res) => {
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
    
    connection.release();
    res.json({ success: true, message: '角色分配成功' });
  } catch (e) {
    console.error('分配角色失败:', e);
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
    connection.release();
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
    connection.release();
    res.json({ success: true, permissions });
  } catch (e) {
    console.error('获取权限列表失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 创建权限
app.post('/api/permissions', auth, checkPermission('role:view'), async (req, res) => {
  try {
    const { permKey, name, module, description } = req.body;
    
    if (!permKey || !name || !module) {
      return res.status(400).json({ 
        success: false, 
        message: '权限键、名称和模块不能为空' 
      });
    }
    
    const connection = await getConn();
    
    // 检查权限键是否已存在
    const [existing] = await connection.execute(
      'SELECT id FROM permissions WHERE perm_key = ?',
      [permKey]
    );
    
    if (existing.length > 0) {
      connection.release();
      return res.status(400).json({ 
        success: false, 
        message: '权限键已存在' 
      });
    }
    
    // 插入新权限
    const [result] = await connection.execute(
      'INSERT INTO permissions (perm_key, name, module, description, created_at) VALUES (?, ?, ?, ?, NOW())',
      [permKey, name, module, description || null]
    );
    
    connection.release();
    
    res.json({ 
      success: true, 
      message: '权限创建成功',
      permission: {
        id: result.insertId,
        perm_key: permKey,
        name,
        module,
        description
      }
    });
  } catch (e) {
    console.error('创建权限失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 删除权限
app.delete('/api/permissions/:id', auth, checkPermission('role:view'), async (req, res) => {
  try {
    const permissionId = parseInt(req.params.id, 10);
    
    console.log('删除权限请求:', permissionId);
    
    const connection = await getConn();
    
    // 先删除角色权限关联（处理外键）
    await connection.execute(
      'DELETE FROM role_permissions WHERE permission_id = ?',
      [permissionId]
    );
    
    console.log('已删除权限关联');
    
    // 删除权限
    const [result] = await connection.execute(
      'DELETE FROM permissions WHERE id = ?',
      [permissionId]
    );
    
    connection.release();
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ 
        success: false, 
        message: '权限不存在' 
      });
    }
    
    console.log('权限删除成功:', permissionId);
    res.json({ success: true, message: '权限删除成功' });
  } catch (e) {
    console.error('删除权限失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 获取角色的权限（用于编辑角色）
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
    
    connection.release();
    res.json({ success: true, permissions });
  } catch (e) {
    console.error('获取角色权限失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 创建角色
app.post('/api/roles', auth, checkPermission('role:view'), async (req, res) => {
  try {
    const { roleName, description } = req.body;
    
    if (!roleName) {
      return res.status(400).json({ success: false, message: '角色名称不能为空' });
    }
    
    const connection = await getConn();
    
    const [result] = await connection.execute(
      'INSERT INTO roles (role_name, description, created_at) VALUES (?, ?, NOW())',
      [roleName, description || null]
    );
    
    connection.release();
    
    res.json({ 
      success: true, 
      message: '角色创建成功',
      role: {
        id: result.insertId,
        role_name: roleName,
        description
      }
    });
  } catch (e) {
    console.error('创建角色失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 更新角色
app.put('/api/roles/:id', auth, checkPermission('role:view'), async (req, res) => {
  try {
    const roleId = parseInt(req.params.id, 10);
    const { roleName, description } = req.body;
    
    const connection = await getConn();
    
    await connection.execute(
      'UPDATE roles SET role_name = ?, description = ? WHERE id = ?',
      [roleName, description, roleId]
    );
    
    connection.release();
    
    res.json({ success: true, message: '角色更新成功' });
  } catch (e) {
    console.error('更新角色失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 删除角色
app.delete('/api/roles/:id', auth, checkPermission('role:view'), async (req, res) => {
  try {
    const roleId = parseInt(req.params.id, 10);
    const connection = await getConn();
    
    // 先删除角色权限关联
    await connection.execute('DELETE FROM role_permissions WHERE role_id = ?', [roleId]);
    
    // 删除用户角色关联
    await connection.execute('DELETE FROM user_roles WHERE role_id = ?', [roleId]);
    
    // 删除角色
    await connection.execute('DELETE FROM roles WHERE id = ?', [roleId]);
    
    connection.release();
    
    res.json({ success: true, message: '角色删除成功' });
  } catch (e) {
    console.error('删除角色失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 为角色分配权限
app.post('/api/roles/:roleId/permissions', auth, checkPermission('role:view'), async (req, res) => {
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
    
    connection.release();
    res.json({ success: true, message: '权限分配成功' });
  } catch (e) {
    console.error('分配权限失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 获取日志列表
app.get('/api/logs', auth, async (req, res) => {
  try {
    const connection = await getConn();
    
    // 管理端可以查看所有日志，但限制数量
    const [logs] = await connection.execute(`
      SELECT l.*, u.username, u.real_name
      FROM logs l
      LEFT JOIN users u ON l.author_user_id = u.id
      ORDER BY l.created_at DESC
      LIMIT 100
    `);
    
    connection.release();
    
    res.json({ 
      success: true, 
      data: logs.map(log => ({
        id: log.id,
        content: log.content,
        priority: log.priority,
        userId: log.author_user_id,
        username: log.username,
        realName: log.real_name,
        createdAt: log.created_at,
        taskId: log.task_id
      }))
    });
  } catch (e) {
    console.error('获取日志列表失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 获取任务列表
app.get('/api/tasks', auth, async (req, res) => {
  try {
    const connection = await getConn();

    const [tasks] = await connection.execute(`
      SELECT t.*,
             a.username as assignee_username, a.real_name as assignee_real_name,
             c.username as creator_username, c.real_name as creator_real_name
      FROM tasks t
             LEFT JOIN users a ON t.assignee_id = a.id
             LEFT JOIN users c ON t.creator_id = c.id
      ORDER BY t.created_at DESC
        LIMIT 100
    `);

    connection.release();

    // 将关联用户信息包装为更明确的结构，避免前端混用字段导致显示错位
    const normalized = tasks.map(t => ({
      // 先保留原始任务字段（展开 t）
      ...t,
      // 字段名映射：将数据库的 snake_case 转换为前端期望的 camelCase
      name: t.task_name || null,              // 任务名称：task_name -> name
      due_time: t.plan_end_time || null,      // 截止时间：plan_end_time -> due_time
      // 明确的子对象，前端使用这些字段会更稳健
      assignee: {
        id: t.assignee_id || null,
        username: t.assignee_username || null,
        realName: t.assignee_real_name || null
      },
      creator: {
        id: t.creator_id || null,
        username: t.creator_username || null,
        realName: t.creator_real_name || null
      }
    }));

    res.json({ success: true, tasks: normalized });
  } catch (e) {
    console.error('获取任务列表失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 将ISO日期格式转换为MySQL日期时间格式
function formatDateTimeForMySQL(isoString) {
  if (!isoString) return null;
  try {
    const date = new Date(isoString);
    // 转换为本地时区的 YYYY-MM-DD HH:MM:SS 格式
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  } catch (e) {
    console.error('日期格式转换失败:', e);
    return null;
  }
}

// 创建任务
app.post('/api/tasks', auth, checkPermission('task:create'), async (req, res) => {
  try {
    const { name, description, priority, assigneeId, dueTime, status } = req.body;
    
    if (!name) {
      return res.status(400).json({ success: false, message: '任务名称不能为空' });
    }
    
    const connection = await getConn();
    
    // 转换日期格式为MySQL格式
    const mysqlDateTime = formatDateTimeForMySQL(dueTime);
    
    // 插入新任务
    const [result] = await connection.execute(
      `INSERT INTO tasks (task_name, description, priority, assignee_id, creator_id, plan_end_time, status, progress, created_at, updated_at) 
       VALUES (?, ?, ?, ?, ?, ?, ?, 0, NOW(), NOW())`,
      [
        name,
        description || null,
        priority || 'low',
        assigneeId || null,
        req.user.id, // 创建者ID
        mysqlDateTime,
        status || 'pending'
      ]
    );
    
    connection.release();
    
    res.status(201).json({
      success: true,
      message: '任务创建成功',
      task: {
        id: result.insertId,
        name,
        description,
        priority,
        assigneeId,
        dueTime,
        status
      }
    });
  } catch (e) {
    console.error('创建任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 更新任务
app.put('/api/tasks/:id', auth, checkPermission('task:edit'), async (req, res) => {
  try {
    const taskId = parseInt(req.params.id, 10);
    const { name, description, priority, assigneeId, dueTime, status, progress } = req.body;
    
    const connection = await getConn();
    
    // 构建更新字段
    const updateFields = [];
    const updateValues = [];
    
    if (name !== undefined) {
      updateFields.push('task_name = ?');
      updateValues.push(name);
    }
    if (description !== undefined) {
      updateFields.push('description = ?');
      updateValues.push(description);
    }
    if (priority !== undefined) {
      updateFields.push('priority = ?');
      updateValues.push(priority);
    }
    if (assigneeId !== undefined) {
      updateFields.push('assignee_id = ?');
      updateValues.push(assigneeId || null);
    }
    if (dueTime !== undefined) {
      updateFields.push('plan_end_time = ?');
      // 转换日期格式为MySQL格式
      const mysqlDateTime = formatDateTimeForMySQL(dueTime);
      updateValues.push(mysqlDateTime);
    }
    
    // 处理进度和状态：如果进度为100%，优先设置状态为completed
    let finalStatus = status;
    if (progress !== undefined) {
      updateFields.push('progress = ?');
      updateValues.push(progress);
      // 如果进度为100%，自动设置状态为completed（覆盖用户设置的状态）
      if (progress === 100) {
        finalStatus = 'completed';
      }
    }
    
    // 设置状态（如果进度为100%，这里会覆盖之前的状态）
    if (finalStatus !== undefined) {
      updateFields.push('status = ?');
      updateValues.push(finalStatus);
    }
    
    if (updateFields.length === 0) {
      connection.release();
      return res.status(400).json({ success: false, message: '没有要更新的字段' });
    }
    
    // 添加更新时间
    updateFields.push('updated_at = NOW()');
    updateValues.push(taskId);
    
    const sql = `UPDATE tasks SET ${updateFields.join(', ')} WHERE id = ?`;
    await connection.execute(sql, updateValues);
    
    connection.release();
    
    res.json({ success: true, message: '任务更新成功' });
  } catch (e) {
    console.error('更新任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 删除任务
app.delete('/api/tasks/:id', auth, checkPermission('task:delete'), async (req, res) => {
  try {
    const taskId = parseInt(req.params.id, 10);
    const connection = await getConn();
    
    const [result] = await connection.execute('DELETE FROM tasks WHERE id = ?', [taskId]);
    
    connection.release();
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '任务不存在' });
    }
    
    res.json({ success: true, message: '任务删除成功' });
  } catch (e) {
    console.error('删除任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

// 启动服务器
app.listen(PORT, () => {
  console.log(`🚀 管理后台服务器运行在 http://localhost:${PORT}`);
  console.log(`📊 健康检查: http://localhost:${PORT}/api/health`);
});
