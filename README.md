# Tujidan - 四象限应用

一个基于Flutter开发的四象限任务管理应用，支持用户注册登录和数据持久化存储。

## 🚀 快速启动

### 环境要求
- Flutter SDK (3.0+)
- Node.js (v14+)
- MySQL数据库

### 启动步骤

#### 1. 启动后端服务器
```bash
cd backend
npm install
npm start
```

#### 2. 启动Flutter应用
```bash
flutter clean
flutter pub get
flutter run
```

## 📱 支持平台
- ✅ **Android** (主要目标平台)
- ✅ Windows
- ✅ Web

## 🗄️ 数据库配置
- 服务器: 117.72.181.99
- 数据库: tujidan
- 用户: tu

## 🔧 功能特性
- ✅ 用户注册/登录
- ✅ JWT身份验证
- ✅ 密码加密存储
- ✅ 四象限任务管理界面
- ✅ 跨平台支持

## 📦 构建发布

### Android APK (推荐)
```bash
flutter build apk --release
```

### Windows
```bash
flutter build windows --release
```

### Web
```bash
flutter build web
```

## 🏗️ 项目结构
```
Tujidan/
├── lib/                    # Flutter前端代码
│   ├── main.dart          # 主应用入口
│   ├── auth_service.dart  # 认证服务
│   ├── login_page.dart    # 登录页面
│   └── register_page.dart # 注册页面
└── backend/               # Node.js后端服务器
    ├── simple_server_final.js  # 主服务器文件
    ├── config.js          # 数据库配置
    └── package.json       # 依赖配置
```

## 📞 技术支持
如有问题，请检查：
1. 后端服务器是否正常运行 (http://localhost:3001/api/health)
2. 数据库连接是否成功
3. Flutter依赖是否正确安装

## 许可证
MIT License
