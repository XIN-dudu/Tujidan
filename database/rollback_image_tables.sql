-- ============================================
-- 数据库回滚脚本：删除任务和日志图片表
-- 创建时间：2024
-- 说明：撤销添加图片表的迁移
-- 警告：执行此脚本会删除所有图片数据，请谨慎操作！
-- ============================================

-- 1. 删除触发器（如果存在）
DROP TRIGGER IF EXISTS trg_task_images_insert;
DROP TRIGGER IF EXISTS trg_task_images_delete;
DROP TRIGGER IF EXISTS trg_log_images_insert;
DROP TRIGGER IF EXISTS trg_log_images_delete;

-- 2. 删除 tasks 表的 image_count 字段（如果存在）
ALTER TABLE tasks DROP COLUMN IF EXISTS image_count;

-- 3. 删除 logs 表的 image_count 字段（如果存在）
ALTER TABLE logs DROP COLUMN IF EXISTS image_count;

-- 4. 删除任务图片表
DROP TABLE IF EXISTS task_images;

-- 5. 删除日志图片表
DROP TABLE IF EXISTS log_images;

-- ============================================
-- 注意：
-- 1. 如果表中有外键约束，MySQL 可能要求先删除外键约束
-- 2. 如果遇到外键约束错误，可以先执行：
--    ALTER TABLE task_images DROP FOREIGN KEY fk_task_images_task;
--    ALTER TABLE log_images DROP FOREIGN KEY fk_log_images_log;
-- ============================================

