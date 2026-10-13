// Northstar — search function (Notes + Search)
// The app sends a word or a sentence. This function turns it into "meaning"
// (a small built-in model, gte-small, no extra key) and searches the person's
// notes by words and meaning together. Row-level security applies: the search
// runs as the signed-in person, so it only ever sees their own notes.
//
// Request:  { query: string, limit?: number }
// Response: { results: [{ id, text, context, subject, created_at, score }] }

import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// Built into Supabase Edge Functions. Created on first use, so search still
// works by words if the meaning model is unavailable.
// deno-lint-ignore no-explicit-any
let meaningSession: any;
// deno-lint-ignore no-explicit-any
const meaning = () => (meaningSession ??= new (globalThis as any).Supabase.ai.Session("gte-small"));

// How close in meaning a note must be (0 = same, 2 = opposite). Tuned on real notes.
const MAX_DISTANCE = 0.2;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return json({ error: "Sign in first." }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Send JSON: { query }" }, 400);
  }
  const query = typeof body.query === "string" ? body.query.trim().slice(0, 200) : "";
  if (!query) return json({ results: [] });
  const limit = Math.min(Math.max(Number(body.limit) || 20, 1), 50);

  // The person's own session, so row-level security decides what they can see.
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false },
  });

  let embedding: number[] | null = null;
  try {
    embedding = Array.from(await meaning().run(query, { mean_pool: true, normalize: true }) as number[]);
  } catch (e) {
    console.error("meaning failed, words only:", String(e).slice(0, 200));
  }

  const { data, error } = await db.rpc("search_notes", {
    query_text: query,
    query_embedding: embedding ? JSON.stringify(embedding) : null,
    match_count: limit,
    max_distance: MAX_DISTANCE,
  });
  if (error) {
    console.error("search failed:", error.message);
    return json({ error: "Search didn't work. Try again." }, 500);
  }
  return json({ results: data ?? [] });
});
