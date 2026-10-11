import { html, raw } from '../html.js';
import { cover, portrait, tile, stars, review, icon, antiSpamFields } from './components.js';

const DECADES = [1990, 2000, 2010, 2020];

// Adresse d'une page du catalogue avec ses filtres.
export function catalogueUrl({ q = '', decade = 0, kind = '', sort = 'year', page = 1 }) {
  const p = new URLSearchParams();
  if (q) p.set('q', q);
  if (decade) p.set('decennie', decade);
  if (kind) p.set('type', kind);
  if (sort && sort !== 'year') p.set('tri', sort);
  if (page > 1) p.set('page', page);
  const qs = p.toString();
  return `/albums${qs ? `?${qs}` : ''}`;
}

export function albumsPage({ result, filters, totalAll, status = {} }) {
  const { albums, total, page, pages } = result;
  const f = filters;
  const chip = (label, patch, pressed) => html`<a class="chip" href="${catalogueUrl({ ...f, ...patch, page: 1 })}" aria-current="${pressed ? 'true' : 'false'}" data-chip>${label}</a>`;
  return html`
  <section class="page-head page-head-dark">
    <h1 class="display" data-split>Albums.</h1>
    <p class="lede">${totalAll.toLocaleString('fr-FR')} albums, mixtapes et EP du rap français, de 1991 à aujourd'hui.</p>
    <p><a class="btn btn-quiet btn-sm" href="/au-hasard">🎲 Un album au hasard</a></p>
  </section>
  <section class="catalogue" data-catalogue>
    <p class="sync-note" data-sync ${raw(status.running ? '' : 'hidden')}>
      <span class="sync-dot" aria-hidden="true"></span>
      <span data-sync-text>${status.phase === 'images'
        ? 'Récupération des dernières pochettes…'
        : `Récupération des discographies : ${status.done || 0} / ${status.total || '…'} artistes. Les albums apparaissent au fur et à mesure.`}</span>
    </p>
    <form class="filters" role="search" action="/albums" method="get" data-filters>
      <label class="field-inline">
        <span class="visually-hidden">Filtrer par titre ou artiste</span>
        ${icon('search')}
        <input type="search" name="q" value="${f.q}" placeholder="Titre ou artiste" autocomplete="off" data-filter-q>
      </label>
      <div class="chips" role="group" aria-label="Décennie">
        ${chip('Toutes', { decade: 0 }, !f.decade)}
        ${DECADES.map((d) => chip(`${String(d).slice(2)}’s`, { decade: d }, f.decade === d))}
      </div>
      <div class="chips" role="group" aria-label="Type">
        ${chip('Tout', { kind: '' }, !f.kind)}
        ${chip('Albums', { kind: 'album' }, f.kind === 'album')}
        ${chip('EP', { kind: 'ep' }, f.kind === 'ep')}
      </div>
      <label class="field-inline select">
        <span class="visually-hidden">Trier</span>
        <select name="tri" data-sort>
          ${[['year', 'Chronologique'], ['recent', 'Plus récents'], ['title', 'Titre A → Z'], ['rating', 'Mieux notés'], ['popular', 'Plus notés']]
            .map(([v, l]) => html`<option value="${v}" ${raw(f.sort === v ? 'selected' : '')}>${l}</option>`)}
        </select>
      </label>
      ${f.decade ? html`<input type="hidden" name="decennie" value="${f.decade}">` : ''}
      ${f.kind ? html`<input type="hidden" name="type" value="${f.kind}">` : ''}
      <noscript><button class="btn btn-quiet" type="submit">Filtrer</button></noscript>
    </form>
    <p class="catalogue-count" aria-live="polite" data-count>${total.toLocaleString('fr-FR')} résultat${total > 1 ? 's' : ''}</p>
    <div class="grid" data-grid data-page="${page}" data-pages="${pages}">
      ${albums.map((a) => tile(a))}
    </div>
    ${total ? '' : html`<p class="empty">Aucun album ne correspond. Essaie un autre mot.</p>`}
    ${pages > 1 ? html`<nav class="pager" aria-label="Pages du catalogue" data-pager>
      ${page > 1 ? html`<a class="btn btn-quiet" href="${catalogueUrl({ ...f, page: page - 1 })}" rel="prev">Page précédente</a>` : ''}
      <span class="pager-info">Page ${page} sur ${pages}</span>
      ${page < pages ? html`<a class="btn btn-quiet" href="${catalogueUrl({ ...f, page: page + 1 })}" rel="next" data-more>Voir la suite</a>` : ''}
    </nav>` : ''}
  </section>`;
}

