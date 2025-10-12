const mysql = require('mysql2/promise');

// 数据库配置
const dbConfig = {
  host: '117.72.181.99',
  user: 'tu',
  password: 'tu123',
  database: 'tujidan',
  port: 3306,
  charset: 'utf8mb4',
};

async function testRBAC() {
  let connection;
  
  try {
    console.log('🔗 连接数据库...');
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ 数据库连接成功');
    
    // 测试1: 检查表是否存在
    console.log('\n📋 检查表结构...');
    const tables = ['users', 'roles', 'user_roles', 'permissions', 'role_permissions'];
    
    for (const table of tables) {
      const [rows] = await connection.execute(`SHOW TABLES LIKE '${table}'`);
      if (rows.length > 0) {
        console.log(`✅ 表 ${table} 存在`);
      } else {
        console.log(`❌ 表 ${table} 不存在`);
      }
    }
    
    // 测试2: 检查角色数据
    console.log('\n👥 检查角色数据...');
    const [roles] = await connection.execute('SELECT * FROM roles');
    console.log(`找到 ${roles.length} 个角色:`);
    roles.forEach(role => {
      console.log(`  - ${role.role_name}: ${role.description}`);
    });
    
    // 测试3: 检查权限数据
    console.log('\n🔐 检查权限数据...');
    const [permissions] = await connection.execute('SELECT * FROM permissions ORDER BY module, perm_key');
    console.log(`找到 ${permissions.length} 个权限:`);
    
    const modules = {};
    permissions.forEach(perm => {
      if (!modules[perm.module]) {
        modules[perm.module] = [];
      }
      modules[perm.module].push(perm);
    });
    
    Object.keys(modules).forEach(module => {
      console.log(`  📁 ${module}:`);
      modules[module].forEach(perm => {
        console.log(`    - ${perm.perm_key}: ${perm.name}`);
      });
    });
    
    // 测试4: 检查角色权限分配
    console.log('\n🔗 检查角色权限分配...');
    const [rolePerms] = await connection.execute(`
      SELECT r.role_name, COUNT(rp.permission_id) as permission_count
      FROM roles r
      LEFT JOIN role_permissions rp ON r.id = rp.role_id
      GROUP BY r.id, r.role_name
      ORDER BY r.role_name
    `);
    
    rolePerms.forEach(rp => {
      console.log(`  - ${rp.role_name}: ${rp.permission_count} 个权限`);
    });
    
    // 测试5: 创建测试用户并分配角色
    console.log('\n👤 创建测试用户...');
    
    // 检查是否已存在测试用户
    const [existingUsers] = await connection.execute(
      'SELECT id FROM users WHERE username = ?',
      ['test_user']
    );
    
    let testUserId;
    if (existingUsers.length > 0) {
      testUserId = existingUsers[0].id;
      console.log(`✅ 测试用户已存在，ID: ${testUserId}`);
    } else {
      const [result] = await connection.execute(
        'INSERT INTO users (username, password_hash, real_name, status) VALUES (?, ?, ?, 1)',
        ['test_user', 'hashed_password', '测试用户']
      );
      testUserId = result.insertId;
      console.log(`✅ 创建测试用户成功，ID: ${testUserId}`);
    }
    
    // 为测试用户分配staff角色
    const [staffRole] = await connection.execute('SELECT id FROM roles WHERE role_name = ?', ['staff']);
    if (staffRole.length > 0) {
      // 删除现有角色分配
      await connection.execute('DELETE FROM user_roles WHERE user_id = ?', [testUserId]);
      
      // 分配新角色
      await connection.execute(
        'INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)',
        [testUserId, staffRole[0].id]
      );
      console.log('✅ 为测试用户分配staff角色成功');
    }
    
    // 测试6: 查询用户权限
    console.log('\n🔍 查询测试用户权限...');
    const [userPerms] = await connection.execute(`
      SELECT DISTINCT p.perm_key, p.name, p.module
      FROM permissions p
      JOIN role_permissions rp ON p.id = rp.permission_id
      JOIN user_roles ur ON rp.role_id = ur.role_id
      WHERE ur.user_id = ?
      ORDER BY p.module, p.perm_key
    `, [testUserId]);
    
    console.log(`测试用户拥有 ${userPerms.length} 个权限:`);
    userPerms.forEach(perm => {
      console.log(`  - ${perm.perm_key} (${perm.module}): ${perm.name}`);
    });
    
    console.log('\n🎉 RBAC系统测试完成！');
    
  } catch (error) {
    console.error('❌ 测试失败:', error.message);
  } finally {
    if (connection) {
      await connection.end();
      console.log('🔌 数据库连接已关闭');
    }
  }
}

// 运行测试
testRBAC();
