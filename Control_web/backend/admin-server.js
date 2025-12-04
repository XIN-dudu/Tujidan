const path = require('path');
const express = require('express');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const app = express();
const PORT = process.env.PORT || 3002; // 使用不同端口

// 中间件
app.use(cors({
  origin: function (origin, callback) {
    // 允许所有本地请求和file://协议
    if (!origin || origin.startsWith('file://') || 
        origin.startsWith('http://localhost') || 
        origin.startsWith('http://127.0.0.1')) {
      callback(null, true);
    } else {
      callback(null, true); // 开发环境允许所有来源，生产环境应限制
    }
  },
  credentials: true
}));
app.use(express.json());

// Swagger 配置
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Tujidan 管理后台 API',
      version: '1.0.0',
      description: 'Tujidan 管理后台 API 文档 - 用户、角色、权限、任务、日志管理',
      contact: {
        name: 'API Support',
      },
    },
    servers: [
      {
        url: 'http://localhost:3002',
        description: '开发环境',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        User: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            username: { type: 'string' },
            email: { type: 'string' },
            real_name: { type: 'string' },
            phone: { type: 'string' },
            position: { type: 'string' },
            avatar_url: { type: 'string' },
            status: { type: 'integer' },
            department_id: { type: 'integer' },
            mbit: { type: 'string' },
            created_at: { type: 'string', format: 'date-time' },
          },
        },
        Task: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            name: { type: 'string' },
            description: { type: 'string' },
            priority: { type: 'string', enum: ['low', 'medium', 'high'] },
            status: { type: 'string' },
            progress: { type: 'integer', minimum: 0, maximum: 100 },
            assigneeId: { type: 'integer' },
            dueTime: { type: 'string', format: 'date-time' },
          },
        },
        Log: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            title: { type: 'string' },
            content: { type: 'string' },
            logType: { type: 'string', enum: ['work', 'study', 'life', 'other'] },
            priority: { type: 'string', enum: ['low', 'medium', 'high'] },
            logStatus: { type: 'string', enum: ['pending', 'completed', 'cancelled'] },
            progress: { type: 'integer', minimum: 0, maximum: 100 },
            timeFrom: { type: 'string', format: 'date-time' },
            timeTo: { type: 'string', format: 'date-time' },
            taskId: { type: 'integer' },
          },
        },
      },
    },
    security: [
      {
        bearerAuth: [],
      },
    ],
    tags: [
      { name: '系统', description: '系统健康检查' },
      { name: '认证相关', description: '用户注册、登录、验证' },
      { name: '用户管理', description: '用户 CRUD 操作' },
      { name: '角色权限', description: 'RBAC 角色和权限管理' },
      { name: '任务管理', description: '任务 CRUD 操作' },
      { name: '日志管理', description: '日志查看和删除' },
      { name: 'TopItems', description: '公司十大事项管理' },
    ],
  },
  apis: [path.join(__dirname, 'admin-server.js')],
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

