// Northstar — chat function (Engine Q1)
// The app sends the conversation here. This function adds the Northstar
// Constitution and asks Claude. The Claude key stays in Supabase secrets,
// never in the app.

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const MODEL = Deno.env.get("NORTHSTAR_MODEL") ?? "claude-sonnet-5-5";

const CONSTITUTION = `You are Northstar. You help people decide what matters and keep moving toward it.
Follow these promises:
1. Your direction is yours. Help people reach the destinations they choose; never decide what their life should be.
2. Answer first. Simple questions get simple answers. Guide only when it helps.
3. Remember only what people tell you. Never guess their personality, values or mood.
4. Tell the truth kindly. Honest feedback over flattery.
5. Their time matters more than our numbers. No streaks, no guilt, no tricks.
6. Point to people. You are not a therapist, doctor or lawyer. Say so when a real person is needed.
7. Design for everyone. Plain words, short sentences.
8. Earn trust over time.
9. Ask before acting. Anything that changes something important is shown first and confirmed.`;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Turn = { role: "user" | "assistant"; content: string };

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) return json({ error: "Server is missing ANTHROPIC_API_KEY." }, 500);

  let messages: Turn[];
  try {
    const body = await req.json();
    messages = body.messages;
  } catch {
    return json({ error: "Send JSON: { messages: [{ role, content }] }" }, 400);
  }

  // Basic checks: recent turns only, text only, sensible size.
  if (!Array.isArray(messages) || messages.length === 0) {
    return json({ error: "messages must be a non-empty list." }, 400);
  }
  messages = messages
    .filter((m) => (m.role === "user" || m.role === "assistant") && typeof m.content === "string")
    .slice(-20)
    .map((m) => ({ role: m.role, content: m.content.slice(0, 8000) }));
  if (messages.length === 0 || messages[messages.length - 1].role !== "user") {
    return json({ error: "The last message must be from the user." }, 400);
  }

  const res = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "x-api-key": key,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({ model: MODEL, max_tokens: 1024, system: CONSTITUTION, messages }),
  });

  if (!res.ok) {
    console.error("Claude error", res.status, await res.text());
    return json({ error: "Northstar couldn't reach Claude. Try again." }, 502);
  }

  const data = await res.json();
  const reply = (data.content ?? [])
    .filter((b: { type: string }) => b.type === "text")
    .map((b: { text: string }) => b.text)
    .join("\n")
    .trim();

  return json({ reply });
});
