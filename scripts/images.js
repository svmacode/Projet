// Génère toutes les images du site, compressées en WebP (et JPEG pour les réseaux sociaux).
//  - Pochettes : data/sources/covers/<slug>.jpg|png|webp si présentes, sinon visuel provisoire typographique.
//  - Portraits : data/sources/artists/<slug>.jpg|png|webp si présents, sinon visuel provisoire.
//  - Images de partage (Open Graph), favicons, icônes d'application.
import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';
import { artists, albums, albumSlug } from '../data/catalogue.js';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const pub = (...p) => path.join(root, 'public', ...p);
const src = (...p) => path.join(root, 'data', 'sources', ...p);
for (const d of [pub('img', 'covers'), pub('img', 'artists'), pub('img', 'og')]) fs.mkdirSync(d, { recursive: true });

const xml = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' }[c]));

function hash(s) {
  let h = 2166136261;
  for (const c of s) h = Math.imul(h ^ c.codePointAt(0), 16777619);
  return h >>> 0;
}

// Teintes sobres et profondes : les visuels provisoires ne doivent pas faire « sapin de Noël ».
const PALETTES = [
  ['#1d1d1f', '#f5f5f7'], ['#0b2a4a', '#e8eef6'], ['#3a1f1a', '#f3e7e1'], ['#123b2e', '#e3f0ea'],
  ['#2b2140', '#ece8f5'], ['#4a3b12', '#f6efda'], ['#3d0f1c', '#f6e3e8'], ['#0f3440', '#dff0f4'],
  ['#e8e6e1', '#1d1d1f'], ['#d9dde3', '#14202e'], ['#efe4d6', '#3a2410'], ['#5b1717', '#fbe9e7'],
  ['#1e3b5c', '#f0f5fb'], ['#26332b', '#e9efe9'], ['#40342d', '#f4ede7'], ['#111827', '#cfd8e3'],
];

function wrap(text, maxChars) {
  const words = text.split(/\s+/);
  const lines = [];
  let line = '';
  for (const w of words) {
    if (!line) line = w;
    else if ((line + ' ' + w).length <= maxChars) line += ' ' + w;
    else { lines.push(line); line = w; }
  }
  if (line) lines.push(line);
  return lines;
}

