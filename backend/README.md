# Tujidan 后端服务器

这是Tujidan Flutter应用的后端API服务器，使用Node.js + Express + MySQL实现。

## 功能特性

- ✅ 用户登录
- ✅ JWT token认证
- ✅ 密码加密存储
- ✅ MySQL数据库连接
- ✅ CORS跨域支持
- ✅ 错误处理

## 安装和运行

### 1. 安装依赖
```bash
cd backend
npm install
```

### 2. 设置数据库
首先需要在你的MySQL数据库中执行 `database.sql` 文件来创建数据库和表：

```sql
-- 在MySQL中执行
source database.sql;
```

### 3. 启动服务器
```bash
# 开发模式（自动重启）
npm run dev

# 生产模式
npm start
```

服务器将在 `http://localhost:3000` 启动

## API接口

### 用户登录
```
POST /api/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

### 验证token
```
GET /api/verify
Authorization: Bearer <your_token>
```

### 健康检查
```
GET /api/health
```

## 数据库配置

在 `config.js` 中修改数据库连接信息：
- host: 数据库服务器地址
- user: 数据库用户名
- password: 数据库密码
- database: 数据库名称

## 安全说明

- 密码使用bcrypt加密存储
- JWT token有效期7天
- 生产环境请修改JWT_SECRET密钥


