// Mesure la vitesse et la qualité des pages principales avec Lighthouse (outil de Google).
// Usage : npm start (dans un autre terminal), puis npm run check:perf [-- http://localhost:8080]
// Lighthouse est téléchargé automatiquement par npx ; il utilise Chrome installé sur ta machine
// (ou celui indiqué par la variable CHROME_PATH).
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const base = (process.argv[2] || 'http://localhost:8080').replace(/\/$/, '');
const pages = ['/', '/albums', '/album/iam-l-ecole-du-micro-d-argent', '/rappeurs', '/connexion'];
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'myrapfr-lh-'));
const npx = process.platform === 'win32' ? 'npx.cmd' : 'npx';
const pct = (s) => (s == null ? ' —' : String(Math.round(s * 100)).padStart(3));

console.log('Page'.padEnd(42), 'Perf  Access  Bonnes  SEO   LCP     CLS    TBT');
let worst = 1;
for (const page of pages) {
  const out = path.join(tmp, 'report.json');
  try {
    execFileSync(npx, [
      '--yes', 'lighthouse', base + page, '--quiet', '--output=json', `--output-path=${out}`,
      '--only-categories=performance,accessibility,best-practices,seo',
      '--chrome-flags=--headless=new --no-sandbox --ignore-certificate-errors',
      ...(process.argv.includes('--mobile') ? [] : ['--preset=desktop']),
    ], { stdio: ['ignore', 'ignore', 'inherit'], shell: process.platform === 'win32' });
  } catch {
    console.error(`Échec de Lighthouse sur ${page}. Le serveur tourne-t-il ? Chrome est-il installé ?`);
    process.exit(2);
  }
  const r = JSON.parse(fs.readFileSync(out, 'utf8'));
  const c = r.categories;
  const a = r.audits;
  worst = Math.min(worst, c.performance.score ?? 0);
  console.log(
    page.padEnd(42),
    pct(c.performance.score), '  ', pct(c.accessibility.score), '   ', pct(c['best-practices'].score), '  ', pct(c.seo.score), ' ',
    a['largest-contentful-paint'].displayValue.padEnd(7), a['cumulative-layout-shift'].displayValue.padEnd(6), a['total-blocking-time'].displayValue,
  );
}
fs.rmSync(tmp, { recursive: true, force: true });
console.log(worst >= 0.9 ? '\nToutes les pages sont rapides (score ≥ 90).' : '\nAu moins une page est sous 90 en performance : regarde le rapport détaillé avec `npx lighthouse <url> --view`.');