function coverSvg(title, artist, year, slug) {
  const h = hash(slug);
  const [bg, fg] = PALETTES[h % PALETTES.length];
  const variant = (h >>> 8) % 3;
  const size = 1200;
  const len = title.length;
  const fontSize = len <= 6 ? 260 : len <= 12 ? 170 : len <= 20 ? 128 : len <= 32 ? 100 : 80;
  const lines = wrap(title, Math.max(6, Math.floor(1000 / (fontSize * 0.56))));
  const lh = fontSize * 1.02;
  const grain = `<filter id="g"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 0.5  0 0 0 0 0.5  0 0 0 0 0.5  0 0 0 0.10 0"/></filter>`;
  const light = `<radialGradient id="l" cx="${20 + (h % 60)}%" cy="${15 + ((h >>> 4) % 30)}%" r="85%"><stop offset="0" stop-color="#fff" stop-opacity="0.10"/><stop offset="1" stop-color="#000" stop-opacity="0.18"/></radialGradient>`;
  let body;
  if (variant === 0) {
    const y0 = size - 120 - (lines.length - 1) * lh;
    body = `
      <text x="90" y="150" font-size="40" font-weight="500" fill="${fg}" opacity="0.72" letter-spacing="1">${xml(artist.toUpperCase())}</text>
      ${lines.map((l, i) => `<text x="84" y="${y0 + i * lh}" font-size="${fontSize}" font-weight="700" fill="${fg}" letter-spacing="${-fontSize * 0.035}">${xml(l)}</text>`).join('')}
      <text x="${size - 90}" y="150" text-anchor="end" font-size="40" font-weight="500" fill="${fg}" opacity="0.72">${year}</text>`;
  } else if (variant === 1) {
    const small = Math.min(fontSize, 110);
    const sl = wrap(title, Math.floor(1000 / (small * 0.56)));
    body = `
      <text x="${size / 2}" y="${size / 2 + 140}" text-anchor="middle" font-size="520" font-weight="800" fill="${fg}" opacity="0.08" letter-spacing="-30">${String(year).slice(2)}</text>
      ${sl.map((l, i) => `<text x="${size / 2}" y="${size / 2 - ((sl.length - 1) * small) / 2 + i * small * 1.04 + small * 0.35}" text-anchor="middle" font-size="${small}" font-weight="700" fill="${fg}" letter-spacing="${-small * 0.03}">${xml(l)}</text>`).join('')}
      <line x1="500" x2="700" y1="${size - 210}" y2="${size - 210}" stroke="${fg}" stroke-opacity="0.5" stroke-width="2"/>
      <text x="${size / 2}" y="${size - 140}" text-anchor="middle" font-size="40" font-weight="500" fill="${fg}" opacity="0.8">${xml(artist)} · ${year}</text>`;
  } else {
    body = `
      <rect x="90" y="90" width="${size - 180}" height="${size - 180}" fill="none" stroke="${fg}" stroke-opacity="0.35" stroke-width="2"/>
      ${lines.map((l, i) => `<text x="140" y="${250 + i * lh}" font-size="${fontSize}" font-weight="700" fill="${fg}" letter-spacing="${-fontSize * 0.035}">${xml(l)}</text>`).join('')}
      <text x="140" y="${size - 150}" font-size="44" font-weight="600" fill="${fg}">${xml(artist)}</text>
      <text x="${size - 140}" y="${size - 150}" text-anchor="end" font-size="44" font-weight="400" fill="${fg}" opacity="0.7">${year}</text>`;
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" font-family="Inter Display, Inter, Helvetica Neue, Arial, sans-serif">
    <defs>${grain}${light}</defs>
    <rect width="100%" height="100%" fill="${bg}"/>
    <rect width="100%" height="100%" fill="url(#l)"/>
    ${body}
    <rect width="100%" height="100%" filter="url(#g)"/>
  </svg>`;
}

function portraitSvg(name, origin, slug) {
  const h = hash(slug);
  const [bg, fg] = PALETTES[(h >>> 3) % 8];
  const w = 1200;
  const hgt = 1500;
  const initials = name.replace(/[^A-Za-zÀ-ÿ0-9 ]/g, '').split(/\s+/).filter(Boolean).slice(0, 2).map((s) => s[0]).join('').toUpperCase() || name[0];
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${hgt}" viewBox="0 0 ${w} ${hgt}" font-family="Inter Display, Inter, Helvetica Neue, Arial, sans-serif">
    <defs>
      <linearGradient id="v" x1="0" y1="0" x2="0" y2="1"><stop offset="0.45" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.55"/></linearGradient>
      <filter id="g"><feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 0.5  0 0 0 0 0.5  0 0 0 0 0.5  0 0 0 0.12 0"/></filter>
    </defs>
    <rect width="100%" height="100%" fill="${bg}"/>
    <text x="${-60 + (h % 80)}" y="${hgt * 0.78}" font-size="${initials.length > 1 ? 900 : 1300}" font-weight="800" fill="${fg}" opacity="0.13" letter-spacing="-60">${xml(initials)}</text>
    <circle cx="${w * 0.62}" cy="${hgt * 0.36}" r="${260 + (h % 80)}" fill="${fg}" opacity="0.07"/>
    <rect width="100%" height="100%" fill="url(#v)"/>
    <text x="90" y="${hgt - 200}" font-size="110" font-weight="700" fill="#f5f5f7" letter-spacing="-3">${xml(name)}</text>
    <text x="94" y="${hgt - 120}" font-size="46" font-weight="500" fill="#f5f5f7" opacity="0.8">${xml(origin)} · photo à venir</text>
    <rect width="100%" height="100%" filter="url(#g)"/>
  </svg>`;
}

function findSource(dir, slug) {
  for (const ext of ['jpg', 'jpeg', 'png', 'webp', 'avif']) {
    const f = src(dir, `${slug}.${ext}`);
    if (fs.existsSync(f)) return f;
  }
  return null;
}

async function dominant(input) {
  const { dominant: d } = await sharp(input).resize(64, 64).stats();
  return `#${[d.r, d.g, d.b].map((v) => v.toString(16).padStart(2, '0')).join('')}`;
}

async function pool(items, n, fn) {
  let i = 0;
  await Promise.all(Array.from({ length: n }, async () => {
    while (i < items.length) await fn(items[i++]);
  }));
}

let only = false;
let manifest = { covers: {}, artists: {} };
let changed = 0;
const manifestFile = path.join(root, 'data', 'images.json');

// Une image est à refaire si elle n'existe pas, ou si sa source a changé depuis.
function stale(out, source) {
  if (!only || !fs.existsSync(out)) return true;
  if (!source) return false;
  return fs.statSync(source).mtimeMs > fs.statSync(out).mtimeMs;
}
const artistBySlug = Object.fromEntries(artists.map((a) => [a.slug, a]));

async function buildCovers() {
  await pool(albums, 6, async ([artistSlug, title, year]) => {
    const slug = albumSlug(artistSlug, title);
    const real = findSource('covers', slug);
    const out = (w) => pub('img', 'covers', `${slug}-${w}.webp`);
    const wasReal = manifest.covers[slug]?.placeholder === false;
    if (!stale(out(1200), real) && wasReal === Boolean(real) && manifest.covers[slug]) return;
    const input = real ? await sharp(real).rotate().resize(1200, 1200, { fit: 'cover' }).toBuffer()
      : await sharp(Buffer.from(coverSvg(title, artistBySlug[artistSlug].name, year, slug))).png().toBuffer();
    for (const w of [300, 600, 1200]) {
      await sharp(input).resize(w, w).webp({ quality: w === 300 ? 72 : 78, effort: 5 }).toFile(out(w));
    }
    await ogImage(input, title, artistBySlug[artistSlug].name, year, slug);
    manifest.covers[slug] = { color: await dominant(input), placeholder: !real };
    changed++;
  });
}

async function ogImage(coverBuf, title, artist, year, slug) {
  const bg = await sharp(coverBuf).resize(1200, 630, { fit: 'cover' }).blur(60).modulate({ brightness: 0.45 }).toBuffer();
  const art = await sharp(coverBuf).resize(470, 470).toBuffer();
  const lines = wrap(title, 22).slice(0, 3);
  const text = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" font-family="Inter Display, Inter, Helvetica Neue, Arial, sans-serif">
    ${lines.map((l, i) => `<text x="600" y="${250 + i * 70}" font-size="62" font-weight="700" fill="#f5f5f7" letter-spacing="-1.5">${xml(l)}</text>`).join('')}
    <text x="602" y="${250 + lines.length * 70 + 10}" font-size="34" font-weight="500" fill="#f5f5f7" opacity="0.85">${xml(artist)} · ${year}</text>
    <text x="602" y="560" font-size="28" font-weight="600" fill="#f5f5f7" opacity="0.9">MyRapFr</text>
  </svg>`;
  await sharp(bg)
    .composite([{ input: art, left: 80, top: 80 }, { input: Buffer.from(text), left: 0, top: 0 }])
    .jpeg({ quality: 78, mozjpeg: true })
    .toFile(pub('img', 'og', `${slug}.jpg`));
}

async function buildArtists() {
  await pool(artists, 6, async (a) => {
    const real = findSource('artists', a.slug);
    const out = (w) => pub('img', 'artists', `${a.slug}-${w}.webp`);
    const wasReal = manifest.artists[a.slug]?.placeholder === false;
    if (!stale(out(1200), real) && wasReal === Boolean(real) && manifest.artists[a.slug]) return;
    const input = real ? await sharp(real).rotate().resize(1200, 1500, { fit: 'cover', position: 'attention' }).toBuffer()
      : await sharp(Buffer.from(portraitSvg(a.name, a.origin, a.slug))).png().toBuffer();
    for (const w of [400, 800, 1200]) {
      await sharp(input).resize(w, Math.round(w * 1.25)).webp({ quality: 76, effort: 5 }).toFile(out(w));
    }
    manifest.artists[a.slug] = { color: await dominant(input), placeholder: !real };
    changed++;
  });
}

async function buildDefaultOg() {
  const picks = albums.slice(0, 60).filter((_, i) => i % 3 === 0).slice(0, 14);
  const tiles = await Promise.all(picks.map(([a, t]) => sharp(pub('img', 'covers', `${albumSlug(a, t)}-300.webp`)).resize(160, 160).toBuffer()));
  const composites = tiles.map((input, i) => ({ input, left: 24 + (i % 7) * 168, top: i < 7 ? 24 : 446 }));
  const title = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" font-family="Inter Display, Inter, Helvetica Neue, Arial, sans-serif">
    <rect width="1200" height="630" fill="#000" opacity="0.35"/>
    <text x="600" y="318" text-anchor="middle" font-size="96" font-weight="700" fill="#f5f5f7" letter-spacing="-3">MyRapFr</text>
    <text x="600" y="378" text-anchor="middle" font-size="40" font-weight="500" fill="#f5f5f7" opacity="0.85">Le rap français, album par album.</text>
  </svg>`);
  await sharp({ create: { width: 1200, height: 630, channels: 3, background: '#000' } })
    .composite([...composites, { input: title, left: 0, top: 0 }])
    .jpeg({ quality: 80, mozjpeg: true })
    .toFile(pub('img', 'og', 'default.jpg'));
}

