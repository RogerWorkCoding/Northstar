// Northstar — nearby events ("Happening near you" on the Concierge screen)
// The app sends its CITY's center point (never the person's exact spot). This asks Ticketmaster
// and SeatGeek (whichever has a key) for upcoming events within 30 miles, merges them (one card per
// show), and returns up to 10 with a real event image, soonest first.
// Secrets: TICKETMASTER_KEY (developer.ticketmaster.com) and/or SEATGEEK_CLIENT_ID (seatgeek.com/account/develop).
// Results are kept for 1 hour per city so it stays fast and well inside the free limits.

// Trimmed: a pasted key often brings a stray space or line break with it.
const TM_KEY = (Deno.env.get("TICKETMASTER_KEY") ?? "").trim();
const SG_ID = (Deno.env.get("SEATGEEK_CLIENT_ID") ?? "").replace(/^client id:\s*/i, "").trim();
// What each service last answered (a status, never a key), returned as `check` for troubleshooting.
const check: Record<string, string> = {};
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

type Event = {
  name: string; date: string; time: string | null; venue: string; city: string;
  image: string; url: string; miles: number | null; source: "Ticketmaster" | "SeatGeek";
};
const cache = new Map<string, { at: number; events: Event[] }>();

function milesBetween(a: [number, number], b: [number, number]) {
  const r = (d: number) => d * Math.PI / 180, R = 3958.8;
  const dLat = r(b[0] - a[0]), dLon = r(b[1] - a[1]);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(r(a[0])) * Math.cos(r(b[0])) * Math.sin(dLon / 2) ** 2;
  return Math.round(2 * R * Math.asin(Math.sqrt(h)) * 10) / 10;
}

async function ticketmaster(lat: number, lng: number): Promise<Event[]> {
  if (!TM_KEY) return [];
  const url = new URL("https://app.ticketmaster.com/discovery/v2/events.json");
  url.search = new URLSearchParams({
    apikey: TM_KEY, latlong: `${lat},${lng}`, radius: "30", unit: "miles", sort: "date,asc",
    size: "40", startDateTime: new Date().toISOString().replace(/\.\d{3}Z$/, "Z"), locale: "*",
  }).toString();
  const res = await fetch(url);
  check.ticketmaster = String(res.status);
  if (!res.ok) return [];
  const raw = ((await res.json())?._embedded?.events ?? []) as Array<Record<string, any>>;
  const out: Event[] = [];
  for (const e of raw) {
    const img = ((e.images ?? []) as Array<{ url: string; ratio?: string; width?: number }>)
      .filter((i) => i.ratio === "16_9" && /^https:/.test(i.url))
      .sort((a, b) => Math.abs((a.width ?? 0) - 640) - Math.abs((b.width ?? 0) - 640))[0];
    const venue = e._embedded?.venues?.[0];
    if (!img || !/^https:/.test(String(e.url ?? "")) || !e.dates?.start?.localDate) continue;
    out.push({
      name: String(e.name ?? "").slice(0, 100),
      date: e.dates.start.localDate,
      time: e.dates.start.localTime ? String(e.dates.start.localTime).slice(0, 5) : null,
      venue: String(venue?.name ?? "").slice(0, 80),
      city: String(venue?.city?.name ?? "").slice(0, 40),
      image: img.url, url: String(e.url),
      miles: typeof e.distance === "number" ? Math.round(e.distance * 10) / 10 : null,
      source: "Ticketmaster",
    });
  }
  return out;
}

// Northstar's own event cards (night sky, one per kind of event), served from the public repo.
const CARDS = "https://cdn.jsdelivr.net/gh/RogerWorkCoding/Northstar@8cc9b4d8747c7e1837b1320b1f9585d8f2a5b844/assets/events/";
function cardFor(e: Record<string, any>): string {
  const kinds = [String(e.type ?? ""), ...((e.taxonomies ?? []) as Array<Record<string, any>>).map((t) => String(t?.name ?? ""))]
    .join(" ").toLowerCase();
  const kind = /comedy/.test(kinds) ? "comedy"
    : /theater|theatre|broadway|musical|opera|ballet|dance|classical/.test(kinds) ? "theater"
    : /concert|music|festival|band/.test(kinds) ? "music"
    : /sport|nba|nfl|mlb|nhl|mls|ncaa|wnba|soccer|football|baseball|basketball|hockey|tennis|golf|racing|fight|boxing|mma|wrestling|rodeo/.test(kinds) ? "sports"
    : "events";
  return `${CARDS}${kind}.jpg`;
}

