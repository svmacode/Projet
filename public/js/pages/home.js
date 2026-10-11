// Accueil : le mouvement est le fil conducteur, mais chaque section n'a qu'un geste.
import { motion, lenis } from '../app.js';

const { gsap, ScrollTrigger } = window;

if (motion) {
  hero();
  zoom();
  eras();
  velocity();
  features();
  textReveal();
  roster();
  // Les déclencheurs créés avant l'épinglage des décennies doivent être recalculés dans l'ordre de la page.
  ScrollTrigger.sort();
  ScrollTrigger.refresh();
} else {
  // Sans animation, la séquence de dézoom affiche simplement la grille.
  document.querySelector('[data-zoom-grid]')?.classList.add('is-static');
}

// ---------- Héros : un mur de pochettes qui dérive lentement ----------
function hero() {
  const section = document.querySelector('[data-hero]');
  const wall = section.querySelector('[data-hero-wall]');
  const rows = wall.querySelectorAll('.hero-row');

  rows.forEach((row, i) => {
    const dir = i % 2 ? 1 : -1;
    // Chaque rangée contient deux fois la même série : on boucle sur la moitié de sa largeur.
    const tween = gsap.fromTo(row, { xPercent: dir < 0 ? 0 : -50 }, {
      xPercent: dir < 0 ? -50 : 0, duration: 140 + i * 18, ease: 'none', repeat: -1,
    });
    // Le mur ne tourne que lorsqu'il est visible.
    ScrollTrigger.create({ trigger: section, start: 'top bottom', end: 'bottom top', onToggle: (s) => (s.isActive ? tween.play() : tween.pause()) });
  });

  // Entrée : le titre monte ligne par ligne, le mur apparaît en fondu.
  const lines = section.querySelectorAll('.hero-title > span');
  gsap.from(wall, { opacity: 0, scale: 1.12, duration: 2.4, ease: 'expo.out' });
  gsap.from(lines, { yPercent: 60, opacity: 0, duration: 1.4, ease: 'expo.out', stagger: 0.12, delay: 0.15 });
  gsap.from(section.querySelectorAll('.hero-sub, .hero-copy .btn, .hero-scroll'), {
    y: 20, opacity: 0, duration: 1.2, ease: 'expo.out', stagger: 0.1, delay: 0.5,
  });

  // Au scroll : le mur recule et se floute, le texte s'éloigne plus vite (parallaxe).
  const tl = gsap.timeline({ scrollTrigger: { trigger: section, start: 'top top', end: 'bottom top', scrub: true } });
  tl.to(wall, { scale: 1.25, opacity: 0.15, filter: 'blur(6px)', ease: 'none' }, 0)
    .to(section.querySelector('[data-hero-copy]'), { yPercent: -35, opacity: 0, ease: 'none' }, 0);
}

// ---------- Albums : une pochette plein écran qui recule pour révéler la collection ----------
function zoom() {
  const root = document.querySelector('[data-zoom]');
  if (!root) return;
  const grid = root.querySelector('[data-zoom-grid]');
  const heroCell = grid.querySelector('[data-zoom-hero]');
  const others = [...grid.children].filter((c) => c !== heroCell);
  const caption = root.querySelector('[data-zoom-caption]');

  // La grille est posée en grand puis réduite : l'image reste nette pendant tout le zoom.
  let scale = 1;
  const size = () => {
    grid.style.width = '';
    grid.style.gap = '';
    const fit = grid.offsetWidth;
    const gap = parseFloat(getComputedStyle(grid).columnGap) || 0;
    const cell = (fit - gap * 4) / 5;
    scale = Math.max(1, Math.min(innerWidth * 0.92, innerHeight * 0.78) / cell);
    grid.style.width = `${fit * scale}px`;
    grid.style.gap = `${gap * scale}px`;
  };
  size();
  ScrollTrigger.addEventListener('refreshInit', size);

  const tl = gsap.timeline({
    scrollTrigger: { trigger: root, start: 'top top', end: 'bottom bottom', scrub: 1, invalidateOnRefresh: true },
  });
  tl.fromTo(grid, { scale: 1 }, { scale: () => 1 / scale, ease: 'power2.inOut', duration: 1 }, 0)
    .fromTo(others, { opacity: 0, scale: 0.86 }, {
      opacity: 1, scale: 1, ease: 'power2.out', duration: 0.5,
      stagger: { each: 0.02, from: 'center', grid: [5, 5] },
    }, 0.45)
    .fromTo(caption, { opacity: 0, y: 20 }, { opacity: 1, y: 0, duration: 0.25 }, 0.85)
    .to({}, { duration: 0.25 });
}

