// Socle commun à toutes les pages : défilement doux, révélations, navigation, cookies.
import { loginRedirect } from './lib/api.js';
import { toast } from './lib/ui.js';

const html = document.documentElement;
const { gsap, ScrollTrigger, Lenis } = window;
export const motion = Boolean(html.classList.contains('has-motion') && gsap && ScrollTrigger);
if (!motion) {
  html.classList.remove('has-motion');
  html.classList.add('reduce-motion');
}
window.__mrfReady = true;

export let lenis = null;

if (motion) {
  gsap.registerPlugin(ScrollTrigger);
  // Défilement doux avec inertie, synchronisé avec GSAP.
  if (Lenis) {
    lenis = new Lenis({ lerp: 0.09, smoothWheel: true, anchors: { offset: -48 } });
    lenis.on('scroll', ScrollTrigger.update);
    gsap.ticker.add((time) => lenis.raf(time * 1000));
    gsap.ticker.lagSmoothing(0);
  }
  window.__lenis = lenis;
}

// ---------- Navigation ----------
const nav = document.querySelector('[data-nav]');
const burger = document.querySelector('[data-burger]');
burger?.addEventListener('click', () => {
  const open = !nav.classList.contains('is-open');
  nav.classList.toggle('is-open', open);
  burger.setAttribute('aria-expanded', String(open));
  burger.setAttribute('aria-label', open ? 'Fermer le menu' : 'Ouvrir le menu');
  if (open) lenis?.stop(); else lenis?.start();
});
nav?.querySelectorAll('.gnav-links a').forEach((a) => a.addEventListener('click', () => {
  nav.classList.remove('is-open');
  burger?.setAttribute('aria-expanded', 'false');
  lenis?.start();
}));
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && nav?.classList.contains('is-open')) burger.click();
});

// La barre passe en version claire au-dessus des sections claires.
const lightZones = document.querySelectorAll('.s-artists, .s-about');
if (lightZones.length && nav) {
  const update = () => {
    const y = nav.offsetHeight / 2;
    let light = false;
    lightZones.forEach((z) => {
      const r = z.getBoundingClientRect();
      if (r.top <= y && r.bottom >= y) light = true;
    });
    nav.classList.toggle('is-light', light);
  };
  if (lenis) lenis.on('scroll', update); else addEventListener('scroll', update, { passive: true });
  update();
}

// ---------- Couleurs et mesures posées par JS (la CSP interdit les styles en ligne dans le HTML) ----------
document.querySelectorAll('.tile-media, .artist-card-media').forEach((el) => {
  const color = el.closest('[data-color]')?.dataset.color;
  if (color) el.style.backgroundColor = color;
});
document.querySelectorAll('.histo-bar').forEach((bar) => {
  requestAnimationFrame(() => { bar.style.height = `${Math.max(4, Number(bar.dataset.h))}%`; });
});

// ---------- Boutons qui demandent d'être connecté ----------
document.addEventListener('click', (e) => {
  if (e.target.closest('[data-auth]')) {
    e.preventDefault();
    loginRedirect();
  }
});

// ---------- Transition d'image entre une vignette et la page album (View Transitions) ----------
document.addEventListener('click', (e) => {
  const link = e.target.closest('a[href^="/album/"]');
  const img = link?.querySelector('img[data-vt]');
  if (!img || e.metaKey || e.ctrlKey || e.shiftKey) return;
  document.querySelectorAll('[style*="view-transition-name"]').forEach((el) => { el.style.viewTransitionName = ''; });
  img.style.viewTransitionName = 'album-cover';
});
// Sur la page album, la grande pochette reçoit le même nom pour l'animation d'arrivée.
const albumCover = document.querySelector('.album-cover-img');
if (albumCover) albumCover.style.viewTransitionName = 'album-cover';

// ---------- Révélations génériques ----------
function splitLines(el) {
  const parts = el.innerHTML.split(/<br\s*\/?>/i);
  el.innerHTML = parts.map((p) => `<span class="split-line"><span>${p.trim()}</span></span>`).join('');
  return el.querySelectorAll('.split-line > span');
}

