-- 检查RBAC迁移结果
USE tujidan;

-- 检查表结构
SELECT '检查表结构' as check_type;
SHOW TABLES;

-- 检查users表结构
SELECT '检查users表结构' as check_type;
DESCRIBE users;

-- 检查外键约束
SELECT '检查外键约束' as check_type;
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE 
WHERE REFERENCED_TABLE_NAME IN ('users', 'roles', 'permissions')
AND TABLE_SCHEMA = DATABASE()
ORDER BY TABLE_NAME, CONSTRAINT_NAME;

-- 检查角色数据
SELECT '检查角色数据' as check_type;
SELECT * FROM roles;

-- 检查权限数据
SELECT '检查权限数据' as check_type;
SELECT module, COUNT(*) as permission_count 
FROM permissions 
GROUP BY module 
ORDER BY module;

-- 检查角色权限分配
SELECT '检查角色权限分配' as check_type;
SELECT 
    r.role_name,
    COUNT(rp.permission_id) as permission_count
FROM roles r
LEFT JOIN role_permissions rp ON r.id = rp.role_id
GROUP BY r.id, r.role_name
ORDER BY r.role_name;

-- 检查用户角色分配
SELECT '检查用户角色分配' as check_type;
SELECT 
    u.username,
    u.real_name,
    COUNT(ur.role_id) as role_count
FROM users u
LEFT JOIN user_roles ur ON u.id = ur.user_id
GROUP BY u.id, u.username, u.real_name
ORDER BY u.username;

-- 检查数据完整性
SELECT '检查数据完整性' as check_type;
SELECT 
    'users' as table_name,
    COUNT(*) as record_count
FROM users
UNION ALL
SELECT 
    'roles' as table_name,
    COUNT(*) as record_count
FROM roles
UNION ALL
SELECT 
    'permissions' as table_name,
    COUNT(*) as record_count
FROM permissions
UNION ALL
SELECT 
    'user_roles' as table_name,
    COUNT(*) as record_count
FROM user_roles
UNION ALL
SELECT 
    'role_permissions' as table_name,
    COUNT(*) as record_count
FROM role_permissions;
