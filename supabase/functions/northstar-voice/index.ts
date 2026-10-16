// Northstar — voice function (ElevenLabs)
// Turns one reply into speech with a premium ElevenLabs voice.
//
//   { action: "voices" }             → { voices: [{ id, name }] }     (the voices people can pick)
//   { action: "speak", text, voice } → audio/mpeg bytes                (voice = one of the ids above)
//
// Signed-in people only. Every reply spoken counts toward the cost guard (the same daily budget
// as chat). The ElevenLabs key stays in Supabase secrets (ELEVENLABS_API_KEY), never in the app.
// The voice list is set in the secret NS_ELEVEN_VOICES as JSON: [{"id":"…","name":"Calm"}, …].

import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

// Fast, natural and the lower price (about $0.05 per 1,000 characters).
const MODEL = Deno.env.get("NS_ELEVEN_MODEL") ?? "eleven_flash_v2_5";
const DOLLARS_PER_1K_CHARS = Number(Deno.env.get("NS_ELEVEN_DOLLARS_PER_1K") ?? 0.05);
const MAX_CHARS = 1500;

const LIMITS = {
  userCostMicros: Number(Deno.env.get("NS_USER_DAILY_DOLLARS") ?? 2) * 1_000_000,
  globalCostMicros: Number(Deno.env.get("NS_GLOBAL_DAILY_DOLLARS") ?? 25) * 1_000_000,
};

type Voice = { id: string; name: string };

/** The voices people can choose (from the NS_ELEVEN_VOICES secret). Only these ids are ever used. */
function voices(): Voice[] {
  try {
    const raw = JSON.parse(Deno.env.get("NS_ELEVEN_VOICES") ?? "[]");
    if (!Array.isArray(raw)) return [];
    return raw
      .map((v) => ({ id: String(v?.id ?? "").trim(), name: String(v?.name ?? "").trim().slice(0, 30) }))
      .filter((v) => /^[A-Za-z0-9]{10,40}$/.test(v.id) && v.name)
      .slice(0, 6);
  } catch {
    return [];
  }
}

function serviceDb() {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
}

/** The signed-in person's id from their token (the gateway already checked it), or null. */
function userIdFrom(auth: string): string | null {
  try {
    const part = auth.replace(/^Bearer\s+/i, "").split(".")[1];
    if (!part) return null;
    const j = JSON.parse(atob(part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "=")));
    return j?.role === "authenticated" && /^[0-9a-f-]{36}$/i.test(j?.sub ?? "") ? j.sub : null;
  } catch {
    return null;
  }
}

async function overLimit(userId: string): Promise<boolean> {
  try {
    const { data, error } = await serviceDb().rpc("usage_today", { p_user: userId });
    if (error) throw error;
    const row = (Array.isArray(data) ? data[0] : data) ?? {};
    return Number(row.global_cost_micros ?? 0) >= LIMITS.globalCostMicros ||
      Number(row.user_cost_micros ?? 0) >= LIMITS.userCostMicros;
  } catch (e) {
    console.error("voice cost check skipped:", String((e as Error)?.message ?? e).slice(0, 160));
    return false;
  }
}

async function recordUsage(userId: string, micros: number) {
  try {
    const { error } = await serviceDb().rpc("add_usage", { p_user: userId, p_cost_micros: Math.min(micros, 1_000_000) });
    if (error) throw error;
  } catch (e) {
    console.error("voice cost record skipped:", String((e as Error)?.message ?? e).slice(0, 160));
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const userId = userIdFrom(req.headers.get("Authorization") ?? "");
  if (!userId) return json({ error: "Sign in first." }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Send JSON." }, 400);
  }

  const list = voices();
  if (body.action === "voices") return json({ voices: list.map((v) => ({ id: v.id, name: v.name })) });

  if (body.action !== "speak") return json({ error: "Unknown action." }, 400);
  const key = (Deno.env.get("ELEVENLABS_API_KEY") ?? "").trim();
  if (!key) return json({ error: "Premium voices aren't set up yet." }, 503);

  const voice = list.find((v) => v.id === body.voice);
  if (!voice) return json({ error: "Unknown voice." }, 400);
  const text = String(body.text ?? "").replace(/\s+/g, " ").trim().slice(0, MAX_CHARS);
  if (!text) return json({ error: "Nothing to say." }, 400);

  if (await overLimit(userId)) return json({ error: "Today's limit is reached. The phone's own voice will read it." }, 429);

  const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voice.id}?output_format=mp3_44100_64`, {
    method: "POST",
    headers: { "xi-api-key": key, "Content-Type": "application/json", Accept: "audio/mpeg" },
    body: JSON.stringify({
      text,
      model_id: MODEL,
      voice_settings: { stability: 0.55, similarity_boost: 0.75, style: 0.15, use_speaker_boost: true },
    }),
  });
  if (!res.ok) {
    console.error("elevenlabs failed:", res.status, (await res.text()).slice(0, 200));
    return json({ error: "The premium voice couldn't speak right now." }, 502);
  }
  const audio = await res.arrayBuffer();
  await recordUsage(userId, Math.round((text.length / 1000) * DOLLARS_PER_1K_CHARS * 1_000_000));
  return new Response(audio, { headers: { ...CORS, "Content-Type": "audio/mpeg", "Cache-Control": "no-store" } });
});
