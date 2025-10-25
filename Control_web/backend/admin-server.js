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
  keepAliveInitialDelay: 0,
  enableKeepAlive: true,
};

const JWT_SECRET = 'your_jwt_secret_key_here_change_this_in_production';

// 获取数据库连接
async function getConn() {
  return mysql.createConnection(dbConfig);
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

// 健康检查接口
app.get('/api/health', (req, res) => {
  res.json({ 
    success: true, 
    message: '管理后台服务器运行正常',
    timestamp: new Date().toISOString()
  });
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
    const connection = await getConn();

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
    
    await connection.end();
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
      await connection.end();
      return res.status(403).json({ success: false, message: '权限不足' });
    }
    
    const [users] = await connection.execute(
      'SELECT id, username, email, real_name, phone, position, avatar_url, status, created_at FROM users WHERE id = ?',
      [userId]
    );
    await connection.end();
    
    if (users.length === 0) {
      return res.status(404).json({ success: false, message: '用户不存在' });
    }
    
    return res.json({ success: true, user: users[0] });
  } catch (e) {
    console.error('查询用户详情失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 检查用户权限的辅助函数
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
      await connection.end();
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
      await connection.end();
      return res.status(400).json({ success: false, message: '没有要更新的字段' });
    }
    
    updateValues.push(userId);
    const sql = `UPDATE users SET ${updateFields.join(', ')} WHERE id = ?`;
    
    await connection.execute(sql, updateValues);
    await connection.end();
    
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
      
      // 2. 删除用户创建的任务（如果有tasks表）
      // await connection.execute('DELETE FROM tasks WHERE owner_user_id = ?', [userId]);
      
      // 3. 删除用户的日志（如果有logs表）
      // await connection.execute('DELETE FROM logs WHERE user_id = ?', [userId]);
      
      // 4. 硬删除用户（直接从数据库删除）
      const [result] = await connection.execute('DELETE FROM users WHERE id = ?', [userId]);
      
      if (result.affectedRows === 0) {
        await connection.rollback();
        await connection.end();
        return res.status(404).json({ success: false, message: '用户不存在' });
      }
      
      // 提交事务
      await connection.commit();
      await connection.end();
      
      console.log('用户硬删除成功:', userId);
      return res.json({ success: true, message: '用户删除成功' });
    } catch (err) {
      // 回滚事务
      await connection.rollback();
      await connection.end();
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
    
    await connection.end();
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
    
    await connection.end();
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
      await connection.end();
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
    
    await connection.end();
    
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
    
    await connection.end();
    
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

// 启动服务器
app.listen(PORT, () => {
  console.log(`🚀 管理后台服务器运行在 http://localhost:${PORT}`);
  console.log(`📊 健康检查: http://localhost:${PORT}/api/health`);
});
