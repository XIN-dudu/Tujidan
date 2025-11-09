const express = require('express');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const app = express();
const PORT = process.env.PORT || 3001;

// 中间件
app.use(cors());
app.use(express.json());

// Swagger 配置
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Tujidan API',
      version: '1.0.0',
      description: 'Tujidan 后端 API 文档 - 任务管理系统',
      contact: {
        name: 'API Support',
      },
    },
    servers: [
      {
        url: 'http://localhost:3001',
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
            realName: { type: 'string' },
            phone: { type: 'string' },
            position: { type: 'string' },
            avatarUrl: { type: 'string' },
          },
        },
        Task: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            name: { type: 'string' },
            description: { type: 'string' },
            priority: { type: 'string', enum: ['low', 'medium', 'high'] },
            status: { type: 'string' },
            progress: { type: 'integer', minimum: 0, maximum: 100 },
            plan_start_time: { type: 'string', format: 'date-time' },
            due_time: { type: 'string', format: 'date-time' },
            owner_user_id: { type: 'string' },
            creator_user_id: { type: 'string' },
          },
        },
        Log: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            userId: { type: 'integer' },
            title: { type: 'string' },
            content: { type: 'string' },
            type: { type: 'string', enum: ['work', 'study', 'life', 'other'] },
            priority: { type: 'string', enum: ['low', 'medium', 'high'] },
            progress: { type: 'integer', minimum: 0, maximum: 100 },
            startTime: { type: 'string', format: 'date-time' },
            endTime: { type: 'string', format: 'date-time' },
            taskId: { type: 'integer' },
            logStatus: { type: 'string', enum: ['pending', 'completed', 'cancelled'] },
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
      { name: '认证相关', description: '用户注册、登录、验证' },
      { name: '系统', description: '系统健康检查' },
      { name: '用户管理', description: '用户相关操作' },
      { name: '任务管理', description: '任务 CRUD 操作' },
      { name: '日志管理', description: '日志 CRUD 操作' },
      { name: '权限管理', description: 'RBAC 权限管理' },
    ],
  },
  apis: ['./simple_server_final.js'],
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

// 添加 Swagger UI 路由
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// 提供 JSON 格式的文档
app.get('/api-docs.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});

// 确保上传目录存在
const uploadsDir = path.join(__dirname, 'uploads', 'avatars');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// 配置 multer 用于文件上传
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'avatar-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB
  },
  fileFilter: (req, file, cb) => {
    // 允许的文件扩展名
    const allowedExts = ['.jpeg', '.jpg', '.png', '.gif', '.webp'];
    // 允许的 MIME 类型（支持多种可能的格式）
    const allowedMimeTypes = [
      'image/jpeg', 
      'image/jpg', 
      'image/png', 
      'image/gif', 
      'image/webp',
      'image/x-png',  // 某些客户端可能发送这个
      'image/pjpeg'   // 某些客户端可能发送这个
    ];
    
    const ext = path.extname(file.originalname).toLowerCase();
    const mimetype = file.mimetype ? file.mimetype.toLowerCase() : '';
    
    // 检查扩展名或 MIME 类型（只要有一个匹配即可）
    const isValidExt = allowedExts.includes(ext);
    const isValidMime = mimetype && (allowedMimeTypes.includes(mimetype) || mimetype.startsWith('image/'));
    
    if (isValidExt || isValidMime) {
      return cb(null, true);
    } else {
      console.log('文件验证失败:', { 
        filename: file.originalname, 
        ext, 
        mimetype: file.mimetype,
        isValidExt,
        isValidMime
      });
      cb(new Error('只允许上传图片文件 (jpeg, jpg, png, gif, webp)'));
    }
  }
});

// 静态文件服务 - 提供头像访问
app.use('/uploads/avatars', express.static(uploadsDir));

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

// 检查用户是否有指定权限的辅助函数
async function hasPermission(userId, permission) {
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
    console.error('检查权限失败:', e);
    return false;
  }
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


