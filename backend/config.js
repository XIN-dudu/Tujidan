// d:\shixun\Tujidan\backend\config.js

// 最终确认的、完全正确的数据库配置文件
const config = {
  // 主机
  host: '127.0.0.1',

  // 用户名
  user: 'root',

  // 您在命令行和 Navicat 中验证通过的正确密码
  password: '123456',

  // 数据库名
  database: 'tujidan',

  // 端口
  port: 3306,

  // 强制使用数据库支持的新版验证插件，这是解决问题的关键
  authPlugin: 'caching_sha2_password',

  // 连接池设置
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  charset: 'utf8mb4',
  connectTimeout: 30000,
  acquireTimeout: 30000,
  timeout: 30000,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0
};

// JWT 密钥
const JWT_SECRET = 'your_jwt_secret_key_here_change_this_in_production';

module.exports = { config, JWT_SECRET };