// Recherche sur tout le site : une palette ouverte depuis n'importe quelle page
// (icône loupe, touche « / » ou Ctrl / ⌘ + K), résultats instantanés, navigation au clavier.
const dialog = document.querySelector('[data-search]');
const input = dialog?.querySelector('[data-search-input]');
const results = dialog?.querySelector('[data-search-results]');
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

let lastFocus = null;
let active = -1;
let controller = null;

function items() { return [...results.querySelectorAll('[role="option"]')]; }

function setActive(i) {
  const list = items();
  if (!list.length) return;
  active = (i + list.length) % list.length;
  list.forEach((el, j) => el.setAttribute('aria-selected', String(j === active)));
  list[active].scrollIntoView({ block: 'nearest' });
  input.setAttribute('aria-activedescendant', list[active].id);
}

export function openSearch() {
  if (!dialog) return;
  lastFocus = document.activeElement;
  dialog.hidden = false;
  document.documentElement.classList.add('search-open');
  window.__lenis?.stop();
  requestAnimationFrame(() => { dialog.classList.add('is-open'); input.focus(); input.select(); });
}

function closeSearch() {
  dialog.classList.remove('is-open');
  document.documentElement.classList.remove('search-open');
  window.__lenis?.start();
  setTimeout(() => { dialog.hidden = true; }, 200);
  lastFocus?.focus?.();
}

async function run(term) {
  controller?.abort();
  if (term.trim().length < 2) {
    results.innerHTML = '<p class="search-hint">Tape au moins deux lettres. Raccourci : <kbd>/</kbd> ou <kbd>Ctrl</kbd> + <kbd>K</kbd> sur toutes les pages.</p>';
    input.setAttribute('aria-expanded', 'false');
    return;
  }
  controller = new AbortController();
  results.setAttribute('aria-busy', 'true');
  try {
    const res = await fetch(`/api/v1/search?q=${encodeURIComponent(term)}`, { signal: controller.signal, headers: { Accept: 'application/json' } });
    const data = await res.json();
    let n = 0;
    const opt = (href, inner) => `<a class="search-item" role="option" id="sr-${n++}" aria-selected="false" href="${href}">${inner}</a>`;
    const parts = [];
    if (data.artists.length) {
      parts.push(`<p class="search-group">Rappeurs</p>${data.artists.slice(0, 4).map((a) => opt(`/rappeur/${a.slug}`,
        `<img src="/img/artists/${a.slug}-400.webp" alt="" width="40" height="50" loading="lazy" class="search-thumb is-portrait"><span>${esc(a.name)}</span>`)).join('')}`);
    }
    if (data.albums.length) {
      parts.push(`<p class="search-group">Albums</p>${data.albums.slice(0, 7).map((a) => opt(`/album/${a.slug}`,
        `<img src="${a.cover}-300.webp${a.v}" alt="" width="40" height="40" loading="lazy" class="search-thumb"><span>${esc(a.title)}<small>${esc(a.artist.name)} · ${a.year}</small></span>`)).join('')}`);
    }
    if (data.users.length) {
      parts.push(`<p class="search-group">Membres</p>${data.users.slice(0, 3).map((u) => opt(`/membre/${u.username}`,
        `<span class="avatar">${esc(u.display_name.slice(0, 1).toUpperCase())}</span><span>${esc(u.display_name)}<small>@${esc(u.username)}</small></span>`)).join('')}`);
    }
    parts.push(opt(`/recherche?q=${encodeURIComponent(term)}`, `<span class="search-all">Tous les résultats pour « ${esc(term)} »</span>`));
    results.innerHTML = parts.length > 1 ? parts.join('')
      : `<p class="search-hint">Aucun résultat pour « ${esc(term)} ». Essaie une autre orthographe ou le nom de l'artiste.</p>${parts.join('')}`;
    input.setAttribute('aria-expanded', 'true');
    active = -1;
    setActive(0);
  } catch (err) {
    if (err.name !== 'AbortError') results.innerHTML = '<p class="search-hint">Recherche indisponible, réessaie.</p>';
  } finally {
    results.removeAttribute('aria-busy');
  }
}

if (dialog) {
  let timer;
  input.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(() => run(input.value), 140); });
  input.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); setActive(active + 1); }
    if (e.key === 'ArrowUp') { e.preventDefault(); setActive(active - 1); }
    if (e.key === 'Enter' && active >= 0 && items()[active]) { e.preventDefault(); items()[active].click(); }
  });
  dialog.addEventListener('click', (e) => { if (e.target.closest('[data-search-close]')) closeSearch(); });
  document.addEventListener('keydown', (e) => {
    const typing = /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName) || document.activeElement?.isContentEditable;
    if (!dialog.hidden && e.key === 'Escape') { e.preventDefault(); closeSearch(); return; }
    if (dialog.hidden && ((e.key === '/' && !typing) || ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k'))) {
      e.preventDefault();
      openSearch();
    }
    // Garde le focus dans la palette (Tab)
    if (!dialog.hidden && e.key === 'Tab') {
      const focusables = [input, ...items()];
      const i = focusables.indexOf(document.activeElement);
      if (e.shiftKey && i <= 0) { e.preventDefault(); focusables.at(-1).focus(); }
      else if (!e.shiftKey && i === focusables.length - 1) { e.preventDefault(); input.focus(); }
    }
  });
  document.addEventListener('click', (e) => {
    const trigger = e.target.closest('[data-search-open]');
    if (trigger && !e.metaKey && !e.ctrlKey) { e.preventDefault(); openSearch(); }
  });
}