/**
 * @swagger
 * /api/register:
 *   post:
 *     summary: 用户注册
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
 *               - realName
 *             properties:
 *               username:
 *                 type: string
 *                 description: 用户名
 *                 example: testuser
 *               password:
 *                 type: string
 *                 description: 密码（至少6位）
 *                 example: password123
 *               email:
 *                 type: string
 *                 description: 邮箱（可选）
 *                 example: test@example.com
 *               realName:
 *                 type: string
 *                 description: 真实姓名
 *                 example: 张三
 *               phone:
 *                 type: string
 *                 description: 手机号（可选）
 *                 example: 13800138000
 *               position:
 *                 type: string
 *                 description: 职位（可选）
 *                 example: 开发工程师
 *     responses:
 *       201:
 *         description: 注册成功
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
 *                   example: 注册成功
 *                 token:
 *                   type: string
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       400:
 *         description: 参数错误或用户名已存在
 */
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

/**
 * @swagger
 * /api/login:
 *   post:
 *     summary: 用户登录
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
 *                 example: testuser
 *               password:
 *                 type: string
 *                 description: 密码
 *                 example: password123
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
 *       500:
 *         description: 服务器内部错误
 */
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
 *                   example: 服务器运行正常
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 */
// 健康检查接口
app.get('/api/health', (req, res) => {
  res.json({ 
    success: true, 
    message: '服务器运行正常',
    timestamp: new Date().toISOString()
  });
});

/**
 * @swagger
 * /api/user/avatar:
 *   post:
 *     summary: 上传头像
 *     tags: [用户管理]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - avatar
 *             properties:
 *               avatar:
 *                 type: string
 *                 format: binary
 *                 description: 图片文件（jpeg/jpg/png/gif/webp，最大5MB）
 *     responses:
 *       200:
 *         description: 上传成功
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
 *                   example: 头像上传成功
 *                 avatarUrl:
 *                   type: string
 *                   example: data:image/png;base64,iVBORw0KGgo...
 *       400:
 *         description: 未选择文件或文件格式不正确
 */
// 上传头像接口 - 将图片转换为 base64 字符串存储
app.post('/api/user/avatar', auth, upload.single('avatar'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ 
        success: false, 
        message: '请选择要上传的图片' 
      });
    }

    const connection = await getConn();
    
    // 读取文件并转换为 base64 字符串
    const fileBuffer = fs.readFileSync(req.file.path);
    const base64String = fileBuffer.toString('base64');
    
    // 根据文件扩展名确定正确的 MIME 类型（因为 multer 可能返回 application/octet-stream）
    const ext = path.extname(req.file.originalname).toLowerCase();
    let mimeType = req.file.mimetype;
    
    // 如果 MIME 类型不正确，根据扩展名修正
    if (mimeType === 'application/octet-stream' || !mimeType.startsWith('image/')) {
      const mimeMap = {
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.gif': 'image/gif',
        '.webp': 'image/webp'
      };
      mimeType = mimeMap[ext] || 'image/jpeg'; // 默认使用 jpeg
    }
    
    // 构建 data URI（包含正确的 MIME 类型）
    const avatarDataUri = `data:${mimeType};base64,${base64String}`;
    
    // 保存文件路径，用于后续删除
    const tempFilePath = req.file.path;
    
    // 删除临时文件（不再需要）
    try {
      if (fs.existsSync(tempFilePath)) {
        fs.unlinkSync(tempFilePath);
      }
    } catch (err) {
      console.error('删除临时文件失败:', err);
    }
    
    // 更新用户头像（存储 base64 字符串）
    await connection.execute(
      'UPDATE users SET avatar_url = ? WHERE id = ?',
      [avatarDataUri, req.user.id]
    );
    
    // 同时更新 avatars 表（file_name 等字段作为元数据保留，用于记录原始文件名等信息）
    const [existingAvatar] = await connection.execute(
      'SELECT id FROM avatars WHERE user_id = ?',
      [req.user.id]
    );
    
    if (existingAvatar.length > 0) {
      // 更新现有记录（file_name 保留作为元数据，记录原始文件名）
      await connection.execute(
        'UPDATE avatars SET avatar_url = ?, file_name = ?, file_size = ?, mime_type = ?, updated_at = NOW() WHERE user_id = ?',
        [avatarDataUri, req.file.originalname, req.file.size, req.file.mimetype, req.user.id]
      );
    } else {
      // 插入新记录
      await connection.execute(
        'INSERT INTO avatars (user_id, avatar_url, file_name, file_size, mime_type) VALUES (?, ?, ?, ?, ?)',
        [req.user.id, avatarDataUri, req.file.originalname, req.file.size, req.file.mimetype]
      );
    }
    
    await connection.end();
    
    // 调试信息：检查返回的数据
    console.log('头像上传成功，返回数据长度:', avatarDataUri.length);
    console.log('头像数据前100字符:', avatarDataUri.substring(0, 100));
    
    res.json({
      success: true,
      message: '头像上传成功',
      avatarUrl: avatarDataUri
    });
  } catch (e) {
    console.error('上传头像失败:', e);
    // 如果上传失败，删除已上传的临时文件
    if (req.file && req.file.path && fs.existsSync(req.file.path)) {
      try {
        fs.unlinkSync(req.file.path);
      } catch (err) {
        console.error('删除上传文件失败:', err);
      }
    }
    res.status(500).json({ 
      success: false, 
      message: '服务器内部错误: ' + e.message 
    });
  }
});