function histogram(album) {
  const max = Math.max(1, ...album.histogram);
  return html`<div class="histo" aria-label="Répartition des notes">
    ${album.histogram.map((n, i) => html`<span class="histo-bar" data-h="${Math.round((n / max) * 100)}" title="${n} × ${(i + 1) / 2} étoile${i ? 's' : ''}"></span>`)}
  </div>`;
}

export function albumPage({ album, reviews, friendsReviews, state, user, lists, more, formToken, links }) {
  const rating = state?.rating || 0;
  return html`
  <article class="album" data-album="${album.slug}" data-color="${album.color}">
    <div class="album-backdrop" aria-hidden="true"><img src="${album.cover}-300.webp${album.v}" alt="" width="300" height="300"></div>
    <div class="album-hero">
      <figure class="album-cover" data-tilt>
        <span class="album-cover-inner" data-tilt-target>${cover(album, { sizes: '(min-width: 1068px) 420px, 80vw', eager: true, cls: 'album-cover-img', vt: true })}</span>
        <figcaption class="album-credit">${album.placeholder ? 'Visuel provisoire' : album.coverCredit || ''}</figcaption>
      </figure>
      <div class="album-info">
        <p class="album-year">${album.year}</p>
        <h1 class="album-title">${album.title}</h1>
        <p class="album-artist">par <a href="/rappeur/${album.artist.slug}">${album.artist.name}</a></p>
        <div class="album-share">
          <button class="copy-btn" type="button" data-share data-share-campaign="album">${icon('share')}<span>Partager</span></button>
          <button class="copy-btn" type="button" data-copy-text="${album.title} — ${album.artist.name} (${album.year})">${icon('copy')}<span>Copier le titre</span></button>
        </div>
        <div class="listen" aria-label="Écouter l'album">
          <a class="listen-btn listen-deezer" href="${links.deezer}" target="_blank" rel="noopener noreferrer" data-listen-deezer>Deezer</a>
          <a class="listen-btn" href="${links.spotify}" target="_blank" rel="noopener noreferrer">Spotify</a>
          <a class="listen-btn" href="${links.apple}" target="_blank" rel="noopener noreferrer">Apple Music</a>
          <a class="listen-btn" href="${links.youtube}" target="_blank" rel="noopener noreferrer">YouTube Music</a>
        </div>
        <dl class="album-stats">
          <div><dt>Note moyenne</dt><dd>${album.avg ? html`${(album.avg / 2).toFixed(1).replace('.', ',')} ${stars(Math.round(album.avg), { label: false })}` : '—'}</dd></div>
          <div><dt>Notes</dt><dd>${album.ratings}</dd></div>
          <div><dt>Écoutes</dt><dd>${album.stats.listened || 0}</dd></div>
          <div><dt>Coups de cœur</dt><dd>${album.stats.likes || 0}</dd></div>
        </dl>
        ${histogram(album)}

        ${user ? html`
        <div class="actions" data-actions>
          <div class="actions-row">
            <button type="button" class="action" data-toggle="listened" aria-pressed="${state.listened ? 'true' : 'false'}">${icon('eye')}<span>Écouté</span></button>
            <button type="button" class="action" data-toggle="liked" aria-pressed="${state.liked ? 'true' : 'false'}">${icon('heart')}<span>Coup de cœur</span></button>
            <button type="button" class="action" data-toggle="wishlist" aria-pressed="${state.wishlist ? 'true' : 'false'}">${icon('clock')}<span>À écouter</span></button>
          </div>
          <fieldset class="rate" data-rate data-value="${rating}">
            <legend>Ta note</legend>
            <div class="rate-stars">
              ${[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((v) => html`<label class="rate-half ${v % 2 ? 'is-left' : 'is-right'}">
                <input type="radio" name="rating" value="${v}" ${raw(v === rating ? 'checked' : '')}>
                <span class="visually-hidden">${v / 2} étoile${v > 2 ? 's' : ''}</span>
              </label>`)}
              <span class="rate-fill" aria-hidden="true">
                <span class="rate-base">${[0, 1, 2, 3, 4].map(() => icon('star'))}</span>
                <span class="rate-on" data-rate-on>${[0, 1, 2, 3, 4].map(() => icon('star'))}</span>
              </span>
            </div>
            <button type="button" class="text-btn" data-rate-clear ${raw(rating ? '' : 'hidden')}>Effacer</button>
          </fieldset>
          <div class="actions-row">
            <button type="button" class="btn btn-quiet" data-open-review aria-expanded="false" aria-controls="review-form">Écrire une chronique</button>
            ${lists.length ? html`<label class="field-inline select">
              <span class="visually-hidden">Ajouter à une liste</span>
              <select data-add-to-list>
                <option value="">Ajouter à une liste…</option>
                ${lists.map((l) => html`<option value="${l.id}">${l.title}${l.shared ? ' (partagée)' : ''}</option>`)}
              </select>
            </label>` : ''}
          </div>
        </div>
        <form class="review-form form" id="review-form" hidden data-review-form novalidate>
          ${user.verified ? '' : html`<p class="notice">Confirme ton adresse e-mail pour publier une chronique. <button type="button" class="text-btn" data-resend>Renvoyer l'e-mail</button></p>`}
          <div class="field">
            <label for="listenedOn">Écouté le</label>
            <input type="date" id="listenedOn" name="listenedOn" required max="${new Date().toISOString().slice(0, 10)}" value="${new Date().toISOString().slice(0, 10)}">
            <p class="field-error" data-error-for="listenedOn"></p>
          </div>
          <div class="field">
            <label for="body">Ta chronique</label>
            <textarea id="body" name="body" rows="6" maxlength="5000" placeholder="Ce que cet album t'a fait…"></textarea>
            <p class="field-help"><span data-count-for="body">0</span> / 5 000</p>
            <p class="field-error" data-error-for="body"></p>
          </div>
          ${antiSpamFields(formToken)}
          <div class="form-actions">
            <button type="submit" class="btn btn-primary">Publier</button>
          </div>
        </form>`
        : html`<p class="actions-guest"><a href="/connexion?retour=/album/${album.slug}">Connecte-toi</a> pour noter cet album, le marquer comme écouté et écrire ta chronique.</p>`}
      </div>
    </div>

    <section class="tracks" aria-labelledby="tracks-title" data-tracks>
      <h2 id="tracks-title" class="h-section">Titres <span class="tracks-meta" data-tracks-meta></span></h2>
      <p class="empty-note" data-tracks-status>Chargement des titres…</p>
      <ol class="track-list" data-track-list hidden></ol>
    </section>

    ${friendsReviews.length ? html`<section class="reviews" aria-labelledby="friends-reviews">
      <h2 id="friends-reviews" class="h-section">Chez tes amis</h2>
      ${friendsReviews.map((r) => review(r, { viewer: user }))}
    </section>` : ''}

    <section class="reviews" aria-labelledby="pop-reviews">
      <h2 id="pop-reviews" class="h-section">Chroniques</h2>
      ${reviews.length ? reviews.map((r) => review(r, { viewer: user })) : html`<p class="empty-note">Personne n'a encore chroniqué cet album. La première chronique peut être la tienne.</p>`}
    </section>

    ${more.length ? html`<section class="more" aria-labelledby="more-title">
      <h2 id="more-title" class="h-section">Du même artiste</h2>
      <div class="row-scroll">${more.map((a) => tile(a, { showArtist: false, sizes: '200px' }))}</div>
    </section>` : ''}
  </article>`;
}

export function artistsPage({ artists }) {
  return html`
  <section class="page-head">
    <h1 class="display" data-split>Rappeurs.</h1>
    <p class="lede">${artists.length} artistes et groupes, classés par date de leur premier projet.</p>
  </section>
  <section class="artists-grid" data-stagger>
    ${artists.map((a) => html`<a class="artist-card" href="/rappeur/${a.slug}" data-color="${a.color}">
      <span class="artist-card-media">${portrait(a, { sizes: '(min-width: 1068px) 22vw, 45vw' })}</span>
      <span class="artist-card-name">${a.name}</span>
      <span class="artist-card-meta">${a.origin ? `${a.origin} · ` : ''}${a.albums} projet${a.albums > 1 ? 's' : ''}</span>
    </a>`)}
  </section>`;
}

export function artistPage({ artist }) {
  return html`
  <article class="artist">
    <header class="artist-hero">
      <div class="artist-portrait" data-clip-hero>${portrait(artist, { sizes: '(min-width: 1068px) 40vw, 90vw', eager: true })}</div>
      <div class="artist-copy">
        ${artist.origin ? html`<p class="feature-origin">${artist.origin}</p>` : ''}
        <h1 class="display">${artist.name}</h1>
        ${artist.bio ? html`<p class="artist-bio" id="artist-bio">${artist.bio}</p>` : html`<p class="artist-bio">${artist.albums.length} projets au catalogue, de ${artist.albums[0]?.year} à ${artist.albums.at(-1)?.year}.</p>`}
        <div class="album-share">
          ${artist.bio ? html`<button class="copy-btn" type="button" data-copy="#artist-bio">${icon('copy')}<span>Copier la biographie</span></button>` : ''}
          <button class="copy-btn" type="button" data-share data-share-campaign="rappeur">${icon('share')}<span>Partager</span></button>
        </div>
        ${artist.bio_source ? html`<p class="credit">Source : ${artist.bio_source}</p>` : ''}
        ${artist.photo_credit ? html`<p class="credit">Photo : ${artist.photo_credit}</p>` : ''}
      </div>
    </header>
    ${[['album', 'Albums et mixtapes'], ['ep', 'EP']].map(([kind, label]) => {
      const list = artist.albums.filter((a) => a.kind === kind);
      return list.length ? html`<section class="artist-albums" aria-labelledby="disco-${kind}">
        <h2 id="disco-${kind}" class="h-section">${label} <span class="h-count">${list.length}</span></h2>
        <div class="grid grid-light">${list.map((a) => tile(a, { showArtist: false }))}</div>
      </section>` : '';
    })}
  </article>`;
}

export function searchPage({ term, results }) {
  const none = term && !results.albums.length && !results.artists.length && !results.users.length;
  return html`
  <section class="page-head">
    <h1 class="display">Recherche.</h1>
    <form class="search-big" role="search" action="/recherche" method="get">
      <label for="q" class="visually-hidden">Rechercher un album, un rappeur ou un membre</label>
      <input id="q" type="search" name="q" value="${term}" placeholder="Album, rappeur, membre…" minlength="2" maxlength="60" autofocus>
      <button class="btn btn-quiet" type="submit">Rechercher</button>
    </form>
  </section>
  <section class="search-results">
    ${none ? html`<p class="empty-note">Aucun résultat pour « ${term} ».</p>` : ''}
    ${results.artists.length ? html`<h2 class="h-section">Rappeurs</h2><ul class="plain-list">${results.artists.map((a) => html`<li><a href="/rappeur/${a.slug}">${a.name}</a></li>`)}</ul>` : ''}
    ${results.users.length ? html`<h2 class="h-section">Membres</h2><ul class="plain-list">${results.users.map((u) => html`<li><a href="/membre/${u.username}">${u.display_name} <span>@${u.username}</span></a></li>`)}</ul>` : ''}
    ${results.albums.length ? html`<h2 class="h-section">Albums</h2><div class="grid grid-light">${results.albums.map((a) => tile(a))}</div>` : ''}
  </section>`;
}
