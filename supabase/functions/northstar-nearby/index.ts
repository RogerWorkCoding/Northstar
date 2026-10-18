// Northstar — nearby events ("Happening near you" on the Concierge screen)
// The app sends its CITY's center point (never the person's exact spot). This asks Ticketmaster's
// Discovery API for upcoming events within 30 miles and returns up to 10 with a real event image.
// Needs the secret TICKETMASTER_KEY (the Consumer Key from developer.ticketmaster.com).
// Results are kept for 1 hour per city so it stays fast and well inside the free limit.

const KEY = Deno.env.get("TICKETMASTER_KEY") ?? "";
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

type Event = { name: string; date: string; time: string | null; venue: string; city: string; image: string; url: string; miles: number | null };
const cache = new Map<string, { at: number; events: Event[] }>();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (!KEY) return json({ events: [], note: "not set up" });

  let body: { lat?: unknown; lng?: unknown } = {};
  try { body = await req.json(); } catch { /* empty */ }
  const lat = Number(body.lat), lng = Number(body.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
    return json({ error: "Send { lat, lng } for the city center." }, 400);
  }
  // Rounded to about a mile: a city, not a person.
  const key = `${lat.toFixed(2)},${lng.toFixed(2)}`;
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < 60 * 60 * 1000) return json({ events: hit.events });

  const start = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const url = new URL("https://app.ticketmaster.com/discovery/v2/events.json");
  url.search = new URLSearchParams({
    apikey: KEY, latlong: key, radius: "30", unit: "miles", sort: "date,asc",
    size: "40", startDateTime: start, locale: "*",
  }).toString();

  try {
    const res = await fetch(url);
    if (!res.ok) return json({ events: [], note: `ticketmaster ${res.status}` });
    const data = await res.json();
    const raw = (data?._embedded?.events ?? []) as Array<Record<string, any>>;
    const seen = new Set<string>();
    const events: Event[] = [];
    for (const e of raw) {
      const name = String(e.name ?? "").slice(0, 100);
      if (!name || seen.has(name.toLowerCase())) continue;   // one card per show, not every night
      const images = (e.images ?? []) as Array<{ url: string; ratio?: string; width?: number }>;
      const img = images.filter((i) => i.ratio === "16_9" && /^https:/.test(i.url))
        .sort((a, b) => Math.abs((a.width ?? 0) - 640) - Math.abs((b.width ?? 0) - 640))[0];
      const venue = e._embedded?.venues?.[0];
      const link = String(e.url ?? "");
      if (!img || !/^https:/.test(link) || !e.dates?.start?.localDate) continue;
      seen.add(name.toLowerCase());
      events.push({
        name,
        date: e.dates.start.localDate,
        time: e.dates.start.localTime ? String(e.dates.start.localTime).slice(0, 5) : null,
        venue: String(venue?.name ?? "").slice(0, 80),
        city: String(venue?.city?.name ?? "").slice(0, 40),
        image: img.url,
        url: link,
        miles: typeof e.distance === "number" ? Math.round(e.distance * 10) / 10 : null,
      });
      if (events.length === 10) break;
    }
    cache.set(key, { at: Date.now(), events });
    return json({ events });
  } catch {
    return json({ events: [], note: "couldn't reach ticketmaster" });
  }
});
