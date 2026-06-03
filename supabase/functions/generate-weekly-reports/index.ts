type JsonMap = Record<string, unknown>;

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const openaiApiKey = Deno.env.get("OPENAI_API_KEY") ?? "";

const headers = {
  apikey: serviceRoleKey,
  authorization: `Bearer ${serviceRoleKey}`,
  "content-type": "application/json",
};

Deno.serve(async () => {
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ ok: false, error: "Missing Supabase environment variables" }, 500);
  }

  const users = await getRows<JsonMap>("/rest/v1/users?select=id,username,full_name");
  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const periodStart = dateOnly(since);
  const periodEnd = dateOnly(new Date());
  const results: JsonMap[] = [];

  for (const user of users) {
    const userId = Number(user.id);
    const report = await buildReport(userId, since);
    const summary = await summarizeWithOpenAI(report);
    report.aiSummary = summary ?? report.insight;

    await upsert("/rest/v1/weekly_reports?on_conflict=user_id,period_start", {
      user_id: userId,
      period_start: periodStart,
      period_end: periodEnd,
      summary: report.aiSummary,
      report_data: report,
    });

    const alertRows = (report.alerts as JsonMap[])
      .filter((alert) => alert.level !== "low")
      .map((alert) => ({
        user_id: userId,
        level: alert.level,
        title: alert.title,
        message: alert.message,
        source: "scheduled_weekly_report",
      }));

    if (alertRows.length > 0) {
      await insert("/rest/v1/caregiver_alerts", alertRows);
    }

    results.push({ userId, alerts: alertRows.length });
  }

  return json({ ok: true, generated: results.length, results });
});

async function buildReport(userId: number, since: Date): Promise<JsonMap> {
  const from = since.toISOString();
  const [brainwaves, tests, emotions, activities, chats] = await Promise.all([
    getRows<JsonMap>(`/rest/v1/brainwave_data?select=*&user_id=eq.${userId}&recorded_at=gte.${from}`),
    getRows<JsonMap>(`/rest/v1/test_results?select=*&user_id=eq.${userId}&test_date=gte.${from}`),
    getRows<JsonMap>(`/rest/v1/emotion_logs?select=*&user_id=eq.${userId}&created_at=gte.${from}`),
    getRows<JsonMap>(`/rest/v1/activities?select=*&user_id=eq.${userId}&completed_at=gte.${from}`),
    getRows<JsonMap>(`/rest/v1/chat_messages?select=*&user_id=eq.${userId}&sent_at=gte.${from}`),
  ]);

  const eeg = summarizeBrainwaves(brainwaves);
  const mood = summarizeMood(emotions, chats);
  const stress = summarizeStress(tests);
  const activity = summarizeActivities(activities);
  const alerts = buildAlerts(eeg, mood, stress);
  const insight =
    `Weekly status: EEG=${eeg.label}, top mood=${mood.topEmotion}, ` +
    `activities=${activity.sessions}, alerts=${alerts.filter((a) => a.level !== "low").length}`;

  return {
    periodStart: since.toISOString(),
    periodEnd: new Date().toISOString(),
    brainwaveCount: brainwaves.length,
    emotionCount: emotions.length,
    activityCount: activities.length,
    chatCount: chats.length,
    eeg,
    mood,
    stress,
    activity,
    alerts,
    insight,
    carePlan: buildCarePlan(eeg, mood, stress),
  };
}

function summarizeBrainwaves(rows: JsonMap[]) {
  const avg = (key: string) => {
    const values = rows.map((r) => Number(r[key] ?? 0)).filter((v) => Number.isFinite(v));
    return values.length ? values.reduce((a, b) => a + b, 0) / values.length : 0;
  };
  const alpha = avg("alpha_wave");
  const beta = avg("beta_wave");
  const delta = avg("delta_wave");
  const attention = avg("attention_score");
  const meditation = avg("meditation_score");
  const stressIndex = clamp((beta + delta) - (alpha + meditation / 2), 0, 100);
  const sleepScore = avg("delta_wave");
  return {
    alpha,
    beta,
    delta,
    attention,
    meditation,
    stressIndex,
    sleepScore,
    sleepTrend: sleepScore >= 45 ? "restorative sleep signal" : "needs sleep monitoring",
    label: stressIndex >= 55 ? "high_watch" : stressIndex >= 35 ? "moderate" : "balanced",
  };
}

