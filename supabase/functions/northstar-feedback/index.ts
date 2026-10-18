// Northstar — feedback function (Settings › Feedback)
// Testers send a short note, an optional 1–5 rating and a kind (general / idea / problem).
// It's anonymous: the sign-in is only checked to stop spam; no user id, name or email is stored.
//   { message, rating?, kind?, app_version? } → { ok: true }

import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const db = () => createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

// A light spam guard per sign-in, kept only in memory (never stored): 5 notes an hour.
const recent = new Map<string, number[]>();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data } = await db().auth.getUser(token);
    const who = data.user?.id;
    if (!who) return json({ error: "Please open Northstar again and try once more." }, 401);

    const now = Date.now();
    const times = (recent.get(who) ?? []).filter((t) => now - t < 3_600_000);
    if (times.length >= 5) return json({ error: "Thanks! That's plenty for this hour." }, 429);

    const body = await req.json().catch(() => ({}));
    const message = String(body?.message ?? "").trim().slice(0, 2000);
    if (!message) return json({ error: "Write a few words first." }, 400);
    const r = Number(body?.rating);
    const rating = Number.isInteger(r) && r >= 1 && r <= 5 ? r : null;
    const kind = ["general", "idea", "problem"].includes(body?.kind) ? body.kind : "general";
    const app_version = String(body?.app_version ?? "").slice(0, 20) || null;

    const { error } = await db().from("feedback").insert({ message, rating, kind, app_version });
    if (error) throw error;
    times.push(now);
    recent.set(who, times);
    return json({ ok: true });
  } catch (e) {
    console.error("feedback failed:", String((e as Error)?.message ?? e).slice(0, 200));
    return json({ error: "Couldn't send right now. Please try again." }, 500);
  }
});
