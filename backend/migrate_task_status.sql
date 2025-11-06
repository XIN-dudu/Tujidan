-- 任务状态迁移脚本：添加"待分配"状态
-- 执行前请备份数据库！

-- 1. 检查tasks表的status字段类型
-- 如果status是ENUM类型，需要修改ENUM定义
-- 如果status是VARCHAR类型，则不需要修改结构，可以直接使用新状态值

-- 方法1：如果status字段是ENUM类型，修改ENUM定义
-- 注意：MySQL中修改ENUM需要重新定义所有值
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

-- 方法2：如果status字段是VARCHAR类型，确保字段长度足够（推荐）
-- 如果当前是VARCHAR(20)或更小，建议改为VARCHAR(50)以支持更长的状态值
ALTER TABLE tasks 
MODIFY COLUMN status VARCHAR(50) DEFAULT 'not_started'
COMMENT '任务状态: pending_assignment(待分配), not_started(未开始), in_progress(进行中), paused(已暂停), completed(已完成), closed(已关闭), cancelled(已取消)';

-- 2. （可选）将现有的一些任务状态更新为新状态
-- 例如：如果有些任务应该标记为"待分配"
-- UPDATE tasks SET status = 'pending_assignment' WHERE status = 'not_started' AND assignee_id IS NULL;

-- 3. 验证修改
SELECT COLUMN_NAME, COLUMN_TYPE, COLUMN_DEFAULT, COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME = 'tasks' 
  AND COLUMN_NAME = 'status';

