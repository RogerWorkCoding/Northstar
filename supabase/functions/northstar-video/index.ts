// Northstar — video function (Google Veo)
// Turns one shot card's prompt into a short video clip.
//
// Making a video takes from ~15 seconds to a few minutes, so it's a job:
//   { action: "start", prompt, seconds }  → { job_id, status: "working" }
//   { action: "check", job_id }           → { status: "working" | "done" | "failed", url?, error? }
// When Google finishes, the clip is copied into private storage (videos/<user>/<job>.mp4)
// and the app gets a short-lived link to play it.
//
// Signed-in people only. Limits: a few clips per person per day, and every clip counts
// toward the cost guard (the same daily budget as chat). The Google key stays in
// Supabase secrets (GEMINI_API_KEY), never in the app.

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

const GEMINI = "https://generativelanguage.googleapis.com/v1beta";
// Lite is the cheapest (≈ $0.05/s); set NS_VEO_MODEL to "veo-3.1-fast-generate-preview" for better quality.
const MODEL = Deno.env.get("NS_VEO_MODEL") ?? "veo-3.1-lite-generate-preview";
// Price per second of video, in millionths of a dollar (Veo 3.1 Lite, 720p ≈ $0.05/s; Fast ≈ $0.10/s).
// 720p (default) or 1080p. Google only makes 1080p clips at 8 seconds.
const RESOLUTION = Deno.env.get("NS_VEO_RESOLUTION") === "1080p" ? "1080p" : "720p";
const PRICE_PER_SECOND = Number(Deno.env.get("NS_VEO_DOLLARS_PER_SECOND") ?? 0.05) * 1_000_000;

const LIMITS = {
  userVideos: Number(Deno.env.get("NS_USER_DAILY_VIDEOS") ?? 3),
  userCostMicros: Number(Deno.env.get("NS_USER_DAILY_DOLLARS") ?? 2) * 1_000_000,
  globalCostMicros: Number(Deno.env.get("NS_GLOBAL_DAILY_DOLLARS") ?? 25) * 1_000_000,
};