// 添加 Swagger UI 路由
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// 提供 JSON 格式的文档
app.get('/api-docs.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});

// 添加请求日志中间件
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// 数据库配置（本地数据库）
const dbConfig = {
  host: 'localhost', // 本地数据库地址
  user: 'root', // 请根据您的本地MySQL用户名修改
  password: '123456', // 请根据您的本地MySQL密码修改（如果设置了密码）
  database: 'tujidan', // 数据库名称保持不变
  port: 3306,
  charset: 'utf8mb4',
  connectTimeout: 10000, // 本地数据库连接超时时间改为10秒（比云数据库快）
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

// 用户列表缓存（减少频繁数据库访问）
let userListCache = {
  data: null,
  timestamp: 0,
  ttl: 60 * 1000 // 60秒
};

function isUserCacheValid() {
  return (
    userListCache.data &&
    Date.now() - userListCache.timestamp < userListCache.ttl
  );
}

function clearUserCache() {
  userListCache = { data: null, timestamp: 0, ttl: userListCache.ttl };
}

// 获取用户权限（带缓存）
async function getUserPermissions(userId) {
  const cacheKey = `user_${userId}`;
  const cached = permissionCache.get(cacheKey);
  
  if (cached && Date.now() - cached.timestamp < PERMISSION_CACHE_TTL) {
    console.log(`使用缓存的权限，用户ID: ${userId}`);
    return cached.permissions;
  }
  
  let connection;
  try {
    console.log(`开始查询用户权限，用户ID: ${userId}`);
    
    // 添加超时控制（10秒，适用于本地数据库）
    const connectionPromise = getConn();
    let timeoutHandle;
    const timeoutPromise = new Promise((_, reject) => {
      timeoutHandle = setTimeout(() => reject(new Error('获取数据库连接超时（10秒）')), 10000);
    });
    
    connection = await Promise.race([connectionPromise, timeoutPromise]);
    if (timeoutHandle) clearTimeout(timeoutHandle);
    console.log(`数据库连接成功，开始查询权限，用户ID: ${userId}`);
    
    const [permissions] = await connection.execute(`
      SELECT DISTINCT p.perm_key 
      FROM permissions p
      JOIN role_permissions rp ON p.id = rp.permission_id
      JOIN user_roles ur ON rp.role_id = ur.role_id
      WHERE ur.user_id = ?
    `, [userId]);
    
    const permissionKeys = permissions.map(p => p.perm_key);
    console.log(`用户 ${userId} 的权限:`, permissionKeys);
    
    // 更新缓存
    permissionCache.set(cacheKey, {
      permissions: permissionKeys,
      timestamp: Date.now()
    });
    
    return permissionKeys;
  } catch (error) {
    console.error(`获取用户权限失败，用户ID: ${userId}`, error);
    throw error;
  } finally {
    if (connection) {
      try {
        connection.release(); // 释放连接回连接池
      } catch (releaseError) {
        console.error('释放连接失败:', releaseError);
      }
    }
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
      console.log(`开始权限检查，用户ID: ${req.user.id}, 需要权限: ${permission}`);
      const startTime = Date.now();
      
      const userPermissions = await getUserPermissions(req.user.id);
      
      const duration = Date.now() - startTime;
      console.log(`权限检查完成，耗时: ${duration}ms, 用户权限:`, userPermissions);
      
      // 检查是否有指定权限
      if (!userPermissions.includes(permission)) {
        console.log(`用户 ${req.user.id} 缺少权限: ${permission}`);
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
        message: `权限检查失败: ${e.message || '未知错误'}` 
      });
    }
  };
}

/**
 * @swagger
 * /api/health:
 *   get:
 *     summary: 健康检查
 *     tags: [系统]
 *     security: []
 *     responses:
 *       200:
 *         description: 服务器运行正常
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: 管理后台服务器运行正常
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 */
// 健康检查接口
app.get('/api/health', (req, res) => {
  res.json({ 
    success: true, 
    message: '管理后台服务器运行正常',
    timestamp: new Date().toISOString()
  });
});

/**
 * @swagger
 * /api/register:
 *   post:
 *     summary: 注册/创建用户（管理员功能）
 *     tags: [认证相关]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - username
 *               - password
 *               - realName
 *             properties:
 *               username:
 *                 type: string
 *                 description: 用户名
 *                 example: newuser1
 *               password:
 *                 type: string
 *                 description: 密码
 *                 example: 123456
 *               email:
 *                 type: string
 *                 description: 邮箱（可选）
 *                 example: newuser1@tujidan.com
 *               realName:
 *                 type: string
 *                 description: 真实姓名
 *                 example: 测试用户1
 *               phone:
 *                 type: string
 *                 description: 手机号（可选）
 *                 example: 13800000000
 *               position:
 *                 type: string
 *                 description: 职位（可选）
 *                 example: 开发工程师
 *     responses:
 *       201:
 *         description: 用户创建成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: 用户创建成功
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       400:
 *         description: 参数错误或用户名已存在
 *       409:
 *         description: 用户名已存在
 */
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

    clearUserCache();
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

/**
 * @swagger
 * /api/login:
 *   post:
 *     summary: 用户登录（仅限 founder/admin）
 *     tags: [认证相关]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - username
 *               - password
 *             properties:
 *               username:
 *                 type: string
 *                 description: 用户名或邮箱
 *                 example: admin
 *               password:
 *                 type: string
 *                 description: 密码
  *                 example: 123456
 *     responses:
 *       200:
 *         description: 登录成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: 登录成功
 *                 token:
 *                   type: string
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       401:
 *         description: 用户名或密码错误
 *       403:
 *         description: 没有权限登录管理后台（只有 founder/admin 可以登录）
 */
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

/**
 * @swagger
 * /api/verify:
 *   get:
 *     summary: 验证 Token
 *     tags: [认证相关]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Token 有效
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       401:
 *         description: Token 无效或未提供
 */
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

