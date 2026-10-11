// Images du site, fabriquées à la demande puis gardées sur le disque :
//  - pochettes  /img/covers/<album>-<300|600|1200>.webp
//  - portraits  /img/artists/<artiste>-<400|800|1200>.webp
//  - partage    /img/og/<album>.jpg (1200 × 630)
// Source : la vraie image de data/sources/ si elle existe, sinon un visuel provisoire typographique.
import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';
import { config } from './config.js';
import { loadCatalog } from './catalog.js';

const pub = (...p) => path.join(config.root, 'public', 'img', ...p);
const src = (...p) => path.join(config.root, 'data', 'sources', ...p);
for (const d of [pub('covers'), pub('artists'), pub('og'), src('covers'), src('artists'), src('manuel', 'covers'), src('manuel', 'artists')]) fs.mkdirSync(d, { recursive: true });

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

export function wrap(text, maxChars) {
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

export function coverSvg(title, artist, year, slug) {
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

export function portraitSvg(name, origin, slug) {
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
    <text x="94" y="${hgt - 120}" font-size="46" font-weight="500" fill="#f5f5f7" opacity="0.8">${xml(origin ? `${origin} · ` : '')}photo à venir</text>
    <rect width="100%" height="100%" filter="url(#g)"/>
  </svg>`;
}


// ---------- Sources disponibles (vraies images) ----------
const EXTS = ['jpg', 'jpeg', 'png', 'webp', 'avif'];
let sources = null;
// Une image déposée dans data/sources/manuel/ passe avant tout et n'est jamais remplacée.
let manual = null;
function scanSources() {
  sources = { covers: new Map(), artists: new Map() };
  manual = { covers: new Set(), artists: new Set() };
  for (const kind of ['covers', 'artists']) {
    for (const [folder, isManualDir] of [[src(kind), false], [src('manuel', kind), true]]) {
      for (const f of fs.readdirSync(folder)) {
        const m = f.match(/^(.+)\.(jpe?g|png|webp|avif)$/i);
        if (!m) continue;
        sources[kind].set(m[1], path.join(folder, f));
        if (isManualDir) {
          manual[kind].add(m[1]);
          // Image déposée à la main depuis la dernière fabrication : on refait les versions du site.
          const made = pub(kind, `${m[1]}-1200.webp`);
          if (fs.existsSync(made) && fs.statSync(made).mtimeMs < fs.statSync(path.join(folder, f)).mtimeMs) clearOutputs(kind, m[1]);
        }
      }
    }
  }
}
export function isManual(kind, slug) {
  if (!manual) scanSources();
  return manual[kind].has(slug);
}
export function sourceFor(kind, slug) {
  if (!sources) scanSources();
  return sources[kind].get(slug) || null;
}
export const hasRealImage = (kind, slug) => Boolean(sourceFor(kind, slug));

// Une nouvelle vraie image vient d'arriver : on efface les anciennes versions générées.
export function sourceAdded(kind, slug) {
  if (!sources) scanSources();
  if (manual[kind].has(slug)) return;
  for (const ext of EXTS) {
    const f = src(kind, `${slug}.${ext}`);
    if (fs.existsSync(f)) { sources[kind].set(slug, f); break; }
  }
  clearOutputs(kind, slug);
}

function clearOutputs(kind, slug) {
  const widths = kind === 'covers' ? [300, 600, 1200] : [400, 800, 1200];
  for (const w of widths) fs.rmSync(pub(kind, `${slug}-${w}.webp`), { force: true });
  if (kind === 'covers') fs.rmSync(pub('og', `${slug}.jpg`), { force: true });
  if (manifest) { delete manifest[kind][slug]; scheduleSave(); }
}
export function rescanSources() { sources = null; }

// ---------- Couleur dominante de chaque image (fond pendant le chargement) ----------
const manifestFile = path.join(config.root, 'data', 'images.json');
let manifest = { covers: {}, artists: {} };
try { manifest = { covers: {}, artists: {}, ...JSON.parse(fs.readFileSync(manifestFile, 'utf8')) }; } catch { /* premier lancement */ }
let saveTimer = null;
function scheduleSave() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => fs.writeFile(manifestFile, JSON.stringify(manifest), () => {}), 2000);
}
export const imageColor = (kind, slug) => manifest[kind][slug]?.color || '#1d1d1f';

async function dominant(buffer) {
  const { dominant: d } = await sharp(buffer).resize(64, 64).stats();
  return `#${[d.r, d.g, d.b].map((v) => v.toString(16).padStart(2, '0')).join('')}`;
}

// ---------- Fabrication ----------
async function baseCover(slug) {
  const { albums, bySlug } = loadCatalog();
  const album = albums.find((a) => a.slug === slug);
  if (!album) return null;
  const real = sourceFor('covers', slug);
  if (real) {
    try { return await sharp(real).rotate().resize(1200, 1200, { fit: 'cover' }).toBuffer(); } catch { /* fichier abîmé : visuel provisoire */ }
  }
  return sharp(Buffer.from(coverSvg(album.title, bySlug.get(album.artist)?.name || '', album.year, slug))).png().toBuffer();
}

async function basePortrait(slug) {
  const artist = loadCatalog().bySlug.get(slug);
  if (!artist) return null;
  const real = sourceFor('artists', slug);
  if (real) {
    try { return await sharp(real).rotate().resize(1200, 1500, { fit: 'cover', position: 'attention' }).toBuffer(); } catch { /* visuel provisoire */ }
  }
  return sharp(Buffer.from(portraitSvg(artist.name, artist.origin || '', slug))).png().toBuffer();
}

async function ogImage(coverBuf, slug) {
  const { albums, bySlug } = loadCatalog();
  const album = albums.find((a) => a.slug === slug);
  const artist = bySlug.get(album.artist)?.name || '';
  const bg = await sharp(coverBuf).resize(1200, 630, { fit: 'cover' }).blur(60).modulate({ brightness: 0.45 }).toBuffer();
  const art = await sharp(coverBuf).resize(470, 470).toBuffer();
  const lines = wrap(album.title, 22).slice(0, 3);
  const text = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" font-family="Inter Display, Inter, Helvetica Neue, Arial, sans-serif">
    ${lines.map((l, i) => `<text x="600" y="${250 + i * 70}" font-size="62" font-weight="700" fill="#f5f5f7" letter-spacing="-1.5">${xml(l)}</text>`).join('')}
    <text x="602" y="${250 + lines.length * 70 + 10}" font-size="34" font-weight="500" fill="#f5f5f7" opacity="0.85">${xml(artist)} · ${album.year}</text>
    <text x="602" y="560" font-size="28" font-weight="600" fill="#f5f5f7" opacity="0.9">MyRapFr</text>
  </svg>`;
  return sharp(bg).composite([{ input: art, left: 80, top: 80 }, { input: Buffer.from(text), left: 0, top: 0 }])
    .jpeg({ quality: 78, mozjpeg: true }).toBuffer();
}

const pending = new Map();
// Fabrique (une seule fois, même si plusieurs visiteurs la demandent en même temps) puis renvoie le chemin.
export function ensureImage(kind, slug, width) {
  const file = kind === 'og' ? pub('og', `${slug}.jpg`) : pub(kind, `${slug}-${width}.webp`);
  if (fs.existsSync(file)) return Promise.resolve(file);
  if (pending.has(file)) return pending.get(file);
  const job = (async () => {
    const base = kind === 'artists' ? await basePortrait(slug) : await baseCover(slug);
    if (!base) return null;
    const bucket = kind === 'og' ? 'covers' : kind;
    if (!manifest[bucket][slug]) {
      manifest[bucket][slug] = { color: await dominant(base), placeholder: !sourceFor(bucket, slug) };
      scheduleSave();
    }
    let out;
    if (kind === 'og') out = await ogImage(base, slug);
    else if (kind === 'covers') out = await sharp(base).resize(width, width).webp({ quality: width === 300 ? 72 : 78, effort: 4 }).toBuffer();
    else out = await sharp(base).resize(width, Math.round(width * 1.25)).webp({ quality: 76, effort: 4 }).toBuffer();
    const tmp = `${file}.${process.pid}.tmp`;
    fs.writeFileSync(tmp, out);
    fs.renameSync(tmp, file);
    return file;
  })().finally(() => pending.delete(file));
  pending.set(file, job);
  return job;
}

const WIDTHS = { covers: [300, 600, 1200], artists: [400, 800, 1200] };

// Middleware Express : sert l'image demandée en la fabriquant si besoin.
export function imagesOnDemand() {
  return async (req, res, next) => {
    const m = req.path.match(/^\/img\/(covers|artists)\/([a-z0-9-]+)-(\d+)\.webp$/) || req.path.match(/^\/img\/(og)\/([a-z0-9-]+)\.jpg$/);
    if (!m) return next();
    const [, kind, slug, w] = m;
    const width = Number(w);
    if (kind !== 'og' && !WIDTHS[kind].includes(width)) return next();
    try {
      const file = await ensureImage(kind, slug, width);
      if (!file) return next();
      res.set('Cache-Control', 'public, max-age=2592000');
      res.sendFile(file);
    } catch (err) {
      next(err);
    }
  };
}
