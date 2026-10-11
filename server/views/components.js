import { html, raw } from '../html.js';

export const icon = (name, label) => label
  ? html`<svg class="icon" role="img" aria-label="${label}"><use href="/img/icons.svg#${name}"></use></svg>`
  : html`<svg class="icon" aria-hidden="true" focusable="false"><use href="/img/icons.svg#${name}"></use></svg>`;

// Pochette responsive : 300 / 600 / 1200 px en WebP.
export function cover(album, { sizes = '(min-width: 1068px) 220px, 45vw', eager = false, cls = '', vt = false } = {}) {
  return html`<img class="cover ${cls}" src="${album.cover}-600.webp${album.v}"
    srcset="${album.cover}-300.webp${album.v} 300w, ${album.cover}-600.webp${album.v} 600w, ${album.cover}-1200.webp${album.v} 1200w"
    sizes="${sizes}" width="600" height="600" alt="Pochette de ${album.title}, ${album.artist.name}"
    ${raw(eager ? 'fetchpriority="high"' : 'loading="lazy"')} decoding="async"
    ${raw(vt ? `data-vt="cover-${album.slug}"` : '')}>`;
}

export function portrait(artist, { sizes = '(min-width: 1068px) 30vw, 80vw', eager = false, cls = '' } = {}) {
  return html`<img class="portrait ${cls}" src="${artist.photo}-800.webp${artist.v}"
    srcset="${artist.photo}-400.webp${artist.v} 400w, ${artist.photo}-800.webp${artist.v} 800w, ${artist.photo}-1200.webp${artist.v} 1200w"
    sizes="${sizes}" width="800" height="1000" alt="Portrait de ${artist.name}"
    ${raw(eager ? 'fetchpriority="high"' : 'loading="lazy"')} decoding="async">`;
}

// Vignette d'album : l'image et le titre sont le sujet.
export function tile(album, { sizes, showArtist = true, gl = true } = {}) {
  return html`<a class="tile" href="/album/${album.slug}" data-color="${album.color}" ${raw(gl ? 'data-gl' : '')}
      data-title="${album.title}" data-artist="${album.artist.name}" data-year="${album.year}" data-slug="${album.slug}">
    <span class="tile-media">${cover(album, { sizes, vt: true })}</span>
    <span class="tile-title">${album.title}</span>
    ${showArtist ? html`<span class="tile-meta">${album.artist.name} · ${album.year}${album.kind === 'ep' ? ' · EP' : ''}</span>` : html`<span class="tile-meta">${album.year}${album.kind === 'ep' ? ' · EP' : ''}</span>`}
  </a>`;
}

// Note sur 10 (demi-étoiles) affichée en étoiles SVG.
export function stars(rating, { label = true } = {}) {
  if (!rating) return '';
  const full = Math.floor(rating / 2);
  const half = rating % 2;
  const items = [];
  for (let i = 0; i < full; i++) items.push(icon('star'));
  if (half) items.push(icon('star-half'));
  return html`<span class="stars" ${raw(label ? `role="img" aria-label="${rating / 2} sur 5"` : 'aria-hidden="true"')}>${items}</span>`;
}

export const avatar = (user, cls = '') =>
  html`<span class="avatar ${cls}" aria-hidden="true">${(user.display_name || user.displayName || user.username || '?').slice(0, 1).toUpperCase()}</span>`;

export function formatDate(iso) {
  const d = new Date(iso.length <= 10 ? `${iso}T12:00:00Z` : `${iso.replace(' ', 'T')}Z`);
  return d.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
}

export function review(r, { showAlbum = false, viewer = null } = {}) {
  return html`<article class="review" data-review="${r.id}">
    ${showAlbum && r.album ? html`<a class="review-cover" href="/album/${r.album.slug}">${cover(r.album, { sizes: '80px' })}</a>` : ''}
    <div class="review-body">
      <header class="review-head">
        ${showAlbum && r.album ? html`<a class="review-album" href="/album/${r.album.slug}">${r.album.title} <span>${r.album.year}</span></a>` : ''}
        <a class="review-author" href="/membre/${r.username}">${avatar(r)} <span>${r.display_name}</span></a>
        ${stars(r.rating)}
        ${r.loved ? icon('heart', 'Coup de cœur') : ''}
        <time datetime="${r.listened_on || r.created_at}">${formatDate(r.listened_on || r.created_at)}</time>
      </header>
      ${r.body ? html`<p class="review-text">${r.body}</p>` : ''}
      ${r.likes !== undefined ? html`<footer class="review-foot">
        <button class="like-btn" type="button" data-like="${r.id}" aria-pressed="${r.liked_by_me ? 'true' : 'false'}" ${raw(viewer ? '' : 'data-auth')}>
          ${icon('heart')} <span class="like-count">${r.likes}</span><span class="visually-hidden"> j'aime</span>
        </button>
        ${viewer && viewer.username !== r.username ? html`<button class="text-btn" type="button" data-report="${r.id}">Signaler</button>` : ''}
        ${viewer && viewer.username === r.username ? html`<button class="text-btn" type="button" data-delete-review="${r.id}">Supprimer</button>` : ''}
      </footer>` : ''}
    </div>
  </article>`;
}

// Champs anti-spam communs à tous les formulaires publics.
export const antiSpamFields = (formToken) => html`
  <div class="hp" aria-hidden="true">
    <label>Ne pas remplir <input type="text" name="website" tabindex="-1" autocomplete="off"></label>
  </div>
  <input type="hidden" name="formToken" value="${formToken}">`;