/**
 * @swagger
 * /api/admin/users:
 *   get:
 *     summary: 获取所有用户列表（分页）
 *     tags: [用户管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *           minimum: 1
 *         description: 页码
 *       - in: query
 *         name: pageSize
 *         schema:
 *           type: integer
 *           default: 20
 *           minimum: 1
 *           maximum: 100
 *         description: 每页数量
 *     responses:
 *       200:
 *         description: 获取成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 users:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/User'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     page:
 *                       type: integer
 *                     pageSize:
 *                       type: integer
 *                     total:
 *                       type: integer
 *                     totalPages:
 *                       type: integer
 */
// 管理员获取所有用户（登录后直接允许访问，提高响应速度）
app.get('/api/admin/users', auth, async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || '1', 10), 1);
    const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '20', 10), 1), 100);
    const offset = (page - 1) * pageSize;

    console.log(`开始获取用户列表... page=${page}, pageSize=${pageSize}`);

    if (!isUserCacheValid()) {
      console.log('用户列表缓存失效，重新加载...');
      const users = await fetchAllActiveUsers();
      userListCache = { data: users, timestamp: Date.now(), ttl: userListCache.ttl };
    }

    const allUsers = userListCache.data || [];
    const total = allUsers.length;
    const pageUsers = allUsers.slice(offset, offset + pageSize);

    return res.json({
      success: true,
      users: pageUsers,
      pagination: {
        page,
        pageSize,
        total,
        totalPages: Math.ceil(total / pageSize)
      }
    });
  } catch (e) {
    console.error('查询所有用户失败:', e);
    let errorMessage = '服务器内部错误';
    if (e.message && e.message.includes('超时')) {
      errorMessage = '数据库连接超时，请检查数据库服务是否正常运行';
    } else if (e.message) {
      errorMessage = `数据库错误: ${e.message}`;
    }

    return res.status(500).json({
      success: false,
      message: errorMessage
    });
  }
});

/**
 * @swagger
 * /api/users/stats:
 *   get:
 *     summary: 获取用户统计信息
 *     tags: [用户管理]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 获取成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 totalUsers:
 *                   type: integer
 *                   description: 总用户数
 */
// 用户统计接口
app.get('/api/users/stats', auth, async (req, res) => {
  try {
    if (!isUserCacheValid()) {
      console.log('用户统计缓存失效，重新加载...');
      const users = await fetchAllActiveUsers();
      userListCache = { data: users, timestamp: Date.now(), ttl: userListCache.ttl };
    }
    const total = userListCache.data ? userListCache.data.length : 0;
    res.json({ success: true, totalUsers: total });
  } catch (e) {
    console.error('获取用户统计失败:', e);
    res.status(500).json({ success: false, message: '获取用户统计失败: ' + e.message });
  }
});

/**
 * @swagger
 * /api/users/{id}:
 *   get:
 *     summary: 获取单个用户详情
 *     tags: [用户管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 用户ID
 *     responses:
 *       200:
 *         description: 获取成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       403:
 *         description: 权限不足
 *       404:
 *         description: 用户不存在
 */
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

