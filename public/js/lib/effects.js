// Effets de finition, chacun discret et réservé aux écrans qui s'y prêtent.
// Règles suivies (UI UX Pro Max) : un ou deux éléments « magnétiques » par écran, déplacements
// courts, rien sans `prefers-reduced-motion: no-preference`.
const { gsap, ScrollTrigger } = window;
const finePointer = matchMedia('(hover: hover) and (pointer: fine)').matches;

// Boutons principaux attirés par le pointeur (force limitée à 25 %).
export function magnetic(selector = '.btn-lg.btn-primary, .hero-scroll, .to-top') {
  if (!finePointer) return;
  document.querySelectorAll(selector).forEach((el) => {
    const xTo = gsap.quickTo(el, 'x', { duration: 0.6, ease: 'elastic.out(1, 0.4)' });
    const yTo = gsap.quickTo(el, 'y', { duration: 0.6, ease: 'elastic.out(1, 0.4)' });
    el.addEventListener('pointermove', (e) => {
      const r = el.getBoundingClientRect();
      xTo((e.clientX - r.left - r.width / 2) * 0.25);
      yTo((e.clientY - r.top - r.height / 2) * 0.25);
    });
    el.addEventListener('pointerleave', () => { xTo(0); yTo(0); });
  });
}

// Chiffres qui défilent jusqu'à leur valeur quand ils entrent à l'écran (statistiques).
export function tickers(selector = '.album-stats dd, .profile-stats dd, [data-ticker]') {
  document.querySelectorAll(selector).forEach((el) => {
    const node = [...el.childNodes].find((n) => n.nodeType === 3 && /^\s*\d[\d\s ]*\s*$/.test(n.textContent));
    if (!node) return;
    const target = Number(node.textContent.replace(/\D/g, ''));
    if (!target) return;
    const state = { v: 0 };
    node.textContent = '0';
    gsap.to(state, {
      v: target, duration: Math.min(2, 0.6 + target / 400), ease: 'power3.out',
      scrollTrigger: { trigger: el, start: 'top 92%', once: true },
      onUpdate: () => { node.textContent = Math.round(state.v).toLocaleString('fr-FR'); },
    });
  });
}

// Pochette de la page album : reflet qui suit le pointeur en plus de l'inclinaison.
export function coverGlare() {
  const tilt = document.querySelector('[data-tilt]');
  const box = tilt?.querySelector('[data-tilt-target]');
  if (!box || !finePointer) return;
  const glare = document.createElement('span');
  glare.className = 'cover-glare';
  glare.setAttribute('aria-hidden', 'true');
  box.appendChild(glare);
  tilt.addEventListener('pointermove', (e) => {
    const r = box.getBoundingClientRect();
    glare.style.setProperty('--gx', `${((e.clientX - r.left) / r.width) * 100}%`);
    glare.style.setProperty('--gy', `${((e.clientY - r.top) / r.height) * 100}%`);
    glare.style.opacity = '1';
  });
  tilt.addEventListener('pointerleave', () => { glare.style.opacity = '0'; });
}

// Grands titres de section : légère parallaxe, ils glissent un peu moins vite que la page.
export function sectionParallax() {
  document.querySelectorAll('.section-head .display').forEach((title) => {
    gsap.fromTo(title, { yPercent: 12 }, {
      yPercent: -12, ease: 'none',
      scrollTrigger: { trigger: title, start: 'top bottom', end: 'bottom top', scrub: true },
    });
  });
}

export function initEffects() {
  magnetic();
  tickers();
  coverGlare();
  sectionParallax();
  ScrollTrigger.refresh();
}
