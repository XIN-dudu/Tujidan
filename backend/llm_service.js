// 加载环境变量（支持 .env）
require('dotenv').config();
// 大模型服务 - 通义千问（免费版）
// 使用 Node.js 18+ 内置的 fetch

// 配置（从环境变量读取，或直接在这里设置）
// 按你的要求：直接硬编码 Key（无需 .env）
const DASHSCOPE_API_KEY = 'sk-6df07e9af5ac48d196a7cd4d8d95fe74';

/**
 * 调用通义千问生成文本
 * @param {string} prompt - 提示词
 * @returns {Promise<string>} 生成的文本
 */
async function callQwen(prompt) {
  if (!DASHSCOPE_API_KEY || typeof DASHSCOPE_API_KEY !== 'string' || DASHSCOPE_API_KEY.length < 10) {
    throw new Error('请先配置 DASHSCOPE_API_KEY 环境变量或在代码中设置API密钥');
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 30000); // 30秒超时

  try {
    const response = await fetch(
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${DASHSCOPE_API_KEY}`,
        },
        body: JSON.stringify({
          model: 'qwen-turbo', // 免费模型
          input: {
            messages: [
              {
                role: 'user',
                content: prompt
              }
            ]
          },
          parameters: {
            temperature: 0.7,
            max_tokens: 2000,
          }
        }),
        signal: controller.signal,
      }
    );

    clearTimeout(timeoutId);

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(`通义千问 API 错误: ${response.status} - ${errorData.message || response.statusText}`);
    }

    const data = await response.json();
    
    // 提取返回的文本
    const text = data.output?.text || 
                 data.output?.choices?.[0]?.message?.content || 
                 '';
    
    if (!text) {
      throw new Error('API返回内容为空');
    }

    return text;
  } catch (error) {
    if (error.name === 'AbortError') {
      throw new Error('请求超时，请稍后重试');
    }
    throw error;
  }
}

/**
 * 根据关键词生成 MBTI 分析
 * @param {Array<string>} keywords - 关键词列表
 * @returns {Promise<{mbti: string, analysis: string, traits: Array<string>}>}
 */
async function generateMBTIAnalysis(keywords) {
  if (!keywords || keywords.length === 0) {
    throw new Error('关键词列表不能为空');
  }

  // 统计关键词频率
  const keywordCounts = {};
  keywords.forEach(kw => {
    keywordCounts[kw] = (keywordCounts[kw] || 0) + 1;
  });

  // 按频率排序，取前20个
  const topKeywords = Object.entries(keywordCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 20)
    .map(([word, count]) => `${word}(${count}次)`)
    .join('、');

  const prompt = `你是一位专业的MBTI性格分析专家。请根据以下用户日志中的关键词，分析该用户的MBTI性格类型。

用户日志关键词（按出现频率排序）：
${topKeywords}

请按照以下格式返回分析结果（必须是有效的JSON格式，不要包含其他文字）：
{
  "mbti": "16种MBTI类型之一（如：INTJ、ENFP等）",
  "analysis": "详细的分析说明（200-300字，简洁明了）",
  "traits": ["特征1", "特征2", "特征3", "特征4", "特征5"],
  "confidence": "分析的可信度（高/中/低）"
}`;

  try {
    const response = await callQwen(prompt);
    
    // 尝试解析JSON
    let jsonStr = response.trim();
    
    // 如果包含代码块，提取JSON部分
    const jsonMatch = jsonStr.match(/```(?:json)?\s*(\{[\s\S]*\})\s*```/);
    if (jsonMatch) {
      jsonStr = jsonMatch[1];
    } else {
      // 尝试提取第一个 { 到最后一个 } 之间的内容
      const firstBrace = jsonStr.indexOf('{');
      const lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace !== -1 && lastBrace !== -1) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
      }
    }

    const result = JSON.parse(jsonStr);
    
    // 验证结果格式
    if (!result.mbti || !result.analysis) {
      throw new Error('大模型返回格式不正确');
    }

    return {
      mbti: result.mbti.toUpperCase(),
      analysis: result.analysis,
      traits: result.traits || [],
      confidence: result.confidence || '中',
      keywords: topKeywords,
    };
  } catch (error) {
    console.error('[LLM] MBTI分析失败:', error);
    throw new Error(`MBTI分析失败: ${error.message}`);
  }
}

/**
 * 根据MBTI类型生成发展建议
 * @param {string} mbti - MBTI类型
 * @param {Array<string>} keywords - 关键词列表（用于个性化建议）
 * @returns {Promise<{suggestions: Array<string>, summary: string}>}
 */
async function generateDevelopmentSuggestions(mbti, keywords) {
  if (!mbti) {
    throw new Error('MBTI类型不能为空');
  }

  // 统计关键词频率，提取主要关注领域
  const keywordCounts = {};
  keywords.forEach(kw => {
    keywordCounts[kw] = (keywordCounts[kw] || 0) + 1;
  });

  const topKeywords = Object.entries(keywordCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([word]) => word)
    .join('、');

  const prompt = `你是一位专业的职业发展顾问。请根据用户的MBTI性格类型（${mbti}）和其日志关键词，提供个性化的发展建议。

用户MBTI类型：${mbti}
用户主要关注领域：${topKeywords || '未明确'}

请按照以下格式返回建议（必须是有效的JSON格式，不要包含其他文字）：
{
  "suggestions": [
    "建议1（50-80字）",
    "建议2（50-80字）",
    "建议3（50-80字）",
    "建议4（50-80字）",
    "建议5（50-80字）"
  ],
  "summary": "总结性建议（100-150字）"
}

建议要具体、实用，结合用户的MBTI特点和关注领域。`;

  try {
    const response = await callQwen(prompt);
    
    // 尝试解析JSON
    let jsonStr = response.trim();
    
    const jsonMatch = jsonStr.match(/```(?:json)?\s*(\{[\s\S]*\})\s*```/);
    if (jsonMatch) {
      jsonStr = jsonMatch[1];
    } else {
      const firstBrace = jsonStr.indexOf('{');
      const lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace !== -1 && lastBrace !== -1) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
      }
    }

    const result = JSON.parse(jsonStr);
    
    // 验证结果格式
    if (!result.suggestions || !Array.isArray(result.suggestions)) {
      throw new Error('大模型返回格式不正确');
    }

    return {
      suggestions: result.suggestions || [],
      summary: result.summary || '',
    };
  } catch (error) {
    console.error('[LLM] 发展建议生成失败:', error);
    throw new Error(`发展建议生成失败: ${error.message}`);
  }
}

/**
 * 直接根据日志原文文本生成 MBTI 分析（关键词缺失时的降级策略）
 * @param {string} logsText - 近期日志的标题与正文拼接文本
 * @returns {Promise<{mbti: string, analysis: string, traits: Array<string>}>}
 */
async function generateMBTIFromLogsText(logsText) {
  const snippet = (logsText || '').trim().slice(0, 8000); // 控制长度，避免超长
  if (!snippet) {
    throw new Error('日志文本为空，无法分析');
  }

  const prompt = `你是一位专业的MBTI性格分析专家。请基于以下用户的若干条工作/学习/生活日志原文，推断其最可能的MBTI类型，并解释理由。\n\n用户日志原文（节选）：\n${snippet}\n\n请按照以下格式返回分析结果（必须是有效的JSON格式，不要包含其他文字）：\n{\n  "mbti": "16种MBTI类型之一（如：INTJ、ENFP等）",\n  "analysis": "详细的分析说明（200-300字，结合日志行为特征与偏好）",\n  "traits": ["特征1", "特征2", "特征3", "特征4", "特征5"],\n  "confidence": "分析的可信度（高/中/低）"\n}`;

  try {
    const response = await callQwen(prompt);
    let jsonStr = response.trim();
    const jsonMatch = jsonStr.match(/```(?:json)?\\s*(\\{[\\s\\S]*\\})\\s*```/);
    if (jsonMatch) {
      jsonStr = jsonMatch[1];
    } else {
      const firstBrace = jsonStr.indexOf('{');
      const lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace !== -1 && lastBrace !== -1) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
      }
    }

    const result = JSON.parse(jsonStr);
    if (!result.mbti || !result.analysis) {
      throw new Error('大模型返回格式不正确');
    }

    return {
      mbti: result.mbti.toUpperCase(),
      analysis: result.analysis,
      traits: result.traits || [],
      confidence: result.confidence || '中',
    };
  } catch (error) {
    console.error('[LLM] 文本MBTI分析失败:', error);
    throw new Error(`文本MBTI分析失败: ${error.message}`);
  }
}

module.exports = {
  callQwen,
  generateMBTIAnalysis,
  generateDevelopmentSuggestions,
  generateMBTIFromLogsText,
};

