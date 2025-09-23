-- 使用你的数据库（假设已经存在）
USE tujidan;

-- 创建用户表
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 插入一些测试数据（可选）
-- INSERT INTO users (email, password) VALUES 
-- ('test@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi');

-- 任务表
CREATE TABLE IF NOT EXISTS tasks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64) NOT NULL,
    priority ENUM('high','mid','low') NOT NULL DEFAULT 'low',
    progress TINYINT UNSIGNED NOT NULL DEFAULT 0, -- 0~100
    due_time DATETIME NULL,
    owner_user_id INT NOT NULL,
    creator_user_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_tasks_owner FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_tasks_creator FOREIGN KEY (creator_user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT chk_tasks_progress CHECK (progress <= 100),
    INDEX idx_tasks_owner (owner_user_id),
    INDEX idx_tasks_due (due_time),
    UNIQUE KEY uk_task_name_creator (name, creator_user_id)
);

-- 日志表
CREATE TABLE IF NOT EXISTS logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    author_user_id INT NOT NULL,
    content TEXT NOT NULL,
    priority ENUM('high','mid','low') NOT NULL DEFAULT 'low',
    progress TINYINT UNSIGNED NOT NULL DEFAULT 0, -- 0~100
    time_from DATETIME NULL,
    time_to DATETIME NULL,
    task_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_logs_author FOREIGN KEY (author_user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_logs_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE SET NULL,
    CONSTRAINT chk_logs_progress CHECK (progress <= 100),
    INDEX idx_logs_author (author_user_id),
    INDEX idx_logs_task (task_id),
    INDEX idx_logs_time_from (time_from)
);