-- Hamro Sewa AI chat history (Supabase)
-- Run in Supabase SQL editor to enable: GET /api/ai/history/ and persistence from POST /api/ai/query/

CREATE TABLE IF NOT EXISTS seva_ai_chat (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES seva_auth_user(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  answer TEXT,
  retrieved_json JSONB,
  ranking_json JSONB,
  model TEXT,
  meta_json JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_seva_ai_chat_user_id_created_at
  ON seva_ai_chat(user_id, created_at DESC);

COMMENT ON TABLE seva_ai_chat IS 'Stores AI query + retrieved DB context + answer (no secrets).';

-- Hamro Sewa AI chat history (Supabase)
-- Run in Supabase SQL editor to enable: POST /api/ai/query/ persistence

CREATE TABLE IF NOT EXISTS seva_ai_chat (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES seva_auth_user(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  answer TEXT,
  retrieved_json JSONB,
  ranking_json JSONB,
  model TEXT,
  meta_json JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_seva_ai_chat_user_id_created_at
  ON seva_ai_chat(user_id, created_at DESC);

COMMENT ON TABLE seva_ai_chat IS 'Stores AI query + retrieved DB context + answer (no secrets).';