function summarizeMood(emotions: JsonMap[], chats: JsonMap[]) {
  const counts = new Map<string, number>();
  for (const row of emotions) {
    const type = String(row.emotion_type ?? "unknown");
    counts.set(type, (counts.get(type) ?? 0) + 1);
  }
  const topEmotion = [...counts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? "no_data";
  const riskWords = ["เครียด", "ไม่ไหว", "เศร้า", "ตาย", "ทำร้าย", "help"];
  const riskChatCount = chats.filter((row) => {
    if (row.is_bot === true || row.is_bot === 1) return false;
    const text = String(row.message ?? "").toLowerCase();
    return riskWords.some((word) => text.includes(word));
  }).length;
  return { topEmotion, riskChatCount, counts: Object.fromEntries(counts) };
}

function summarizeStress(rows: JsonMap[]) {
  const levels = rows.map((r) => String(r.stress_level ?? ""));
  const highCount = levels.filter((l) => /high|severe|สูง/i.test(l)).length;
  const scores = rows.map((r) => Number(r.stress_score ?? 0));
  return {
    latestLevel: levels[0] ?? "no_data",
    highCount,
    avgScore: scores.length ? scores.reduce((a, b) => a + b, 0) / scores.length : 0,
  };
}

function summarizeActivities(rows: JsonMap[]) {
  const minutes = rows.reduce((sum, row) => sum + Number(row.duration_minutes ?? 0), 0);
  return { sessions: rows.length, minutes };
}

function buildAlerts(eeg: JsonMap, mood: JsonMap, stress: JsonMap): JsonMap[] {
  const alerts: JsonMap[] = [];
  if (Number(eeg.stressIndex) >= 55) {
    alerts.push({ level: "high", title: "High EEG stress signal", message: "EEG-derived stress index is elevated." });
  }
  if (Number(mood.riskChatCount) > 0) {
    alerts.push({ level: "high", title: "Risk text detected", message: "Recent chat contains caregiver attention keywords." });
  }
  if (Number(stress.highCount) > 0) {
    alerts.push({ level: "medium", title: "High stress assessment", message: "A weekly stress test is in the high range." });
  }
  return alerts.length ? alerts : [{ level: "low", title: "No crisis signal", message: "Continue routine monitoring." }];
}

function buildCarePlan(eeg: JsonMap, mood: JsonMap, stress: JsonMap): string[] {
  const plan = ["Use this report as monitoring support, not medical diagnosis."];
  if (Number(eeg.stressIndex) >= 55 || Number(stress.highCount) > 0) {
    plan.unshift("Caregiver should check in and repeat a calming activity with EEG follow-up.");
  }
  if (Number(mood.riskChatCount) > 0) {
    plan.unshift("Review flagged chat and keep emergency contacts available.");
  }
  return plan;
}

async function summarizeWithOpenAI(report: JsonMap): Promise<string | null> {
  if (!openaiApiKey) return null;
  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      authorization: `Bearer ${openaiApiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: "Summarize weekly elderly brain and mood monitoring in Thai. Do not diagnose. Keep it concise.",
        },
        { role: "user", content: JSON.stringify(report) },
      ],
      max_tokens: 450,
      temperature: 0.4,
    }),
  });
  if (!response.ok) return null;
  const data = await response.json();
  return data.choices?.[0]?.message?.content ?? null;
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

async function upsert(path: string, body: unknown) {
  await fetch(`${supabaseUrl}${path}`, {
    method: "POST",
    headers: { ...headers, prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify(body),
  });
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function dateOnly(value: Date) {
  return value.toISOString().slice(0, 10);
}
