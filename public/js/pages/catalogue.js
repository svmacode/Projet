// Catalogue : filtre instantané par texte et par décennie, tri sans rechargement.
import { motion } from '../app.js';

const root = document.querySelector('[data-catalogue]');
const grid = root.querySelector('[data-grid]');
const input = root.querySelector('[data-filter-q]');
const sort = root.querySelector('[data-sort]');
const count = root.querySelector('[data-count]');
const empty = root.querySelector('[data-empty]');
const chips = root.querySelectorAll('[data-decade]');
const tiles = [...grid.querySelectorAll('.tile')];
const original = new Map(tiles.map((t, i) => [t, i]));

const params = new URLSearchParams(location.search);
let decade = Number(params.get('decennie')) || 0;
input.value = params.get('q') || '';
if (params.get('tri')) sort.value = params.get('tri');

const norm = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

// Note moyenne et nombre de notes, chargés une fois pour le tri.
let stats = null;
async function loadStats() {
  if (stats) return stats;
  try {
    const res = await fetch('/api/v1/albums', { headers: { Accept: 'application/json' } });
    const { albums } = await res.json();
    stats = new Map(albums.map((a) => [a.slug, a]));
  } catch { stats = new Map(); }
  return stats;
}

async function apply() {
  const q = norm(input.value.trim());
  let shown = 0;
  for (const t of tiles) {
    const year = Number(t.dataset.year);
    const ok = (!q || norm(`${t.dataset.title} ${t.dataset.artist}`).includes(q))
      && (!decade || (year >= decade && year < decade + 10));
    t.hidden = !ok;
    if (ok) shown++;
  }
  chips.forEach((c) => c.setAttribute('aria-pressed', String(Number(c.dataset.decade || 0) === decade)));
  count.textContent = `${shown} album${shown > 1 ? 's' : ''}`;
  empty.hidden = shown > 0;

  const mode = sort.value;
  let ordered = [...tiles];
  if (mode === 'recent') ordered.sort((a, b) => b.dataset.year - a.dataset.year || original.get(a) - original.get(b));
  else if (mode === 'title') ordered.sort((a, b) => a.dataset.title.localeCompare(b.dataset.title, 'fr'));
  else if (mode === 'rating' || mode === 'popular') {
    const s = await loadStats();
    const key = (t) => s.get(t.dataset.slug) || {};
    ordered.sort(mode === 'rating'
      ? (a, b) => (key(b).avg ?? -1) - (key(a).avg ?? -1) || (key(b).ratings || 0) - (key(a).ratings || 0)
      : (a, b) => (key(b).ratings || 0) - (key(a).ratings || 0) || b.dataset.year - a.dataset.year);
  } else ordered.sort((a, b) => original.get(a) - original.get(b));
  grid.append(...ordered);

  if (motion) {
    window.gsap.set(tiles, { opacity: 1, y: 0 });
    window.ScrollTrigger.refresh();
  }

  // L'adresse reflète les filtres : on peut la partager.
  const next = new URLSearchParams();
  if (input.value.trim()) next.set('q', input.value.trim());
  if (decade) next.set('decennie', decade);
  if (mode !== 'year') next.set('tri', mode);
  history.replaceState(null, '', `${location.pathname}${next.size ? `?${next}` : ''}`);
}

let timer;
input.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(apply, 120); });
sort.addEventListener('change', apply);
chips.forEach((c) => c.addEventListener('click', () => { decade = Number(c.dataset.decade || 0); apply(); }));
root.querySelector('[data-filters]').addEventListener('submit', (e) => { e.preventDefault(); apply(); });

if (input.value || decade || sort.value !== 'year') apply();
