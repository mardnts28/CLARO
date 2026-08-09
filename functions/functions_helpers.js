const fetch = require('node-fetch');

async function callGeminiApi(apiKey, messages) {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: 'gpt-4.1-mini',
      messages,
      max_tokens: 500,
      temperature: 0.0,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Gemini API call failed: ${response.status} ${errorText}`);
  }

  return await response.json();
}

module.exports = {
  callGeminiApi,
};
