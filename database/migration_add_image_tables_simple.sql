-- ============================================
-- 数据库迁移脚本（简化版）：添加任务和日志图片表
-- 创建时间：2024
-- 说明：为任务和日志添加多图片支持（base64存储）
-- 注意：此版本不包含触发器和 image_count 字段
-- ============================================

-- 1. 创建任务图片表
CREATE TABLE IF NOT EXISTS task_images (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '图片ID（自增主键）',
  task_id BIGINT NOT NULL COMMENT '关联的任务ID',
  image_data LONGTEXT NOT NULL COMMENT '图片数据（base64 data URI格式：data:image/jpeg;base64,xxx）',
  file_name VARCHAR(255) DEFAULT NULL COMMENT '原始文件名',
  file_size INT DEFAULT NULL COMMENT '文件大小（字节）',
  mime_type VARCHAR(50) DEFAULT NULL COMMENT 'MIME类型（如：image/jpeg, image/png）',
  width INT DEFAULT NULL COMMENT '图片宽度（像素）',
  height INT DEFAULT NULL COMMENT '图片高度（像素）',
  display_order INT DEFAULT 0 COMMENT '显示顺序（数字越小越靠前）',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  
  -- 索引
  INDEX idx_task_id (task_id),
  INDEX idx_display_order (display_order),
  
  -- 外键约束：删除任务时级联删除图片
  CONSTRAINT fk_task_images_task FOREIGN KEY (task_id) 
    REFERENCES tasks(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='任务图片表';

-- 2. 创建日志图片表
CREATE TABLE IF NOT EXISTS log_images (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '图片ID（自增主键）',
  log_id INT NOT NULL COMMENT '关联的日志ID',
  image_data LONGTEXT NOT NULL COMMENT '图片数据（base64 data URI格式：data:image/jpeg;base64,xxx）',
  file_name VARCHAR(255) DEFAULT NULL COMMENT '原始文件名',
  file_size INT DEFAULT NULL COMMENT '文件大小（字节）',
  mime_type VARCHAR(50) DEFAULT NULL COMMENT 'MIME类型（如：image/jpeg, image/png）',
  width INT DEFAULT NULL COMMENT '图片宽度（像素）',
  height INT DEFAULT NULL COMMENT '图片高度（像素）',
  display_order INT DEFAULT 0 COMMENT '显示顺序（数字越小越靠前）',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  
  -- 索引
  INDEX idx_log_id (log_id),
  INDEX idx_display_order (display_order),
  
  -- 外键约束：删除日志时级联删除图片
  CONSTRAINT fk_log_images_log FOREIGN KEY (log_id) 
    REFERENCES logs(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='日志图片表';

-- ============================================
-- 说明：
-- 1. task_images 和 log_images 表结构相同，只是关联的表不同
-- 2. image_data 字段存储完整的 data URI：data:image/jpeg;base64,xxx
-- 3. 外键约束确保删除任务/日志时，关联的图片也会自动删除
-- 4. display_order 字段用于控制图片显示顺序
-- 5. 如果需要统计图片数量，可以在查询时使用 COUNT(*) 或添加 image_count 字段
-- ============================================

