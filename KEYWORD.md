# 百度云关键词提取功能使用说明

## 已完成的改动

### 1. 后端改动

#### 新增文件
- `backend/nlp_service.js` - 百度云 NLP 服务封装
  - 自动管理 Access Token（缓存29天）
  - 提供 `extractKeywords()` 方法提取关键词

#### 数据库
- 新增 `log_keywords` 表，字段：
  - `id` - 主键
  - `log_id` - 日志ID（外键关联 logs 表）
  - `keyword` - 关键词文本
  - `score` - 权重（百度API返回）
  - `created_at` - 创建时间

#### API 接口
1. **POST /api/logs** - 创建日志时自动提取关键词（异步，不阻塞响应）
2. **GET /api/logs/:id/keywords** - 获取单个日志的关键词
3. **GET /api/logs/keywords?startTime=xxx&endTime=xxx** - 批量获取时间范围内的关键词

### 2. 前端改动

#### 新增文件
- `lib/services/log_keyword_service.dart` - 关键词服务
  - `getKeywordsRange()` - 批量获取
  - `getKeywordsByLogId()` - 单个获取

#### 修改文件
- `lib/pages/log_view_page.dart`
  - 在 `_loadLogs()` 中自动加载关键词
  - 在 `_buildLogItem()` 中展示关键词标签（蓝色圆角标签）


#### 创建日志
当用户创建日志时，后端会：
1. 保存日志到 `logs` 表
//以下已关闭 --在Tujidan\lib\services\log_keyword_service.dart 2267~2300中
2. 异步调用百度 NLP API 提取关键词
3. 将关键词保存到 `log_keywords` 表

后端控制台会显示：
```
✅ 日志 123 关键词提取成功: 会议, 讨论, 产品, 需求, 功能
```

#### 查看关键词
前端在日志视图中会自动：
1. 加载时间范围内的所有关键词
2. 在每条日志下方显示蓝色关键词标签
3. 每个标签带有 tag 图标

## API 密钥说明

当前使用的百度云密钥：
- API Key: `1s46BQK5fkDpp0UftqcRbfRv`
- Secret Key: `AvoMiRxEpYpO0qg6ORLGsDMwl6DPIsch`

**注意**：这是你提供的密钥，请确保：
- 已在百度云控制台开通"关键词提取"服务
- 密钥有足够的免费额度或余额
- 生产环境中将密钥移到环境变量

## 故障排查

### 1. 关键词提取失败
检查后端控制台日志：
```
❌ 日志 123 关键词提取失败: xxx
```

可能原因：
- 网络连接问题
- API 密钥无效或过期
- 免费额度用完
- 文本内容为空或过短

### 2. 前端不显示关键词
- 确认后端已成功提取（查看控制台）
- 检查前端网络请求是否成功（开发者工具 Network 标签）
- 确认日志ID匹配

### 3. 数据库表不存在
手动执行 SQL：
```sql
CREATE TABLE IF NOT EXISTS log_keywords (
  id INT AUTO_INCREMENT PRIMARY KEY,
  log_id INT NOT NULL,
  keyword VARCHAR(64) NOT NULL,
  score FLOAT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_log_id (log_id),
  CONSTRAINT fk_log_kw_log FOREIGN KEY (log_id) REFERENCES logs(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## 下一步优化建议

1. **环境变量配置**
   - 将 API 密钥移到 `.env` 文件
   - 使用 `process.env.BAIDU_NLP_API_KEY`

2. **错误重试**
   - 提取失败时自动重试 2-3 次
   - 记录失败日志到数据库

3. **批量提取**
   - 对已有日志批量提取关键词
   - 添加管理接口触发批量任务

4. **关键词分析页面**
   - 统计高频关键词
   - 生成词云图
   - 按时间维度分析趋势

5. **缓存优化**
   - 前端缓存已加载的关键词
   - 减少重复请求

## 文件清单

### 后端
- `backend/nlp_service.js` ✅ 新增
- `backend/simple_server_final.js` ✅ 修改（导入服务、添加接口、初始化表）

### 前端
- `lib/services/log_keyword_service.dart` ✅ 新增
- `lib/pages/log_view_page.dart` ✅ 修改（加载关键词、显示标签）

### 数据库
- `log_keywords` 表 ✅ 自动创建

## 完成情况

✅ 百度云 NLP 服务集成
✅ 独立关键词表设计
✅ 日志创建时自动提取
✅ 前端批量加载关键词
✅ 关键词标签展示
✅ API 密钥配置

现在你可以启动后端和前端，创建日志时会自动提取关键词并显示！
