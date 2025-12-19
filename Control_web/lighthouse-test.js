/**
 * Lighthouse 性能测试脚本
 * 
 * 使用方法：
 * 1. 确保服务器已启动：npm start
 * 2. 运行测试：node lighthouse-test.js
 */

const lighthouse = require('lighthouse');
const chromeLauncher = require('chrome-launcher');
const fs = require('fs');
const path = require('path');

const URL = 'http://localhost:3002';
const OUTPUT_DIR = './lighthouse-reports';

// 确保输出目录存在
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR);
}

async function runLighthouse() {
  console.log('🚀 启动 Lighthouse 测试...');
  console.log(`📊 测试 URL: ${URL}`);
  console.log('⏳ 请稍候，测试可能需要 30-60 秒...\n');

  // 启动 Chrome
  const chrome = await chromeLauncher.launch({
    chromeFlags: ['--headless', '--no-sandbox']
  });

  const options = {
    logLevel: 'info',
    output: 'html',
    onlyCategories: ['performance'],
    port: chrome.port,
  };

  try {
    // 运行 Lighthouse
    const runnerResult = await lighthouse(URL, options);

    // 保存报告
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const reportPath = path.join(OUTPUT_DIR, `lighthouse-report-${timestamp}.html`);
    
    fs.writeFileSync(reportPath, runnerResult.report);
    
    console.log('✅ 测试完成！');
    console.log(`📄 报告已保存到: ${reportPath}`);
    console.log('\n📊 性能得分:', runnerResult.lhr.categories.performance.score * 100);
    
    // 显示 Core Web Vitals
    const audits = runnerResult.lhr.audits;
    console.log('\n🎯 Core Web Vitals:');
    if (audits['largest-contentful-paint']) {
      console.log(`   LCP: ${(audits['largest-contentful-paint'].numericValue / 1000).toFixed(2)}s`);
    }
    if (audits['first-input-delay']) {
      console.log(`   FID: ${audits['first-input-delay'].numericValue.toFixed(0)}ms`);
    }
    if (audits['cumulative-layout-shift']) {
      console.log(`   CLS: ${audits['cumulative-layout-shift'].numericValue.toFixed(3)}`);
    }
    
    console.log('\n💡 提示: 打开 HTML 报告查看详细分析和优化建议');
    
  } catch (error) {
    console.error('❌ 测试失败:', error);
  } finally {
    await chrome.kill();
  }
}

// 检查服务器是否运行
const http = require('http');
const checkServer = () => {
  return new Promise((resolve, reject) => {
    const req = http.get(URL, (res) => {
      resolve(true);
    });
    req.on('error', () => {
      reject(false);
    });
    req.setTimeout(2000, () => {
      req.destroy();
      reject(false);
    });
  });
};

// 主函数
(async () => {
  try {
    await checkServer();
    await runLighthouse();
  } catch (error) {
    console.error('❌ 错误: 无法连接到服务器');
    console.log('💡 请先启动服务器: npm start');
    process.exit(1);
  }
})();