// Logo : un disque vu de face, sobre, lisible à 16 px.
const LOGO = (pad = 0) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="${pad ? 0 : 112}" fill="#000"/>
  <circle cx="256" cy="256" r="${170 - pad}" fill="#f5f5f7"/>
  <circle cx="256" cy="256" r="${118 - pad * 0.7}" fill="none" stroke="#000" stroke-opacity="0.18" stroke-width="6"/>
  <circle cx="256" cy="256" r="${54 - pad * 0.3}" fill="#000"/>
  <circle cx="256" cy="256" r="12" fill="#f5f5f7"/>
</svg>`;

// Un fichier .ico peut contenir directement une image PNG.
function pngToIco(png) {
  const header = Buffer.alloc(22);
  header.writeUInt16LE(0, 0); header.writeUInt16LE(1, 2); header.writeUInt16LE(1, 4);
  header.writeUInt8(32, 6); header.writeUInt8(32, 7); header.writeUInt8(0, 8); header.writeUInt8(0, 9);
  header.writeUInt16LE(1, 10); header.writeUInt16LE(32, 12);
  header.writeUInt32LE(png.length, 14); header.writeUInt32LE(22, 18);
  return Buffer.concat([header, png]);
}

async function buildIcons() {
  fs.writeFileSync(pub('favicon.svg'), LOGO());
  const svg = Buffer.from(LOGO());
  fs.writeFileSync(pub('favicon.ico'), pngToIco(await sharp(svg).resize(32, 32).png().toBuffer()));
  await sharp(svg).resize(180, 180).png().toFile(pub('apple-touch-icon.png'));
  await sharp(svg).resize(192, 192).png().toFile(pub('img', 'icon-192.png'));
  await sharp(svg).resize(512, 512).png().toFile(pub('img', 'icon-512.png'));
  await sharp(Buffer.from(LOGO(40))).resize(512, 512).png().toFile(pub('img', 'icon-maskable-512.png'));
}

// Génère les images. `onlyChanged` : ne refait que ce qui manque ou dont la source a changé.
export async function buildImages({ onlyChanged = false, log = console.log } = {}) {
  const t0 = Date.now();
  only = onlyChanged;
  changed = 0;
  manifest = { covers: {}, artists: {} };
  if (only) {
    try { manifest = JSON.parse(fs.readFileSync(manifestFile, 'utf8')); } catch { only = false; }
  }
  await buildCovers();
  await buildArtists();
  if (changed || !fs.existsSync(pub('img', 'og', 'default.jpg'))) await buildDefaultOg();
  if (!only || !fs.existsSync(pub('favicon.ico'))) await buildIcons();
  fs.writeFileSync(manifestFile, JSON.stringify(manifest, null, 1));
  const realCovers = Object.values(manifest.covers).filter((c) => !c.placeholder).length;
  const realArtists = Object.values(manifest.artists).filter((c) => !c.placeholder).length;
  log(`Images : ${realCovers}/${albums.length} vraies pochettes, ${realArtists}/${artists.length} vraies photos (${changed} image(s) refaite(s) en ${((Date.now() - t0) / 1000).toFixed(1)} s).`);
  return { changed, realCovers, realArtists };
}

// Lancé directement : `npm run images` (tout) ou `npm run images -- --only-missing`.
if (import.meta.url === `file://${process.argv[1]}`) {
  await buildImages({ onlyChanged: process.argv.includes('--only-missing') });
}
