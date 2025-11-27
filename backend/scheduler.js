const mysql = require('mysql2/promise');

// 数据库配置 (与 simple_server_final.js 保持一致)
const dbConfig = {
  host: '127.0.0.1',
  user: 'root',
  password: '123456',
  database: 'tujidan',
  port: 3306,
  authPlugin: 'caching_sha2_password',
  charset: 'utf8mb4',
  connectTimeout: 60000,
  keepAliveInitialDelay: 0,
  enableKeepAlive: true,
};

// 创建一个函数来检查并创建截止日期通知
async function checkDeadlinesAndCreateNotifications() {
  let connection;
  try {
    // 1. 连接数据库
    connection = await mysql.createConnection(dbConfig);
    console.log('Scheduler connected to the database.');

    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(now.getDate() + 1);

    // 格式化日期为 YYYY-MM-DD
    const todayStr = now.toISOString().split('T')[0];
    const tomorrowStr = tomorrow.toISOString().split('T')[0];

    // 2. 检查任务截止日期
    const [tasks] = await connection.execute(
      "SELECT id, task_name, assignee_id, plan_end_time FROM tasks WHERE status NOT IN ('completed', 'closed', 'cancelled') AND plan_end_time IS NOT NULL"
    );

    for (const task of tasks) {
      const deadline = new Date(task.plan_end_time);
      const deadlineStr = deadline.toISOString().split('T')[0];

      // 检查是否已存在相关通知
      const [[existingNotification]] = await connection.execute(
        "SELECT id FROM notifications WHERE entity_type = 'task' AND related_id = ? AND type IN (?, ?)",
        [task.id, 'deadline_soon', 'deadline_passed']
      );

      if (existingNotification) {
        continue;
      }

      // 情况 1: 任务即将截止
      if (deadlineStr === tomorrowStr) {
        const title = `任务即将截止: ${task.task_name}`;
        const content = `您被指派的任务 \"${task.task_name}\" 将于明天截止，请尽快处理。`;
        await connection.execute(
          "INSERT INTO notifications (user_id, type, title, content, related_id, entity_type) VALUES (?, ?, ?, ?, ?, 'task')",
          [task.assignee_id, 'deadline_soon', title, content, task.id]
        );
      }
      // 情况 2: 任务已经截止
      else if (deadline < now && deadlineStr !== todayStr) {
        const title = `任务已截止: ${task.task_name}`;
        const content = `您被指派的任务 \"${task.task_name}\" 已于 ${deadlineStr} 截止，请及时更新状态。`;
        await connection.execute(
          "INSERT INTO notifications (user_id, type, title, content, related_id, entity_type) VALUES (?, ?, ?, ?, ?, 'task')",
          [task.assignee_id, 'deadline_passed', title, content, task.id]
        );
      }
    }

    // 3. 检查日志截止日期
    const [logs] = await connection.execute("SELECT id, title, content, author_user_id, time_to FROM logs WHERE log_status != 'completed' AND time_to IS NOT NULL");

    for (const log of logs) {
        const deadline = new Date(log.time_to);
        const deadlineStr = deadline.toISOString().split('T')[0];

        const [[existingNotification]] = await connection.execute(
            "SELECT id FROM notifications WHERE entity_type = 'log' AND related_id = ? AND type IN (?, ?)",
            [log.id, 'log_deadline_soon', 'log_deadline_passed']
        );

        if (existingNotification) {
            continue;
        }

        const displayTitle = log.title || (log.content ? `${log.content.substring(0, 20)}...` : '(无标题日志)');

        if (deadlineStr === tomorrowStr) {
            const title = `日志即将截止: ${displayTitle}`;
            const content = `您创建的日志 \"${displayTitle}\" 将于明天截止。`;
            await connection.execute(
                "INSERT INTO notifications (user_id, type, title, content, related_id, entity_type) VALUES (?, ?, ?, ?, ?, 'log')",
                [log.author_user_id, 'log_deadline_soon', title, content, log.id]
            );
        } else if (deadline < now && deadlineStr !== todayStr) {
            const title = `日志已截止: ${displayTitle}`;
            const content = `您创建的日志 \"${displayTitle}\" 已于 ${deadlineStr} 截止。`;
            await connection.execute(
                "INSERT INTO notifications (user_id, type, title, content, related_id, entity_type) VALUES (?, ?, ?, ?, ?, 'log')",
                [log.author_user_id, 'log_deadline_passed', title, content, log.id]
            );
        }
    }
    console.log('Deadline check completed.');

  } catch (error) {
    console.error('Error in scheduler:', error);
  } finally {
    if (connection) {
      await connection.end();
      console.log('Scheduler database connection closed.');
    }
  }
}

// 设置定时器
function startScheduler() {
  const interval =  60 * 60 * 1000; // 恢复为 1 小时
  
  console.log(`Scheduler started. Will run every ${interval / 1000 / 60} minutes.`);
  
  checkDeadlinesAndCreateNotifications(); 
  
  setInterval(checkDeadlinesAndCreateNotifications, interval);
}

module.exports = { startScheduler };