const str = (v: unknown, max = 2000) => (typeof v === "string" ? v.trim().slice(0, max) : "");

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
    const json = JSON.parse(atob(part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "=")));
    return json?.role === "authenticated" && /^[0-9a-f-]{36}$/i.test(json?.sub ?? "") ? json.sub : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const userId = userIdFrom(req.headers.get("Authorization") ?? "");
  if (!userId) return json({ error: "Sign in first." }, 401);

  const key = (Deno.env.get("GEMINI_API_KEY") ?? "").trim();
  if (!key) return json({ status: "failed", error: "Video isn't set up yet." }, 503);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Send JSON." }, 400);
  }
  const db = serviceDb();

  // ---- Start a clip ---------------------------------------------------------
  if (body.action === "start") {
    const prompt = str(body.prompt, 1200);
    const asked = [4, 6, 8].includes(Number(body.seconds)) ? Number(body.seconds) : 8;
    const seconds = RESOLUTION === "1080p" ? 8 : asked;
    if (!prompt) return json({ error: "Missing prompt." }, 400);
    const cost = Math.round(seconds * PRICE_PER_SECOND);

    // Check the limits and reserve the clip in one step, before asking Google (no races, no free clips).
    const { data: jobId, error: reserveError } = await db.rpc("reserve_video", {
      p_user: userId, p_prompt: prompt, p_seconds: seconds, p_cost_micros: cost,
      p_max_videos: LIMITS.userVideos, p_user_cap_micros: LIMITS.userCostMicros, p_global_cap_micros: LIMITS.globalCostMicros,
    });
    if (reserveError || !jobId) {
      const msg = reserveError?.message ?? "";
      if (msg.includes("limit:videos")) {
        return json({ status: "failed", limit: "user", error: `That's today's ${LIMITS.userVideos} videos. You can make more tomorrow.` }, 429);
      }
      if (msg.includes("limit:budget")) {
        return json({ status: "failed", limit: "budget", error: "Today's limit is reached. Please try again tomorrow." }, 429);
      }
      console.error("reserve_video failed", msg.slice(0, 200));
      return json({ status: "failed", error: "Video isn't ready yet. Please try again later." }, 503);
    }

    let operation = "";
    try {
      const res = await fetch(`${GEMINI}/models/${MODEL}:predictLongRunning`, {
        method: "POST",
        headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
        body: JSON.stringify({
          instances: [{ prompt }],
          parameters: { aspectRatio: "16:9", durationSeconds: seconds, resolution: RESOLUTION },
        }),
      });
      if (res.ok) operation = str((await res.json())?.name, 300);
      else console.error("veo start failed", res.status, (await res.text()).slice(0, 300));
    } catch (e) {
      console.error("veo start error", String(e).slice(0, 200));
    }
    if (!operation) {
      await db.rpc("release_video", { p_job: jobId });
      return json({ status: "failed", error: "Google couldn't start this video. Please try again." }, 502);
    }
    await db.from("video_jobs").update({ operation, updated_at: new Date().toISOString() }).eq("id", jobId);
    return json({ job_id: jobId, status: "working" });
  }

  // ---- Check a clip ---------------------------------------------------------
  if (body.action === "check") {
    const jobId = str(body.job_id, 40);
    if (!/^[0-9a-f-]{36}$/i.test(jobId)) return json({ error: "Missing job_id." }, 400);
    const { data: job } = await db.from("video_jobs").select("*").eq("id", jobId).eq("user_id", userId).maybeSingle();
    if (!job) return json({ error: "Not found." }, 404);

    const signed = async (path: string) =>
      (await db.storage.from("videos").createSignedUrl(path, 60 * 60)).data?.signedUrl ?? null;

    if (job.status === "done" && job.storage_path) {
      return json({ status: "done", url: await signed(job.storage_path) });
    }
    if (job.status === "failed") return json({ status: "failed", error: job.error ?? "The video didn't work." });

    // Still working: ask Google (a just-reserved job may not have its operation yet).
    if (!job.operation) return json({ status: "working" });
    const res = await fetch(`${GEMINI}/${job.operation}`, { headers: { "x-goog-api-key": key } });
    if (!res.ok) {
      console.error("veo check failed", res.status, (await res.text()).slice(0, 200));
      return json({ status: "working" });
    }
    const op = await res.json();
    if (!op?.done) return json({ status: "working" });

    const fail = async (message: string) => {
      await db.from("video_jobs").update({ status: "failed", error: message, updated_at: new Date().toISOString() }).eq("id", jobId);
      return json({ status: "failed", error: message });
    };
    if (op.error) {
      console.error("veo error", JSON.stringify(op.error).slice(0, 300));
      return await fail("Google couldn't make this video. Try changing the prompt a little.");
    }
    const sample = op?.response?.generateVideoResponse?.generatedSamples?.[0];
    const uri = str(sample?.video?.uri, 1000);
    if (!uri) {
      // Usually Google's safety filters (e.g. real people or unsafe content).
      return await fail("Google didn't make this one (it may have hit a safety rule). Try a different prompt.");
    }

    // Copy the clip into our private storage (Google keeps it only 2 days).
    const file = await fetch(uri, { headers: { "x-goog-api-key": key }, redirect: "follow" });
    if (!file.ok) return json({ status: "working" });
    const bytes = new Uint8Array(await file.arrayBuffer());
    const path = `${userId}/${jobId}.mp4`;
    const up = await db.storage.from("videos").upload(path, bytes, { contentType: "video/mp4", upsert: true });
    if (up.error) {
      console.error("video upload failed", up.error.message);
      return json({ status: "working" });
    }
    await db.from("video_jobs").update({ status: "done", storage_path: path, updated_at: new Date().toISOString() }).eq("id", jobId);
    return json({ status: "done", url: await signed(path) });
  }

  return json({ error: "Unknown action." }, 400);
});
