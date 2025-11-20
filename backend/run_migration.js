/**
 * 数据库迁移脚本执行工具
 * 用于执行 SQL 迁移文件
 * 
 * 使用方法：
 * node run_migration.js migration_add_image_tables.sql
 * 或
 * node run_migration.js migration_add_image_tables_simple.sql
 */

const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

// 数据库配置（与 simple_server_final.js 保持一致）
const dbConfig = {
  host: '127.0.0.1',
  user: 'root',
  password: '123456',
  database: 'tujidan',
  port: 3306,
  charset: 'utf8mb4',
  multipleStatements: true, // 允许执行多条 SQL 语句
};

async function runMigration(sqlFilePath) {
  let connection;
  
  try {
    // 检查文件是否存在
    const fullPath = path.join(__dirname, '..', 'database', sqlFilePath);
    if (!fs.existsSync(fullPath)) {
      console.error(`❌ 文件不存在: ${fullPath}`);
      process.exit(1);
    }

    // 读取 SQL 文件
    console.log(`📖 读取 SQL 文件: ${sqlFilePath}`);
    const sql = fs.readFileSync(fullPath, 'utf8');
    
    if (!sql || sql.trim().length === 0) {
      console.error('❌ SQL 文件为空');
      process.exit(1);
    }

    // 连接数据库
    console.log('🔌 连接数据库...');
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ 数据库连接成功');

    // 执行 SQL
    console.log('🚀 开始执行迁移...');
    console.log('---');
    
    // 使用 query 而不是 execute，因为文件可能包含多条语句和触发器
    await connection.query(sql);
    
    console.log('---');
    console.log('✅ 迁移执行成功！');
    
    // 验证表是否创建成功
    console.log('\n📊 验证表结构...');
    const [tables] = await connection.query(`
      SELECT TABLE_NAME 
      FROM information_schema.TABLES 
      WHERE TABLE_SCHEMA = ? 
      AND TABLE_NAME IN ('task_images', 'log_images')
    `, [dbConfig.database]);
    
    if (tables.length > 0) {
      console.log('✅ 已创建的表:');
      tables.forEach(table => {
        console.log(`   - ${table.TABLE_NAME}`);
      });
    }

    await connection.end();
    console.log('\n✨ 完成！');
    
  } catch (error) {
    console.error('\n❌ 执行失败:');
    console.error(error.message);
    
    if (error.code === 'ER_TABLE_EXISTS_ERROR') {
      console.error('\n⚠️  提示: 表已存在，如果需要重新创建，请先执行回滚脚本');
    } else if (error.code === 'ER_DUP_FIELDNAME') {
      console.error('\n⚠️  提示: 字段已存在，可能需要先执行回滚脚本');
    }
    
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

// 主函数
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('📝 数据库迁移工具');
    console.log('\n使用方法:');
    console.log('  node run_migration.js <sql文件名>');
    console.log('\n示例:');
    console.log('  node run_migration.js migration_add_image_tables.sql');
    console.log('  node run_migration.js migration_add_image_tables_simple.sql');
    console.log('  node run_migration.js rollback_image_tables.sql');
    console.log('\n可用的 SQL 文件:');
    const databaseDir = path.join(__dirname, '..', 'database');
    if (fs.existsSync(databaseDir)) {
      const files = fs.readdirSync(databaseDir).filter(f => f.endsWith('.sql'));
      files.forEach(file => {
        console.log(`  - ${file}`);
      });
    }
    process.exit(0);
  }

  const sqlFile = args[0];
  await runMigration(sqlFile);
}

main();