async function seatgeek(lat: number, lng: number): Promise<Event[]> {
  if (!SG_ID) return [];
  const url = new URL("https://api.seatgeek.com/2/events");
  url.search = new URLSearchParams({
    client_id: SG_ID, lat: String(lat), lon: String(lng), range: "30mi", per_page: "40",
    sort: "datetime_local.asc", "datetime_utc.gte": new Date().toISOString().slice(0, 19),
  }).toString();
  const res = await fetch(url);
  check.seatgeek = String(res.status);
  if (!res.ok) {
    check.seatgeek += " " + (await res.text()).slice(0, 120).replace(SG_ID, "…");
    return [];
  }
  const raw = ((await res.json())?.events ?? []) as Array<Record<string, any>>;
  check.seatgeek += ` · ${raw.length} found`;
  const out: Event[] = [];
  const skipped = { link: 0, date: 0 };
  for (const e of raw) {
    // Never SeatGeek's own images: SeatGeek told Northstar (Oct 19, 2026) that event and performer
    // images are licensed for SeatGeek's own use only, even for affiliates. Always Northstar's
    // night-sky card for that kind of event.
    const img = cardFor(e);
    const local = String(e.datetime_local ?? "");
    if (!/^https:/.test(String(e.url ?? ""))) { skipped.link++; continue; }
    if (!/^\d{4}-\d{2}-\d{2}/.test(local)) { skipped.date++; continue; }
    const loc = e.venue?.location;
    out.push({
      name: String(e.title ?? e.short_title ?? "").slice(0, 100),
      date: local.slice(0, 10),
      time: e.time_tbd ? null : local.slice(11, 16) || null,
      venue: String(e.venue?.name ?? "").slice(0, 80),
      city: String(e.venue?.city ?? "").slice(0, 40),
      image: img, url: String(e.url),
      miles: loc && typeof loc.lat === "number" ? milesBetween([lat, lng], [loc.lat, loc.lon]) : null,
      source: "SeatGeek",
    });
  }
  if (out.length < raw.length) check.seatgeek += ` · skipped ${JSON.stringify(skipped)}`;
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (!TM_KEY && !SG_ID) return json({ events: [], note: "not set up" });

  let body: { lat?: unknown; lng?: unknown } = {};
  try { body = await req.json(); } catch { /* empty */ }
  const lat = Number(body.lat), lng = Number(body.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
    return json({ error: "Send { lat, lng } for the city center." }, 400);
  }
  // Rounded to about a mile: a city, not a person.
  const la = Math.round(lat * 100) / 100, ln = Math.round(lng * 100) / 100;
  const key = `${la},${ln}`;
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < 60 * 60 * 1000) return json({ events: hit.events, check: { ...check, cached: "yes" } });

  const [tm, sg] = await Promise.all([
    ticketmaster(la, ln).catch(() => [] as Event[]),
    seatgeek(la, ln).catch((e) => { check.seatgeek = "error " + String(e).slice(0, 80); return [] as Event[]; }),
  ]);
  // One card per show. Names are compared loosely (the start of the name, letters only), because the two
  // companies spell the same show differently ("Jim Henson's Labyrinth: In Concert 40th…" vs "Jim Hensons
  // Labyrinth - In Concert"). Ticketmaster goes first, so a show listed by both keeps its real image.
  const short = (n: string) => n.toLowerCase().replace(/['’]/g, "").replace(/[^a-z0-9]/g, "").slice(0, 14);
  // Same show if one name starts the other ("Sarah Jarosz" and "Sarah Jarosz: 10 Years of Undercurrent").
  const seen: string[] = [];
  const same = (a: string, b: string) => Math.min(a.length, b.length) >= 6 && (a.startsWith(b) || b.startsWith(a));
  const kept: Event[] = [];
  for (const e of [...tm, ...sg]) {
    const k = short(e.name);
    if (!e.name || !k || seen.some((s) => same(s, k))) continue;
    seen.push(k);
    kept.push(e);
  }
  // Closest first (test round 1: Petaluma showed mostly Napa, Napa showed Berkeley): events within about
  // 12 miles come first, soonest first; farther ones fill the rest, also soonest first. Each card shows its town.
  const NEAR = 12;
  const byDate = (a: Event, b: Event) => `${a.date}${a.time ?? ""}`.localeCompare(`${b.date}${b.time ?? ""}`);
  const isNear = (e: Event) => typeof e.miles === "number" && e.miles <= NEAR;
  const merged = [...kept.filter(isNear).sort(byDate), ...kept.filter((e) => !isNear(e)).sort(byDate)].slice(0, 10);
  // Only keep results worth keeping, so a hiccup doesn't hide events for an hour.
  if (merged.length) cache.set(key, { at: Date.now(), events: merged });
  return json({ events: merged, check });
});
