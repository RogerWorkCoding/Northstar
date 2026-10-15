// Northstar — account function
// { action: "delete" } → permanently deletes the signed-in person's account and everything
// Northstar saved for them: memory, subjects, notes, chats, videos (files too) and usage.
// Every table is linked to the account with "on delete cascade", so deleting the account
// removes its rows; stored video files are removed first because files don't cascade.
// Only the person themselves can do this (their own sign-in token); nobody else's data is touched.

import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

/** The signed-in person's id from their token (the gateway already checked it), or null. */
function userIdFrom(auth: string): string | null {
  try {
    const part = auth.replace(/^Bearer\s+/i, "").split(".")[1];
    if (!part) return null;
    const p = JSON.parse(atob(part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "=")));
    return p?.role === "authenticated" && /^[0-9a-f-]{36}$/i.test(p?.sub ?? "") ? p.sub : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const userId = userIdFrom(req.headers.get("Authorization") ?? "");
  if (!userId) return json({ error: "Sign in first." }, 401);

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { /* empty */ }
  if (body.action !== "delete") return json({ error: "Unknown action." }, 400);

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  // 1. Video files (storage doesn't cascade). Page through in case there are many.
  try {
    for (let round = 0; round < 20; round++) {
      const { data: files } = await db.storage.from("videos").list(userId, { limit: 1000 });
      if (!files?.length) break;
      await db.storage.from("videos").remove(files.map((f) => `${userId}/${f.name}`));
      if (files.length < 1000) break;
    }
  } catch (e) {
    console.error("video files cleanup:", String(e).slice(0, 160));
  }

  // 2. The account itself; every table row linked to it is deleted with it.
  const { error } = await db.auth.admin.deleteUser(userId);
  if (error) {
    console.error("delete user failed:", error.message);
    return json({ error: "Couldn't delete the account. Please try again." }, 500);
  }
  return json({ deleted: true });
});
