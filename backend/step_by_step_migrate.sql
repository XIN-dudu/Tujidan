-- 分步骤RBAC迁移脚本
-- 请按顺序执行每个步骤，如果某步出错，请检查后再继续

USE tujidan;

-- ========================================
-- 步骤1: 检查当前数据库状态
-- ========================================
SELECT '步骤1: 检查当前数据库状态' as step;

-- 检查现有表结构
SHOW TABLES;

-- 检查users表结构
DESCRIBE users;

-- 检查外键约束
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE 
WHERE REFERENCED_TABLE_NAME = 'users' 
AND TABLE_SCHEMA = DATABASE();

-- ========================================
-- 步骤2: 备份现有数据
-- ========================================
SELECT '步骤2: 备份现有数据' as step;

-- 备份用户表
CREATE TABLE IF NOT EXISTS users_backup AS SELECT * FROM users;

-- 备份任务表
CREATE TABLE IF NOT EXISTS tasks_backup AS SELECT * FROM tasks;

-- 备份日志表
CREATE TABLE IF NOT EXISTS logs_backup AS SELECT * FROM logs;

-- ========================================
-- 步骤3: 删除外键约束
-- ========================================
SELECT '步骤3: 删除外键约束' as step;

-- 删除tasks表的外键约束
ALTER TABLE tasks DROP FOREIGN KEY IF EXISTS fk_tasks_owner;
ALTER TABLE tasks DROP FOREIGN KEY IF EXISTS fk_tasks_creator;

-- 删除logs表的外键约束
ALTER TABLE logs DROP FOREIGN KEY IF EXISTS fk_logs_author;
ALTER TABLE logs DROP FOREIGN KEY IF EXISTS fk_logs_task;

-- ========================================
-- 步骤4: 修改字段类型
-- ========================================
SELECT '步骤4: 修改字段类型' as step;

-- 修改tasks表的用户ID字段
ALTER TABLE tasks MODIFY COLUMN owner_user_id BIGINT NOT NULL;
ALTER TABLE tasks MODIFY COLUMN creator_user_id BIGINT NOT NULL;

-- 修改logs表的用户ID字段
ALTER TABLE logs MODIFY COLUMN author_user_id BIGINT NOT NULL;
ALTER TABLE logs MODIFY COLUMN task_id BIGINT NULL;

-- ========================================
-- 步骤5: 重建users表
-- ========================================
SELECT '步骤5: 重建users表' as step;

-- 创建新的users表结构
CREATE TABLE users_new (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(64) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(120) NULL,
    real_name VARCHAR(64) NOT NULL,
    phone VARCHAR(20) NULL,
    avatar_url VARCHAR(255) NULL,
    department_id BIGINT NULL,
    position VARCHAR(64) NULL,
    status TINYINT NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_username (username),
    INDEX idx_users_email (email),
    INDEX idx_users_department (department_id)
);

-- 迁移现有用户数据
INSERT INTO users_new (id, username, password_hash, email, real_name, status, created_at, updated_at)
SELECT 
    id, 
    COALESCE(email, CONCAT('user_', id)) as username, 
    password as password_hash, 
    email, 
    COALESCE(email, CONCAT('用户_', id)) as real_name, 
    1 as status, 
    created_at, 
    updated_at
FROM users;

-- 删除旧表并重命名新表
DROP TABLE users;
RENAME TABLE users_new TO users;

-- ========================================
-- 步骤6: 重新创建外键约束
-- ========================================
SELECT '步骤6: 重新创建外键约束' as step;

-- 为tasks表重新创建外键约束
ALTER TABLE tasks 
ADD CONSTRAINT fk_tasks_owner FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE RESTRICT;

ALTER TABLE tasks 
ADD CONSTRAINT fk_tasks_creator FOREIGN KEY (creator_user_id) REFERENCES users(id) ON DELETE RESTRICT;

-- 为logs表重新创建外键约束
ALTER TABLE logs 
ADD CONSTRAINT fk_logs_author FOREIGN KEY (author_user_id) REFERENCES users(id) ON DELETE RESTRICT;

ALTER TABLE logs 
ADD CONSTRAINT fk_logs_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE SET NULL;

-- ========================================
-- 步骤7: 创建RBAC相关表
-- ========================================
SELECT '步骤7: 创建RBAC相关表' as step;

-- 创建角色表
CREATE TABLE IF NOT EXISTS roles (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(64) NOT NULL UNIQUE,
    description VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_roles_name (role_name)
);

-- 创建用户角色关联表
CREATE TABLE IF NOT EXISTS user_roles (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    UNIQUE KEY uk_user_role (user_id, role_id),
    INDEX idx_user_roles_user (user_id),
    INDEX idx_user_roles_role (role_id)
);

