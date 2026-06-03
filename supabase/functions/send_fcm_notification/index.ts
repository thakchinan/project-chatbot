import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'
// Note: To use FCM HTTP v1 API, you typically need to generate an OAuth2 token 
// using a Service Account Key. For simplicity in Edge Functions, you can use 
// the 'google-auth-library' or pass a pre-generated token, but the most robust
// way is to store your Service Account JSON in Supabase Secrets.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { userId, title, body } = await req.json()
    
    if (!userId || !title || !body) {
      throw new Error('Missing required parameters: userId, title, or body')
    }

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // 1. Fetch FCM Tokens for the Caregivers of this User
    // Assuming caregiver_device_tokens stores tokens for users
    const { data: tokensData, error: tokenError } = await supabaseClient
      .from('caregiver_device_tokens')
      .select('fcm_token')
      .eq('user_id', userId)

    if (tokenError) {
      throw tokenError
    }

    if (!tokensData || tokensData.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: 'No devices registered for push.' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    const tokens = tokensData.map(t => t.fcm_token)

    // 2. Prepare FCM Payload
    // In production, you must generate an OAuth2 token using your Firebase Service Account
    // Here is the structure of the request to FCM HTTP v1 API:
    const PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID') || 'smart-brain-care' // Replace with actual
    const FCM_API_URL = `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`
    
    // IMPORTANT: Replace this with actual OAuth2 token generation logic using your Service Account JSON
    const OAUTH2_ACCESS_TOKEN = Deno.env.get('FIREBASE_OAUTH_TOKEN') || 'mock-token'

    let successCount = 0;
    let failureCount = 0;

    for (const token of tokens) {
      const fcmPayload = {
        message: {
          token: token,
          notification: {
            title: title,
            body: body,
          },
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
          }
        }
      }

      const response = await fetch(FCM_API_URL, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${OAUTH2_ACCESS_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(fcmPayload),
      })

      if (response.ok) {
        successCount++;
      } else {
        failureCount++;
        const errText = await response.text();
        console.error(`FCM Error for token ${token}:`, errText);
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Notifications sent. Success: ${successCount}, Failures: ${failureCount}` 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
