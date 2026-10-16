// Northstar — insights function
// A report for Northstar Labs only: how many people use Northstar, which features, which
// topics, and what they asked for that Northstar can't do yet. Never anyone's words.
//
//   { days?: 1..90 }  → { allowed: true, report: {...} }   (admins only)
//   anyone else       → { allowed: false }                  (so the app hides the screen)
//
// Admins are the Supabase user ids listed (comma separated) in the NS_ADMIN_USERS secret.

import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

function serviceDb() {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
}

/** The signed-in person, checked with Supabase Auth (not just read from the token). */
async function verifiedUserId(auth: string): Promise<string | null> {
  const token = auth.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data, error } = await serviceDb().auth.getUser(token);
  return error ? null : data.user?.id ?? null;
}

function count<T extends string>(items: T[]): Array<{ name: T; count: number }> {
  const m = new Map<T, number>();
  for (const i of items) m.set(i, (m.get(i) ?? 0) + 1);
  return [...m.entries()].map(([name, count]) => ({ name, count })).sort((a, b) => b.count - a.count);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const admins = (Deno.env.get("NS_ADMIN_USERS") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
    const userId = await verifiedUserId(req.headers.get("Authorization") ?? "");
    if (!userId || !admins.includes(userId)) return json({ allowed: false });

    const body = await req.json().catch(() => ({}));
    const days = Math.min(90, Math.max(1, Number(body?.days) || 7));
    const since = new Date(Date.now() - days * 86_400_000);
    const sinceDay = since.toISOString().slice(0, 10);
    const today = new Date().toISOString().slice(0, 10);
    const db = serviceDb();

    const [{ data: rows, error }, { data: cost }, { data: users }] = await Promise.all([
      db.from("insight_events").select("at, who, features, topic, unmet, failed, ms")
        .gte("at", since.toISOString()).order("at", { ascending: false }).limit(20000),
      db.from("usage_global").select("day, requests, cost_micros").gte("day", sinceDay).order("day"),
      db.from("usage_daily").select("user_id, day").gte("day", sinceDay),
    ]);
    if (error) throw error;
    const list = rows ?? [];

    // Housekeeping: counts older than 180 days aren't needed.
    db.from("insight_events").delete().lt("at", new Date(Date.now() - 180 * 86_400_000).toISOString())
      .then(() => {}, () => {});

    const people = new Set((users ?? []).map((u: { user_id: string }) => u.user_id));
    const peopleToday = new Set((users ?? []).filter((u: { day: string }) => u.day === today)
      .map((u: { user_id: string }) => u.user_id));
    const msList = list.map((r) => Number(r.ms) || 0).filter((n) => n > 0).sort((a, b) => a - b);

    return json({
      allowed: true,
      report: {
        days,
        people: people.size,
        people_today: peopleToday.size,
        questions: list.length,
        questions_today: list.filter((r) => String(r.at).slice(0, 10) === today).length,
        features: count(list.flatMap((r) => (r.features ?? []) as string[])).slice(0, 15),
        topics: count(list.map((r) => String(r.topic))).slice(0, 12),
        unmet: count(list.map((r) => r.unmet).filter(Boolean) as string[]).slice(0, 15),
        failed: list.filter((r) => r.failed).length,
        median_seconds: msList.length ? Math.round(msList[Math.floor(msList.length / 2)] / 100) / 10 : 0,
        cost: (cost ?? []).map((c: { day: string; requests: number; cost_micros: number }) => ({
          day: c.day, requests: c.requests, dollars: Math.round(c.cost_micros / 10_000) / 100,
        })),
      },
    });
  } catch (e) {
    console.error("insights failed:", String((e as Error)?.message ?? e).slice(0, 200));
    return json({ error: "Insights couldn't load right now." }, 500);
  }
});