-- 创建权限表
CREATE TABLE IF NOT EXISTS permissions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    perm_key VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(64) NOT NULL,
    module VARCHAR(64) NOT NULL,
    description VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_permissions_key (perm_key),
    INDEX idx_permissions_module (module)
);

-- 创建角色权限关联表
CREATE TABLE IF NOT EXISTS role_permissions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    role_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE,
    UNIQUE KEY uk_role_permission (role_id, permission_id),
    INDEX idx_role_permissions_role (role_id),
    INDEX idx_role_permissions_permission (permission_id)
);

-- ========================================
-- 步骤8: 插入初始数据
-- ========================================
SELECT '步骤8: 插入初始数据' as step;

-- 插入初始角色数据
INSERT INTO roles (role_name, description) VALUES 
('founder', '创始人，拥有所有权限'),
('admin', '管理员，拥有管理权限'),
('dept_head', '部门负责人，拥有部门管理权限'),
('staff', '普通员工，基础权限')
ON DUPLICATE KEY UPDATE role_name = role_name;

-- 插入初始权限数据
INSERT INTO permissions (perm_key, name, module, description) VALUES 
-- 用户管理权限
('user:create', '创建用户', 'user_management', '创建新用户'),
('user:view', '查看用户', 'user_management', '查看用户信息'),
('user:edit', '编辑用户', 'user_management', '编辑用户信息'),
('user:delete', '删除用户', 'user_management', '删除用户'),
('user:assign_role', '分配角色', 'user_management', '为用户分配角色'),

-- 任务管理权限
('task:create', '创建任务', 'task_management', '创建新任务'),
('task:view', '查看任务', 'task_management', '查看任务信息'),
('task:edit', '编辑任务', 'task_management', '编辑任务信息'),
('task:delete', '删除任务', 'task_management', '删除任务'),
('task:assign', '分配任务', 'task_management', '分配任务给其他用户'),

-- 日志管理权限
('log:create', '创建日志', 'log_management', '创建新日志'),
('log:view', '查看日志', 'log_management', '查看日志信息'),
('log:edit', '编辑日志', 'log_management', '编辑日志信息'),
('log:delete', '删除日志', 'log_management', '删除日志'),
('log:view_all', '查看所有日志', 'log_management', '查看所有用户的日志'),

-- 角色权限管理
('role:create', '创建角色', 'role_management', '创建新角色'),
('role:view', '查看角色', 'role_management', '查看角色信息'),
('role:edit', '编辑角色', 'role_management', '编辑角色信息'),
('role:delete', '删除角色', 'role_management', '删除角色'),
('role:assign_permission', '分配权限', 'role_management', '为角色分配权限'),

-- 系统管理权限
('system:config', '系统配置', 'system_management', '系统配置管理'),
('system:backup', '数据备份', 'system_management', '数据备份和恢复'),
('system:logs', '系统日志', 'system_management', '查看系统日志')
ON DUPLICATE KEY UPDATE perm_key = perm_key;

-- ========================================
-- 步骤9: 分配角色权限
-- ========================================
SELECT '步骤9: 分配角色权限' as step;

-- Founder 拥有所有权限
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id 
FROM roles r, permissions p 
WHERE r.role_name = 'founder'
ON DUPLICATE KEY UPDATE role_id = role_id;

-- Admin 拥有管理权限（除了系统管理）
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id 
FROM roles r, permissions p 
WHERE r.role_name = 'admin' 
AND p.module IN ('user_management', 'task_management', 'log_management', 'role_management')
ON DUPLICATE KEY UPDATE role_id = role_id;

-- Dept Head 拥有部门管理权限
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id 
FROM roles r, permissions p 
WHERE r.role_name = 'dept_head' 
AND p.perm_key IN ('user:view', 'task:create', 'task:view', 'task:edit', 'task:assign', 'log:create', 'log:view', 'log:edit')
ON DUPLICATE KEY UPDATE role_id = role_id;

-- Staff 拥有基础权限
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id 
FROM roles r, permissions p 
WHERE r.role_name = 'staff' 
AND p.perm_key IN ('task:view', 'log:create', 'log:view', 'log:edit')
ON DUPLICATE KEY UPDATE role_id = role_id;

-- ========================================
-- 步骤10: 为现有用户分配默认角色
-- ========================================
SELECT '步骤10: 为现有用户分配默认角色' as step;

-- 为现有用户分配staff角色
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u, roles r
WHERE r.role_name = 'staff'
AND NOT EXISTS (
    SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id
);

-- ========================================
-- 完成
-- ========================================
SELECT 'RBAC系统迁移完成！' as message;
SELECT '请检查所有表和数据是否正确' as reminder;
