# 任务状态"待分配"数据库迁移说明

## 概述

本次更新为任务表（tasks）添加了新的状态值 `pending_assignment`（待分配）。

## 自动迁移（推荐）

**服务器启动时会自动检查和更新数据库结构**，无需手动操作。

只需要重启后端服务器，迁移代码会自动：
1. 检查 `tasks.status` 字段的类型
2. 如果是 ENUM 类型，更新 ENUM 定义以包含新状态
3. 如果是 VARCHAR 类型，确保长度足够（至少50字符）
4. 更新字段注释

## 手动迁移（可选）

如果自动迁移失败，或者你希望手动执行迁移，可以使用以下 SQL 脚本：

### 方法1：如果 status 字段是 ENUM 类型

```sql
ALTER TABLE tasks 
MODIFY COLUMN status ENUM(
  'pending_assignment',  -- 待分配（新增）
  'not_started',         -- 未开始
  'in_progress',         -- 进行中
  'paused',              -- 已暂停
  'completed',           -- 已完成
  'closed',              -- 已关闭
  'cancelled'            -- 已取消
) DEFAULT 'not_started';
```

### 方法2：如果 status 字段是 VARCHAR 类型（推荐）

```sql
-- 确保字段长度足够
ALTER TABLE tasks 
MODIFY COLUMN status VARCHAR(50) DEFAULT 'not_started'
COMMENT '任务状态: pending_assignment(待分配), not_started(未开始), in_progress(进行中), paused(已暂停), completed(已完成), closed(已关闭), cancelled(已取消)';
```

### 方法3：使用提供的 SQL 脚本

执行 `migrate_task_status.sql` 文件：

```bash
mysql -u your_username -p your_database < migrate_task_status.sql
```

或在 MySQL 客户端中：

```sql
source migrate_task_status.sql;
```

## 验证迁移

执行以下 SQL 查询验证字段类型：

```sql
SELECT COLUMN_NAME, COLUMN_TYPE, COLUMN_DEFAULT, COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME = 'tasks' 
  AND COLUMN_NAME = 'status';
```

## 状态值对照表

| 数据库值 | 中文名称 | 说明 |
|---------|---------|------|
| `pending_assignment` | 待分配 | 新添加的状态，表示任务尚未分配给负责人 |
| `not_started` | 未开始 | 任务已分配但尚未开始 |
| `in_progress` | 进行中 | 任务正在进行 |
| `paused` | 已暂停 | 任务暂时暂停 |
| `completed` | 已完成 | 任务已完成 |
| `closed` | 已关闭 | 任务已关闭 |
| `cancelled` | 已取消 | 任务已取消 |

## 注意事项

1. **备份数据库**：在执行任何数据库修改前，请先备份数据库
2. **测试环境**：建议先在测试环境验证迁移脚本
3. **数据一致性**：如果现有数据中有无效的状态值，可能需要先清理
4. **权限检查**：确保数据库用户有 ALTER TABLE 权限

## 故障排除

### 问题1：ENUM 修改失败

**解决方案**：将字段类型改为 VARCHAR

```sql
ALTER TABLE tasks 
MODIFY COLUMN status VARCHAR(50) DEFAULT 'not_started';
```

### 问题2：字段长度不足

**解决方案**：扩展 VARCHAR 长度

```sql
ALTER TABLE tasks 
MODIFY COLUMN status VARCHAR(50);
```

### 问题3：现有数据不兼容

**解决方案**：检查并更新现有数据

```sql
-- 查看所有不同的状态值
SELECT DISTINCT status FROM tasks;

-- 如果发现无效状态，可以更新为默认值
UPDATE tasks SET status = 'not_started' WHERE status NOT IN (
  'pending_assignment', 'not_started', 'in_progress', 
  'paused', 'completed', 'closed', 'cancelled'
);
```

## 联系支持

如果遇到问题，请检查：
1. 服务器启动日志中的迁移信息
2. 数据库用户权限
3. MySQL 版本兼容性（建议 5.7+ 或 8.0+）

