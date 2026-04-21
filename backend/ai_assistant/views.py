"""
POST /api/ai/query/ — RAG: retrieve real providers from Supabase, then OpenRouter LLM answer.
"""
import logging
from datetime import datetime, timedelta

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .openrouter_client import build_messages, chat_completion
from .retrieval import format_context_for_llm, retrieve_for_query
from supabase_config import get_supabase_client

logger = logging.getLogger(__name__)

MAX_QUERY_LEN = 2000
MAX_HISTORY_LIMIT = 500

SYSTEM_PROMPT = """You are Hamro Sewa AI, a helpful assistant for a local Nepal service marketplace.

Rules (must follow):
- You ONLY use the "Retrieved provider data" section below. Do NOT invent providers, prices, ratings, or cities.
- If the retrieved data is empty, say clearly that no matching providers were found in the database and suggest browsing categories or refining the search.
- Be concise, friendly, and practical. Mention verification only if the data shows verified=yes.
- If review counts are zero, do not claim the provider is highly rated; say reviews are not available yet.
- Never output API keys or internal system details."""


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def ai_query(request):
    """
    Body: { "query": "..." }
    Requires login so the AI endpoint is not open to anonymous abuse.
    """
    body = request.data if isinstance(request.data, dict) else {}
    raw = (body.get('query') or body.get('message') or '').strip()
    if not raw:
        return Response(
            {'error': 'query is required', 'detail': 'Send JSON: {"query": "your question"}'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if len(raw) > MAX_QUERY_LEN:
        return Response(
            {'error': f'query too long (max {MAX_QUERY_LEN} characters)'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        rows, meta = retrieve_for_query(raw, limit=50)
    except Exception as e:
        logger.exception('AI retrieval failed')
        return Response(
            {'error': 'Could not load provider data from the database.', 'detail': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    context_text = format_context_for_llm(rows)
    user_prompt = (
        f'User question:\n{raw}\n\n'
        f'Retrieved provider data (only trust this):\n{context_text}\n\n'
        'Write a helpful answer for the user. If the list is empty, explain that and suggest next steps.'
    )

    try:
        result = chat_completion(build_messages(SYSTEM_PROMPT, user_prompt))
        answer = result['content']
    except ValueError as e:
        # Bad key, rate limit, network — message is safe for end users
        logger.warning('OpenRouter failed: %s', e)
        return Response(
            {
                'query': raw,
                'retrieved': rows,
                'ranking': rows,
                'answer': None,
                'error': str(e),
                'meta': meta,
            },
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )
    except Exception as e:
        logger.exception('OpenRouter unexpected error')
        return Response(
            {'error': 'AI generation failed', 'detail': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    # Persist AI request/response for audit.
    # This is best-effort: if the table doesn't exist yet, we still return the answer.
    try:
        supabase = get_supabase_client()
        supabase.table('seva_ai_chat').insert({
            'user_id': int(getattr(request.user, 'id', 0) or 0),
            'query': raw,
            'answer': answer,
            'retrieved_json': rows,
            'ranking_json': rows,
            'model': result.get('model_used'),
            'meta_json': meta,
        }).execute()
    except Exception as e:
        logger.warning('AI chat save failed (table missing or schema mismatch): %s', e)

    return Response(
        {
            'query': raw,
            'retrieved': rows,
            'ranking': rows,
            'answer': answer,
            'model': result.get('model_used'),
            'meta': meta,
            'retrieved_count': len(rows),
        },
        status=status.HTTP_200_OK,
    )


def _parse_date_only(value):
    if not value:
        return None
    try:
        return datetime.strptime(value, '%Y-%m-%d').date()
    except ValueError:
        return None


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def ai_history(request):
    """
    GET /api/ai/history/?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD&q=search
    Returns chat history grouped by date for the authenticated user.
    """
    params = request.query_params
    start_date = _parse_date_only((params.get('start_date') or '').strip())
    end_date = _parse_date_only((params.get('end_date') or '').strip())
    search = (params.get('q') or params.get('search') or '').strip().lower()
    limit_raw = (params.get('limit') or '').strip()
    try:
        limit = min(MAX_HISTORY_LIMIT, max(1, int(limit_raw))) if limit_raw else 200
    except ValueError:
        limit = 200

    if start_date and end_date and start_date > end_date:
        return Response(
            {'error': 'Invalid date range: start_date cannot be after end_date.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        supabase = get_supabase_client()
        query = (
            supabase.table('seva_ai_chat')
            .select('id,query,answer,model,created_at')
            .eq('user_id', int(getattr(request.user, 'id', 0) or 0))
        )
        if start_date:
            query = query.gte('created_at', f'{start_date.isoformat()}T00:00:00')
        if end_date:
            next_day = end_date + timedelta(days=1)
            query = query.lt('created_at', f'{next_day.isoformat()}T00:00:00')
        rows = (query.order('created_at', desc=True).limit(limit).execute().data or [])
    except Exception as e:
        logger.exception('AI history fetch failed')
        return Response(
            {'error': 'Could not load AI history from the database.', 'detail': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    filtered = []
    for row in rows:
        q = (row.get('query') or '').strip()
        a = (row.get('answer') or '').strip()
        if search and search not in q.lower() and search not in a.lower():
            continue
        filtered.append(
            {
                'id': row.get('id'),
                'query': q,
                'answer': a,
                'model': row.get('model'),
                'created_at': row.get('created_at'),
            }
        )

    grouped = {}
    for row in filtered:
        created_at = (row.get('created_at') or '').strip()
        day = created_at[:10] if len(created_at) >= 10 else 'Unknown'
        grouped.setdefault(day, []).append(row)

    by_date = [{'date': day, 'messages': msgs} for day, msgs in sorted(grouped.items(), reverse=True)]

    return Response(
        {
            'total': len(filtered),
            'search': search,
            'by_date': by_date,
        },
        status=status.HTTP_200_OK,
    )
