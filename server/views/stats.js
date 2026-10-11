import { html } from '../html.js';
import { cover, avatar, icon, stars, tile } from './components.js';

const MONTHS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const MONTHS_LONG = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const fmt = (n) => String(n).replace('.', ',');
const dateFr = (d) => new Date(`${d}T12:00:00Z`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' });

// Histogramme vertical en SVG (tailles en attributs : compatible avec la politique de sécurité du site).
function columns(items, { label = 'Histogramme', unit = 'album' } = {}) {
  const max = Math.max(1, ...items.map((i) => i.value));
  const w = 100 / items.length;
  return html`<figure class="chart">
    <svg viewBox="0 0 100 50" preserveAspectRatio="none" role="img" aria-label="${label}">
      ${items.map((it, i) => {
        const h = (it.value / max) * 46;
        return html`<rect x="${(i * w + w * 0.15).toFixed(2)}" y="${(50 - h).toFixed(2)}" width="${(w * 0.7).toFixed(2)}" height="${h.toFixed(2)}" rx="0.8"><title>${it.label} : ${it.value} ${unit}${it.value > 1 ? 's' : ''}</title></rect>`;
      })}
    </svg>
    <figcaption class="chart-labels">${items.map((it) => html`<span>${it.label}</span>`)}</figcaption>
  </figure>`;
}

// Barres horizontales (rappeurs les plus écoutés).
function rows(items) {
  const max = Math.max(1, ...items.map((i) => i.n));
  return html`<ol class="hbars">${items.map((it) => html`<li>
    <a href="/rappeur/${it.slug}">${it.name}</a>
    <svg viewBox="0 0 100 8" preserveAspectRatio="none" aria-hidden="true"><rect x="0" y="0" height="8" width="${((it.n / max) * 100).toFixed(1)}" rx="4"></rect></svg>
    <span>${it.n}</span>
  </li>`)}</ol>`;
}

export function statsPage({ profile: p, s, years }) {
  const t = s.totals;
  return html`
  <section class="page-head page-head-dark">
    <p class="kick-link"><a href="/membre/${p.username}">${icon('chevron-left')} ${p.display_name}</a></p>
    <h1 class="display">Statistiques.</h1>
    <p class="lede">Le rap français de ${p.display_name}, en chiffres.</p>
    ${years.length ? html`<p class="year-links">${years.map((y) => html`<a class="btn btn-quiet btn-sm" href="/membre/${p.username}/bilan/${y}">Bilan ${y}</a>`)}</p>` : ''}
  </section>
  <section class="page-body stats">
    <dl class="big-numbers">
      <div><dt>Albums écoutés</dt><dd>${t.listened}</dd></div>
      <div><dt>Chroniques</dt><dd>${t.reviews}</dd></div>
      <div><dt>Coups de cœur</dt><dd>${t.liked}</dd></div>
      <div><dt>Note moyenne</dt><dd>${t.avg ? html`${fmt((t.avg / 2).toFixed(1))}<small>/5</small>` : '—'}</dd></div>
    </dl>

    ${t.listened || t.rated ? html`
    <div class="stats-grid">
      <section class="panel"><h2 class="h-section">Par décennie de sortie</h2>
        ${s.byDecade.length ? columns(s.byDecade.map((d) => ({ label: `${String(d.decade).slice(2)}’s`, value: d.n })), { label: 'Albums écoutés par décennie de sortie' }) : html`<p class="empty-note">Aucun album marqué comme écouté.</p>`}
      </section>
      <section class="panel"><h2 class="h-section">Notes données</h2>
        ${t.rated ? columns(s.ratings.map((n, i) => ({ label: i % 2 ? `${(i + 1) / 2}★` : '', value: n })), { label: 'Répartition des notes, de une demi-étoile à cinq étoiles', unit: 'note' }) : html`<p class="empty-note">Aucune note.</p>`}
      </section>
      ${s.byYear.length > 1 ? html`<section class="panel"><h2 class="h-section">Par année d'écoute</h2>
        ${columns(s.byYear.map((y) => ({ label: y.year, value: y.n })), { label: "Albums écoutés par année d'écoute" })}
      </section>` : ''}
      <section class="panel"><h2 class="h-section">Rappeurs les plus écoutés</h2>
        ${s.topArtists.length ? rows(s.topArtists) : html`<p class="empty-note">Rien pour l'instant.</p>`}
      </section>
    </div>
    ${s.topRated.length ? html`<section><h2 class="h-section">Ses mieux notés</h2>
      <div class="grid grid-small">${s.topRated.map((a) => tile(a, { gl: false, sizes: '160px' }))}</div>
    </section>` : ''}` : html`<p class="empty-note">Pas encore assez d'écoutes pour des statistiques. Note des albums et tiens ton journal !</p>`}
  </section>`;
}

export function yearPage({ profile: p, b, years, isMe }) {
  const who = isMe ? 'Ton' : `L'`;
  return html`
  <article class="wrapped">
    <header class="wrapped-hero">
      <p class="wrapped-kicker">${avatar(p, 'avatar-lg')} <a href="/membre/${p.username}">${p.display_name}</a></p>
      <h1 class="wrapped-title">${who === 'Ton' ? 'Ton année' : 'Son année'} <span>${b.year}</span> en rap.</h1>
      <p class="wrapped-big"><strong>${b.albums}</strong> album${b.albums > 1 ? 's' : ''} écouté${b.albums > 1 ? 's' : ''}${b.reviews ? html`, <strong>${b.reviews}</strong> chronique${b.reviews > 1 ? 's' : ''}` : ''}${b.avg ? html`, une note moyenne de <strong>${fmt((b.avg / 2).toFixed(1))}/5</strong>` : ''}.</p>
      <div class="album-share album-share-center"><button class="copy-btn" type="button" data-share data-share-campaign="bilan">${icon('share')}<span>Partager ce bilan</span></button></div>
    </header>

    ${b.best.length ? html`<section class="wrapped-section">
      <h2 class="wrapped-h">Le podium</h2>
      <ol class="podium">${b.best.map((x, i) => html`<li class="podium-item ${i === 0 ? 'is-first' : ''}">
        <a href="/album/${x.album.slug}">${cover(x.album, { sizes: i === 0 ? '320px' : '200px' })}
          <span class="podium-rank">${i + 1}</span>
          <span class="podium-title">${x.album.title}</span><span class="podium-artist">${x.album.artist.name}</span></a>
        ${stars(x.rating)}
      </li>`)}</ol>
    </section>` : ''}

    <section class="wrapped-section wrapped-grid">
      ${b.artists.length ? html`<div class="wrapped-card"><h2 class="wrapped-h">Rappeurs de l'année</h2>${rows(b.artists)}</div>` : ''}
      <div class="wrapped-card"><h2 class="wrapped-h">Mois par mois</h2>
        ${columns(b.months.map((n, i) => ({ label: MONTHS[i].slice(0, 1).toUpperCase(), value: n })), { label: "Écoutes par mois de l'année" })}
        <p>Le mois le plus chargé : <strong>${MONTHS_LONG[b.topMonth]}</strong>.</p>
      </div>
      ${b.decade ? html`<div class="wrapped-card"><h2 class="wrapped-h">Décennie préférée</h2>
        <p class="wrapped-stat">Les années ${b.decade.decade}</p><p>${b.decade.n} écoute${b.decade.n > 1 ? 's' : ''} d'albums sortis entre ${b.decade.decade} et ${b.decade.decade + 9}.</p>
        <p>Le plus ancien : <a href="/album/${b.oldest.slug}">${b.oldest.title}</a> (${b.oldest.year}).</p></div>` : ''}
      <div class="wrapped-card"><h2 class="wrapped-h">Premier et dernier</h2>
        <p>L'année a commencé le ${dateFr(b.first.date)} avec <a href="/album/${b.first.album.slug}">${b.first.album.title}</a> de ${b.first.album.artist.name}.</p>
        <p>Dernière écoute : <a href="/album/${b.last.album.slug}">${b.last.album.title}</a>, le ${dateFr(b.last.date)}.</p>
        ${b.longest ? html`<p>La plus longue chronique : <a href="/chronique/${b.longest.id}">${b.longest.words} mots sur ${b.longest.album.title}</a>.</p>` : ''}
      </div>
    </section>

    <footer class="wrapped-foot">
      ${years.length > 1 ? html`<p class="year-links">${years.map((y) => html`<a class="btn btn-quiet btn-sm" href="/membre/${p.username}/bilan/${y}" ${y === b.year ? html`aria-current="page"` : ''}>${y}</a>`)}</p>` : ''}
      <p><a href="/membre/${p.username}/stats">Toutes les statistiques</a></p>
    </footer>
  </article>`;
}
