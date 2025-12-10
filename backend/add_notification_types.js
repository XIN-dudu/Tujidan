const mysql = require('mysql2/promise');
const { config: dbConfig } = require('./config');

(async () => {
  let connection;
  try {
    connection = await mysql.createConnection(dbConfig);
    console.log('Connected to database.');

    const newEnumDefinition = "ENUM('assignment','status_change','log_created','progress_update','deadline_soon','deadline_passed','log_deadline_soon','log_deadline_passed','task_update','log_update')";
    
    console.log('Modifying type column to:', newEnumDefinition);
    
    await connection.query(`ALTER TABLE notifications MODIFY COLUMN type ${newEnumDefinition} NOT NULL`);
    
    console.log('Successfully updated type column definition.');
    
  } catch (e) {
    console.error('Failed to update database:', e);
  } finally {
    if (connection) await connection.end();
  }
})();