// ---------- Décennies : la frise défile à l'horizontale pendant qu'on descend ----------
function eras() {
  const root = document.querySelector('[data-eras]');
  if (!root) return;
  const track = root.querySelector('[data-eras-track]');
  const bar = root.querySelector('[data-eras-progress]');
  const mm = gsap.matchMedia();

  mm.add('(min-width: 1068px)', () => {
    const distance = () => track.scrollWidth - innerWidth;
    const tween = gsap.to(track, {
      x: () => -distance(), ease: 'none',
      scrollTrigger: {
        trigger: root, pin: true, scrub: 1, start: 'top top', end: () => `+=${distance()}`,
        invalidateOnRefresh: true,
        onUpdate: (self) => gsap.set(bar, { scaleX: self.progress }),
      },
    });
    // Chaque pochette se dévoile par un masque quand elle entre dans le cadre.
    track.querySelectorAll('.era').forEach((era) => {
      const tiles = era.querySelectorAll('.tile-media');
      gsap.fromTo(tiles, { clipPath: 'inset(100% 0% 0% 0%)' }, {
        clipPath: 'inset(0% 0% 0% 0%)', ease: 'expo.out', duration: 1.2, stagger: 0.06,
        scrollTrigger: { trigger: era, containerAnimation: tween, start: 'left 75%', toggleActions: 'play none none reverse' },
      });
      gsap.from(era.querySelector('.era-title'), {
        xPercent: 20, opacity: 0, ease: 'none',
        scrollTrigger: { trigger: era, containerAnimation: tween, start: 'left right', end: 'left 40%', scrub: true },
      });
    });
  });

  mm.add('(max-width: 1067px)', () => {
    track.querySelectorAll('.era-title').forEach((t) => gsap.from(t, {
      y: 40, opacity: 0, duration: 1, ease: 'expo.out', scrollTrigger: { trigger: t, start: 'top 88%', once: true },
    }));
  });
}

// ---------- Titres en défilement : la vitesse réagit à celle du scroll ----------
function velocity() {
  const root = document.querySelector('[data-velocity]');
  if (!root) return;
  const rows = [...root.querySelectorAll('.velocity-row')].map((row) => ({
    inner: row.querySelector('.velocity-inner'),
    dir: Number(row.dataset.direction) || 1,
    x: 0,
  }));
  let factor = 0;
  let visible = false;
  ScrollTrigger.create({ trigger: root, start: 'top bottom', end: 'bottom top', onToggle: (s) => { visible = s.isActive; } });

  gsap.ticker.add((time, delta) => {
    if (!visible) return;
    const v = lenis ? lenis.velocity : 0;
    // Lissage : la bande accélère avec le scroll puis revient doucement à sa vitesse de croisière.
    factor += (Math.min(6, Math.abs(v) * 0.15) * Math.sign(v || 1) - factor) * 0.08;
    for (const r of rows) {
      const half = r.inner.scrollWidth / 2;
      if (!half) continue;
      r.x -= r.dir * (0.035 * delta) * (1 + Math.abs(factor)) * (factor < -0.5 ? -1 : 1);
      r.x = ((r.x % half) - half) % half;
      r.inner.style.transform = `translate3d(${r.x}px,0,0)`;
    }
  });
}

// ---------- Rappeurs à la une : portrait dévoilé par un masque, image en parallaxe ----------
function features() {
  document.querySelectorAll('[data-feature]').forEach((feature) => {
    const clip = feature.querySelector('[data-clip]');
    const img = clip.querySelector('img');
    gsap.fromTo(clip, { clipPath: 'inset(16% 14% 16% 14% round 28px)' }, {
      clipPath: 'inset(0% 0% 0% 0% round 28px)', ease: 'none',
      scrollTrigger: { trigger: feature, start: 'top 90%', end: 'top 25%', scrub: 1 },
    });
    gsap.fromTo(img, { yPercent: -8, scale: 1.18 }, {
      yPercent: 8, scale: 1.05, ease: 'none',
      scrollTrigger: { trigger: feature, start: 'top bottom', end: 'bottom top', scrub: true },
    });
    gsap.from(feature.querySelectorAll('.feature-copy > *'), {
      y: 30, opacity: 0, duration: 1.1, ease: 'expo.out', stagger: 0.08,
      scrollTrigger: { trigger: feature, start: 'top 70%', once: true },
    });
  });
}

// ---------- À propos : le texte s'allume mot à mot au fil du scroll ----------
function textReveal() {
  const root = document.querySelector('[data-text-reveal]');
  if (!root) return;
  const p = root.querySelector('.reveal-text-inner');
  const esc = (t) => t.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  const text = p.textContent.trim();
  // Une copie intacte pour les lecteurs d'écran, les mots découpés pour l'animation.
  p.innerHTML = `<span class="visually-hidden">${esc(text)}</span><span aria-hidden="true">${
    text.split(/\s+/).map((w) => `<span class="w">${esc(w)}</span>`).join(' ')}</span>`;
  gsap.to(p.querySelectorAll('.w'), {
    color: '#1d1d1f', ease: 'none', stagger: 0.5,
    scrollTrigger: { trigger: root, start: 'top 65%', end: 'bottom 75%', scrub: true },
  });
}

// ---------- Liste des rappeurs : portrait WebGL qui suit le pointeur ----------
function roster() {
  const list = document.querySelector('[data-roster] .roster-list');
  if (!list || !matchMedia('(hover: hover) and (pointer: fine) and (min-width: 834px)').matches) return;
  let started = false;
  list.addEventListener('pointerenter', () => {
    if (started) return;
    started = true;
    import('../gl/portrait.js').then((m) => {
      m.initPortraits(list);
      // Le premier survol a déclenché le chargement : on rejoue l'entrée sur l'élément pointé.
      list.querySelector('.roster-item:hover')?.dispatchEvent(new PointerEvent('pointerenter'));
    }).catch(() => {});
  });
}
