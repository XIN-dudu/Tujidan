require('dotenv').config();
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
const { extractKeywords } = require('./nlp_service');
const { generateMBTIAnalysis, generateDevelopmentSuggestions, generateMBTIFromLogsText } = require('./llm_service');
const { startScheduler } = require('./scheduler');

const app = express();
const PORT = process.env.PORT || 3001;

// 中间件
app.use(cors());
// 增加请求体大小限制，支持 base64 图片上传（50MB）
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

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

const IMAGE_MIME_MAP = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.gif': 'image/gif',
  '.webp': 'image/webp'
};

const MAX_IMAGES_PER_REQUEST = 9;

function normalizeMimeType(file) {
  if (file?.mimetype && file.mimetype.startsWith('image/')) {
    return file.mimetype;
  }
  const ext = path.extname(file?.originalname || '').toLowerCase();
  return IMAGE_MIME_MAP[ext] || 'image/jpeg';
}

async function convertFileToDataUri(file) {
  if (!file?.path) {
    throw new Error('上传文件无效');
  }
  const buffer = await fs.promises.readFile(file.path);
  const mimeType = normalizeMimeType(file);
  const base64String = buffer.toString('base64');
  return {
    dataUri: `data:${mimeType};base64,${base64String}`,
    meta: {
      fileName: file.originalname || 'image',
      fileSize: file.size || buffer.length,
      mimeType
    }
  };
}

function cleanupUploadedFiles(files) {
  if (!files) return;
  files.forEach(file => {
    if (file?.path && fs.existsSync(file.path)) {
      try {
        fs.unlinkSync(file.path);
      } catch (err) {
        console.error('删除临时文件失败:', err);
      }
    }
  });
}

function formatImageRow(row) {
  return {
    id: row.id,
    dataUri: row.image_data,
    fileName: row.file_name,
    fileSize: row.file_size,
    mimeType: row.mime_type,
    width: row.width,
    height: row.height,
    displayOrder: row.display_order,
    createdAt: row.created_at
  };
}

async function fetchImagesGrouped(connection, tableName, fkField, ids) {
  if (!Array.isArray(ids) || ids.length === 0) return {};
  const uniqueIds = [...new Set(ids)].filter(id => id !== null && id !== undefined);
  if (uniqueIds.length === 0) return {};
  const placeholders = uniqueIds.map(() => '?').join(',');
  const [rows] = await connection.execute(
    `SELECT id, ${fkField} AS owner_id, image_data, file_name, file_size, mime_type, width, height, display_order, created_at 
     FROM ${tableName} 
     WHERE ${fkField} IN (${placeholders}) 
     ORDER BY ${fkField}, display_order, id`,
    uniqueIds
  );
  return rows.reduce((acc, row) => {
    if (!acc[row.owner_id]) acc[row.owner_id] = [];
    acc[row.owner_id].push(formatImageRow(row));
    return acc;
  }, {});
}

async function attachImagesToRows(connection, rows, tableName, fkField) {
  if (!Array.isArray(rows) || rows.length === 0) return rows;
  const ids = [...new Set(rows.map(row => row.id).filter(id => id !== null && id !== undefined))];
  const imageMap = await fetchImagesGrouped(connection, tableName, fkField, ids);
  rows.forEach(row => {
    row.images = imageMap[row.id] || [];
  });
  return rows;
}

async function getImagesForSingle(connection, tableName, fkField, id) {
  if (id === null || id === undefined) return [];
  const map = await fetchImagesGrouped(connection, tableName, fkField, [id]);
  return map[id] || [];
}

async function enrichTaskRows(connection, tasks) {
  await attachImagesToRows(connection, tasks, 'task_images', 'task_id');
  return tasks;
}

async function enrichLogRows(connection, logs) {
  await attachImagesToRows(connection, logs, 'log_images', 'log_id');
  return logs;
}

async function saveDataUriImages(connection, tableName, fkField, ownerId, dataUris, startOrder = 0) {
  if (!Array.isArray(dataUris) || dataUris.length === 0) return;
  let order = startOrder;
  for (const uri of dataUris) {
    if (typeof uri !== 'string' || !uri.startsWith('data:')) continue;
    
    // 从 data URI 中提取 MIME 类型和文件大小
    let mimeType = null;
    let fileSize = null;
    
    // 解析 data URI: data:image/png;base64,xxx
    const match = uri.match(/^data:([^;]+)(?:;base64)?,(.+)$/);
    if (match) {
      mimeType = match[1] || null;
      const base64Data = match[2] || '';
      // 计算 base64 解码后的实际文件大小（base64 编码会增加约 33%）
      // 实际大小 = base64 长度 * 3 / 4（减去可能的填充）
      const base64Length = base64Data.length;
      const padding = (base64Data.match(/=/g) || []).length;
      fileSize = Math.floor((base64Length * 3) / 4) - padding;
    }
    
    // 生成默认文件名（基于时间戳和顺序）
    const timestamp = Date.now();
    const ext = mimeType ? (mimeType.includes('png') ? '.png' : mimeType.includes('webp') ? '.webp' : mimeType.includes('gif') ? '.gif' : '.jpg') : '.jpg';
    const fileName = `image-${timestamp}-${order}${ext}`;
    
    await connection.execute(
      `INSERT INTO ${tableName} (${fkField}, image_data, file_name, file_size, mime_type, display_order) VALUES (?, ?, ?, ?, ?, ?)`,
      [ownerId, uri, fileName, fileSize, mimeType, order]
    );
    order += 1;
  }
}

// 静态文件服务 - 提供头像访问
app.use('/uploads/avatars', express.static(uploadsDir));

// 数据库配置（优化连接）
const dbConfig = {
  host: '127.0.0.1',
  user: 'root',
  password: '123456',
  database: 'tujidan',
  port: 3306,
  authPlugin: 'caching_sha2_password', // 强制使用新版验证插件
  charset: 'utf8mb4',
  connectTimeout: 60000,    // 增加到60秒
  keepAliveInitialDelay: 0,
  enableKeepAlive: true,
};

const JWT_SECRET = 'your_jwt_secret_key_here_change_this_in_production';
const DASHBOARD_LOG_LIMIT = 10;
const DASHBOARD_TASK_LIMIT = 10;
const TOP_ITEMS_LIMIT = 10;
const PERSONAL_TOP_ITEMS_LIMIT = 10;

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

async function getUserRoleNames(connection, userId) {
  const [rows] = await connection.execute(
    `SELECT r.role_name 
     FROM roles r
     JOIN user_roles ur ON r.id = ur.role_id
     WHERE ur.user_id = ?`,
    [userId]
  );
  return rows.map(r => r.role_name);
}

async function getUserDepartmentId(connection, userId) {
  const [[row]] = await connection.execute(
    'SELECT department_id FROM users WHERE id = ? LIMIT 1',
    [userId]
  );
  return row ? row.department_id : null;
}

function normalizeOptionalOwnerUserId(rawValue) {
  if (rawValue === undefined) {
    return { provided: false, value: undefined };
  }
  if (rawValue === null || rawValue === '') {
    return { provided: true, value: null };
  }
  const parsed = Number(rawValue);
  if (!Number.isFinite(parsed) || !Number.isInteger(parsed) || parsed <= 0) {
    return { provided: true, error: '负责人ID必须为正整数' };
  }
  return { provided: true, value: parsed };
}

async function validateDeptHeadAssignment(connection, deptHeadUserId, targetUserId) {
  if (!targetUserId || Number(targetUserId) === Number(deptHeadUserId)) {
    return { ok: true };
  }
  const [[deptHead]] = await connection.execute(
    'SELECT id, department_id FROM users WHERE id = ? LIMIT 1',
    [deptHeadUserId]
  );
  if (!deptHead) {
    return { ok: false, status: 400, message: '部门负责人不存在' };
  }
  if (deptHead.department_id === null || deptHead.department_id === undefined) {
    return { ok: false, status: 400, message: '请先为该负责人设置所属部门' };
  }
  const [[targetUser]] = await connection.execute(
    'SELECT id, department_id FROM users WHERE id = ? LIMIT 1',
    [targetUserId]
  );
  if (!targetUser) {
    return { ok: false, status: 400, message: '指定的负责人不存在' };
  }
  if (targetUser.department_id === null || targetUser.department_id === undefined) {
    return { ok: false, status: 403, message: '负责人只能分配给已加入部门的成员' };
  }
  if (Number(targetUser.department_id) !== Number(deptHead.department_id)) {
    return { ok: false, status: 403, message: '部门负责人只能给本部门成员分配任务' };
  }
  return { ok: true };
}

async function hasPermissionWithConnection(connection, userId, permission) {
  const [permissions] = await connection.execute(`
    SELECT DISTINCT p.perm_key 
    FROM permissions p
    JOIN role_permissions rp ON p.id = rp.permission_id
    JOIN user_roles ur ON rp.role_id = ur.role_id
    WHERE ur.user_id = ? AND p.perm_key = ?
    LIMIT 1
  `, [userId, permission]);
  return permissions.length > 0;
}

// 获取数据库连接
async function getConn() {
  return mysql.createConnection(dbConfig);
}

