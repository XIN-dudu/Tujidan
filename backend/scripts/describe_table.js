const mysql = require('mysql2/promise');
const table = process.argv[2];
if (!table) {
  console.error('Usage: node scripts/describe_table.js <table>');
  process.exit(1);
}

(async () => {
  const conn = await mysql.createConnection({
    host: '127.0.0.1',
    user: 'root',
    password: '123456',
    database: 'tujidan',
    port: 3306,
  });
  const [rows] = await conn.query('DESCRIBE ' + table);
  console.table(rows);
  await conn.end();
})();
