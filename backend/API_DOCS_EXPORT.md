# API 接口文档导出指南

## 方法一：使用导出脚本（推荐）

1. 确保后端服务已启动（可选，脚本可以直接生成）
2. 在 `backend` 目录下运行：
   ```bash
   npm run export-docs
   ```
   或者：
   ```bash
   node export-api-docs.js
   ```

3. 导出文件将保存在 `backend/api-docs-export/` 目录下：
   - `api-docs.json` - OpenAPI 3.0 JSON 格式
   - `api-docs.html` - 独立的 HTML 文档

## 方法二：直接从服务器下载

1. 启动后端服务：
   ```bash
   cd backend
   npm start
   ```

2. 在浏览器中访问：
   - **在线查看**: http://localhost:3001/api-docs/
   - **下载 JSON**: http://localhost:3001/api-docs.json

3. 在浏览器中打开 `http://localhost:3001/api-docs.json`，右键保存为文件

## 方法三：使用命令行下载（如果服务正在运行）

```bash
# Windows PowerShell
Invoke-WebRequest -Uri http://localhost:3001/api-docs.json -OutFile api-docs.json

# 或者使用 curl（如果已安装）
curl http://localhost:3001/api-docs.json -o api-docs.json
```

## 提交文档的建议

### 选项 1：提交 JSON 文件
- 文件：`api-docs.json`
- 优点：标准格式，可导入各种工具（Postman、Swagger Editor、Insomnia 等）
- 适用场景：需要进一步处理或导入工具

### 选项 2：提交 HTML 文件
- 文件：`api-docs.html`
- 优点：可直接在浏览器中查看，格式美观
- 适用场景：直接阅读和展示

### 选项 3：提供在线链接
- 链接：`http://localhost:3001/api-docs/`
- 优点：实时更新，无需文件
- 适用场景：开发环境可访问时

### 选项 4：生成 PDF（可选）
1. 打开 `api-docs.html` 文件
2. 在浏览器中按 `Ctrl+P` (Windows) 或 `Cmd+P` (Mac)
3. 选择"另存为 PDF"
4. 保存为 `api-docs.pdf`

## 使用导出的文档

### 导入 Postman
1. 打开 Postman
2. 点击 Import
3. 选择 `api-docs.json` 文件
4. 所有接口将自动导入

### 使用 Swagger Editor
1. 访问 https://editor.swagger.io/
2. 点击 File > Import file
3. 选择 `api-docs.json` 文件
4. 可以查看和编辑文档

### 使用其他工具
- **Insomnia**: 支持导入 OpenAPI 3.0 JSON
- **Apifox**: 支持导入 OpenAPI 3.0 JSON
- **RapidAPI**: 支持导入 OpenAPI 3.0 JSON