async function fetchAllActiveUsers() {
  let connection;
  try {
    connection = await getConn();
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
        u.department_id,
        u.mbit,
        u.created_at
      FROM users u
      WHERE u.status = 1
      ORDER BY u.created_at DESC
    `);

    if (users.length === 0) {
      return [];
    }

    const userIds = users.map(u => u.id);
    const placeholders = userIds.map(() => '?').join(',');
    const [roleRows] = await connection.execute(`
      SELECT ur.user_id, r.role_name, r.id as role_id
      FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id IN (${placeholders})
      ORDER BY r.id ASC
    `, userIds);

    const roleMap = new Map();
    roleRows.forEach(row => {
      if (!roleMap.has(row.user_id)) {
        roleMap.set(row.user_id, { names: [], ids: [] });
      }
      const entry = roleMap.get(row.user_id);
      entry.names.push(row.role_name);
      entry.ids.push(row.role_id);
    });

    return users.map(user => {
      const roleInfo = roleMap.get(user.id) || { names: [], ids: [] };
      return {
        id: user.id,
        username: user.username,
        email: user.email,
        real_name: user.real_name,
        phone: user.phone,
        position: user.position,
        avatar_url: user.avatar_url,
        status: user.status,
        department_id: user.department_id || null,
        department_name: user.department_id ? `部门${user.department_id}` : null,
        mbit: user.mbit || null,
        created_at: user.created_at,
        primaryRole: roleInfo.names[0] || null,
        allRoles: roleInfo.names,
        roleIds: roleInfo.ids.join(',')
      };
    });
  } finally {
    if (connection) connection.release();
  }
}

/**
 * @swagger
 * /api/users/{id}:
 *   put:
 *     summary: 更新用户信息
 *     tags: [用户管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 用户ID
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               username:
 *                 type: string
 *               realName:
 *                 type: string
 *               email:
 *                 type: string
 *               phone:
 *                 type: string
 *               position:
 *                 type: string
 *               password:
 *                 type: string
 *                 description: 新密码（可选）
 *               departmentId:
 *                 type: integer
 *                 description: 部门ID（可选）
 *               mbit:
 *                 type: string
 *                 description: MBTI类型（可选）
 *     responses:
 *       200:
 *         description: 更新成功
 *       400:
 *         description: 没有要更新的字段
 *       403:
 *         description: 权限不足
 */
// 更新用户信息
app.put('/api/users/:id', auth, async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const { username, realName, email, phone, position, password, departmentId, mbit } = req.body;
    
    console.log('更新用户请求:', { userId, departmentId, mbit, body: req.body });
    
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
    if (departmentId !== undefined) {
      updateFields.push('department_id = ?');
      updateValues.push(departmentId || null);
      console.log('添加部门更新:', departmentId);
    }
    if (mbit !== undefined) {
      // 现在字段允许 NULL，所以可以更新 null 值
      updateFields.push('mbit = ?');
      updateValues.push(mbit || null);
      console.log('添加MBTI更新:', mbit);
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
    
    console.log('执行SQL:', sql);
    console.log('参数值:', updateValues);
    
    const [result] = await connection.execute(sql, updateValues);
    console.log('更新结果:', result.affectedRows, '行受影响');
    
    connection.release();
    
    clearUserCache();
    return res.json({ success: true, message: '用户信息更新成功' });
  } catch (e) {
    console.error('更新用户信息失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/users/{id}:
 *   delete:
 *     summary: 删除用户（硬删除）
 *     tags: [用户管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 用户ID
 *     responses:
 *       200:
 *         description: 删除成功
 *       403:
 *         description: 权限不足或不能删除自己
 *       404:
 *         description: 用户不存在
 */
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
      clearUserCache();
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

/**
 * @swagger
 * /api/user-roles/{userId}:
 *   get:
 *     summary: 获取用户当前角色
 *     tags: [角色权限]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: integer
 *         description: 用户ID
 *     responses:
 *       200:
 *         description: 获取成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 roles:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       role_name:
 *                         type: string
 *                       description:
 *                         type: string
 */
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

/**
 * @swagger
 * /api/user-roles/{userId}:
 *   post:
 *     summary: 为用户分配角色
 *     tags: [角色权限]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: integer
 *         description: 用户ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - roleIds
 *             properties:
 *               roleIds:
 *                 type: array
 *                 items:
 *                   type: integer
 *                 description: 角色ID列表
 *     responses:
 *       200:
 *         description: 分配成功
 *       400:
 *         description: 角色ID列表格式错误
 *       403:
 *         description: 权限不足（需要 user:assign_role 权限）
 */
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
    clearUserCache();
    res.json({ success: true, message: '角色分配成功' });
  } catch (e) {
    console.error('分配角色失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

/**
 * @swagger
 * /api/roles:
 *   get:
 *     summary: 获取所有角色
 *     tags: [角色权限]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 获取成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 roles:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       role_name:
 *                         type: string
 *                       description:
 *                         type: string
 *                       user_count:
 *                         type: integer
 *                       created_at:
 *                         type: string
 *                         format: date-time
 *       403:
 *         description: 权限不足（需要 role:view 权限）
 */
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

/**
 * @swagger
 * /api/permissions:
 *   get:
 *     summary: 获取所有权限
 *     tags: [角色权限]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 获取成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 permissions:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       perm_key:
 *                         type: string
 *                       name:
 *                         type: string
 *                       module:
 *                         type: string
 *                       description:
 *                         type: string
 *       403:
 *         description: 权限不足（需要 role:view 权限）
 */
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

/**
 * @swagger
 * /api/permissions:
 *   post:
 *     summary: 创建权限
 *     tags: [角色权限]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - permKey
 *               - name
 *               - module
 *             properties:
 *               permKey:
 *                 type: string
 *                 description: 权限键（唯一标识）
 *                 example: user:create
 *               name:
 *                 type: string
 *                 description: 权限名称
 *                 example: 创建用户
 *               module:
 *                 type: string
 *                 description: 所属模块
 *                 example: 用户管理
 *               description:
 *                 type: string
 *                 description: 权限描述（可选）
 *     responses:
 *       200:
 *         description: 创建成功
 *       400:
 *         description: 参数错误或权限键已存在
 *       403:
 *         description: 权限不足（需要 role:view 权限）
 */
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

/**
 * @swagger
 * /api/permissions/{id}:
 *   delete:
 *     summary: 删除权限
 *     tags: [角色权限]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 权限ID
 *     responses:
 *       200:
 *         description: 删除成功
 *       404:
 *         description: 权限不存在
 *       403:
 *         description: 权限不足（需要 role:view 权限）
 */
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

/**
 * @swagger
 * /api/roles/{roleId}/permissions:
 *   get:
 *     summary: 获取角色的权限列表
 *     tags: [角色权限]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: integer
 *         description: 角色ID
 *     responses:
 *       200:
 *         description: 获取成功
 *       403:
 *         description: 权限不足（需要 role:view 权限）
 */
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

/**
 * @swagger
 * /api/roles:
 *   post:
 *     summary: 创建角色
 *     tags: [角色权限]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - roleName
 *             properties:
 *               roleName:
 *                 type: string
 *                 description: 角色名称
 *                 example: 部门经理
 *               description:
 *                 type: string
 *                 description: 角色描述（可选）
 *     responses:
 *       200:
 *         description: 创建成功
 *       400:
 *         description: 角色名称不能为空
 *       403:
 *         description: 权限不足（需要 role:view 权限）
 */
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

/**
 * @swagger
 * /api/roles/{id}:
 *   put:
 *     summary: 更新角色
 *     tags: [角色权限]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 角色ID
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               roleName:
 *                 type: string
 *               description:
 *                 type: string
 *     responses:
 *       200:
 *         description: 更新成功
 *       403:
 *         description: 权限不足（需要 role:view 权限）
 */
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

/**
 * @swagger
 * /api/roles/{id}:
 *   delete:
 *     summary: 删除角色
 *     tags: [角色权限]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 角色ID
 *     responses:
 *       200:
 *         description: 删除成功
 *       403:
 *         description: 权限不足（需要 role:view 权限）
 */
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

/**
 * @swagger
 * /api/roles/{roleId}/permissions:
 *   post:
 *     summary: 为角色分配权限
 *     tags: [角色权限]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: integer
 *         description: 角色ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - permissionIds
 *             properties:
 *               permissionIds:
 *                 type: array
 *                 items:
 *                   type: integer
 *                 description: 权限ID列表
 *     responses:
 *       200:
 *         description: 分配成功
 *       400:
 *         description: 权限ID列表格式错误
 *       403:
 *         description: 权限不足（需要 role:view 权限）
 */
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

/**
 * @swagger
 * /api/logs/{id}:
 *   get:
 *     summary: 获取单个日志详情
 *     tags: [日志管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 日志ID
 *     responses:
 *       200:
 *         description: 获取成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 log:
 *                   $ref: '#/components/schemas/Log'
 *       404:
 *         description: 日志不存在
 */
// 获取单个日志详情（必须在 /api/logs 之前定义，因为路由按顺序匹配）
app.get('/api/logs/:id', auth, async (req, res) => {
  try {
    const logId = parseInt(req.params.id, 10);
    const connection = await getConn();
    
    const [logs] = await connection.execute(`
      SELECT l.*, u.username, u.real_name
      FROM logs l
      LEFT JOIN users u ON l.author_user_id = u.id
      WHERE l.id = ?
    `, [logId]);
    
    connection.release();
    
    if (logs.length === 0) {
      return res.status(404).json({ success: false, message: '日志不存在' });
    }
    
    const log = logs[0];
    res.json({
      success: true,
      log: {
        id: log.id,
        title: log.title,
        content: log.content,
        logType: log.log_type,
        priority: log.priority,
        logStatus: log.log_status,
        progress: log.progress,
        timeFrom: log.time_from,
        timeTo: log.time_to,
        totalHours: log.total_hours,
        timeTag: log.time_tag,
        taskId: log.task_id,
        userId: log.author_user_id,
        username: log.username,
        realName: log.real_name,
        createdAt: log.created_at,
        updatedAt: log.updated_at
      }
    });
  } catch (e) {
    console.error('获取日志详情失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/logs/{id}:
 *   delete:
 *     summary: 删除日志
 *     tags: [日志管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 日志ID
 *     responses:
 *       200:
 *         description: 删除成功
 *       404:
 *         description: 日志不存在
 */
// 删除日志
app.delete('/api/logs/:id', auth, async (req, res) => {
  try {
    const logId = parseInt(req.params.id, 10);
    const connection = await getConn();
    
    const [result] = await connection.execute('DELETE FROM logs WHERE id = ?', [logId]);
    
    connection.release();
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '日志不存在' });
    }
    
    res.json({ success: true, message: '日志删除成功' });
  } catch (e) {
    console.error('删除日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/logs:
 *   get:
 *     summary: 获取日志列表（最多100条）
 *     tags: [日志管理]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 获取成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Log'
 */
// 获取日志列表（必须在 /api/logs/:id 之后定义）
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
        title: log.title,
        content: log.content,
        logType: log.log_type,
        priority: log.priority,
        logStatus: log.log_status,
        progress: log.progress,
        timeFrom: log.time_from,
        timeTo: log.time_to,
        totalHours: log.total_hours,
        timeTag: log.time_tag,
        userId: log.author_user_id,
        username: log.username,
        realName: log.real_name,
        createdAt: log.created_at,
        updatedAt: log.updated_at,
        taskId: log.task_id
      }))
    });
  } catch (e) {
    console.error('获取日志列表失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/tasks:
 *   get:
 *     summary: 获取任务列表（最多100条）
 *     tags: [任务管理]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 获取成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 tasks:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Task'
 */
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

/**
 * @swagger
 * /api/top-items:
 *   get:
 *     summary: 获取公司十大事项列表
 *     tags: [TopItems]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 获取成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 items:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       title:
 *                         type: string
 *                       content:
 *                         type: string
 *                       orderIndex:
 *                         type: integer
 *                       status:
 *                         type: integer
 *                       creator:
 *                         type: object
 */
// 公司十大事项管理
app.get('/api/top-items', auth, async (req, res) => {
  let connection;
  try {
    connection = await getConn();
    const [items] = await connection.execute(`
      SELECT ti.*, u.username AS creator_username, u.real_name AS creator_real_name
      FROM top_items ti
      LEFT JOIN users u ON ti.created_by = u.id
      ORDER BY ti.order_index ASC, ti.created_at DESC
      LIMIT 10
    `);

    const normalized = items.map(item => ({
      id: item.id,
      title: item.title,
      content: item.content,
      orderIndex: item.order_index,
      status: item.status,
      createdAt: item.created_at,
      updatedAt: item.updated_at,
      creator: {
        id: item.created_by,
        username: item.creator_username,
        realName: item.creator_real_name
      }
    }));

    res.json({ success: true, items: normalized });
  } catch (e) {
    console.error('获取十大事项失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  } finally {
    if (connection) connection.release();
  }
});

/**
 * @swagger
 * /api/top-items:
 *   post:
 *     summary: 创建公司十大事项
 *     tags: [TopItems]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - orderIndex
 *               - status
 *             properties:
 *               title:
 *                 type: string
 *                 description: 事项标题
 *               content:
 *                 type: string
 *                 description: 事项内容（可选）
 *               orderIndex:
 *                 type: integer
 *                 minimum: 0
 *                 description: 排序序号
 *               status:
 *                 type: integer
 *                 enum: [0, 1]
 *                 description: 状态（0=禁用，1=启用）
 *     responses:
 *       201:
 *         description: 创建成功
 *       400:
 *         description: 参数错误
 */
app.post('/api/top-items', auth, async (req, res) => {
  let connection;
  try {
    const { title, content, orderIndex, status } = req.body;

    if (!title || orderIndex === undefined || status === undefined) {
      return res.status(400).json({
        success: false,
        message: '标题、排序序号和状态不能为空'
      });
    }

    const parsedOrderIndex = parseInt(orderIndex, 10);
    const parsedStatus = parseInt(status, 10);

    if (Number.isNaN(parsedOrderIndex) || parsedOrderIndex < 0) {
      return res.status(400).json({ success: false, message: '排序序号必须是非负整数' });
    }

    if (![0, 1].includes(parsedStatus)) {
      return res.status(400).json({ success: false, message: '状态必须是 0 或 1' });
    }

    connection = await getConn();
    const [result] = await connection.execute(
      `INSERT INTO top_items (title, content, created_by, order_index, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, NOW(), NOW())`,
      [title.trim(), content || null, req.user.id, parsedOrderIndex, parsedStatus]
    );

    const [rows] = await connection.execute(
      `SELECT ti.*, u.username AS creator_username, u.real_name AS creator_real_name
       FROM top_items ti
       LEFT JOIN users u ON ti.created_by = u.id
       WHERE ti.id = ?`,
      [result.insertId]
    );

    const item = rows.length > 0 ? {
      id: rows[0].id,
      title: rows[0].title,
      content: rows[0].content,
      orderIndex: rows[0].order_index,
      status: rows[0].status,
      createdAt: rows[0].created_at,
      updatedAt: rows[0].updated_at,
      creator: {
        id: rows[0].created_by,
        username: rows[0].creator_username,
        realName: rows[0].creator_real_name
      }
    } : null;

    res.status(201).json({
      success: true,
      message: '事项创建成功',
      item
    });
  } catch (e) {
    console.error('创建十大事项失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  } finally {
    if (connection) connection.release();
  }
});

/**
 * @swagger
 * /api/top-items/{id}:
 *   put:
 *     summary: 更新公司十大事项
 *     tags: [TopItems]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 事项ID
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *               content:
 *                 type: string
 *               orderIndex:
 *                 type: integer
 *                 minimum: 0
 *               status:
 *                 type: integer
 *                 enum: [0, 1]
 *     responses:
 *       200:
 *         description: 更新成功
 *       400:
 *         description: 参数错误
 *       404:
 *         description: 事项不存在
 */
app.put('/api/top-items/:id', auth, async (req, res) => {
  let connection;
  try {
    const itemId = parseInt(req.params.id, 10);
    if (Number.isNaN(itemId)) {
      return res.status(400).json({ success: false, message: 'ID 参数错误' });
    }

    const { title, content, orderIndex, status } = req.body;
    const updateFields = [];
    const updateValues = [];

    if (title !== undefined) {
      updateFields.push('title = ?');
      updateValues.push(title.trim());
    }

    if (content !== undefined) {
      updateFields.push('content = ?');
      updateValues.push(content);
    }

    if (orderIndex !== undefined) {
      const parsedOrderIndex = parseInt(orderIndex, 10);
      if (Number.isNaN(parsedOrderIndex) || parsedOrderIndex < 0) {
        return res.status(400).json({ success: false, message: '排序序号必须是非负整数' });
      }
      updateFields.push('order_index = ?');
      updateValues.push(parsedOrderIndex);
    }

    if (status !== undefined) {
      const parsedStatus = parseInt(status, 10);
      if (![0, 1].includes(parsedStatus)) {
        return res.status(400).json({ success: false, message: '状态必须是 0 或 1' });
      }
      updateFields.push('status = ?');
      updateValues.push(parsedStatus);
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ success: false, message: '没有要更新的字段' });
    }

    updateFields.push('updated_at = NOW()');
    connection = await getConn();
    updateValues.push(itemId);
    const sql = `UPDATE top_items SET ${updateFields.join(', ')} WHERE id = ?`;
    const [result] = await connection.execute(sql, updateValues);

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '事项不存在' });
    }

    res.json({ success: true, message: '事项更新成功' });
  } catch (e) {
    console.error('更新十大事项失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  } finally {
    if (connection) connection.release();
  }
});

/**
 * @swagger
 * /api/top-items/{id}:
 *   delete:
 *     summary: 删除公司十大事项
 *     tags: [TopItems]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 事项ID
 *     responses:
 *       200:
 *         description: 删除成功
 *       400:
 *         description: ID参数错误
 *       404:
 *         description: 事项不存在
 */
app.delete('/api/top-items/:id', auth, async (req, res) => {
  let connection;
  try {
    const itemId = parseInt(req.params.id, 10);
    if (Number.isNaN(itemId)) {
      return res.status(400).json({ success: false, message: 'ID 参数错误' });
    }

    connection = await getConn();
    const [result] = await connection.execute('DELETE FROM top_items WHERE id = ?', [itemId]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '事项不存在' });
    }

    res.json({ success: true, message: '事项删除成功' });
  } catch (e) {
    console.error('删除十大事项失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  } finally {
    if (connection) connection.release();
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

/**
 * @swagger
 * /api/tasks:
 *   post:
 *     summary: 创建任务
 *     tags: [任务管理]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *             properties:
 *               name:
 *                 type: string
 *                 description: 任务名称
 *               description:
 *                 type: string
 *                 description: 任务描述（可选）
 *               priority:
 *                 type: string
 *                 enum: [low, medium, high]
 *                 default: low
 *               assigneeId:
 *                 type: integer
 *                 description: 负责人ID（可选）
 *               dueTime:
 *                 type: string
 *                 format: date-time
 *                 description: 截止时间（可选）
 *               status:
 *                 type: string
 *                 default: not_started
 *     responses:
 *       201:
 *         description: 创建成功
 *       400:
 *         description: 任务名称不能为空
 *       403:
 *         description: 权限不足（需要 task:create 权限）
 */
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
        status || 'not_started'
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

/**
 * @swagger
 * /api/tasks/{id}:
 *   put:
 *     summary: 更新任务
 *     tags: [任务管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 任务ID
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 description: 任务名称
 *               description:
 *                 type: string
 *                 description: 任务描述
 *               priority:
 *                 type: string
 *                 enum: [low, medium, high]
 *               assigneeId:
 *                 type: integer
 *                 description: 负责人ID（可选，传 null 表示清空）
 *               dueTime:
 *                 type: string
 *                 format: date-time
 *                 description: 截止时间
 *               status:
 *                 type: string
 *                 enum: [pending_assignment, not_started, in_progress, paused, completed, closed, cancelled]
 *                 description: 任务状态
 *               progress:
 *                 type: integer
 *                 minimum: 0
 *                 maximum: 100
 *                 description: 进度（0-100），如果为100会自动设置状态为completed
 *     responses:
 *       200:
 *         description: 更新成功
 *       400:
 *         description: 没有要更新的字段
 *       403:
 *         description: 权限不足（需要 task:edit 权限）
 *       404:
 *         description: 任务不存在
 */
// 更新任务
app.put('/api/tasks/:id', auth, checkPermission('task:edit'), async (req, res) => {
  try {
    const taskId = parseInt(req.params.id, 10);
    const { name, description, priority, assigneeId, dueTime, status, progress } = req.body;
    
    // 兼容旧的/前端可能传入的状态值，统一映射为表结构中定义的枚举值
    const VALID_STATUSES = [
      'pending_assignment',
      'not_started',
      'in_progress',
      'paused',
      'completed',
      'closed',
      'cancelled'
    ];
    const STATUS_MAP = {
      pending: 'not_started',        // 旧值 pending -> not_started
      doing: 'in_progress',          // 如果前端用 doing 表示进行中
      done: 'completed'              // 如果前端用 done 表示已完成
      // 如有其他历史值，可以在这里继续扩展映射
    };
    // 将空字符串/null 视为“未提供状态”，避免错误更新
    let normalizedStatus = status;
    if (normalizedStatus === '' || normalizedStatus === null) {
      normalizedStatus = undefined;
    }
    let finalStatus = normalizedStatus !== undefined
      ? (STATUS_MAP[normalizedStatus] || normalizedStatus)
      : undefined;
    
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
      // 只有在合法枚举值列表中的状态才更新，非法值直接忽略，避免数据库报错
      if (VALID_STATUSES.includes(finalStatus)) {
      updateFields.push('status = ?');
      updateValues.push(finalStatus);
      } else {
        console.warn('忽略非法的任务状态值，不更新 status 字段:', finalStatus);
      }
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

/**
 * @swagger
 * /api/tasks/{id}:
 *   delete:
 *     summary: 删除任务
 *     tags: [任务管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 任务ID
 *     responses:
 *       200:
 *         description: 删除成功
 *       404:
 *         description: 任务不存在
 *       403:
 *         description: 权限不足（需要 task:delete 权限）
 */
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
const server = app.listen(PORT, () => {
  console.log(`🚀 管理后台服务器运行在 http://localhost:${PORT}`);
  console.log(`📊 健康检查: http://localhost:${PORT}/api/health`);
});

// 处理端口被占用的情况
server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`❌ 错误: 端口 ${PORT} 已被占用！`);
    console.error(`💡 解决方案:`);
    console.error(`   1. 关闭占用该端口的进程（在 PowerShell 中运行）：`);
    console.error(`      netstat -ano | findstr :${PORT}`);
    console.error(`      Stop-Process -Id <PID> -Force`);
    console.error(`   2. 或者使用其他端口：`);
    console.error(`      PORT=3003 node admin-server.js`);
    process.exit(1);
  } else {
    console.error('❌ 服务器启动失败:', err);
    process.exit(1);
  }
});
