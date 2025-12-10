const mysql = require('mysql2/promise');
const { config: dbConfig } = require('./config');

(async () => {
  try {
    const connection = await mysql.createConnection(dbConfig);
    const [rows] = await connection.query("SHOW COLUMNS FROM notifications WHERE Field = 'type'");
    console.log('Current type column definition:', rows[0].Type);
    await connection.end();
  } catch (e) {
    console.error(e);
  }
})();
