-- 快速修复外键约束问题
-- 这个脚本专门解决外键类型不匹配的问题

USE tujidan;

-- 1. 删除所有外键约束
ALTER TABLE tasks DROP FOREIGN KEY IF EXISTS fk_tasks_owner;
ALTER TABLE tasks DROP FOREIGN KEY IF EXISTS fk_tasks_creator;
ALTER TABLE logs DROP FOREIGN KEY IF EXISTS fk_logs_author;
ALTER TABLE logs DROP FOREIGN KEY IF EXISTS fk_logs_task;

-- 2. 修改字段类型为BIGINT
ALTER TABLE tasks MODIFY COLUMN owner_user_id BIGINT NOT NULL;
ALTER TABLE tasks MODIFY COLUMN creator_user_id BIGINT NOT NULL;
ALTER TABLE logs MODIFY COLUMN author_user_id BIGINT NOT NULL;
ALTER TABLE logs MODIFY COLUMN task_id BIGINT NULL;

-- 3. 重新创建外键约束
ALTER TABLE tasks 
ADD CONSTRAINT fk_tasks_owner FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE RESTRICT;

ALTER TABLE tasks 
ADD CONSTRAINT fk_tasks_creator FOREIGN KEY (creator_user_id) REFERENCES users(id) ON DELETE RESTRICT;

ALTER TABLE logs 
ADD CONSTRAINT fk_logs_author FOREIGN KEY (author_user_id) REFERENCES users(id) ON DELETE RESTRICT;

ALTER TABLE logs 
ADD CONSTRAINT fk_logs_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE SET NULL;

-- 4. 验证修复结果
SELECT '外键约束修复完成' as message;
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE 
WHERE REFERENCED_TABLE_NAME = 'users' 
AND TABLE_SCHEMA = DATABASE();
