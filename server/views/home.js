import { html, raw } from '../html.js';
import { cover, portrait, tile, icon } from './components.js';

const pick = (albums, slugs) => slugs.map((s) => albums.find((a) => a.slug === s)).filter(Boolean);

const ERAS = [
  { id: '90', label: 'Années 90', range: [1990, 1999], line: "Marseille et la Seine-Saint-Denis écrivent les bases. Le rap devient une langue." },
  { id: '00', label: 'Années 2000', range: [2000, 2009], line: "Le rap de rue domine les ventes. Les collectifs éclatent en carrières solo." },
  { id: '10', label: 'Années 2010', range: [2010, 2019], line: "Internet change tout. La trap, l'indépendance et le streaming s'imposent." },
  { id: '20', label: 'Années 2020', range: [2020, 2029], line: "Drill, mélodie et albums-concepts. Le rap est la musique la plus écoutée du pays." },
];

const FEATURED = ['iam', 'diams', 'pnl'];

export function homePage({ albums, artists, user }) {
  const total = albums.length;
  const first = albums[0];
  const last = albums[albums.length - 1];

  // Mur de pochettes du héros : 5 rangées.
  const wall = [0, 1, 2, 3, 4].map((row) => albums.filter((_, i) => i % 5 === row).slice(0, 12));

  // Séquence « dézoom » façon page produit : une pochette centrale entourée d'une grille.
  const hero = albums.find((a) => a.slug === 'iam-l-ecole-du-micro-d-argent') || albums[0];
  const ring = pick(albums, [
    'ntm-paris-sous-les-bombes', 'lunatic-mauvais-oeil', 'mc-solaar-prose-combat', 'oxmo-puccino-opera-puccino',
    'arsenik-quelques-gouttes-suffisent', 'booba-temps-mort', 'diams-dans-ma-bulle', 'pnl-dans-la-legende',
    'nekfeu-feu', 'orelsan-la-fete-est-finie', 'damso-ipseite', 'kaaris-or-noir',
    'nepal-adios-bahamas', 'laylow-trinity', 'sch-jvlivs', 'fonky-family-art-de-rue',
    'ideal-j-le-combat-continue', 'jul-my-world', 'ninho-destin', '113-les-princes-de-la-ville',
    'lomepal-jeannine', 'tiakola-melo', 'alpha-wann-une-main-lave-l-autre', 'rohff-la-fierte-des-notres',
  ]);
  // 5 × 5 : la pochette héroïne occupe le centre.
  const grid = [...ring.slice(0, 12), hero, ...ring.slice(12, 24)];

  const eraAlbums = ERAS.map((era) => ({
    ...era,
    albums: albums.filter((a) => a.year >= era.range[0] && a.year <= era.range[1]),
  }));

  const titlesA = albums.filter((_, i) => i % 2 === 0).slice(0, 24);
  const titlesB = albums.filter((_, i) => i % 2 === 1).slice(0, 24);

  const featured = FEATURED.map((slug) => artists.find((a) => a.slug === slug)).filter(Boolean);
  const index = artists.filter((a) => !FEATURED.includes(a.slug)).slice(0, 18);

  const cta = html`<a class="btn btn-primary btn-lg" href="${user ? `/membre/${user.username}` : '/inscription'}">${user ? 'Ouvrir mon carnet' : 'Créer mon compte'}</a>`;

  return html`
  <section class="hero" aria-labelledby="hero-title" data-hero>
    <div class="hero-wall" aria-hidden="true" data-hero-wall>
      ${wall.map((row, r) => html`<div class="hero-row" data-row="${r}">
        ${[...row, ...row].map((a) => html`<img src="${a.cover}-300.webp" width="300" height="300" alt="" decoding="async" fetchpriority="low">`)}
      </div>`)}
    </div>
    <div class="hero-shade" aria-hidden="true"></div>
    <div class="hero-copy" data-hero-copy>
      <h1 id="hero-title" class="hero-title"><span>Le rap français,</span> <span>album par album.</span></h1>
      <p class="hero-sub">Note, chronique et partage les ${total} albums qui ont fait le rap français. Avec tes amis.</p>
      ${cta}
    </div>
    <a class="hero-scroll" href="#albums" aria-label="Descendre vers les albums">${icon('chevron-down')}</a>
  </section>

  <section class="s-albums" id="albums" aria-labelledby="albums-title">
    <header class="section-head">
      <h2 id="albums-title" class="display" data-split>Albums.</h2>
      <p class="lede" data-reveal>De <em>${first.title}</em> en ${first.year} à <em>${last.title}</em> en ${last.year}. ${total} disques, une seule histoire.</p>
    </header>

    <div class="zoom" data-zoom>
      <div class="zoom-stage">
        <div class="zoom-grid" data-zoom-grid>
          ${grid.map((a) => html`<a class="zoom-cell ${a === hero ? 'is-hero' : ''}" href="/album/${a.slug}" ${raw(a === hero ? 'data-zoom-hero' : '')} tabindex="${a === hero ? '0' : '-1'}">
            ${cover(a, { sizes: a === hero ? '(min-width: 734px) 60vw, 90vw' : '20vw' })}
          </a>`)}
        </div>
        <p class="zoom-caption" data-zoom-caption>
          <span class="zoom-caption-title">${hero.title}</span>
          <span class="zoom-caption-meta">${hero.artist.name}, ${hero.year}</span>
        </p>
      </div>
    </div>

    <div class="eras" data-eras>
      <div class="eras-track" data-eras-track>
        ${eraAlbums.map((era) => html`<section class="era" aria-labelledby="era-${era.id}">
          <div class="era-head">
            <h3 id="era-${era.id}" class="era-title">${era.label}</h3>
            <p class="era-line">${era.line}</p>
            <a class="link-more" href="/albums?decennie=${era.range[0]}">${era.albums.length} albums ${icon('chevron-right')}</a>
          </div>
          <div class="era-covers">
            ${era.albums.slice(0, 6).map((a) => tile(a, { sizes: '(min-width: 1068px) 16vw, 40vw' }))}
          </div>
        </section>`)}
      </div>
      <div class="eras-progress" aria-hidden="true"><span data-eras-progress></span></div>
    </div>

    <div class="velocity" aria-label="Quelques titres du catalogue" data-velocity>
      ${[titlesA, titlesB].map((row, i) => html`<div class="velocity-row" data-direction="${i ? -1 : 1}">
        <div class="velocity-inner">
          ${[...row, ...row].map((a, j) => html`<a href="/album/${a.slug}" ${raw(j >= row.length ? 'aria-hidden="true" tabindex="-1"' : '')}>${a.title}</a>`)}
        </div>
      </div>`)}
    </div>

    <p class="section-foot"><a class="link-more link-more-lg" href="/albums">Voir les ${total} albums ${icon('chevron-right')}</a></p>
  </section>

  <section class="s-artists" id="rappeurs" aria-labelledby="artists-title">
    <header class="section-head">
      <h2 id="artists-title" class="display" data-split>Rappeurs.</h2>
      <p class="lede" data-reveal>Des pionniers de Marseille aux voix de la drill. Leurs histoires, leurs disques.</p>
    </header>

    <div class="features">
      ${featured.map((a, i) => html`<article class="feature ${i % 2 ? 'is-flipped' : ''}" data-feature>
        <a class="feature-media" href="/rappeur/${a.slug}" tabindex="-1" aria-hidden="true">
          <span class="feature-clip" data-clip>${portrait(a, { sizes: '(min-width: 1068px) 42vw, 90vw' })}</span>
        </a>
        <div class="feature-copy">
          <p class="feature-origin">${a.origin} · depuis ${a.first_year}</p>
          <h3 class="feature-name"><a href="/rappeur/${a.slug}">${a.name}</a></h3>
          <p class="feature-bio">${a.bio}</p>
          <a class="link-more" href="/rappeur/${a.slug}">Discographie ${icon('chevron-right')}</a>
        </div>
      </article>`)}
    </div>

    <div class="roster" data-roster>
      <ul class="roster-list">
        ${index.map((a) => html`<li>
          <a class="roster-item" href="/rappeur/${a.slug}" data-portrait="${a.photo}-800.webp" data-color="${a.color}">
            <span class="roster-name">${a.name}</span>
            <span class="roster-meta">${a.origin} · ${a.first_year}</span>
          </a>
        </li>`)}
      </ul>
      <p class="section-foot"><a class="link-more link-more-lg" href="/rappeurs">Tous les rappeurs ${icon('chevron-right')}</a></p>
    </div>
  </section>

  <section class="s-about" id="apropos" aria-labelledby="about-title">
    <h2 id="about-title" class="visually-hidden">À propos de MyRapFr</h2>
    <div class="reveal-text" data-text-reveal>
      <p class="reveal-text-inner">MyRapFr est né d'une idée simple : le rap français mérite son carnet d'écoute. Note chaque album, écris ce qu'il t'a fait, suis tes amis et garde la trace de tout ce que tu écoutes.</p>
    </div>
    <div class="about-cols">
      <div data-reveal><h3>Noter</h3><p>Une note sur cinq, des demi-étoiles, et un cœur pour les albums qui comptent vraiment.</p></div>
      <div data-reveal><h3>Chroniquer</h3><p>Ton journal d'écoute, daté, avec tes chroniques. Relis ce que tu pensais d'un disque il y a trois ans.</p></div>
      <div data-reveal><h3>Partager</h3><p>Suis tes amis, découvre leurs coups de cœur et compare vos classements.</p></div>
    </div>
  </section>

  <section class="s-close" aria-labelledby="close-title">
    <h2 id="close-title" class="display" data-split>Ton carnet d'écoute<br>commence ici.</h2>
    <p class="lede">Gratuit, sans publicité, sans pistage.</p>
    ${cta}
  </section>`;
}
