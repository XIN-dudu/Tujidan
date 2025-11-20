# 数据库迁移说明

## 文件说明

- `migration_add_image_tables.sql` - 完整版迁移脚本（包含触发器和 image_count 字段）
- `migration_add_image_tables_simple.sql` - 简化版迁移脚本（不包含触发器和 image_count 字段）
- `rollback_image_tables.sql` - 回滚脚本（删除所有相关表和字段）

## 执行方法

### 方法 1：使用 Node.js 脚本（推荐）

```bash
# 进入 backend 目录
cd backend

# 执行完整版迁移
node run_migration.js migration_add_image_tables.sql

# 或执行简化版迁移
node run_migration.js migration_add_image_tables_simple.sql

# 如果需要回滚
node run_migration.js rollback_image_tables.sql
```

### 方法 2：使用 MySQL 命令行

```bash
# 连接到本地数据库
mysql -h 127.0.0.1 -u root -p tujidan

# 执行 SQL 文件
source database/migration_add_image_tables.sql;

# 或使用绝对路径
source D:/GitHub/Tujidan/database/migration_add_image_tables.sql;
```

### 方法 3：使用图形化工具

#### MySQL Workbench
1. 打开 MySQL Workbench
2. 连接到数据库（127.0.0.1）
3. 打开 SQL 文件（File → Open SQL Script）
4. 选择要执行的 SQL 文件
5. 点击执行按钮（⚡ Execute）

#### Navicat / phpMyAdmin
1. 连接到数据库
2. 打开 SQL 编辑器
3. 复制 SQL 文件内容
4. 粘贴并执行

### 方法 4：在 Node.js 代码中执行

如果需要在后端代码中执行，可以参考 `backend/simple_server_final.js` 中的 `ensureDashboardLogsTable` 函数：

```javascript
async function ensureImageTables(connection) {
  // 创建 task_images 表
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS task_images (
      id BIGINT PRIMARY KEY AUTO_INCREMENT,
      task_id BIGINT NOT NULL,
      image_data LONGTEXT NOT NULL,
      -- ... 其他字段
      INDEX idx_task_id (task_id),
      CONSTRAINT fk_task_images_task FOREIGN KEY (task_id) 
        REFERENCES tasks(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
  
  // 创建 log_images 表
  // ...
}
```

## 注意事项

1. **备份数据**：执行迁移前，建议先备份数据库
2. **外键约束**：确保 `tasks` 和 `logs` 表已存在
3. **权限检查**：确保数据库用户有 CREATE TABLE 和 ALTER TABLE 权限
4. **触发器**：完整版包含触发器，如果不需要自动计数功能，使用简化版

## 验证迁移

执行后可以运行以下 SQL 验证：

```sql
-- 检查表是否存在
SHOW TABLES LIKE '%_images';

-- 查看表结构
DESCRIBE task_images;
DESCRIBE log_images;

-- 检查外键约束
SELECT 
  CONSTRAINT_NAME,
  TABLE_NAME,
  REFERENCED_TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'tujidan'
  AND TABLE_NAME IN ('task_images', 'log_images')
  AND REFERENCED_TABLE_NAME IS NOT NULL;
```

## 回滚

如果需要撤销迁移：

```bash
node run_migration.js rollback_image_tables.sql
```

**警告**：回滚会删除所有图片数据，请谨慎操作！

