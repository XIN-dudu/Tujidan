/**
 * 导出 API 文档脚本
 * 使用方法: node export-api-docs.js
 */

const fs = require('fs');
const path = require('path');
const swaggerJsdoc = require('swagger-jsdoc');

// 使用与服务器相同的配置
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
            logStatus: { type: 'string', enum: ['in_progress', 'completed'] },
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

// 生成 Swagger 规范
const swaggerSpec = swaggerJsdoc(swaggerOptions);

// 创建导出目录
const exportDir = path.join(__dirname, 'api-docs-export');
if (!fs.existsSync(exportDir)) {
  fs.mkdirSync(exportDir, { recursive: true });
}

// 导出 JSON 格式
const jsonPath = path.join(exportDir, 'api-docs.json');
fs.writeFileSync(jsonPath, JSON.stringify(swaggerSpec, null, 2), 'utf8');
console.log(`✅ JSON 文档已导出到: ${jsonPath}`);

// 导出 YAML 格式（可选，需要安装 js-yaml）
try {
  const yaml = require('js-yaml');
  const yamlPath = path.join(exportDir, 'api-docs.yaml');
  fs.writeFileSync(yamlPath, yaml.dump(swaggerSpec), 'utf8');
  console.log(`✅ YAML 文档已导出到: ${yamlPath}`);
} catch (e) {
  console.log('⚠️  跳过 YAML 导出（需要安装 js-yaml: npm install js-yaml）');
}

// 生成简单的 HTML 文档
const htmlContent = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tujidan API 文档</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.9.0/swagger-ui.css" />
    <style>
        body {
            margin: 0;
            padding: 0;
        }
        .swagger-ui .topbar {
            display: none;
        }
    </style>
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>
    <script>
        window.onload = function() {
            const spec = ${JSON.stringify(swaggerSpec)};
            window.ui = SwaggerUIBundle({
                spec: spec,
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout"
            });
        };
    </script>
</body>
</html>`;

const htmlPath = path.join(exportDir, 'api-docs.html');
fs.writeFileSync(htmlPath, htmlContent, 'utf8');
console.log(`✅ HTML 文档已导出到: ${htmlPath}`);

console.log('\n📄 接口文档导出完成！');
console.log(`📁 导出目录: ${exportDir}`);
console.log('\n📋 导出文件说明:');
console.log('  - api-docs.json: OpenAPI 3.0 JSON 格式（可用于导入 Postman、Swagger Editor 等）');
console.log('  - api-docs.html: 独立的 HTML 文档（可直接在浏览器中打开查看）');
console.log('\n💡 提示:');
console.log('  1. 可以直接提交 api-docs.json 文件');
console.log('  2. 或者提交 api-docs.html 文件（更易阅读）');
console.log('  3. 也可以提供在线链接: http://localhost:3001/api-docs/');
console.log('  4. 如需 PDF，可以使用浏览器打开 HTML 文件后打印为 PDF');



