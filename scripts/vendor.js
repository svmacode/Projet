// Copie les bibliothèques front dans public/vendor (aucun CDN : rapide et sans fuite d'IP).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const nm = (p) => path.join(root, 'node_modules', p);
const out = path.join(root, 'public', 'vendor');
fs.mkdirSync(out, { recursive: true });
fs.mkdirSync(path.join(root, 'public', 'fonts'), { recursive: true });

for (const [from, to] of [
  ['gsap/dist/gsap.min.js', 'gsap.min.js'],
  ['gsap/dist/ScrollTrigger.min.js', 'ScrollTrigger.min.js'],
  ['lenis/dist/lenis.min.js', 'lenis.min.js'],
]) fs.copyFileSync(nm(from), path.join(out, to));

fs.copyFileSync(nm('@fontsource-variable/inter/files/inter-latin-wght-normal.woff2'), path.join(root, 'public', 'fonts', 'inter-var.woff2'));

// Three.js réduit aux seules classes utilisées par le site.
await build({
  entryPoints: [path.join(root, 'scripts', 'three-lite.entry.js')],
  bundle: true, minify: true, format: 'esm', legalComments: 'none',
  outfile: path.join(out, 'three-lite.js'), logLevel: 'warning',
});
console.log('Bibliothèques copiées dans public/vendor.');