if (motion) {
  document.querySelectorAll('[data-split]').forEach((el) => {
    const lines = splitLines(el);
    gsap.fromTo(lines, { y: 0, yPercent: 105 }, {
      yPercent: 0, duration: 1.2, ease: 'expo.out', stagger: 0.08,
      scrollTrigger: { trigger: el, start: 'top 88%', once: true },
    });
  });
  document.querySelectorAll('[data-reveal]').forEach((el) => {
    gsap.to(el, {
      opacity: 1, y: 0, duration: 1.1, ease: 'expo.out',
      scrollTrigger: { trigger: el, start: 'top 90%', once: true },
    });
  });

  // Vignettes : apparition par groupes au fil du scroll.
  const tiles = gsap.utils.toArray('.grid .tile, .artists-grid .artist-card, .favs .tile');
  if (tiles.length) {
    gsap.set(tiles, { opacity: 0, y: 40 });
    ScrollTrigger.batch(tiles, {
      start: 'top 94%',
      once: true,
      onEnter: (batch) => gsap.to(batch, { opacity: 1, y: 0, duration: 0.9, ease: 'expo.out', stagger: 0.05, overwrite: true }),
    });
  }

  // Grande pochette de la page album : légère inclinaison au pointeur.
  const tilt = document.querySelector('[data-tilt]');
  if (tilt && matchMedia('(hover: hover)').matches) {
    const img = tilt.querySelector('img');
    const rx = gsap.quickTo(img, 'rotationX', { duration: 0.8, ease: 'power3.out' });
    const ry = gsap.quickTo(img, 'rotationY', { duration: 0.8, ease: 'power3.out' });
    tilt.addEventListener('pointermove', (e) => {
      const r = tilt.getBoundingClientRect();
      ry(((e.clientX - r.left) / r.width - 0.5) * 10);
      rx(-((e.clientY - r.top) / r.height - 0.5) * 10);
    });
    tilt.addEventListener('pointerleave', () => { rx(0); ry(0); });
  }

  // Portrait de la page rappeur : révélation par masque au chargement.
  const clipHero = document.querySelector('[data-clip-hero]');
  if (clipHero) {
    gsap.fromTo(clipHero, { clipPath: 'inset(100% 0% 0% 0% round 28px)' }, { clipPath: 'inset(0% 0% 0% 0% round 28px)', duration: 1.6, ease: 'expo.out' });
    gsap.fromTo(clipHero.querySelector('img'), { scale: 1.25 }, { scale: 1, duration: 2, ease: 'expo.out' });
  }

  // Effet WebGL de distorsion au survol des vignettes : seulement sur ordinateur, chargé à la demande.
  if (matchMedia('(hover: hover) and (pointer: fine) and (min-width: 834px)').matches && document.querySelector('[data-gl]')) {
    const start = () => import('./gl/hover.js').then((m) => m.initHover()).catch(() => {});
    if ('requestIdleCallback' in window) requestIdleCallback(start, { timeout: 2500 }); else setTimeout(start, 1200);
  }

  addEventListener('load', () => { ScrollTrigger.sort(); ScrollTrigger.refresh(); });
}

// ---------- Bandeau cookies ----------
const CONSENT_KEY = 'mrf-consent';
function readConsent() {
  try {
    const raw = JSON.parse(localStorage.getItem(CONSENT_KEY) || 'null');
    if (raw && Date.now() - raw.at < 182 * 86400_000) return raw;
  } catch { /* stockage indisponible */ }
  return null;
}
function writeConsent(choice) {
  try { localStorage.setItem(CONSENT_KEY, JSON.stringify({ choice, at: Date.now() })); } catch { /* ignoré */ }
}
const banner = document.querySelector('[data-consent]');
if (banner && !readConsent()) {
  banner.hidden = false;
  banner.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-consent-choice]');
    if (!btn) return;
    writeConsent(btn.dataset.consentChoice);
    banner.hidden = true;
    document.dispatchEvent(new CustomEvent('consent-change'));
  });
}
export { readConsent, writeConsent };

// ---------- Messages après redirection ----------
const notices = {
  bienvenue: 'Bienvenue ! Confirme ton adresse e-mail (lien envoyé) pour publier tes chroniques.',
  'compte-supprime': 'Ton compte et toutes tes données ont été supprimés.',
};
const search = new URLSearchParams(location.search);
for (const [key, message] of Object.entries(notices)) {
  if (search.has(key)) {
    setTimeout(() => toast(message), 400);
    search.delete(key);
    history.replaceState(null, '', location.pathname + (search.size ? `?${search}` : '') + location.hash);
  }
}
