// Northstar — Path Forward (the last onboarding screen, and an empty chat later)
// The person writes a few words ("I'm overwhelmed with work"); this suggests 3 to 5 ways forward.
// They are outcomes, never apps, connectors or menu items. Fast model, one tool call, about a second.
//   { text } → { heard, tone, paths: [{ label, icon, opener }] }   or   { crisis: true }
// Crisis words never get bubbles: the app opens chat, where Northstar's crisis help answers.
// Their words are used for this answer only. Nothing is stored here.

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const MODEL = Deno.env.get("NORTHSTAR_PATHS_MODEL") ?? "claude-haiku-5-5";

// Same crisis words as the chat brain (kept in step with northstar-chat).
const CRISIS = [
  /\bkill(ing)? myself\b/i, /\bend(ing)? my life\b/i, /\bend(ing)? it all\b/i, /\bi (want|wanna|plan) to die\b/i,
  /\bi('?m| am)? (feeling |being )?suicidal\b/i, /\b(thinking about|thoughts of|considering) suicide\b/i,
  /\b(hurt|harm|cutt?)(ing)? myself\b(?!\s+(shaving|cooking|by accident|accidentally|at|on|while|during|playing|a |some ))/i,
  /\bself[- ]harm(ing)?\b/i,
  /\bi (just |really |honestly )?(don'?t|do not) want to (be here|live|wake up|exist)( like this)?\b(?!\s+(in|for|at|with|on|there|near|by|until|through|during)\b)/i,
  /\bbetter off without me\b/i, /\bno reason to live\b/i,
];

// Icons the app knows (SF Symbols). Anything else becomes a sparkle.
const ICONS = new Set([
  "list.number", "calendar", "folder", "magnifyingglass", "moon.zzz", "heart", "bubble.left.and.bubble.right",
  "book", "lightbulb", "target", "figure.walk", "leaf", "house", "dollarsign.circle", "paintbrush",
  "video", "person.2", "checklist", "bell.slash", "map", "fork.knife", "graduationcap", "chart.line.uptrend.xyaxis",
  "sparkle", "sparkles",
]);

const FALLBACK = [
  { label: "Organize priorities", icon: "list.number", opener: "Let's sort what matters from what can wait. What's on your plate right now?" },
  { label: "Plan my week", icon: "calendar", opener: "Let's plan your week together. What's the one thing that matters most to finish?" },
  { label: "Learn something new", icon: "book", opener: "Let's find a good way in. What would you love to learn?" },
  { label: "Talk it through", icon: "bubble.left.and.bubble.right", opener: "I'm here. What's on your mind most today?" },
];

const TOOL = {
  name: "ways_forward",
  description: "Suggest a few ways forward for what the person wrote.",
  input_schema: {
    type: "object",
    properties: {
      heard: { type: "string", description: "Their situation in 2-6 of THEIR OWN words, lower case, no quotes (e.g. overwhelmed with work)." },
      tone: { type: "string", enum: ["practical", "personal", "vague", "direct"] },
      paths: {
        type: "array", minItems: 3, maxItems: 5,
        items: {
          type: "object",
          properties: {
            label: { type: "string", description: "2-3 words, verb first, sentence case, in their language. e.g. Plan my week" },
            icon: { type: "string", enum: [...ICONS] },
            opener: { type: "string", description: "Northstar's first chat line for this path: under 25 words, names the path, ends with exactly one question." },
          },
          required: ["label", "icon", "opener"],
        },
      },
    },
    required: ["heard", "tone", "paths"],
  },
};

const RULES = `You are Northstar, a calm guide that helps people find clarity, direction and progress.
Someone just told you, in a few words, what is on their mind. Offer 3 to 5 different WAYS FORWARD.
Rules:
- Outcomes, never features: no app, connector, product or brand names, never "Use Concierge".
- Each path a different kind of help: plan, do, understand, and when feelings show up, "Talk it through".
- Labels: 2-3 words, verb first, sentence case, in the person's language. "Plan my week", not "Weekly Planning".
- No diagnosis, no assumptions beyond their words. "I'm tired all the time" -> "Look at my sleep", never a medical guess.
- tone: practical (tasks), personal (feelings show up: include Talk it through), vague ("idk", "not sure": include "See what Northstar can do"), direct (one clear request like "find sushi tonight").
- Opener: warm, plain, under 25 words, ends with one question.`;

const recent = new Map<string, number[]>();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const body = await req.json().catch(() => ({}));
  const text = String(body?.text ?? "").replace(/[‘’ʼ]/g, "'").trim().slice(0, 300);
  if (!text) return json({ heard: "", tone: "vague", paths: FALLBACK, fallback: true });
  if (CRISIS.some((re) => re.test(text))) return json({ crisis: true });

  // Light guard, in memory only: 30 an hour per sign-in.
  const who = (req.headers.get("Authorization") ?? "").slice(-24);
  const now = Date.now();
  const times = (recent.get(who) ?? []).filter((t) => now - t < 3_600_000);
  if (times.length >= 30) return json({ heard: "", tone: "practical", paths: FALLBACK, fallback: true });
  times.push(now);
  recent.set(who, times);

  const key = (Deno.env.get("ANTHROPIC_API_KEY") ?? "").match(/sk-ant-[A-Za-z0-9_-]{20,}/)?.[0];
  if (!key) return json({ heard: "", tone: "practical", paths: FALLBACK, fallback: true });

  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      signal: AbortSignal.timeout(6000),
      body: JSON.stringify({
        model: MODEL, max_tokens: 600, system: RULES, tools: [TOOL],
        tool_choice: { type: "tool", name: "ways_forward" },
        messages: [{ role: "user", content: text }],
      }),
    });
    if (!res.ok) throw new Error(`Claude ${res.status}`);
    const data = await res.json();
    const out = (data?.content ?? []).find((b: { type: string }) => b.type === "tool_use")?.input ?? {};
    const seen = new Set<string>();
    const paths = (Array.isArray(out.paths) ? out.paths : [])
      .map((p: Record<string, unknown>) => ({
        label: String(p?.label ?? "").replace(/\s+/g, " ").trim().slice(0, 24),
        icon: ICONS.has(String(p?.icon)) ? String(p.icon) : "sparkle",
        opener: String(p?.opener ?? "").trim().slice(0, 200),
      }))
      .filter((p: { label: string }) => p.label && !seen.has(p.label.toLowerCase()) && seen.add(p.label.toLowerCase()))
      .slice(0, 5);
    if (paths.length < 3) throw new Error("too few paths");
    return json({
      heard: String(out.heard ?? "").replace(/["“”]/g, "").trim().slice(0, 60),
      tone: ["practical", "personal", "vague", "direct"].includes(out.tone) ? out.tone : "practical",
      paths,
    });
  } catch (e) {
    console.error("paths failed:", String((e as Error)?.message ?? e).slice(0, 160));
    return json({ heard: "", tone: "practical", paths: FALLBACK, fallback: true });
  }
});
