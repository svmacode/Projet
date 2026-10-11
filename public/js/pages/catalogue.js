// Catalogue : filtres instantanés et chargement continu des pages suivantes.
// Sans JavaScript, la même page fonctionne avec des liens et un formulaire classiques.
import { motion } from '../app.js';

const root = document.querySelector('[data-catalogue]');
const grid = root.querySelector('[data-grid]');
const form = root.querySelector('[data-filters]');
const input = root.querySelector('[data-filter-q]');
const sort = root.querySelector('[data-sort]');
const count = root.querySelector('[data-count]');

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// Même balisage que la vignette rendue par le serveur (server/views/components.js).
function tileHtml(a) {
  const src = (w) => `${a.cover}-${w}.webp${a.v}`;
  return `<a class="tile" href="/album/${a.slug}" data-color="${esc(a.color)}" data-gl data-title="${esc(a.title)}" data-artist="${esc(a.artist.name)}" data-year="${a.year}" data-slug="${a.slug}">
    <span class="tile-media"><img class="cover" src="${src(600)}" srcset="${src(300)} 300w, ${src(600)} 600w, ${src(1200)} 1200w"
      sizes="(min-width: 1068px) 220px, 45vw" width="600" height="600" alt="Pochette de ${esc(a.title)}, ${esc(a.artist.name)}" loading="lazy" decoding="async" data-vt="cover-${a.slug}"></span>
    <span class="tile-title">${esc(a.title)}</span>
    <span class="tile-meta">${esc(a.artist.name)} · ${a.year}${a.kind === 'ep' ? ' · EP' : ''}</span>
  </a>`;
}

const params = new URLSearchParams(location.search);
const state = {
  q: params.get('q') || '',
  decennie: params.get('decennie') || '',
  type: params.get('type') || '',
  tri: params.get('tri') || 'year',
  page: Number(grid.dataset.page) || 1,
  pages: Number(grid.dataset.pages) || 1,
};

function query(page) {
  const p = new URLSearchParams();
  if (state.q) p.set('q', state.q);
  if (state.decennie) p.set('decennie', state.decennie);
  if (state.type) p.set('type', state.type);
  if (state.tri !== 'year') p.set('tri', state.tri);
  if (page > 1) p.set('page', page);
  return p;
}

let loading = null;
async function load(page, { append = false } = {}) {
  const controller = new AbortController();
  loading?.abort();
  loading = controller;
  const res = await fetch(`/api/v1/albums?${query(page)}`, { headers: { Accept: 'application/json' }, signal: controller.signal });
  const data = await res.json();
  loading = null;
  state.page = data.page;
  state.pages = data.pages;
  const markup = data.albums.map(tileHtml).join('');
  if (append) grid.insertAdjacentHTML('beforeend', markup);
  else grid.innerHTML = markup;
  grid.querySelectorAll('.tile:not([data-colored])').forEach((t) => {
    t.dataset.colored = '';
    t.querySelector('.tile-media').style.backgroundColor = t.dataset.color;
  });
  count.textContent = data.total
    ? `${data.total.toLocaleString('fr-FR')} résultat${data.total > 1 ? 's' : ''}`
    : 'Aucun album ne correspond. Essaie un autre mot.';
  updateChips();
  updatePager();
  if (motion) window.ScrollTrigger.refresh();
}

function updateChips() {
  root.querySelectorAll('[data-chip]').forEach((chip) => {
    const u = new URL(chip.href);
    const same = (k, v) => (u.searchParams.get(k) || '') === v;
    const group = chip.closest('[aria-label]').getAttribute('aria-label');
    const pressed = group === 'Décennie' ? same('decennie', state.decennie) : same('type', state.type);
    chip.setAttribute('aria-current', String(pressed));
  });
}

// Le bloc de pagination devient un simple déclencheur de chargement continu.
const pager = root.querySelector('[data-pager]');
const sentinel = document.createElement('div');
sentinel.className = 'pager-sentinel';
grid.after(sentinel);
pager?.remove();

function updatePager() {
  sentinel.hidden = state.page >= state.pages;
}

const io = new IntersectionObserver((entries) => {
  if (entries[0].isIntersecting && !loading && state.page < state.pages) {
    load(state.page + 1, { append: true }).catch(() => {});
  }
}, { rootMargin: '800px 0px' });
io.observe(sentinel);
updatePager();

function refresh() {
  history.replaceState(null, '', `${location.pathname}${query(1).size ? `?${query(1)}` : ''}`);
  load(1).catch((err) => { if (err.name !== 'AbortError') count.textContent = 'Chargement impossible, réessaie.'; });
}

let timer;
input.addEventListener('input', () => {
  clearTimeout(timer);
  timer = setTimeout(() => { state.q = input.value.trim(); refresh(); }, 220);
});
sort.addEventListener('change', () => { state.tri = sort.value; refresh(); });
form.addEventListener('submit', (e) => { e.preventDefault(); state.q = input.value.trim(); refresh(); });
root.querySelectorAll('[data-chip]').forEach((chip) => chip.addEventListener('click', (e) => {
  e.preventDefault();
  const u = new URL(chip.href);
  const group = chip.closest('[aria-label]').getAttribute('aria-label');
  if (group === 'Décennie') state.decennie = u.searchParams.get('decennie') || '';
  else state.type = u.searchParams.get('type') || '';
  refresh();
}));

// Pendant la mise à jour du catalogue : avancement en direct et nouveaux albums ajoutés à l'affichage.
const sync = root.querySelector('[data-sync]');
if (sync && !sync.hidden) {
  const text = sync.querySelector('[data-sync-text]');
  let lastCount = 0;
  const poll = async () => {
    try {
      const s = await (await fetch('/api/v1/catalogue/etat', { headers: { Accept: 'application/json' } })).json();
      if (!s.running) {
        sync.hidden = true;
        refresh();
        return;
      }
      text.textContent = s.phase === 'images'
        ? 'Récupération des dernières pochettes…'
        : `Récupération des discographies : ${s.done} / ${s.total || '…'} artistes, ${s.albums.toLocaleString('fr-FR')} projets. Les albums apparaissent au fur et à mesure.`;
      // Recharge la première page quand de nouveaux albums sont arrivés, si on n'a pas encore fait défiler.
      if (s.albums !== lastCount && state.page === 1 && scrollY < 400) refresh();
      lastCount = s.albums;
    } catch { /* nouvel essai au prochain tour */ }
    setTimeout(poll, 6000);
  };
  setTimeout(poll, 4000);
}
