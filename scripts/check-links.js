// Parcourt tout le site à partir de l'accueil et signale chaque lien interne cassé.
// Usage : npm start (dans un autre terminal), puis npm run check:links [-- http://localhost:8080]
const base = (process.argv[2] || process.env.CHECK_URL || 'http://localhost:8080').replace(/\/$/, '');
if (base.startsWith('https://localhost')) process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const seen = new Map();
const queue = ['/'];
const broken = [];
const referrers = new Map();

const extract = (htmlText) => {
  const out = [];
  for (const m of htmlText.matchAll(/\s(?:href|src)="([^"]+)"/g)) out.push(m[1]);
  for (const m of htmlText.matchAll(/\ssrcset="([^"]+)"/g)) {
    for (const part of m[1].split(',')) out.push(part.trim().split(/\s+/)[0]);
  }
  return out;
};

while (queue.length) {
  const path = queue.shift();
  if (seen.has(path)) continue;
  let res;
  try {
    res = await fetch(base + path, { redirect: 'manual' });
  } catch (err) {
    console.error(`Impossible de joindre ${base} : le serveur est-il lancé ?`);
    process.exit(2);
  }
  seen.set(path, res.status);
  // Pages réservées aux membres : une redirection vers la connexion est attendue.
  const ok = res.status < 400 || (res.status === 303 && (res.headers.get('location') || '').startsWith('/connexion'));
  if (!ok) broken.push({ path, status: res.status, from: referrers.get(path) });
  const type = res.headers.get('content-type') || '';
  if (!type.includes('text/html') || res.status >= 300) continue;
  const body = await res.text();
  for (const raw of extract(body)) {
    if (/^(https?:|mailto:|data:|#)/.test(raw) && !raw.startsWith(base)) continue;
    const url = new URL(raw.replace(base, ''), base + path);
    const next = url.pathname + url.search;
    if (url.pathname.startsWith('/api/')) continue;
    if (!seen.has(next) && !queue.includes(next)) {
      queue.push(next);
      referrers.set(next, path);
    }
  }
}

console.log(`${seen.size} adresses vérifiées.`);
if (broken.length) {
  console.log(`${broken.length} lien(s) cassé(s) :`);
  for (const b of broken) console.log(`  ${b.status}  ${b.path}  (depuis ${b.from || '?'})`);
  process.exit(1);
}
console.log('Aucun lien cassé.');
