type JsonMap = Record<string, unknown>;

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const firebaseServerKey = Deno.env.get("FIREBASE_SERVER_KEY") ?? "";

const headers = {
  apikey: serviceRoleKey,
  authorization: `Bearer ${serviceRoleKey}`,
  "content-type": "application/json",
};

Deno.serve(async () => {
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ ok: false, error: "Missing Supabase environment variables" }, 500);
  }
  if (!firebaseServerKey) {
    return json({ ok: false, error: "Missing FIREBASE_SERVER_KEY" }, 500);
  }

  const alerts = await getRows<JsonMap>(
    "/rest/v1/caregiver_alerts?select=*&is_read=eq.false&level=in.(high,medium)&order=created_at.asc&limit=50",
  );
  let sent = 0;

  for (const alert of alerts) {
    const tokens = await getRows<JsonMap>(
      `/rest/v1/caregiver_device_tokens?select=*&user_id=eq.${alert.user_id}&is_active=eq.true`,
    );
    for (const token of tokens) {
      const delivery = await sendFcm(String(token.device_token), alert);
      await insert("/rest/v1/notification_deliveries", {
        alert_id: alert.alert_id,
        token_id: token.token_id,
        provider: "fcm",
        status: delivery.ok ? "sent" : "failed",
        provider_message_id: delivery.messageId,
        error_message: delivery.error,
        sent_at: delivery.ok ? new Date().toISOString() : null,
      });
      if (delivery.ok) sent++;
    }
    if (tokens.length > 0) {
      await patch(`/rest/v1/caregiver_alerts?alert_id=eq.${alert.alert_id}`, { is_read: true });
    }
  }

  return json({ ok: true, alerts: alerts.length, sent });
});

async function sendFcm(token: string, alert: JsonMap) {
  const response = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      authorization: `key=${firebaseServerKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      to: token,
      priority: "high",
      notification: {
        title: alert.title,
        body: alert.message,
      },
      data: {
        alert_id: String(alert.alert_id),
        user_id: String(alert.user_id),
        level: String(alert.level),
        source: String(alert.source ?? "caregiver_alert"),
      },
    }),
  });
  const data = await response.json().catch(() => ({}));
  return {
    ok: response.ok && Number(data.success ?? 0) > 0,
    messageId: data.results?.[0]?.message_id,
    error: response.ok ? data.results?.[0]?.error : JSON.stringify(data),
  };
}

async function getRows<T>(path: string): Promise<T[]> {
  const response = await fetch(`${supabaseUrl}${path}`, { headers });
  if (!response.ok) return [];
  return await response.json();
}

async function insert(path: string, body: unknown) {
  await fetch(`${supabaseUrl}${path}`, {
    method: "POST",
    headers: { ...headers, prefer: "return=minimal" },
    body: JSON.stringify(body),
  });
}

async function patch(path: string, body: unknown) {
  await fetch(`${supabaseUrl}${path}`, {
    method: "PATCH",
    headers: { ...headers, prefer: "return=minimal" },
    body: JSON.stringify(body),
  });
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
