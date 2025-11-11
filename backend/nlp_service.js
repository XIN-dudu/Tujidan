// 使用 Node.js 18+ 内置的 fetch（无需额外依赖）
const API_KEY = '1s46BQK5fkDpp0UftqcRbfRv';
const SECRET_KEY = 'AvoMiRxEpYpO0qg6ORLGsDMwl6DPIsch';

let _token = null;
let _tokenExpireTs = 0;

/**
 * 获取百度云 Access Token（自动缓存29天）
 */
async function getAccessToken() {
  if (_token && Date.now() < _tokenExpireTs) {
    return _token;
  }
  
  try {
    const params = new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: API_KEY,
      client_secret: SECRET_KEY,
    });
    
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);
    
    const response = await fetch(
      `https://aip.baidubce.com/oauth/2.0/token?${params}`,
      { signal: controller.signal }
    );
    
    clearTimeout(timeoutId);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    
    _token = data.access_token;
    // 缓存29天，避免频繁请求
    _tokenExpireTs = Date.now() + 29 * 24 * 60 * 60 * 1000;
    console.log('[NLP] Access Token 获取成功');
    return _token;
  } catch (error) {
    console.error('[NLP] 获取 Token 失败:', error.message);
    throw error;
  }
}

/**
 * 提取关键词（调用百度 NLP API）
 * @param {string} text - 要分析的文本
 * @param {number} topN - 返回前N个关键词
 * @returns {Promise<Array<{word: string, weight: number}>>}
 */
async function extractKeywords(text, topN = 5) {
  if (!text || !text.trim()) {
    return [];
  }
  
  try {
    const token = await getAccessToken();
    
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 8000);
    
    // 按照百度官方示例：text 是数组，Content-Type 是 x-www-form-urlencoded
    const requestBody = JSON.stringify({
      text: [text.trim()],
      num: topN
    });
    
    const response = await fetch(
      `https://aip.baidubce.com/rpc/2.0/nlp/v1/txt_keywords_extraction?access_token=${token}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
        signal: controller.signal,
      }
    );
    
    clearTimeout(timeoutId);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    
    // 如果有错误码，记录详细信息
    if (data.error_code) {
      console.log('[NLP] API 返回错误:', data.error_code, data.error_msg);
      return [];
    }
    
    // 百度 API 返回的是 results 数组，包含 word 和 score 字段
    if (!data.results || data.results.length === 0) {
      console.log('[NLP] 未提取到关键词');
      return [];
    }
    
    // 返回前 topN 个关键词，保持原始的 score 字段
    const keywords = data.results
      .slice(0, topN)
      .map(item => ({
        word: item.word,
        score: item.score || 0,
      }));
    
    console.log(`[NLP] 成功提取 ${keywords.length} 个关键词:`, keywords.map(k => k.word).join(', '));
    return keywords;
  } catch (error) {
    if (error.name === 'AbortError') {
      console.error('[NLP] 关键词提取超时');
    } else {
      console.error('[NLP] 关键词提取失败:', error.message);
    }
    return [];
  }
}

module.exports = {
  getAccessToken,
  extractKeywords,
};
