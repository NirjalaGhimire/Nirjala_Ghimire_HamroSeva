"""
Call OpenRouter using the OpenAI-compatible Chat Completions API.
Secrets stay on the server — never sent to the Flutter app.
"""
import json
import logging
import os
from typing import Any, Dict, List, Optional

import requests

logger = logging.getLogger(__name__)

DEFAULT_BASE_URL = 'https://openrouter.ai/api/v1'
DEFAULT_MODEL = 'openai/gpt-4o-mini'
# Reasonable cap so we do not burn tokens on huge prompts
MAX_COMPLETION_TOKENS = 900


def get_openrouter_config() -> Dict[str, str]:
    return {
        'api_key': (os.environ.get('OPENROUTER_API_KEY') or '').strip(),
        'model': (os.environ.get('OPENROUTER_MODEL') or DEFAULT_MODEL).strip(),
        'base_url': (os.environ.get('OPENROUTER_BASE_URL') or DEFAULT_BASE_URL).rstrip('/'),
        # Optional: OpenRouter app attribution (recommended on OpenRouter dashboard)
        'site_url': (os.environ.get('OPENROUTER_SITE_URL') or '').strip(),
        'app_title': (os.environ.get('OPENROUTER_APP_TITLE') or 'Hamro Sewa').strip(),
    }


def chat_completion(
    messages: List[Dict[str, str]],
    *,
    temperature: float = 0.3,
    max_tokens: int = MAX_COMPLETION_TOKENS,
) -> Dict[str, Any]:
    """
    POST /chat/completions. Returns parsed JSON or raises requests.HTTPError / ValueError.
    """
    cfg = get_openrouter_config()
    if not cfg['api_key']:
        raise ValueError('OPENROUTER_API_KEY is not set. Add it to backend/.env')

    url = f"{cfg['base_url']}/chat/completions"
    headers = {
        'Authorization': f"Bearer {cfg['api_key']}",
        'Content-Type': 'application/json',
    }
    # OpenRouter recommends Referer + X-Title for rankings/dashboard (optional).
    if cfg['site_url']:
        headers['Referer'] = cfg['site_url']
    if cfg['app_title']:
        headers['X-Title'] = cfg['app_title']

    payload = {
        'model': cfg['model'],
        'messages': messages,
        'temperature': temperature,
        'max_tokens': max_tokens,
    }

    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=60)
    except requests.RequestException as e:
        logger.warning('OpenRouter network error: %s', e)
        raise ValueError('Could not reach AI service. Check your network and try again.') from e

    if resp.status_code == 401:
        raise ValueError('Invalid OpenRouter API key (401). Check OPENROUTER_API_KEY in backend/.env')
    if resp.status_code == 429:
        raise ValueError('AI rate limit reached. Please try again in a minute.')
    if resp.status_code >= 400:
        try:
            err = resp.json()
            detail = err.get('error', {}).get('message') or err.get('message') or resp.text
        except Exception:
            detail = resp.text[:500]
        logger.warning('OpenRouter error %s: %s', resp.status_code, detail)
        raise ValueError(f'AI service error ({resp.status_code}). {detail}')

    data = resp.json()
    choices = data.get('choices') or []
    if not choices:
        raise ValueError('AI returned an empty response.')
    content = (choices[0].get('message') or {}).get('content')
    if content is None:
        raise ValueError('AI response had no text content.')
    return {
        'content': content.strip(),
        'raw': data,
        'model_used': data.get('model') or cfg['model'],
    }


def build_messages(system_text: str, user_text: str) -> List[Dict[str, str]]:
    return [
        {'role': 'system', 'content': system_text},
        {'role': 'user', 'content': user_text},
    ]