// ---- 缓存工具（基于 MySQL JSON 表）----
async function ensureMbtiCacheTable(connection) {
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS user_mbti_cache (
      user_id INT NOT NULL,
      cache_type ENUM('analysis','suggestions') NOT NULL,
      data JSON NOT NULL,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY(user_id, cache_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
}

async function getMbtiCache(userId, type) {
  const connection = await getConn();
  await ensureMbtiCacheTable(connection);
  const [rows] = await connection.execute(
    'SELECT data FROM user_mbti_cache WHERE user_id = ? AND cache_type = ? LIMIT 1',
    [userId, type]
  );
  await connection.end();
  if (rows.length > 0) {
    try {
      return JSON.parse(rows[0].data);
    } catch (e) {
      return rows[0].data; // 若已是对象
    }
  }
  return null;
}

async function setMbtiCache(userId, type, dataObj) {
  const connection = await getConn();
  await ensureMbtiCacheTable(connection);
  await connection.execute(
    'INSERT INTO user_mbti_cache (user_id, cache_type, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated_at = CURRENT_TIMESTAMP',
    [userId, type, JSON.stringify(dataObj)]
  );
  await connection.end();
}

async function ensureDashboardLogsTable(connection) {
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS user_dashboard_logs (
      user_id BIGINT NOT NULL,
      log_id BIGINT NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (user_id, log_id),
      INDEX idx_log_id (log_id),
      CONSTRAINT fk_dashboard_log_log FOREIGN KEY (log_id) REFERENCES logs(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
}

async function ensureDashboardTasksTable(connection) {
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS user_dashboard_tasks (
      user_id BIGINT NOT NULL,
      task_id BIGINT NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (user_id, task_id),
      INDEX idx_task_id (task_id),
      CONSTRAINT fk_dashboard_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
  try {
    await connection.execute('ALTER TABLE user_dashboard_tasks MODIFY task_id BIGINT NOT NULL');
  } catch (e) {
    // ignore if already correct
  }
}

async function ensureUserTopItemsTable(connection) {
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS user_top_items (
      id BIGINT PRIMARY KEY AUTO_INCREMENT,
      user_id BIGINT NOT NULL,
      title VARCHAR(255) NOT NULL,
      content TEXT NULL,
      order_index INT DEFAULT 0,
      status TINYINT DEFAULT 1,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_user_order (user_id, order_index),
      INDEX idx_user_status_order (user_id, status, order_index),
      CONSTRAINT fk_user_top_items_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
}

async function seedDashboardLogs(connection, userId) {
  const [[countRow]] = await connection.execute(
    'SELECT COUNT(*) AS cnt FROM user_dashboard_logs WHERE user_id = ?',
    [userId]
  );
  if ((countRow?.cnt || 0) > 0) return;

  const [rows] = await connection.execute(
    `
      SELECT id
      FROM logs
      WHERE author_user_id = ?
        AND (log_status IS NULL OR log_status != 'completed')
      ORDER BY
        CASE WHEN time_to IS NULL THEN 1 ELSE 0 END,
        time_to ASC,
        created_at DESC
      LIMIT ${DASHBOARD_LOG_LIMIT}
    `,
    [userId]
  );

  for (const row of rows) {
    await connection.execute(
      'INSERT IGNORE INTO user_dashboard_logs (user_id, log_id) VALUES (?, ?)',
      [userId, row.id]
    );
  }
}

async function seedDashboardTasks(connection, userId) {
  const [[countRow]] = await connection.execute(
    'SELECT COUNT(*) AS cnt FROM user_dashboard_tasks WHERE user_id = ?',
    [userId]
  );
  if ((countRow?.cnt || 0) > 0) return;

  const [rows] = await connection.execute(
    `
      SELECT id
      FROM tasks
      WHERE (assignee_id = ? OR creator_id = ?)
        AND (status IS NULL OR status NOT IN ('completed', 'closed'))
      ORDER BY
        CASE WHEN plan_end_time IS NULL THEN 1 ELSE 0 END,
        plan_end_time ASC,
        created_at DESC
      LIMIT ${DASHBOARD_TASK_LIMIT}
    `,
    [userId, userId]
  );

  for (const row of rows) {
    await connection.execute(
      'INSERT IGNORE INTO user_dashboard_tasks (user_id, task_id) VALUES (?, ?)',
      [userId, row.id]
    );
  }
}

async function ensureTopItemsTable(connection) {
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS top_items (
      id BIGINT PRIMARY KEY AUTO_INCREMENT,
      title VARCHAR(255) NOT NULL,
      content TEXT,
      created_by BIGINT,
      order_index INT DEFAULT 0,
      status TINYINT DEFAULT 1,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_status_order (status, order_index)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
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
        avatarUrl: user.avatar_url,
        createdAt: user.created_at
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
// =================================================================
// 通知管理 API
// =================================================================

/**
 * @swagger
 * /api/notifications:
 *   get:
 *     summary: 获取当前用户的通知列表
 *     tags: [通知管理]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取通知列表
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success: { type: boolean }
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id: { type: integer }
 *                       type: { type: string }
 *                       title: { type: string }
 *                       content: { type: string }
 *                       related_id: { type: integer }
 *                       entity_type: { type: string }
 *                       is_read: { type: boolean }
 *                       created_at: { type: string, format: date-time }
 *       401:
 *         description: 未授权
 *       500:
 *         description: 服务器错误
 */
app.get('/api/notifications', auth, async (req, res) => {
  try {
    const connection = await getConn();
    const [notifications] = await connection.execute(
      'SELECT id, type, title, content, related_id, entity_type, is_read, created_at FROM notifications WHERE user_id = ? ORDER BY created_at DESC',
      [req.user.id]
    );
    await connection.end();
    res.json({ success: true, data: notifications });
  } catch (e) {
    console.error('获取通知失败:', e);
    res.status(500).json({ success: false, message: '获取通知失败' });
  }
});

/**
 * @swagger
 * /api/notifications/mark-as-read:
 *   post:
 *     summary: 将所有未读通知标记为已读
 *     tags: [通知管理]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功将所有通知标记为已读
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success: { type: boolean }
 *                 message: { type: string }
 *                 affectedRows: { type: integer }
 *       401:
 *         description: 未授权
 *       500:
 *         description: 服务器错误
 */
app.post('/api/notifications/mark-as-read', auth, async (req, res) => {
  try {
    const connection = await getConn();
    const [result] = await connection.execute(
      'UPDATE notifications SET is_read = TRUE WHERE user_id = ? AND is_read = FALSE',
      [req.user.id]
    );
    await connection.end();
    res.json({ success: true, message: '所有通知已标记为已读', affectedRows: result.affectedRows });
  } catch (e) {
    console.error('标记通知为已读失败:', e);
    res.status(500).json({ success: false, message: '标记通知为已读失败' });
  }
});

/**
 * @swagger
 * /api/notifications/{id}:
 *   delete:
 *     summary: 删除一条通知
 *     tags: [通知管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 要删除的通知的ID
 *     responses:
 *       200:
 *         description: 通知删除成功
 *       403:
 *         description: 权限不足
 *       404:
 *         description: 通知未找到
 *       500:
 *         description: 服务器错误
 */
app.delete('/api/notifications/:id', auth, async (req, res) => {
  const userId = req.user.id;
  const notificationId = req.params.id;

  let connection;
  try {
    connection = await getConn();
    const [result] = await connection.execute(
      'DELETE FROM notifications WHERE id = ? AND user_id = ?',
      [notificationId, userId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '通知未找到或权限不足' });
    }

    res.json({ success: true, message: '通知删除成功' });
  } catch (error) {
    console.error('删除通知失败:', error);
    res.status(500).json({ success: false, message: '删除通知失败' });
  } finally {
    if (connection) await connection.end();
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
      'SELECT id, username, email, real_name, phone, position, avatar_url, status, created_at, department_id, mbit FROM users WHERE id = ? AND status = 1',
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
        avatarUrl: user.avatar_url,
        createdAt: user.created_at,
        departmentId: user.department_id,
        mbti: user.mbit
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
 * /api/geocode:
 *   get:
 *     summary: 地理位置逆编码（将经纬度转换为地址）
 *     tags: [工具]
 *     parameters:
 *       - in: query
 *         name: lat
 *         required: true
 *         schema:
 *           type: number
 *         description: 纬度
 *       - in: query
 *         name: lon
 *         required: true
 *         schema:
 *           type: number
 *         description: 经度
 *     responses:
 *       200:
 *         description: 地址解析成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 address:
 *                   type: string
 *                   example: 北京市朝阳区建国路88号
 *       400:
 *         description: 参数错误
 *       500:
 *         description: 地理编码服务失败
 */
// 地理位置逆编码接口（无需认证，供客户端调用）
app.get('/api/geocode', async (req, res) => {
  try {
    const { lat, lon } = req.query;
    
    // 参数验证
    if (!lat || !lon) {
      return res.status(400).json({
        success: false,
        error: '缺少必要参数 lat 或 lon'
      });
    }
    
    const latitude = parseFloat(lat);
    const longitude = parseFloat(lon);
    
    if (isNaN(latitude) || isNaN(longitude)) {
      return res.status(400).json({
        success: false,
        error: '经纬度参数格式不正确'
      });
    }
    
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return res.status(400).json({
        success: false,
        error: '经纬度参数超出有效范围'
      });
    }
    
    // 调用 Nominatim 逆地理编码服务
    const nominatimUrl = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&accept-language=zh-CN`;
    
    const https = require('https');
    const response = await new Promise((resolve, reject) => {
      https.get(nominatimUrl, {
        headers: {
          'User-Agent': 'Tujidan/1.0 (Log Management App)'
        }
      }, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error('解析 Nominatim 响应失败'));
          }
        });
      }).on('error', reject);
    });
    
    // 解析地址
    if (response && response.display_name) {
      return res.json({
        success: true,
        address: response.display_name
      });
    } else if (response && response.address) {
      // 尝试从 address 字段构建更友好的地址
      const addr = response.address;
      const parts = [
        addr.country,
        addr.state || addr.province,
        addr.city || addr.county,
        addr.suburb || addr.town || addr.village,
        addr.road,
        addr.house_number
      ].filter(Boolean);
      
      return res.json({
        success: true,
        address: parts.join('')
      });
    } else {
      // 如果没有获取到地址信息，返回失败
      return res.status(500).json({
        success: false,
        error: '无法获取地址信息'
      });
    }
    
  } catch (error) {
    console.error('地理编码失败:', error);
    return res.status(500).json({
      success: false,
      error: '地理编码服务暂时不可用'
    });
  }
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

/**
 * @swagger
 * /api/user/profile:
 *   put:
 *     summary: 更新用户个人信息
 *     tags: [用户管理]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               username:
 *                 type: string
 *                 description: 用户名
 *               password:
 *                 type: string
 *                 description: 新密码（可选）
 *               email:
 *                 type: string
 *                 description: 邮箱
 *               phone:
 *                 type: string
 *                 description: 手机号
 *     responses:
 *       200:
 *         description: 更新成功
 *       400:
 *         description: 参数错误
 *       409:
 *         description: 用户名或邮箱已被使用
 */
// 更新用户信息接口
app.put('/api/user/profile', auth, async (req, res) => {
  try {
    const { username, password, email, phone, mbti } = req.body;
    const userId = req.user.id;
    const connection = await getConn();

    // 构建更新字段和值
    const updateFields = [];
    const updateValues = [];

    // 更新用户名
    if (username !== undefined) {
      if (username.trim().length === 0) {
        await connection.end();
        return res.status(400).json({ 
          success: false, 
          message: '用户名不能为空' 
        });
      }
      
      // 检查用户名是否已被其他用户使用
      const [existingUsername] = await connection.execute(
        'SELECT id FROM users WHERE username = ? AND id != ?',
        [username.trim(), userId]
      );
      
      if (existingUsername.length > 0) {
        await connection.end();
        return res.status(409).json({ 
          success: false, 
          message: '该用户名已被使用' 
        });
      }
      
      updateFields.push('username = ?');
      updateValues.push(username.trim());
    }

    // 更新邮箱
    if (email !== undefined) {
      if (email && email.trim().length > 0) {
        // 检查邮箱是否已被其他用户使用
        const [existingEmail] = await connection.execute(
          'SELECT id FROM users WHERE email = ? AND id != ?',
          [email.trim(), userId]
        );
        
        if (existingEmail.length > 0) {
          await connection.end();
          return res.status(409).json({ 
            success: false, 
            message: '该邮箱已被使用' 
          });
        }
      }
      
      updateFields.push('email = ?');
      updateValues.push(email && email.trim().length > 0 ? email.trim() : null);
    }

    // 更新手机号
    if (phone !== undefined) {
      updateFields.push('phone = ?');
      updateValues.push(phone && phone.trim().length > 0 ? phone.trim() : null);
    }

    // 更新MBTI
    if (mbti !== undefined) {
      // 验证MBTI值是否在允许的枚举值中
      const validMbtiValues = ['INTJ', 'INTP', 'ENTJ', 'ENTP', 'INFJ', 'INFP', 'ENFJ', 'ENFP', 'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP'];
      if (mbti && mbti.trim().length > 0) {
        const mbtiUpper = mbti.trim().toUpperCase();
        if (!validMbtiValues.includes(mbtiUpper)) {
          await connection.end();
          return res.status(400).json({ 
            success: false, 
            message: 'MBTI类型无效' 
          });
        }
        updateFields.push('mbit = ?');
        updateValues.push(mbtiUpper);
      } else {
        // 允许设置为null
        updateFields.push('mbit = ?');
        updateValues.push(null);
      }
    }

    // 更新密码
    if (password !== undefined) {
      if (password.length < 6) {
        await connection.end();
        return res.status(400).json({ 
          success: false, 
          message: '密码至少6位' 
        });
      }
      
      const saltRounds = 10;
      const hashedPassword = await bcrypt.hash(password, saltRounds);
      updateFields.push('password_hash = ?');
      updateValues.push(hashedPassword);
    }

    // 如果没有要更新的字段
    if (updateFields.length === 0) {
      await connection.end();
      return res.status(400).json({ 
        success: false, 
        message: '没有提供要更新的字段' 
      });
    }

    // 执行更新
    updateValues.push(userId);
    await connection.execute(
      `UPDATE users SET ${updateFields.join(', ')} WHERE id = ?`,
      updateValues
    );

    // 获取更新后的用户信息
    const [users] = await connection.execute(
      'SELECT id, username, email, real_name, phone, position, avatar_url, created_at, department_id, mbit FROM users WHERE id = ?',
      [userId]
    );

    await connection.end();

    if (users.length === 0) {
      return res.status(404).json({ 
        success: false, 
        message: '用户不存在' 
      });
    }

    const user = users[0];
    res.json({
      success: true,
      message: '更新成功',
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        realName: user.real_name,
        phone: user.phone,
        position: user.position,
        avatarUrl: user.avatar_url,
        createdAt: user.created_at,
        departmentId: user.department_id,
        mbti: user.mbit
      }
    });
  } catch (error) {
    console.error('更新用户信息失败:', error);
    res.status(500).json({ 
      success: false, 
      message: '服务器内部错误' 
    });
  }
});

// ---- Log & Task Images ----

app.post('/api/logs/:id/images', auth, upload.array('images', MAX_IMAGES_PER_REQUEST), async (req, res) => {
  const logId = parseInt(req.params.id, 10);
  if (!Number.isFinite(logId)) {
    return res.status(400).json({ success: false, message: '日志ID无效' });
  }
  if (!req.files || req.files.length === 0) {
    return res.status(400).json({ success: false, message: '请至少上传一张图片' });
  }

  let connection;
  try {
    connection = await getConn();
    const [logRows] = await connection.execute(
      'SELECT id, author_user_id FROM logs WHERE id = ? LIMIT 1',
      [logId]
    );
    if (logRows.length === 0) {
      return res.status(404).json({ success: false, message: '日志不存在' });
    }
    const logRow = logRows[0];
    if (logRow.author_user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: '只能上传自己日志的图片' });
    }

    const [countRows] = await connection.execute(
      'SELECT COUNT(*) AS cnt FROM log_images WHERE log_id = ?',
      [logId]
    );
    let displayOrder = countRows[0]?.cnt || 0;

    const insertedImages = [];
    for (const file of req.files) {
      const { dataUri, meta } = await convertFileToDataUri(file);
      const [result] = await connection.execute(
        'INSERT INTO log_images (log_id, image_data, file_name, file_size, mime_type, display_order) VALUES (?, ?, ?, ?, ?, ?)',
        [logId, dataUri, meta.fileName, meta.fileSize, meta.mimeType, displayOrder]
      );

      insertedImages.push({
        id: result.insertId,
        dataUri,
        fileName: meta.fileName,
        fileSize: meta.fileSize,
        mimeType: meta.mimeType,
        displayOrder,
      });
      displayOrder += 1;
    }

    return res.json({ success: true, images: insertedImages });
  } catch (e) {
    console.error('上传日志图片失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  } finally {
    cleanupUploadedFiles(req.files);
    if (connection) {
      await connection.end();
    }
  }
});

app.get('/api/logs/:id/images', auth, async (req, res) => {
  const logId = parseInt(req.params.id, 10);
  if (!Number.isFinite(logId)) {
    return res.status(400).json({ success: false, message: '日志ID无效' });
  }
  let connection;
  try {
    connection = await getConn();
    const [logRows] = await connection.execute(
      'SELECT id, author_user_id FROM logs WHERE id = ? LIMIT 1',
      [logId]
    );
    if (logRows.length === 0) {
      return res.status(404).json({ success: false, message: '日志不存在' });
    }
    const logRow = logRows[0];
    if (logRow.author_user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: '只能查看自己日志的图片' });
    }

    const images = await getImagesForSingle(connection, 'log_images', 'log_id', logId);
    return res.json({ success: true, images });
  } catch (e) {
    console.error('获取日志图片失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  } finally {
    if (connection) {
      await connection.end();
    }
  }
});

app.post('/api/tasks/:id/images', auth, upload.array('images', MAX_IMAGES_PER_REQUEST), async (req, res) => {
  const taskId = parseInt(req.params.id, 10);
  if (!Number.isFinite(taskId)) {
    return res.status(400).json({ success: false, message: '任务ID无效' });
  }
  if (!req.files || req.files.length === 0) {
    return res.status(400).json({ success: false, message: '请至少上传一张图片' });
  }

  let connection;
  try {
    connection = await getConn();
    const [taskRows] = await connection.execute(
      'SELECT id, creator_id, assignee_id FROM tasks WHERE id = ? LIMIT 1',
      [taskId]
    );
    if (taskRows.length === 0) {
      return res.status(404).json({ success: false, message: '任务不存在' });
    }
    const taskRow = taskRows[0];
    let canUpload = taskRow.creator_id === req.user.id || taskRow.assignee_id === req.user.id;
    if (!canUpload) {
      canUpload = await hasPermissionWithConnection(connection, req.user.id, 'task:edit_all');
    }
    if (!canUpload) {
      return res.status(403).json({ success: false, message: '没有权限上传该任务的图片' });
    }

    const [countRows] = await connection.execute(
      'SELECT COUNT(*) AS cnt FROM task_images WHERE task_id = ?',
      [taskId]
    );
    let displayOrder = countRows[0]?.cnt || 0;

    const insertedImages = [];
    for (const file of req.files) {
      const { dataUri, meta } = await convertFileToDataUri(file);
      const [result] = await connection.execute(
        'INSERT INTO task_images (task_id, image_data, file_name, file_size, mime_type, display_order) VALUES (?, ?, ?, ?, ?, ?)',
        [taskId, dataUri, meta.fileName, meta.fileSize, meta.mimeType, displayOrder]
      );

      insertedImages.push({
        id: result.insertId,
        dataUri,
        fileName: meta.fileName,
        fileSize: meta.fileSize,
        mimeType: meta.mimeType,
        displayOrder,
      });
      displayOrder += 1;
    }

    return res.json({ success: true, images: insertedImages });
  } catch (e) {
    console.error('上传任务图片失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  } finally {
    cleanupUploadedFiles(req.files);
    if (connection) {
      await connection.end();
    }
  }
});

app.get('/api/tasks/:id/images', auth, async (req, res) => {
  const taskId = parseInt(req.params.id, 10);
  if (!Number.isFinite(taskId)) {
    return res.status(400).json({ success: false, message: '任务ID无效' });
  }
  let connection;
  try {
    connection = await getConn();
    const [taskRows] = await connection.execute(
      'SELECT id, creator_id, assignee_id FROM tasks WHERE id = ? LIMIT 1',
      [taskId]
    );
    if (taskRows.length === 0) {
      return res.status(404).json({ success: false, message: '任务不存在' });
    }
    const taskRow = taskRows[0];
    let canView = taskRow.creator_id === req.user.id || taskRow.assignee_id === req.user.id;
    if (!canView) {
      canView = await hasPermissionWithConnection(connection, req.user.id, 'task:view_all');
    }
    if (!canView) {
      return res.status(403).json({ success: false, message: '没有权限查看该任务的图片' });
    }

    const images = await getImagesForSingle(connection, 'task_images', 'task_id', taskId);
    return res.json({ success: true, images });
  } catch (e) {
    console.error('获取任务图片失败:', e);
    return res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  } finally {
    if (connection) {
      await connection.end();
    }
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
  let connection;
  try {
    connection = await getConn();
    const roleNames = await getUserRoleNames(connection, req.user.id);
    const isGlobalManager = roleNames.includes('founder') || roleNames.includes('admin');
    const isDeptHead = roleNames.includes('dept_head');
    let departmentFilter = null;

    if (isDeptHead && !isGlobalManager) {
      departmentFilter = await getUserDepartmentId(connection, req.user.id);
      if (departmentFilter === null || departmentFilter === undefined) {
        await connection.end();
        return res.status(400).json({
          success: false,
          message: '请先在个人信息中设置所属部门后再分配任务'
        });
      }
    }

    let sql = 'SELECT id, username, avatar_url, department_id, created_at, updated_at FROM users WHERE status = 1';
    const params = [];

    if (departmentFilter !== null) {
      sql += ' AND department_id = ?';
      params.push(departmentFilter);
    }

    sql += ' ORDER BY created_at DESC';

    const [rows] = await connection.execute(sql, params);
    
    // 格式化用户数据以匹配前端期望
    const formattedUsers = rows.map(user => ({
      id: user.id.toString(),
      username: user.username,
      avatar_url: user.avatar_url,
      department_id: user.department_id != null ? user.department_id.toString() : null,
      created_at: user.created_at,
      updated_at: user.updated_at
    }));
    
    await connection.end();
    res.json({ success: true, users: formattedUsers });
  } catch (e) {
    if (connection) await connection.end();
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
    await enrichLogRows(connection, logRows);

    task.logs = logRows;
    task.images = await getImagesForSingle(connection, 'task_images', 'task_id', task.id);

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
  let connection;
  try {
    connection = await getConn();
    const keyword = (req.query.keyword || '').toString().trim();
    const roleNames = await getUserRoleNames(connection, req.user.id);
    const isGlobalManager = roleNames.includes('founder') || roleNames.includes('admin');
    const isDeptHead = roleNames.includes('dept_head');
    let departmentFilter = null;

    if (isDeptHead && !isGlobalManager) {
      departmentFilter = await getUserDepartmentId(connection, req.user.id);
      if (departmentFilter === null || departmentFilter === undefined) {
        await connection.end();
        return res.status(400).json({
          success: false,
          message: '请先在个人信息中设置所属部门后再分配任务'
        });
      }
    }

    const conditions = ['status = 1'];
    const params = [];

    if (departmentFilter !== null) {
      conditions.push('department_id = ?');
      params.push(departmentFilter);
    }

    if (keyword) {
      conditions.push('(username LIKE ? OR real_name LIKE ?)');
      params.push(`%${keyword}%`, `%${keyword}%`);
    }

    let sql = 'SELECT id, username, real_name, email, avatar_url, department_id FROM users';
    if (conditions.length) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }
    sql += ' ORDER BY id DESC ' + (keyword ? 'LIMIT 20' : 'LIMIT 50');

    const [userRows] = await connection.execute(sql, params);

    await connection.end();
    return res.json({ success: true, users: userRows });
  } catch (e) {
    if (connection) await connection.end();
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
 * /api/user/mbti-analysis:
 *   get:
 *     summary: 根据用户MBTI和关键词生成发展建议
 *     tags: [用户管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: startTime
 *         schema:
 *           type: string
 *           format: date-time
 *         description: 开始时间（可选，不传则分析所有日志）
 *       - in: query
 *         name: endTime
 *         schema:
 *           type: string
 *           format: date-time
 *         description: 结束时间（可选，不传则分析所有日志）
 *     responses:
 *       200:
 *         description: 生成成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     suggestions:
 *                       type: array
 *                       items:
 *                         type: string
 *                     summary:
 *                       type: string
 *                     whySuitable:
 *                       type: string
 *       400:
 *         description: 参数错误或关键词不足
 */
// 根据用户MBTI和关键词生成发展建议
app.get('/api/user/mbti-analysis', auth, async (req, res) => {
  try {
    const { startTime, endTime, force } = req.query;

    // 先读缓存（除非显式 force 刷新）
    if (!force) {
      const cached = await getMbtiCache(req.user.id, 'analysis');
      if (cached) {
        return res.json({ success: true, data: cached, message: '发展建议读取缓存' });
      }
    }
    const connection = await getConn();

    // 获取用户的MBTI，如果没有则返回错误
    const [userRows] = await connection.execute(
      'SELECT mbit FROM users WHERE id = ?',
      [req.user.id]
    );
    const userMbti = userRows[0]?.mbit;
    
    if (!userMbti || userMbti.trim() === '') {
      await connection.end();
      return res.status(400).json({
        success: false,
        message: '请先在个人信息中设置您的MBTI类型'
      });
    }
    
    const mbtiUpper = userMbti.trim().toUpperCase();

    // 获取用户的关键词
    let sql = `
      SELECT lk.keyword, lk.score
      FROM log_keywords lk
      INNER JOIN logs l ON lk.log_id = l.id
      WHERE l.author_user_id = ?
    `;
    const params = [req.user.id];

    if (startTime && endTime) {
      sql += ' AND l.time_from >= ? AND l.time_from <= ?';
      params.push(startTime, endTime);
    }

    sql += ' ORDER BY lk.score DESC';

    const [rows] = await connection.execute(sql, params);
    await connection.end();

    // 提取关键词
    const keywords = rows.length > 0 
      ? rows.map(row => row.keyword)
      : [];

    // 调用大模型生成发展建议
    const { generateDevelopmentSuggestions } = require('./llm_service');
    const suggestions = await generateDevelopmentSuggestions(mbtiUpper, keywords);

    res.json({
      success: true,
      data: suggestions,
      message: '发展建议生成成功'
    });

    // 写入缓存（异步，不阻塞响应）
    setMbtiCache(req.user.id, 'analysis', suggestions).catch(() => {});
  } catch (e) {
    console.error('生成发展建议失败:', e);
    res.status(500).json({
      success: false,
      message: '生成发展建议失败: ' + e.message
    });
  }
});

/**
 * @swagger
 * /api/user/development-suggestions:
 *   get:
 *     summary: 根据MBTI类型生成发展建议
 *     tags: [用户管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: mbti
 *         required: true
 *         schema:
 *           type: string
 *         description: MBTI类型（如：INTJ）
 *       - in: query
 *         name: startTime
 *         schema:
 *           type: string
 *           format: date-time
 *         description: 开始时间（可选）
 *       - in: query
 *         name: endTime
 *         schema:
 *           type: string
 *           format: date-time
 *         description: 结束时间（可选）
 *     responses:
 *       200:
 *         description: 生成成功
 *       400:
 *         description: 参数错误
 */
// 根据MBTI类型生成发展建议
app.get('/api/user/development-suggestions', auth, async (req, res) => {
  try {
    const { mbti, startTime, endTime, force } = req.query;

    if (!mbti) {
      return res.status(400).json({
        success: false,
        message: 'MBTI类型不能为空'
      });
    }

    // 缓存命中（除非 force）
    if (!force) {
      const cached = await getMbtiCache(req.user.id, 'suggestions');
      if (cached && (cached.mbti ? cached.mbti.toUpperCase() === mbti.toUpperCase() : true)) {
        return res.json({ success: true, data: cached, message: '发展建议读取缓存' });
      }
    }

    const connection = await getConn();

    // 获取用户的关键词（用于个性化建议）
    let sql = `
      SELECT lk.keyword, lk.score
      FROM log_keywords lk
      INNER JOIN logs l ON lk.log_id = l.id
      WHERE l.author_user_id = ?
    `;
    const params = [req.user.id];

    if (startTime && endTime) {
      sql += ' AND l.time_from >= ? AND l.time_from <= ?';
      params.push(startTime, endTime);
    }

    sql += ' ORDER BY lk.score DESC';

    const [rows] = await connection.execute(sql, params);
    await enrichLogRows(connection, rows);
    await connection.end();

    // 提取关键词
    const keywords = rows.map(row => row.keyword);

    // 调用大模型生成发展建议
    const suggestions = await generateDevelopmentSuggestions(mbti, keywords);

    res.json({
      success: true,
      data: suggestions,
      message: '发展建议生成成功'
    });

    // 写入缓存（异步）
    setMbtiCache(req.user.id, 'suggestions', { ...suggestions, mbti }).catch(() => {});
  } catch (e) {
    console.error('生成发展建议失败:', e);
    res.status(500).json({
      success: false,
      message: '生成发展建议失败: ' + e.message
    });
  }
});

/**
 * @swagger
 * /api/top-items:
 *   get:
 *     summary: 获取公司十大重要展示项
 *     tags: [系统]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: 返回的展示项数量，最大 10 条
 *     responses:
 *       200:
 *         description: 获取成功
 */
app.get('/api/top-items', auth, async (req, res) => {
  try {
    const limitRaw = parseInt(req.query.limit, 10);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, TOP_ITEMS_LIMIT) : TOP_ITEMS_LIMIT;

    const connection = await getConn();
    await ensureTopItemsTable(connection);

    const [rows] = await connection.execute(`
        SELECT id, title, content, created_by, order_index, status, created_at, updated_at
        FROM top_items
        WHERE status = 1
        ORDER BY order_index ASC, updated_at DESC
        LIMIT ${limit}
      `);

    await connection.end();

    const data = rows.map(row => ({
      id: row.id,
      title: row.title || '',
      content: row.content || '',
      createdBy: row.created_by,
      orderIndex: row.order_index ?? 0,
      status: row.status ?? 0,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));

    res.json({
      success: true,
      message: '获取展示项成功',
      data,
    });
  } catch (e) {
    console.error('获取展示项失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/personal/top-items:
 *   get:
 *     summary: 获取个人十大展示项
 *     tags: [系统]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: 返回的展示项数量，最大 10 条
 *     responses:
 *       200:
 *         description: 获取成功
 */
app.get('/api/personal/top-items', auth, async (req, res) => {
  try {
    const limitRaw = parseInt(req.query.limit, 10);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, PERSONAL_TOP_ITEMS_LIMIT) : PERSONAL_TOP_ITEMS_LIMIT;

    const connection = await getConn();
    await ensureUserTopItemsTable(connection);

    const [rows] = await connection.execute(
      `
        SELECT id, title, content, order_index, status, created_at, updated_at
        FROM user_top_items
        WHERE user_id = ? AND status = 1
        ORDER BY order_index ASC, updated_at DESC
        LIMIT ${limit}
      `,
      [req.user.id]
    );

    await connection.end();

    const data = rows.map(row => ({
      id: row.id,
      title: row.title || '',
      content: row.content || '',
      orderIndex: row.order_index ?? 0,
      status: row.status ?? 1,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      isPersonal: true,
    }));

    res.json({
      success: true,
      message: '获取个人展示项成功',
      data,
    });
  } catch (e) {
    console.error('获取个人展示项失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/personal/top-items:
 *   post:
 *     summary: 新增个人展示项
 *     tags: [系统]
 *     security:
 *       - bearerAuth: []
 */
app.post('/api/personal/top-items', auth, async (req, res) => {
  try {
    const { title, content = null } = req.body;
    if (!title || typeof title !== 'string') {
      return res.status(400).json({ success: false, message: '标题不能为空' });
    }

    const connection = await getConn();
    await ensureUserTopItemsTable(connection);

    const [[countRow]] = await connection.execute(
      'SELECT COUNT(*) AS cnt FROM user_top_items WHERE user_id = ? AND status = 1',
      [req.user.id]
    );
    if ((countRow?.cnt || 0) >= PERSONAL_TOP_ITEMS_LIMIT) {
      await connection.end();
      return res.status(400).json({ success: false, message: `最多只能添加 ${PERSONAL_TOP_ITEMS_LIMIT} 条展示项` });
    }

    const [[orderRow]] = await connection.execute(
      'SELECT COALESCE(MAX(order_index), 0) + 1 AS nextOrder FROM user_top_items WHERE user_id = ?',
      [req.user.id]
    );

    const [result] = await connection.execute(
      'INSERT INTO user_top_items (user_id, title, content, order_index, status) VALUES (?, ?, ?, ?, 1)',
      [req.user.id, title.trim(), content, orderRow?.nextOrder ?? 1]
    );

    const insertedId = result.insertId;
    const [[row]] = await connection.execute(
      'SELECT id, title, content, order_index, status, created_at, updated_at FROM user_top_items WHERE id = ? AND user_id = ?',
      [insertedId, req.user.id]
    );
    await connection.end();

    res.json({
      success: true,
      message: '创建成功',
      data: {
        id: row.id,
        title: row.title || '',
        content: row.content || '',
        orderIndex: row.order_index ?? 0,
        status: row.status ?? 1,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        isPersonal: true,
      },
    });
  } catch (e) {
    console.error('创建个人展示项失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/personal/top-items/{id}:
 *   patch:
 *     summary: 更新个人展示项
 *     tags: [系统]
 *     security:
 *       - bearerAuth: []
 */
app.patch('/api/personal/top-items/:id', auth, async (req, res) => {
  try {
    const itemId = parseInt(req.params.id, 10);
    if (!Number.isFinite(itemId)) {
      return res.status(400).json({ success: false, message: '参数无效' });
    }
    const { title, content, status, orderIndex } = req.body;
    const fields = [];
    const params = [];

    if (title !== undefined) {
      if (!title || typeof title !== 'string') {
        return res.status(400).json({ success: false, message: '标题不能为空' });
      }
      fields.push('title = ?');
      params.push(title.trim());
    }
    if (content !== undefined) {
      fields.push('content = ?');
      params.push(content);
    }
    if (orderIndex !== undefined) {
      const orderValue = parseInt(orderIndex, 10);
      if (!Number.isFinite(orderValue) || orderValue < 0) {
        return res.status(400).json({ success: false, message: '排序值无效' });
      }
      fields.push('order_index = ?');
      params.push(orderValue);
    }
    if (status !== undefined) {
      const statusValue = parseInt(status, 10);
      if (!(statusValue === 0 || statusValue === 1)) {
        return res.status(400).json({ success: false, message: '状态无效' });
      }
      if (statusValue === 1) {
        const connection = await getConn();
        const [[countRow]] = await connection.execute(
          'SELECT COUNT(*) AS cnt FROM user_top_items WHERE user_id = ? AND status = 1 AND id != ?',
          [req.user.id, itemId]
        );
        if ((countRow?.cnt || 0) >= PERSONAL_TOP_ITEMS_LIMIT) {
          await connection.end();
          return res.status(400).json({ success: false, message: `最多只能展示 ${PERSONAL_TOP_ITEMS_LIMIT} 条` });
        }
        await connection.end();
      }
      fields.push('status = ?');
      params.push(statusValue);
    }

    if (fields.length === 0) {
      return res.status(400).json({ success: false, message: '没有需要更新的字段' });
    }

    const connection = await getConn();
    await ensureUserTopItemsTable(connection);

    params.push(itemId, req.user.id);
    const [result] = await connection.execute(
      `UPDATE user_top_items SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ?`,
      params
    );

    if (result.affectedRows === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '记录不存在' });
    }

    const [[row]] = await connection.execute(
      'SELECT id, title, content, order_index, status, created_at, updated_at FROM user_top_items WHERE id = ? AND user_id = ?',
      [itemId, req.user.id]
    );
    await connection.end();

    res.json({
      success: true,
      message: '更新成功',
      data: {
        id: row.id,
        title: row.title || '',
        content: row.content || '',
        orderIndex: row.order_index ?? 0,
        status: row.status ?? 1,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        isPersonal: true,
      },
    });
  } catch (e) {
    console.error('更新个人展示项失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/personal/top-items/{id}:
 *   delete:
 *     summary: 删除个人展示项
 *     tags: [系统]
 *     security:
 *       - bearerAuth: []
 */
app.delete('/api/personal/top-items/:id', auth, async (req, res) => {
  try {
    const itemId = parseInt(req.params.id, 10);
    if (!Number.isFinite(itemId)) {
      return res.status(400).json({ success: false, message: '参数无效' });
    }

    const connection = await getConn();
    await ensureUserTopItemsTable(connection);

    const [result] = await connection.execute(
      'DELETE FROM user_top_items WHERE id = ? AND user_id = ?',
      [itemId, req.user.id]
    );
    await connection.end();

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '记录不存在' });
    }

    res.json({ success: true, message: '删除成功' });
  } catch (e) {
    console.error('删除个人展示项失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/dashboard/logs:
 *   get:
 *     summary: 获取仪表盘日志列表
 *     tags: [日志管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 8
 *         description: 返回的最大日志条数
 *     responses:
 *       200:
 *         description: 获取成功
 */
app.get('/api/dashboard/logs', auth, async (req, res) => {
  try {
    const limitRaw = parseInt(req.query.limit, 10);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, DASHBOARD_LOG_LIMIT) : DASHBOARD_LOG_LIMIT;

    const connection = await getConn();
    await ensureDashboardLogsTable(connection);
    await seedDashboardLogs(connection, req.user.id);

    const [rows] = await connection.execute(
      `
        SELECT l.id, l.title, l.content, l.log_status, l.time_from, l.time_to, l.priority,
               l.created_at, l.updated_at, udl.created_at AS pinned_at
        FROM user_dashboard_logs udl
        JOIN logs l ON udl.log_id = l.id
        WHERE udl.user_id = ?
          AND l.author_user_id = ?
          AND (l.log_status IS NULL OR l.log_status != 'completed')
        ORDER BY
          CASE WHEN l.time_to IS NULL THEN 1 ELSE 0 END,
          l.time_to ASC,
          l.created_at DESC
        LIMIT ${limit}
      `,
      [req.user.id, req.user.id]
    );

    await connection.end();

    const data = rows.map(row => ({
      id: row.id,
      title: row.title || '',
      content: row.content || '',
      logStatus: row.log_status || 'pending',
      startTime: row.time_from,
      endTime: row.time_to,
      priority: row.priority,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      isPinned: true,
      pinnedAt: row.pinned_at
    }));

    res.json({
      success: true,
      message: '获取仪表盘日志成功',
      data
    });
  } catch (e) {
    console.error('获取仪表盘日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/dashboard/logs:
 *   post:
 *     summary: 固定仪表盘日志
 *     tags: [日志管理]
 *     security:
 *       - bearerAuth: []
 */
app.post('/api/dashboard/logs', auth, async (req, res) => {
  try {
    const { logId } = req.body;
    const logIdNum = parseInt(logId, 10);
    if (!Number.isFinite(logIdNum)) {
      return res.status(400).json({ success: false, message: 'logId 参数无效' });
    }

    const connection = await getConn();
    await ensureDashboardLogsTable(connection);

    const [[logRow]] = await connection.execute(
      'SELECT id FROM logs WHERE id = ? AND author_user_id = ? LIMIT 1',
      [logIdNum, req.user.id]
    );
    if (!logRow) {
      await connection.end();
      return res.status(404).json({ success: false, message: '日志不存在或不属于当前用户' });
    }

    const [[countRow]] = await connection.execute(
      'SELECT COUNT(*) AS cnt FROM user_dashboard_logs WHERE user_id = ?',
      [req.user.id]
    );
    if (countRow.cnt >= DASHBOARD_LOG_LIMIT) {
      await connection.end();
      return res.status(400).json({ success: false, message: `最多只能固定 ${DASHBOARD_LOG_LIMIT} 条日志` });
    }

    const [[existsRow]] = await connection.execute(
      'SELECT 1 FROM user_dashboard_logs WHERE user_id = ? AND log_id = ? LIMIT 1',
      [req.user.id, logIdNum]
    );
    if (existsRow) {
      await connection.end();
      return res.status(409).json({ success: false, message: '该日志已在展示列表中' });
    }

    await connection.execute(
      'INSERT INTO user_dashboard_logs (user_id, log_id) VALUES (?, ?)',
      [req.user.id, logIdNum]
    );
    await connection.end();

    res.json({ success: true, message: '添加成功' });
  } catch (e) {
    console.error('固定仪表盘日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/dashboard/tasks:
 *   get:
 *     summary: 获取仪表盘任务列表
 *     tags: [任务管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: 返回的任务数量
 *     responses:
 *       200:
 *         description: 获取成功
 */
app.get('/api/dashboard/tasks', auth, async (req, res) => {
  try {
    const limitRaw = parseInt(req.query.limit, 10);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, DASHBOARD_TASK_LIMIT) : DASHBOARD_TASK_LIMIT;

    const connection = await getConn();
    await ensureDashboardTasksTable(connection);
    await seedDashboardTasks(connection, req.user.id);

    const [rows] = await connection.execute(
      `
        SELECT t.id, t.task_name AS name, t.description, t.priority, t.status, t.progress,
               t.plan_start_time, t.plan_end_time AS due_time, t.created_at, t.updated_at,
               t.assignee_id AS owner_user_id, t.creator_id AS creator_user_id,
               udt.created_at AS pinned_at
        FROM user_dashboard_tasks udt
        JOIN tasks t ON udt.task_id = t.id
        WHERE udt.user_id = ?
          AND (t.assignee_id = ? OR t.creator_id = ?)
          AND (t.status IS NULL OR t.status NOT IN ('completed', 'closed'))
        ORDER BY
          CASE WHEN t.plan_end_time IS NULL THEN 1 ELSE 0 END,
          t.plan_end_time ASC,
          t.created_at DESC
        LIMIT ${limit}
      `,
      [req.user.id, req.user.id, req.user.id]
    );

    await connection.end();

    const data = rows.map(row => ({
      id: row.id,
      name: row.name || '',
      description: row.description || '',
      status: row.status || 'pending_assignment',
      priority: row.priority || 'low',
      progress: row.progress ?? 0,
      planStartTime: row.plan_start_time,
      dueTime: row.due_time,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      ownerUserId: row.owner_user_id,
      creatorUserId: row.creator_user_id,
      isPinned: true,
      pinnedAt: row.pinned_at,
    }));

    res.json({
      success: true,
      message: '获取仪表盘任务成功',
      data,
    });
  } catch (e) {
    console.error('获取仪表盘任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/dashboard/tasks:
 *   post:
 *     summary: 添加仪表盘任务
 *     tags: [任务管理]
 *     security:
 *       - bearerAuth: []
 */
app.post('/api/dashboard/tasks', auth, async (req, res) => {
  try {
    const { taskId } = req.body;
    const taskIdNum = parseInt(taskId, 10);
    if (!Number.isFinite(taskIdNum)) {
      return res.status(400).json({ success: false, message: 'taskId 参数无效' });
    }

    const connection = await getConn();
    await ensureDashboardTasksTable(connection);

    const [[taskRow]] = await connection.execute(
      `
        SELECT id, assignee_id, creator_id, status
        FROM tasks
        WHERE id = ? AND (assignee_id = ? OR creator_id = ?)
        LIMIT 1
      `,
      [taskIdNum, req.user.id, req.user.id]
    );

    if (!taskRow) {
      await connection.end();
      return res.status(404).json({ success: false, message: '任务不存在或不属于当前用户' });
    }

    if (taskRow.status === 'completed') {
      await connection.end();
      return res.status(400).json({ success: false, message: '已完成的任务无需展示' });
    }

    const [[countRow]] = await connection.execute(
      'SELECT COUNT(*) AS cnt FROM user_dashboard_tasks WHERE user_id = ?',
      [req.user.id]
    );
    if (countRow.cnt >= DASHBOARD_TASK_LIMIT) {
      await connection.end();
      return res.status(400).json({ success: false, message: `最多只能添加 ${DASHBOARD_TASK_LIMIT} 条任务` });
    }

    const [[existsRow]] = await connection.execute(
      'SELECT 1 FROM user_dashboard_tasks WHERE user_id = ? AND task_id = ? LIMIT 1',
      [req.user.id, taskIdNum]
    );
    if (existsRow) {
      await connection.end();
      return res.status(409).json({ success: false, message: '该任务已在展示列表中' });
    }

    await connection.execute(
      'INSERT INTO user_dashboard_tasks (user_id, task_id) VALUES (?, ?)',
      [req.user.id, taskIdNum]
    );
    await connection.end();

    res.json({ success: true, message: '任务添加成功' });
  } catch (e) {
    console.error('添加仪表盘任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/dashboard/tasks/{taskId}:
 *   delete:
 *     summary: 移除仪表盘任务
 *     tags: [任务管理]
 *     security:
 *       - bearerAuth: []
 */
app.delete('/api/dashboard/tasks/:taskId', auth, async (req, res) => {
  try {
    const taskIdNum = parseInt(req.params.taskId, 10);
    if (!Number.isFinite(taskIdNum)) {
      return res.status(400).json({ success: false, message: 'taskId 参数无效' });
    }

    const connection = await getConn();
    await ensureDashboardTasksTable(connection);

    const [result] = await connection.execute(
      'DELETE FROM user_dashboard_tasks WHERE user_id = ? AND task_id = ?',
      [req.user.id, taskIdNum]
    );
    await connection.end();

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '未找到对应的任务' });
    }

    res.json({ success: true, message: '移除成功' });
  } catch (e) {
    console.error('移除仪表盘任务失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
  }
});

/**
 * @swagger
 * /api/dashboard/logs/{logId}:
 *   delete:
 *     summary: 移除固定的仪表盘日志
 *     tags: [日志管理]
 *     security:
 *       - bearerAuth: []
 */
app.delete('/api/dashboard/logs/:logId', auth, async (req, res) => {
  try {
    const logIdNum = parseInt(req.params.logId, 10);
    if (!Number.isFinite(logIdNum)) {
      return res.status(400).json({ success: false, message: 'logId 参数无效' });
    }

    const connection = await getConn();
    await ensureDashboardLogsTable(connection);

    const [result] = await connection.execute(
      'DELETE FROM user_dashboard_logs WHERE user_id = ? AND log_id = ?',
      [req.user.id, logIdNum]
    );
    await connection.end();

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '未找到对应的固定日志' });
    }

    res.json({ success: true, message: '移除成功' });
  } catch (e) {
    console.error('移除仪表盘日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误: ' + e.message });
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
    await enrichTaskRows(connection, rows);
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
      updated_at: task.updated_at,
      images: task.images || [],
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
 *                 default: in_progress
 *                 description: 任务状态（由系统根据负责人自动设置）
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
    const { name, description = null, priority = 'low', progress = 0, dueTime = null, planStartTime = null, ownerUserId, images: imageDataUris = [] } = req.body;
    if (!name) {
      return res.status(400).json({ success: false, message: '任务名称必填' });
    }
    if (typeof name !== 'string' || name.length > 64) {
      return res.status(400).json({ success: false, message: '任务名称长度超限' });
    }

    const ownerUserIdInfo = normalizeOptionalOwnerUserId(ownerUserId);
    if (ownerUserIdInfo.error) {
      return res.status(400).json({ success: false, message: ownerUserIdInfo.error });
    }
    const ownerUserIdValue = ownerUserIdInfo.value;
    const hasExplicitOwner = ownerUserIdInfo.provided && ownerUserIdValue !== null && ownerUserIdValue !== undefined;

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
    let finalAssigneeId;
    let taskStatus;
    
    if (isDeptHead && !isFounderOrAdmin && hasExplicitOwner && ownerUserIdValue !== req.user.id) {
      const deptCheck = await validateDeptHeadAssignment(connection, req.user.id, ownerUserIdValue);
      if (!deptCheck.ok) {
        await connection.end();
        return res.status(deptCheck.status).json({ success: false, message: deptCheck.message });
      }
    }

    if (hasExplicitOwner) {
      if (ownerUserIdValue === null || ownerUserIdValue === undefined) {
        // 主动清空负责人 → 保持待分配状态
        taskStatus = 'pending_assignment';
        finalAssigneeId = req.user.id; // 数据库限制不允许 NULL，使用创建者占位
      } else {
        finalAssigneeId = ownerUserIdValue;
        taskStatus = 'in_progress';
      }
    } else {
      // 未显式指定负责人 → 默认创建者自己负责，立即视为已接收
      finalAssigneeId = req.user.id;
      taskStatus = 'in_progress';
    }
    
    const [result] = await connection.execute(
      'INSERT INTO tasks (task_name, description, priority, status, progress, plan_start_time, plan_end_time, assignee_id, creator_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [name, description, priority, taskStatus, Math.min(Math.max(progress, 0), 100), planStartDt, dueDt, finalAssigneeId, req.user.id]
    );

    // 如果任务被分配，则创建通知
        if (finalAssigneeId && taskStatus === 'in_progress') {
          const notificationTitle = `您有一个新任务: ${name}`;
          const notificationContent = `创建者: ${req.user.username}`;
          await connection.execute(
            "INSERT INTO notifications (user_id, type, title, content, related_id, entity_type) VALUES (?, ?, ?, ?, ?, 'task')",
            [finalAssigneeId, 'assignment', notificationTitle, notificationContent, result.insertId]
          );
        }

    await saveDataUriImages(connection, 'task_images', 'task_id', result.insertId, Array.isArray(imageDataUris) ? imageDataUris : []);
    const [rows] = await connection.execute(
      'SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?',
      [result.insertId]
    );
    rows[0].images = await getImagesForSingle(connection, 'task_images', 'task_id', result.insertId);
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
    const { name, description, priority, status, progress, dueTime, planStartTime, ownerUserId, images: imageDataUris } = req.body;
    
    if (isNaN(id)) {
        return res.status(400).json({ success: false, message: '无效的任务ID' });
    }

    const ownerUserIdInfo = normalizeOptionalOwnerUserId(ownerUserId);
    if (ownerUserIdInfo.error) {
        return res.status(400).json({ success: false, message: ownerUserIdInfo.error });
    }
    const ownerUserIdValue = ownerUserIdInfo.value;
    const ownerUserProvided = ownerUserIdInfo.provided;
    const hasExplicitOwnerValue = ownerUserProvided && ownerUserIdValue !== null && ownerUserIdValue !== undefined;

    const connection = await getConn();
    await connection.beginTransaction(); // 使用事务保证数据一致性

    try {
        // 1. 获取任务更新前的数据，用于后续比较
        const [[taskBeforeUpdate]] = await connection.execute(
            'SELECT id, task_name, creator_id, assignee_id, status, progress FROM tasks WHERE id = ? FOR UPDATE',
            [id]
        );

        if (!taskBeforeUpdate) {
            await connection.rollback();
            await connection.end();
            return res.status(404).json({ success: false, message: '任务不存在' });
        }

        const [roleRows] = await connection.execute(`
          SELECT r.role_name 
          FROM roles r
          JOIN user_roles ur ON r.id = ur.role_id
          WHERE ur.user_id = ?
        `, [req.user.id]);
        const roleNames = roleRows.map(r => r.role_name);
        const isFounderOrAdmin = roleNames.includes('admin') || roleNames.includes('founder');
        const isDeptHead = roleNames.includes('dept_head');

        // 2. 权限检查
        const isCreator = taskBeforeUpdate.creator_id === req.user.id;
        const isAssignee = taskBeforeUpdate.assignee_id === req.user.id;

        // 如果不是创建者，也不是负责人，则无权修改
        if (!isCreator && !isAssignee) {
            await connection.rollback();
            await connection.end();
            return res.status(403).json({ success: false, message: '权限不足，只有创建者或负责人可以修改任务' });
        }
        
        if (!isCreator && ownerUserProvided && ownerUserIdValue !== taskBeforeUpdate.assignee_id) {
            await connection.rollback();
            await connection.end();
            return res.status(403).json({ success: false, message: '只有任务创建者可以重新分配负责人' });
        }

        if (isDeptHead && !isFounderOrAdmin && hasExplicitOwnerValue && ownerUserIdValue !== req.user.id) {
            const deptCheck = await validateDeptHeadAssignment(connection, req.user.id, ownerUserIdValue);
            if (!deptCheck.ok) {
                await connection.rollback();
                await connection.end();
                return res.status(deptCheck.status).json({ success: false, message: deptCheck.message });
            }
        }

        // 3. 执行更新
        const newStatus = normalizeTaskStatus(status);
        let derivedStatus = null;
        if (ownerUserProvided) {
            if (ownerUserIdValue === null || ownerUserIdValue === undefined) {
                derivedStatus = 'pending_assignment';
            } else {
                derivedStatus = 'in_progress';
            }
        }
        const statusToApply = status !== undefined ? newStatus : derivedStatus;
        const planStartDt = toMySQLDateTime(planStartTime);
        const dueDt = toMySQLDateTime(dueTime);

        const assigneeParam = ownerUserProvided ? ownerUserIdValue : null;

        await connection.execute(
            'UPDATE tasks SET task_name = COALESCE(?, task_name), description = COALESCE(?, description), priority = COALESCE(?, priority), status = COALESCE(?, status), progress = COALESCE(?, progress), plan_start_time = COALESCE(?, plan_start_time), plan_end_time = COALESCE(?, plan_end_time), assignee_id = COALESCE(?, assignee_id) WHERE id = ?',
            [name, description, priority, statusToApply, progress, planStartDt, dueDt, assigneeParam, id]
        );

        // 4. --- 通知逻辑 ---
        const updatedTaskName = name || taskBeforeUpdate.task_name;
        const newAssigneeId = ownerUserProvided ? ownerUserIdValue : taskBeforeUpdate.assignee_id;

        // a. 任务分配通知
        if (ownerUserProvided && ownerUserIdValue !== null && ownerUserIdValue !== undefined && ownerUserIdValue !== taskBeforeUpdate.assignee_id) {
            const notificationTitle = `新任务分配: ${updatedTaskName}`;
            const notificationContent = `您被指派了一个新任务: "${updatedTaskName}"`;
            await connection.execute(
                "INSERT INTO notifications (user_id, type, title, content, related_id, entity_type) VALUES (?, ?, ?, ?, ?, 'task')",
                [ownerUserIdValue, 'assignment', notificationTitle, notificationContent, id]
            );
        }

        // b. 任务状态变更通知 (通知负责人)
        if (status !== undefined && newStatus !== taskBeforeUpdate.status && newAssigneeId && req.user.id !== newAssigneeId) {
            const notificationTitle = `任务状态更新: ${updatedTaskName}`;
            const notificationContent = `任务 "${updatedTaskName}" 的状态已从 "${taskBeforeUpdate.status}" 更新为 "${newStatus}"`;
            await connection.execute(
                "INSERT INTO notifications (user_id, type, title, content, related_id, entity_type) VALUES (?, ?, ?, ?, ?, 'task')",
                [newAssigneeId, 'status_change', notificationTitle, notificationContent, id]
            );
        }

        // c. 任务进度更新通知 (通知创建者)
        if (progress !== undefined && progress !== null && progress !== taskBeforeUpdate.progress && taskBeforeUpdate.creator_id && req.user.id !== taskBeforeUpdate.creator_id) {
            const notificationTitle = `任务进度更新: ${updatedTaskName}`;
            const notificationContent = `您创建的任务 "${updatedTaskName}" 进度已从 ${taskBeforeUpdate.progress || 0}% 更新为 ${progress}%`;
            await connection.execute(
                "INSERT INTO notifications (user_id, type, title, content, related_id, entity_type) VALUES (?, ?, ?, ?, ?, 'task')",
                [taskBeforeUpdate.creator_id, 'progress_update', notificationTitle, notificationContent, id]
            );
        }

        // 5. 更新图片
        if (Array.isArray(imageDataUris)) {
            await connection.execute('DELETE FROM task_images WHERE task_id = ?', [id]);
            await saveDataUriImages(connection, 'task_images', 'task_id', id, imageDataUris);
        }

        // 6. 提交事务并返回结果
        await connection.commit();

        const [rows] = await connection.execute('SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?', [id]);
        rows[0].images = await getImagesForSingle(connection, 'task_images', 'task_id', id);
        
        await connection.end();
        res.json({ success: true, task: rows[0] });

    } catch (e) {
        await connection.rollback(); // 发生错误时回滚事务
        console.error('更新任务事务失败:', e);
        res.status(500).json({ success: false, message: '服务器内部错误' });
    }

  } catch (e) {
    console.error('更新任务失败 (连接错误):', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

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
  rows[0].images = await getImagesForSingle(connection, 'task_images', 'task_id', id);
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
// 任务发布（指定负责人并置为进行中）
app.post('/api/tasks/:id/publish', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { ownerUserId } = req.body;
    const ownerUserIdInfo = normalizeOptionalOwnerUserId(ownerUserId);
    if (ownerUserIdInfo.error) {
      return res.status(400).json({ success: false, message: ownerUserIdInfo.error });
    }
    const ownerUserIdValue = ownerUserIdInfo.value;
    const hasExplicitOwner = ownerUserIdInfo.provided && ownerUserIdValue !== null && ownerUserIdValue !== undefined;
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

    if (isDeptHead && !isFounderOrAdmin && hasExplicitOwner && ownerUserIdValue !== req.user.id) {
      const deptCheck = await validateDeptHeadAssignment(connection, req.user.id, ownerUserIdValue);
      if (!deptCheck.ok) {
        await connection.end();
        return res.status(deptCheck.status).json({ success: false, message: deptCheck.message });
      }
    }
    
    const isAssigned = task.status !== null && task.status !== undefined && task.status !== 'pending_assignment';
    
    if (isAssigned) {
      // 撤回分配：将status改回pending_assignment，assignee_id设置为创建者占位
      await connection.execute('UPDATE tasks SET assignee_id = ?, status = ? WHERE id = ?', [task.creator_id, 'pending_assignment', id]);
    } else {
      // 分配任务：设置assignee_id并直接置为进行中
      const finalAssigneeId = hasExplicitOwner ? ownerUserIdValue : req.user.id;
      if (finalAssigneeId === null || finalAssigneeId === undefined) {
        await connection.end();
        return res.status(400).json({ success: false, message: '请指定负责人后再分配任务' });
      }
      await connection.execute('UPDATE tasks SET assignee_id = ?, status = ? WHERE id = ?', [finalAssigneeId, 'in_progress', id]);
    }
    const [rows] = await connection.execute('SELECT id, task_name AS name, description, priority, status, progress, plan_start_time, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?', [id]);
    rows[0].images = await getImagesForSingle(connection, 'task_images', 'task_id', id);
    await connection.end();
    res.json({ success: true, task: rows[0] });
  } catch (e) {
    console.error('发布/撤回任务失败:', e);
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
 *               location:
 *                 type: object
 *                 description: 地理位置信息（可选）
 *                 properties:
 *                   latitude:
 *                     type: number
 *                     description: 纬度
 *                     example: 39.9042
 *                   longitude:
 *                     type: number
 *                     description: 经度
 *                     example: 116.4074
 *                   address:
 *                     type: string
 *                     description: 地址描述
 *                     example: 北京市东城区
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
      images: imageDataUris = [],
      location = null,
    } = req.body;

    if (!content || typeof content !== 'string') {
      return res.status(400).json({ success: false, message: '日志内容不能为空' });
    }

    const connection = await getConn();
    await connection.beginTransaction(); // 开始事务

    try {
        let finalTaskId = taskId;

        // 如果需要，先创建新任务
        if (!finalTaskId && createNewTask && createNewTask.name) {
            const { name, priority: tPriority = 'low', progress: tProgress = 0, dueTime = null, ownerUserId: rawOwnerUserId } = createNewTask;
            const ownerUserIdInfo = normalizeOptionalOwnerUserId(rawOwnerUserId);
            if (ownerUserIdInfo.error) {
                await connection.rollback();
                await connection.end();
                return res.status(400).json({ success: false, message: ownerUserIdInfo.error });
            }
            const ownerUserIdValue = ownerUserIdInfo.value;
            const hasExplicitOwner = ownerUserIdInfo.provided && ownerUserIdValue !== null && ownerUserIdValue !== undefined;
            let finalOwnerUserId;
            let taskStatusForLogCreation;
            if (ownerUserIdInfo.provided) {
                if (ownerUserIdValue === null || ownerUserIdValue === undefined) {
                    taskStatusForLogCreation = 'pending_assignment';
                    finalOwnerUserId = req.user.id;
                } else {
                    finalOwnerUserId = ownerUserIdValue;
                    taskStatusForLogCreation = 'in_progress';
                }
            } else {
                finalOwnerUserId = req.user.id;
                taskStatusForLogCreation = 'in_progress';
            }

            const [roles] = await connection.execute(`
              SELECT r.role_name 
              FROM roles r
              JOIN user_roles ur ON r.id = ur.role_id
              WHERE ur.user_id = ?
            `, [req.user.id]);
            const roleNames = roles.map(r => r.role_name);
            const isFounderOrAdmin = roleNames.includes('admin') || roleNames.includes('founder');
            const isDeptHead = roleNames.includes('dept_head');
            const isStaff = roleNames.includes('staff');

            if (isStaff) {
                await connection.rollback();
                await connection.end();
                return res.status(403).json({ success: false, message: '普通员工不能创建任务' });
            }

            if (isDeptHead && !isFounderOrAdmin && hasExplicitOwner && finalOwnerUserId !== req.user.id) {
                const deptCheck = await validateDeptHeadAssignment(connection, req.user.id, finalOwnerUserId);
                if (!deptCheck.ok) {
                    await connection.rollback();
                    await connection.end();
                    return res.status(deptCheck.status).json({ success: false, message: deptCheck.message });
                }
            }

            const [dup] = await connection.execute('SELECT id FROM tasks WHERE task_name = ? AND creator_id = ? LIMIT 1', [name, req.user.id]);
            if (dup.length > 0) {
                await connection.rollback();
                await connection.end();
                return res.status(409).json({ success: false, message: '任务名称不能重复' });
            }
            const dueDt = toMySQLDateTime(dueTime);
            const [tRes] = await connection.execute(
                'INSERT INTO tasks (task_name, priority, progress, status, plan_end_time, assignee_id, creator_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
                [name, tPriority, Math.min(Math.max(tProgress, 0), 100), taskStatusForLogCreation, dueDt, finalOwnerUserId, req.user.id]
            );
            finalTaskId = tRes.insertId;
        }

        // 插入日志主数据
        const startDt = toMySQLDateTime(timeFrom);
        const endDt = toMySQLDateTime(timeTo);
        const logType = type || 'work';
        const latitude = location?.latitude || null;
        const longitude = location?.longitude || null;
        const address = location?.address || null;

        const [lRes] = await connection.execute(
            'INSERT INTO logs (author_user_id, title, content, log_type, priority, progress, time_from, time_to, task_id, log_status, latitude, longitude, address) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [req.user.id, title, content, logType, priority, Math.min(Math.max(progress, 0), 100), startDt, endDt, finalTaskId, logStatus || 'pending', latitude, longitude, address]
        );
        const logId = lRes.insertId;

        // --- 通知逻辑 ---
        const displayTitle = title || '无标题日志';

        // 1. 给自己发通知，确认日志已创建
        const selfNotificationTitle = `新日志已创建: ${displayTitle}`;
        const selfNotificationContent = `您已成功创建日志，请记得及时更新进度。`;
        await connection.execute(
            "INSERT INTO notifications (user_id, type, title, content, related_id, entity_type) VALUES (?, ?, ?, ?, ?, 'log')",
            [req.user.id, 'log_created', selfNotificationTitle, selfNotificationContent, logId]
        );

        // 2. 如果关联了任务，给任务创建者发通知
        if (finalTaskId) {
            const [[task]] = await connection.execute('SELECT creator_id, task_name FROM tasks WHERE id = ?', [finalTaskId]);
            // 只有当任务存在，且写日志的人不是任务创建者自己时，才发送通知
            if (task && task.creator_id && task.creator_id !== req.user.id) {
                const taskNotificationTitle = `任务有新日志: ${task.task_name}`;
                const taskNotificationContent = `您创建的任务 "${task.task_name}" 有一条新日志: "${displayTitle}"`;
                await connection.execute(
                    "INSERT INTO notifications (user_id, type, title, content, related_id, entity_type) VALUES (?, ?, ?, ?, ?, 'log')",
                    [task.creator_id, 'log_created', taskNotificationTitle, taskNotificationContent, logId]
                );
            }
        }
        
        // 异步提取关键词 (逻辑不变)
        (async () => {
            // ...
        })();

        // 同步任务进度 (逻辑不变)
        if (syncTaskProgress && finalTaskId) {
            await connection.execute('UPDATE tasks SET progress = ?, priority = ? WHERE id = ?', [Math.min(Math.max(progress, 0), 100), priority, finalTaskId]);
        }

        // 保存图片 (逻辑不变)
        await saveDataUriImages(connection, 'log_images', 'log_id', logId, Array.isArray(imageDataUris) ? imageDataUris : []);

        // 提交事务
        await connection.commit();

        // 返回响应 (逻辑不变)
        const [logRows] = await connection.execute('SELECT * FROM logs WHERE id = ?', [logId]);
        logRows[0].images = await getImagesForSingle(connection, 'log_images', 'log_id', logId);
        let taskRow = null;
        if (finalTaskId) {
            const [tRows] = await connection.execute('SELECT id, task_name AS name, priority, progress, plan_end_time AS due_time, assignee_id AS owner_user_id, creator_id AS creator_user_id FROM tasks WHERE id = ?', [finalTaskId]);
            taskRow = tRows[0] || null;
        }
        await connection.end();
        res.status(201).json({ success: true, log: logRows[0], task: taskRow });

    } catch (e) {
        await connection.rollback(); // 错误时回滚
        console.error('创建日志事务失败:', e);
        res.status(500).json({ success: false, message: '服务器内部错误' });
    }
  } catch (e) {
    console.error('创建日志失败 (连接错误):', e);
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
    const connection = await getConn();
    const { type, q, startDate, endDate, startTime, endTime } = req.query;

    // 日志始终只显示当前用户自己的
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
    }

    // 搜索关键词过滤
    if (q && q.trim() !== '') {
      sql += ' AND content LIKE ?';
      params.push(`%${q.trim()}%`);
    }

    // 时间倒序，限制100条
    sql += ' ORDER BY created_at DESC LIMIT 100';

    const [rows] = await connection.execute(sql, params);
    
    // 加载图片数据
    await enrichLogRows(connection, rows);
    
    await connection.end();

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
        images: row.images || [],
        location: row.latitude && row.longitude ? {
          latitude: row.latitude,
          longitude: row.longitude,
          address: row.address
        } : null,
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
    if (rows.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '日志不存在' });
    }
    rows[0].images = await getImagesForSingle(connection, 'log_images', 'log_id', rows[0].id);
    
    // 添加地理位置信息
    if (rows[0].latitude && rows[0].longitude) {
      rows[0].location = {
        latitude: rows[0].latitude,
        longitude: rows[0].longitude,
        address: rows[0].address
      };
    }
    
    await connection.end();
    res.json({ success: true, log: rows[0] });
  } catch (e) {
    console.error('获取日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

/**
 * @swagger
 * /api/logs/{id}/keywords:
 *   get:
 *     summary: 获取单个日志的关键词
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
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       keyword:
 *                         type: string
 *                       score:
 *                         type: number
 *       404:
 *         description: 日志不存在
 */
app.get('/api/logs/:id/keywords', auth, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const connection = await getConn();
    
    // 先验证日志是否属于当前用户
    const [logRows] = await connection.execute(
      'SELECT id FROM logs WHERE id = ? AND author_user_id = ? LIMIT 1',
      [id, req.user.id]
    );
    
    if (logRows.length === 0) {
      await connection.end();
      return res.status(404).json({ success: false, message: '日志不存在' });
    }
    
    // 获取关键词
    const [kwRows] = await connection.execute(
      'SELECT keyword, score FROM log_keywords WHERE log_id = ? ORDER BY score DESC',
      [id]
    );
    
    await connection.end();
    res.json({ success: true, data: kwRows });
  } catch (e) {
    console.error('获取关键词失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

/**
 * @swagger
 * /api/logs/keywords:
 *   get:
 *     summary: 批量获取时间范围内日志的关键词
 *     tags: [日志管理]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: startTime
 *         required: true
 *         schema:
 *           type: string
 *           format: date-time
 *         description: 开始时间
 *       - in: query
 *         name: endTime
 *         required: true
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
 *                 data:
 *                   type: object
 *                   additionalProperties:
 *                     type: array
 *                     items:
 *                       type: object
 *                       properties:
 *                         keyword:
 *                           type: string
 *                         weight:
 *                           type: number
 *       400:
 *         description: 缺少时间参数
 */
app.get('/api/logs/keywords', auth, async (req, res) => {
  try {
    const { startTime, endTime } = req.query;
    
    if (!startTime || !endTime) {
      return res.status(400).json({ success: false, message: '缺少时间范围参数' });
    }
    
    const connection = await getConn();
    
    // 获取当前用户在时间范围内的所有日志及其关键词
    const [rows] = await connection.execute(`
      SELECT lk.log_id, lk.keyword, lk.score
      FROM log_keywords lk
      INNER JOIN logs l ON lk.log_id = l.id
      WHERE l.author_user_id = ? AND l.time_from >= ? AND l.time_from <= ?
      ORDER BY lk.log_id, lk.score DESC
    `, [req.user.id, startTime, endTime]);
    
    await connection.end();
    
    // 按 log_id 分组
    const keywordMap = {};
    rows.forEach(row => {
      if (!keywordMap[row.log_id]) {
        keywordMap[row.log_id] = [];
      }
      keywordMap[row.log_id].push({
        keyword: row.keyword,
        weight: row.weight
      });
    });
    
    res.json({ success: true, data: keywordMap });
  } catch (e) {
    console.error('批量获取关键词失败:', e);
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
    const { title, content, type, priority, progress, timeFrom, timeTo, taskId, syncTaskProgress = false, logStatus, images: imageDataUris, location } = req.body;
    
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
    
    // 更新地理位置信息
    if (location !== undefined) {
      if (location && location.latitude !== undefined) {
        updates.push('latitude = ?');
        params.push(location.latitude);
      }
      if (location && location.longitude !== undefined) {
        updates.push('longitude = ?');
        params.push(location.longitude);
      }
      if (location && location.address !== undefined) {
        updates.push('address = ?');
        params.push(location.address);
      }
    }
    
    if (updates.length > 0) {
      params.push(id);
      await connection.execute(
        `UPDATE logs SET ${updates.join(', ')} WHERE id = ?`,
        params
      );
    }
    if (Array.isArray(imageDataUris)) {
      await connection.execute('DELETE FROM log_images WHERE log_id = ?', [id]);
      await saveDataUriImages(connection, 'log_images', 'log_id', id, imageDataUris);
    }
    if (syncTaskProgress && (taskId || exists[0].task_id)) {
      const targetTaskId = taskId || exists[0].task_id;
      if (typeof progress === 'number') { // 只在 progress 是数字时才更新
        await connection.execute('UPDATE tasks SET progress = COALESCE(?, progress) WHERE id = ?', [progress, targetTaskId]);
      }
    }
    const [rows] = await connection.execute('SELECT * FROM logs WHERE id = ?', [id]);
    rows[0].images = await getImagesForSingle(connection, 'log_images', 'log_id', id);
    await connection.end();
    
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
    
    // 先删除关联的关键词
    await connection.execute('DELETE FROM log_keywords WHERE log_id = ?', [id]);
    
    // 再删除日志
    await connection.execute('DELETE FROM logs WHERE id = ? AND author_user_id = ?', [id, req.user.id]);
    
    await connection.end();
    res.json({ success: true });
  } catch (e) {
    console.error('删除日志失败:', e);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 启动服务器
// 启动定时任务
startScheduler();

// 启动服务器
app.listen(PORT, async () => {
  console.log(`🚀 服务器运行在 http://localhost:${PORT}`);
  console.log(`📊 健康检查: http://localhost:${PORT}/api/health`);
  await testConnection();
});