// ---- Users（用户搜索） ----

/**
 * @swagger
 * /api/users:
 *   get:
 *     summary: 获取用户列表
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
 *                   example: true
 *                 users:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       username:
 *                         type: string
 *                       avatar_url:
 *                         type: string
 *                       created_at:
 *                         type: string
 *                       updated_at:
 *                         type: string
 */
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
/**
 * @swagger
 * /api/tasks/{id}:
 *   get:
 *     summary: 获取任务详情
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
 *         description: 获取成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Task'
 *       404:
 *         description: 任务不存在
 *       403:
 *         description: 权限不足
 */
// 获取单个任务详情
app.get('/api/tasks/:id', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const connection = await getConn();
    
    // 检查是否有查看所有任务的权限
    const canViewAll = await hasPermission(req.user.id, 'task:view_all');
    
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
    if (!canViewAll) {
      // 没有查看所有任务权限的用户，只能查看自己创建的任务或分配给自己的任务
      const isCreator = task.creator_user_id == req.user.id;
      const isAssignee = task.owner_user_id == req.user.id;
      
      if (!isCreator && !isAssignee) {
        await connection.end();
        return res.status(403).json({ success: false, message: '只能查看自己创建或分配给自己的任务' });
      }
      
      // 如果是分配给自己的任务，必须是已分配状态（不是pending_assignment）
      if (isAssignee && task.status == 'pending_assignment') {
        await connection.end();
        return res.status(403).json({ success: false, message: '任务尚未分配，无法查看' });
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

/**
 * @swagger
 * /api/users/search:
 *   get:
 *     summary: 搜索用户
 *     tags: [用户管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: keyword
 *         schema:
 *           type: string
 *         description: 搜索关键词（用户名或真实姓名）
 *         example: 张三
 *     responses:
 *       200:
 *         description: 搜索成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 users:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       username:
 *                         type: string
 *                       real_name:
 *                         type: string
 *                       email:
 *                         type: string
 *                       avatar_url:
 *                         type: string
 */
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

/**
 * @swagger
 * /api/user/permissions:
 *   get:
 *     summary: 获取当前用户角色和权限
 *     tags: [权限管理]
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
 *                   example: true
 *                 roles:
 *                   type: array
 *                   items:
 *                     type: object
 *                 permissions:
 *                   type: array
 *                   items:
 *                     type: object
 */
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

/**
 * @swagger
 * /api/roles:
 *   get:
 *     summary: 获取所有角色
 *     tags: [权限管理]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 获取成功
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
    await connection.end();
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
 *     tags: [权限管理]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 获取成功
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
    await connection.end();
    res.json({ success: true, permissions });
  } catch (e) {
    console.error('获取权限列表失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

/**
 * @swagger
 * /api/roles/{roleId}/permissions:
 *   get:
 *     summary: 获取角色权限
 *     tags: [权限管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: 获取成功
 */
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

/**
 * @swagger
 * /api/users/{userId}/roles:
 *   post:
 *     summary: 为用户分配角色
 *     tags: [权限管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: integer
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
 *     responses:
 *       200:
 *         description: 分配成功
 */
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

/**
 * @swagger
 * /api/roles/{roleId}/permissions:
 *   post:
 *     summary: 为角色分配权限
 *     tags: [权限管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: integer
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
 *     responses:
 *       200:
 *         description: 分配成功
 */
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

/**
 * @swagger
 * /api/tasks:
 *   get:
 *     summary: 获取任务列表
 *     tags: [任务管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: keyword
 *         schema:
 *           type: string
 *         description: 搜索关键词
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *           maximum: 50
 *         description: 返回数量限制
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
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Task'
 */
// ---- Tasks ----
app.get('/api/tasks', auth, async (req, res) => {
  try {
    const keyword = (req.query.keyword || '').trim();
    const raw = parseInt(req.query.limit || '20', 10);
    const limit = Number.isFinite(raw) && raw > 0 && raw <= 50 ? raw : 20;
    const connection = await getConn();
    
    // 检查是否有查看所有任务的权限
    const canViewAll = await hasPermission(req.user.id, 'task:view_all');
    
    let sql = 'SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id, created_at, updated_at FROM tasks';
    const params = [];
    let whereConditions = [];
    
    if (canViewAll) {
      // 有 task:view_all 权限的用户（founder/admin）可以看到所有任务
      // 不需要额外条件
    } else {
      // 没有权限的用户只能看到自己创建的任务或分配给自己的任务
      // 如果是创建者，可以查看；如果是被分配者，且状态不是pending_assignment，可以查看
      whereConditions.push('(creator_id = ? OR (assignee_id = ? AND status != ?))');
      params.push(req.user.id, req.user.id, 'pending_assignment');
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
 *                 description: 任务名称（必填，最大64字符）
 *                 example: 完成项目开发
 *               description:
 *                 type: string
 *                 description: 任务描述
 *                 example: 完成前端和后端开发
 *               priority:
 *                 type: string
 *                 enum: [low, medium, high]
 *                 default: low
 *                 description: 优先级
 *               status:
 *                 type: string
 *                 default: not_started
 *                 description: 任务状态
 *               progress:
 *                 type: integer
 *                 minimum: 0
 *                 maximum: 100
 *                 default: 0
 *                 description: 进度（0-100）
 *               dueTime:
 *                 type: string
 *                 format: date-time
 *                 description: 截止时间
 *               planStartTime:
 *                 type: string
 *                 format: date-time
 *                 description: 计划开始时间
 *               ownerUserId:
 *                 type: integer
 *                 description: 负责人ID
 *     responses:
 *       201:
 *         description: 创建成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 task:
 *                   $ref: '#/components/schemas/Task'
 *       400:
 *         description: 参数错误
 *       403:
 *         description: 权限不足
 *       409:
 *         description: 任务名称重复
 */
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

/**
 * @swagger
 * /api/tasks/{id}:
 *   patch:
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
 *               description:
 *                 type: string
 *               priority:
 *                 type: string
 *                 enum: [low, medium, high]
 *               status:
 *                 type: string
 *               progress:
 *                 type: integer
 *                 minimum: 0
 *                 maximum: 100
 *               dueTime:
 *                 type: string
 *                 format: date-time
 *               planStartTime:
 *                 type: string
 *                 format: date-time
 *               ownerUserId:
 *                 type: integer
 *     responses:
 *       200:
 *         description: 更新成功
 *       404:
 *         description: 任务不存在
 *       403:
 *         description: 权限不足
 */
app.patch('/api/tasks/:id', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { name, description, priority, status, progress, dueTime, planStartTime, ownerUserId } = req.body;
    const connection = await getConn();
    
    // 检查任务是否存在
    const [exists] = await connection.execute('SELECT id, creator_id, assignee_id FROM tasks WHERE id = ? LIMIT 1', [id]);
    if (exists.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '任务不存在' });
    }
    
    const task = exists[0];
    const isCreator = task.creator_id === req.user.id;
    
    // 所有人都可以修改任务，但如果不是创建者，只能更新进度
    if (!isCreator) {
      // 非创建者只能更新进度
      if (progress !== undefined && progress !== null) {
        const newStatus = getTaskStatusFromProgress(progress);
        await connection.execute(
          'UPDATE tasks SET progress = ?, status = ? WHERE id = ?',
          [progress, newStatus, id]
        );
        const [rows] = await connection.execute('SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?', [id]);
        await connection.end();
        return res.json({ success: true, task: rows[0] });
      } else {
        await connection.end();
        return res.status(403).json({ success: false, message: '非创建者只能更新任务进度' });
      }
    }
    
    // 创建者可以更新所有字段
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

/**
 * @swagger
 * /api/tasks/{id}/progress:
 *   patch:
 *     summary: 更新任务进度
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
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - progress
 *             properties:
 *               progress:
 *                 type: integer
 *                 minimum: 0
 *                 maximum: 100
 *                 description: 进度值（0-100）
 *                 example: 50
 *     responses:
 *       200:
 *         description: 更新成功
 *       400:
 *         description: 进度值无效
 *       404:
 *         description: 任务不存在
 *       403:
 *         description: 权限不足
 */
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
 *         description: 权限不足
 */
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

/**
 * @swagger
 * /api/tasks/{id}/publish:
 *   post:
 *     summary: 发布/分配任务
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
 *               ownerUserId:
 *                 type: integer
 *                 description: 负责人ID（可选，不传则撤回分配）
 *     responses:
 *       200:
 *         description: 操作成功
 *       404:
 *         description: 任务不存在
 *       403:
 *         description: 权限不足
 */
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

/**
 * @swagger
 * /api/tasks/{id}/accept:
 *   post:
 *     summary: 接收任务
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
 *         description: 接收成功
 *       400:
 *         description: 任务状态不允许接收
 *       404:
 *         description: 任务不存在
 *       403:
 *         description: 权限不足
 */
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

/**
 * @swagger
 * /api/tasks/{id}/cancel-accept:
 *   post:
 *     summary: 取消接收任务
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
 *         description: 取消成功
 *       404:
 *         description: 任务不存在
 *       403:
 *         description: 权限不足
 */
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

/**
 * @swagger
 * /api/logs:
 *   post:
 *     summary: 创建日志
 *     tags: [日志管理]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - content
 *             properties:
 *               title:
 *                 type: string
 *                 description: 日志标题（可选）
 *               content:
 *                 type: string
 *                 description: 日志内容（必填）
 *                 example: 今天完成了项目开发
 *               type:
 *                 type: string
 *                 enum: [work, study, life, other]
 *                 description: 日志类型
 *               priority:
 *                 type: string
 *                 enum: [low, medium, high]
 *                 default: low
 *               progress:
 *                 type: integer
 *                 minimum: 0
 *                 maximum: 100
 *                 default: 0
 *               timeFrom:
 *                 type: string
 *                 format: date-time
 *                 description: 开始时间
 *               timeTo:
 *                 type: string
 *                 format: date-time
 *                 description: 结束时间
 *               taskId:
 *                 type: integer
 *                 description: 关联任务ID
 *               createNewTask:
 *                 type: object
 *                 description: 创建新任务（可选）
 *               syncTaskProgress:
 *                 type: boolean
 *                 default: false
 *                 description: 是否同步任务进度
 *               logStatus:
 *                 type: string
 *                 enum: [pending, completed, cancelled]
 *                 default: pending
 *     responses:
 *       201:
 *         description: 创建成功
 *       400:
 *         description: 参数错误
 */
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

/**
 * @swagger
 * /api/logs:
 *   get:
 *     summary: 获取日志列表
 *     tags: [日志管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *           enum: [work, study, life, other]
 *         description: 日志类型过滤
 *       - in: query
 *         name: q
 *         schema:
 *           type: string
 *         description: 搜索关键词
 *       - in: query
 *         name: startTime
 *         schema:
 *           type: string
 *           format: date-time
 *         description: 开始时间
 *       - in: query
 *         name: endTime
 *         schema:
 *           type: string
 *           format: date-time
 *         description: 结束时间
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
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: 获取日志成功
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Log'
 *                 code:
 *                   type: integer
 *                   example: 200
 */
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



/**
 * @swagger
 * /api/logs/{id}:
 *   get:
 *     summary: 获取日志详情
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
 *       404:
 *         description: 日志不存在
 */
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

/**
 * @swagger
 * /api/logs/{id}:
 *   patch:
 *     summary: 更新日志
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
 *               type:
 *                 type: string
 *                 enum: [work, study, life, other]
 *               priority:
 *                 type: string
 *                 enum: [low, medium, high]
 *               progress:
 *                 type: integer
 *                 minimum: 0
 *                 maximum: 100
 *               timeFrom:
 *                 type: string
 *                 format: date-time
 *               timeTo:
 *                 type: string
 *                 format: date-time
 *               taskId:
 *                 type: integer
 *               syncTaskProgress:
 *                 type: boolean
 *               logStatus:
 *                 type: string
 *                 enum: [pending, completed, cancelled]
 *     responses:
 *       200:
 *         description: 更新成功
 *       404:
 *         description: 日志不存在
 */
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
});
