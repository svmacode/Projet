// Petites fonctions de confort, communes à toutes les pages.
import { toast } from './ui.js';

const html = document.documentElement;
const icon = (name) => `<svg class="icon" aria-hidden="true" focusable="false"><use href="/img/icons.svg#${name}"></use></svg>`;

// ---------- Thème clair / sombre ----------
export function initTheme() {
  const btn = document.querySelector('[data-theme-toggle]');
  if (!btn) return;
  const current = () => (html.classList.contains('theme-dark') ? 'dark' : 'light');
  const label = () => btn.setAttribute('aria-label', current() === 'dark' ? 'Passer en mode clair' : 'Passer en mode sombre');
  label();
  btn.addEventListener('click', () => {
    const next = current() === 'dark' ? 'light' : 'dark';
    const apply = () => {
      html.classList.remove('theme-dark', 'theme-light');
      html.classList.add(`theme-${next}`);
      html.dataset.theme = next;
      document.querySelector('meta[name="theme-color"]')?.setAttribute('content', next === 'dark' ? '#000000' : '#f5f5f7');
      label();
    };
    // Fondu entre les deux thèmes quand le navigateur le permet.
    if (document.startViewTransition && !html.classList.contains('reduce-motion')) document.startViewTransition(apply);
    else apply();
    try { localStorage.setItem('mrf-theme', next); } catch { /* préférence non retenue */ }
    document.dispatchEvent(new CustomEvent('theme-change', { detail: next }));
  });
}

// ---------- Fin de l'écran de chargement ----------
export function endLoader() {
  if (!html.classList.contains('is-loading')) return;
  const done = () => setTimeout(() => html.classList.remove('is-loading'), 350);
  if (document.readyState === 'complete') done(); else addEventListener('load', done, { once: true });
}

// ---------- Barre de progression de lecture + bouton « retour en haut » ----------
export function initScrollUi(lenis) {
  const bar = document.querySelector('[data-scroll-progress]');
  const top = document.querySelector('[data-to-top]');
  const ring = document.querySelector('[data-to-top-ring]');
  const length = ring ? 2 * Math.PI * 22 : 0;
  if (ring) { ring.style.strokeDasharray = length; ring.style.strokeDashoffset = length; }
  const update = () => {
    const max = document.documentElement.scrollHeight - innerHeight;
    const p = max > 0 ? Math.min(1, scrollY / max) : 0;
    if (bar) bar.style.transform = `scaleX(${p})`;
    if (ring) ring.style.strokeDashoffset = String(length * (1 - p));
    if (top) {
      const show = scrollY > innerHeight * 1.2;
      if (show && top.hidden) { top.hidden = false; requestAnimationFrame(() => top.classList.add('is-visible')); }
      if (!show && !top.hidden) { top.classList.remove('is-visible'); setTimeout(() => { if (!top.classList.contains('is-visible')) top.hidden = true; }, 250); }
    }
  };
  if (lenis) lenis.on('scroll', update); else addEventListener('scroll', update, { passive: true });
  addEventListener('resize', update);
  update();
  top?.addEventListener('click', () => {
    if (lenis) lenis.scrollTo(0, { duration: 1.4 }); else scrollTo({ top: 0, behavior: 'smooth' });
    document.querySelector('#contenu')?.focus?.({ preventScroll: true });
  });
}

// ---------- Œil pour afficher le mot de passe ----------
export function initPasswordToggles() {
  document.querySelectorAll('input[type="password"]').forEach((input) => {
    if (input.dataset.eye) return;
    input.dataset.eye = '1';
    const wrap = document.createElement('span');
    wrap.className = 'pw-wrap';
    input.parentNode.insertBefore(wrap, input);
    wrap.appendChild(input);
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'pw-eye';
    btn.setAttribute('aria-label', 'Afficher le mot de passe');
    btn.setAttribute('aria-pressed', 'false');
    btn.innerHTML = icon('eye');
    btn.addEventListener('click', () => {
      const show = input.type === 'password';
      input.type = show ? 'text' : 'password';
      btn.setAttribute('aria-pressed', String(show));
      btn.setAttribute('aria-label', show ? 'Masquer le mot de passe' : 'Afficher le mot de passe');
      btn.innerHTML = icon(show ? 'eye-off' : 'eye');
      input.focus();
    });
    wrap.appendChild(btn);
    // Par sécurité, le mot de passe est remasqué à l'envoi du formulaire.
    input.form?.addEventListener('submit', () => { if (input.type === 'text') btn.click(); });
  });
}

