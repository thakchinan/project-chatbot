-- Migration: 013_caregiver_notifications
-- Description: Adds LINE Notify token to user_settings and creates FCM device tokens table.

-- 1. Add line_notify_token to user_settings
ALTER TABLE public.user_settings 
ADD COLUMN IF NOT EXISTS line_notify_token VARCHAR(255);

-- 2. Create table for Caregiver FCM tokens
CREATE TABLE IF NOT EXISTS public.caregiver_device_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    fcm_token VARCHAR(500) NOT NULL,
    device_name VARCHAR(100),
    platform VARCHAR(50), -- 'android', 'ios', 'web'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
    UNIQUE(user_id, fcm_token)
);

-- RLS policies for caregiver_device_tokens
ALTER TABLE public.caregiver_device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own device tokens"
    ON public.caregiver_device_tokens
    FOR SELECT
    USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can insert their own device tokens"
    ON public.caregiver_device_tokens
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Users can update their own device tokens"
    ON public.caregiver_device_tokens
    FOR UPDATE
    USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can delete their own device tokens"
    ON public.caregiver_device_tokens
    FOR DELETE
    USING (auth.uid()::text = user_id::text);

CREATE INDEX IF NOT EXISTS idx_caregiver_device_tokens_user_id ON public.caregiver_device_tokens(user_id);
