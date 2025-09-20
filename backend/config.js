// 数据库配置
const config = {
  host: '117.72.181.99',
  user: 'tu',
  password: 'tu123',
  database: 'tujidan',  // 修改为你的数据库名
  port: 3306,
  waitForConnections: true,
  connectionLimit: 5,
  queueLimit: 0,
  charset: 'utf8mb4',
  // 增加超时设置
  acquireTimeout: 30000,    // 30秒
  timeout: 30000,           // 30秒
  reconnect: true,
  // 网络相关设置
  keepAliveInitialDelay: 0,
  enableKeepAlive: true
};

// JWT密钥
const JWT_SECRET = 'your_jwt_secret_key_here_change_this_in_production';

module.exports = { config, JWT_SECRET };
