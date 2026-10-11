// Cadence des requêtes vers les sources publiques, partagée par tout le serveur :
// on va aussi vite que chaque service l'autorise, sans pause inutile.
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Deezer : 50 requêtes par 5 s au maximum. Fenêtre glissante avec un peu de marge.
const WINDOW = 5000;
const MAX_IN_WINDOW = 45;
const stamps = [];
async function deezerSlot() {
  for (;;) {
    const now = Date.now();
    while (stamps.length && now - stamps[0] > WINDOW) stamps.shift();
    if (stamps.length < MAX_IN_WINDOW) { stamps.push(now); return; }
    await sleep(WINDOW - (now - stamps[0]) + 20);
  }
}

// Les autres : un écart minimal entre deux requêtes vers le même service.
const GAPS = {
  'itunes.apple.com': 350,
  'musicbrainz.org': 1100, // une requête par seconde maximum
  'www.theaudiodb.com': 600,
  'fr.wikipedia.org': 40, // Wikimedia tolère bien plus (200 requêtes / s)
};
const next = new Map();
async function spaced(host, gap) {
  const now = Date.now();
  const at = Math.max(now, next.get(host) || 0);
  next.set(host, at + gap);
  if (at > now) await sleep(at - now);
}

// À appeler juste avant chaque requête vers une API.
export async function pace(url) {
  const host = new URL(url).hostname;
  if (host === 'api.deezer.com') return deezerSlot();
  if (GAPS[host]) return spaced(host, GAPS[host]);
}
