// Prépare les images fixes du site : favicons, icônes d'application, image de partage générale.
// Les pochettes et portraits, eux, sont fabriqués à la demande par le serveur (server/imaging.js).
//   npm run images            icônes + image de partage
//   npm run images -- --all   fabrique aussi d'avance toutes les pochettes et tous les portraits
//   npm run images -- --reset efface toutes les images fabriquées (elles seront refaites à la demande)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import sharp from 'sharp';
import { ensureImage } from '../server/imaging.js';
import { loadCatalog } from '../server/catalog.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const pub = (...p) => path.join(root, 'public', ...p);

async function pool(items, n, fn) {
  let i = 0;
  await Promise.all(Array.from({ length: n }, async () => {
    while (i < items.length) await fn(items[i++]);
  }));
}

async function buildDefaultOg() {
  const picks = loadCatalog().albums.filter((a) => a.curated).filter((_, i) => i % 4 === 0).slice(0, 14);
  const tiles = await Promise.all(picks.map(async (a) => sharp(await ensureImage('covers', a.slug, 300)).resize(160, 160).toBuffer()));
  const composites = tiles.map((input, i) => ({ input, left: 24 + (i % 7) * 168, top: i < 7 ? 24 : 446 }));
  const title = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" font-family="Inter Display, Inter, Helvetica Neue, Arial, sans-serif">
    <rect width="1200" height="630" fill="#000" opacity="0.35"/>
    <text x="600" y="318" text-anchor="middle" font-size="96" font-weight="700" fill="#f5f5f7" letter-spacing="-3">MyRapFr</text>
    <text x="600" y="378" text-anchor="middle" font-size="40" font-weight="500" fill="#f5f5f7" opacity="0.85">Le rap français, album par album.</text>
  </svg>`);
  fs.mkdirSync(pub('img', 'og'), { recursive: true });
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

export async function buildImages({ all = false, log = console.log } = {}) {
  const t0 = Date.now();
  await buildIcons();
  await buildDefaultOg();
  if (all) {
    const { albums, artists } = loadCatalog();
    let n = 0;
    await pool(albums, 4, async (a) => { for (const w of [300, 600, 1200]) await ensureImage('covers', a.slug, w); if (++n % 100 === 0) log(`… ${n}/${albums.length} pochettes`); });
    await pool(artists, 4, async (a) => { for (const w of [400, 800, 1200]) await ensureImage('artists', a.slug, w); });
  }
  log(`Images prêtes en ${((Date.now() - t0) / 1000).toFixed(1)} s.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv.includes('--reset')) {
    for (const d of ['covers', 'artists', 'og']) fs.rmSync(pub('img', d), { recursive: true, force: true });
    fs.rmSync(path.join(root, 'data', 'images.json'), { force: true });
    console.log('Images fabriquées effacées : elles seront refaites à la demande.');
  }
  await buildImages({ all: process.argv.includes('--all') });
}
