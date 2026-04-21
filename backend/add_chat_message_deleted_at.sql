-- Add deleted_at column to seva_chat_message table to support soft deletes
-- This allows marking messages as deleted without actually removing them from the database

ALTER TABLE seva_chat_message ADD COLUMN deleted_at TIMESTAMP NULL;