// ---------- Liens de partage avec suivi UTM ----------
export function withUtm(url, { source = 'myrapfr', medium = 'partage', campaign = 'lien' } = {}) {
  const u = new URL(url, location.origin);
  u.searchParams.set('utm_source', source);
  u.searchParams.set('utm_medium', medium);
  u.searchParams.set('utm_campaign', campaign);
  return u.toString();
}

async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    // Repli pour les navigateurs sans presse-papiers asynchrone.
    const area = document.createElement('textarea');
    area.value = text;
    area.setAttribute('readonly', '');
    area.className = 'visually-hidden';
    document.body.appendChild(area);
    area.select();
    const ok = document.execCommand('copy');
    area.remove();
    return ok;
  }
}

// ---------- Boutons « Copier » et « Partager » ----------
// <button data-copy="#id-du-texte"> copie le texte d'un élément ; data-copy-text copie une valeur ;
// <button data-share data-share-campaign="album"> partage l'adresse de la page avec ses paramètres UTM.
export function initCopy() {
  document.addEventListener('click', async (e) => {
    const copyBtn = e.target.closest('[data-copy], [data-copy-text]');
    const shareBtn = e.target.closest('[data-share]');
    if (!copyBtn && !shareBtn) return;
    e.preventDefault();
    if (shareBtn) {
      const url = withUtm(location.pathname, { campaign: shareBtn.dataset.shareCampaign || 'page' });
      if (navigator.share && matchMedia('(pointer: coarse)').matches) {
        try { await navigator.share({ title: document.title, url }); return; } catch { /* annulé : on copie */ }
      }
      if (await copyText(url)) flash(shareBtn, 'Lien copié');
      return;
    }
    const target = copyBtn.dataset.copy ? document.querySelector(copyBtn.dataset.copy) : null;
    const text = copyBtn.dataset.copyText || target?.innerText?.trim() || '';
    if (text && await copyText(text)) flash(copyBtn, 'Texte copié');
  });
}

function flash(btn, message) {
  btn.classList.add('is-done');
  const original = btn.querySelector('use')?.getAttribute('href');
  btn.querySelector('use')?.setAttribute('href', '/img/icons.svg#check');
  toast(message);
  setTimeout(() => {
    btn.classList.remove('is-done');
    if (original) btn.querySelector('use')?.setAttribute('href', original);
  }, 1600);
}

// ---------- Images : apparition douce une fois chargées (squelette animé en attendant) ----------
export function initImageLoading(root = document) {
  root.querySelectorAll('.tile-media img, .artist-card-media img, .feature-clip img, .album-cover img').forEach((img) => {
    const box = img.parentElement;
    if (img.complete && img.naturalWidth) box.classList.add('is-loaded');
    else img.addEventListener('load', () => box.classList.add('is-loaded'), { once: true });
  });
}

// ---------- Origine des visites (UTM) ----------
// Le serveur compte les campagnes de façon anonyme. Si le visiteur a accepté la mesure d'audience,
// la première campagne est gardée pour l'associer à une éventuelle inscription.
export function captureUtm(consent) {
  const params = new URLSearchParams(location.search);
  if (!params.has('utm_source')) return;
  if (consent?.choice === 'accept') {
    try {
      if (!localStorage.getItem('mrf-utm')) {
        localStorage.setItem('mrf-utm', JSON.stringify({
          source: params.get('utm_source'), medium: params.get('utm_medium'), campaign: params.get('utm_campaign'), at: Date.now(),
        }));
      }
    } catch { /* stockage indisponible */ }
  }
  // Adresse nettoyée : les paramètres ne restent pas dans les favoris ni dans les partages suivants.
  ['utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content'].forEach((k) => params.delete(k));
  history.replaceState(null, '', location.pathname + (params.size ? `?${params}` : '') + location.hash);
}

export function storedUtm() {
  try { return JSON.parse(localStorage.getItem('mrf-utm') || 'null'); } catch { return null; }
}

// ---------- Application installable (PWA) ----------
// Service worker (hors ligne, cache des fichiers) + bouton « Installer l'application » quand le
// navigateur le permet (Chrome, Edge, Android). Sur iPhone : Partager → « Sur l'écran d'accueil ».
export function initPwa() {
  if ('serviceWorker' in navigator && window.isSecureContext) {
    addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch(() => {}));
  }
  let deferred = null;
  const buttons = document.querySelectorAll('[data-install]');
  addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferred = e;
    buttons.forEach((b) => { b.hidden = false; });
  });
  buttons.forEach((b) => b.addEventListener('click', async () => {
    if (!deferred) return;
    deferred.prompt();
    await deferred.userChoice.catch(() => null);
    deferred = null;
    buttons.forEach((x) => { x.hidden = true; });
  }));
  addEventListener('appinstalled', () => toast('MyRapFr est installé sur ton appareil'));
}
