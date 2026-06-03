-- Migration: 012_chatbot_action_logs
-- Description: Creates a table to log automated chatbot actions and recognized intents.

CREATE TABLE IF NOT EXISTS public.chatbot_action_logs (
    log_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    intent_type VARCHAR(50) NOT NULL, -- e.g. 'request_help', 'start_eeg', 'log_emotion'
    original_message TEXT NOT NULL,
    response_given TEXT NOT NULL,
    handled_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
    metadata JSONB -- Additional context (e.g. extracted emotion intensity)
);

-- RLS policies
ALTER TABLE public.chatbot_action_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own chatbot action logs"
    ON public.chatbot_action_logs
    FOR SELECT
    USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can insert their own chatbot action logs"
    ON public.chatbot_action_logs
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id::text);

-- Add index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_chatbot_action_logs_user_id ON public.chatbot_action_logs(user_id);
