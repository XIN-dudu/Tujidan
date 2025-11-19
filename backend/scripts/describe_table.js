const mysql = require('mysql2/promise');
const table = process.argv[2];
if (!table) {
  console.error('Usage: node scripts/describe_table.js <table>');
  process.exit(1);
}

(async () => {
  const conn = await mysql.createConnection({
    host: '117.72.181.99',
    user: 'tu',
    password: 'tu123',
    database: 'tujidan',
    port: 3306,
  });
  const [rows] = await conn.query('DESCRIBE ' + table);
  console.table(rows);
  await conn.end();
})();
