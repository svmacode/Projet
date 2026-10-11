import { html } from '../html.js';
import { tile, cover, stars, review, avatar, icon, formatDate } from './components.js';

export function profilePage({ profile: p, user }) {
  const followBtn = !p.isMe && user ? html`<button type="button" class="btn ${p.isFollowing ? 'btn-quiet' : 'btn-primary'}" data-follow="${p.username}" aria-pressed="${p.isFollowing ? 'true' : 'false'}">${p.isFollowing ? (p.followsMe ? 'Amis' : 'Abonné') : 'Suivre'}</button>`
    : !user ? html`<a class="btn btn-quiet" href="/connexion?retour=/membre/${p.username}">Suivre</a>` : '';
  return html`
  <article class="profile">
    <header class="profile-head">
      ${avatar(p, 'avatar-xl')}
      <div class="profile-id">
        <h1 class="profile-name">${p.display_name}</h1>
        <p class="profile-handle">@${p.username} · membre depuis ${formatDate(p.created_at)}</p>
        ${p.bio ? html`<p class="profile-bio">${p.bio}</p>` : ''}
        ${!p.isMe && p.followsMe ? html`<p class="badge">Te suit</p>` : ''}
      </div>
      <div class="profile-cta">
        ${p.isMe ? html`<a class="btn btn-quiet" href="/compte">Modifier le profil</a>` : followBtn}
      </div>
    </header>

    <dl class="profile-stats">
      <div><dt>Albums</dt><dd>${p.stats.listened}</dd></div>
      <div><dt>Cette année</dt><dd>${p.stats.thisYear}</dd></div>
      <div><dt>Chroniques</dt><dd>${p.stats.reviews}</dd></div>
      <div><dt><a href="/membre/${p.username}/abonnes">Abonnés</a></dt><dd data-followers>${p.stats.followers}</dd></div>
      <div><dt><a href="/membre/${p.username}/abonnements">Abonnements</a></dt><dd>${p.stats.following}</dd></div>
    </dl>

    <nav class="tabs" aria-label="Sections du profil">
      <a href="#favoris">Favoris</a><a href="#journal">Journal</a><a href="#coeurs">Coups de cœur</a><a href="#a-ecouter">À écouter</a><a href="#listes">Listes</a><a href="#amis">Amis</a>
    </nav>

    <section id="favoris" class="profile-section" aria-labelledby="fav-t">
      <h2 id="fav-t" class="h-section">Albums favoris</h2>
      ${p.favorites.length ? html`<div class="favs">${p.favorites.map((a) => tile(a))}</div>`
        : html`<p class="empty-note">${p.isMe ? html`Choisis tes 4 albums favoris dans <a href="/compte">ton profil</a>.` : 'Pas encore de favoris.'}</p>`}
    </section>

    <section id="journal" class="profile-section" aria-labelledby="diary-t">
      <h2 id="diary-t" class="h-section">Journal d'écoute</h2>
      ${p.diary.length ? html`<ol class="diary">${p.diary.map((d) => html`<li class="diary-row">
        <time datetime="${d.listened_on}"><span class="diary-day">${d.listened_on.slice(8, 10)}</span><span class="diary-month">${new Date(`${d.listened_on}T12:00:00Z`).toLocaleDateString('fr-FR', { month: 'short', year: 'numeric' })}</span></time>
        <a class="diary-cover" href="/album/${d.album.slug}">${cover(d.album, { sizes: '64px' })}</a>
        <a class="diary-title" href="/album/${d.album.slug}">${d.album.title} <span>${d.album.artist.name}, ${d.album.year}</span></a>
        ${stars(d.rating)}
        ${d.body ? html`<span class="diary-has-review">${icon('text', 'Avec chronique')}</span>` : ''}
      </li>`)}</ol>` : html`<p class="empty-note">Aucune écoute enregistrée pour l'instant.</p>`}
    </section>

    <section id="coeurs" class="profile-section" aria-labelledby="likes-t">
      <h2 id="likes-t" class="h-section">Coups de cœur</h2>
      ${p.liked.length ? html`<div class="grid grid-small">${p.liked.map((a) => tile(a, { gl: false }))}</div>` : html`<p class="empty-note">Aucun coup de cœur.</p>`}
    </section>

    <section id="a-ecouter" class="profile-section" aria-labelledby="wish-t">
      <h2 id="wish-t" class="h-section">À écouter</h2>
      ${p.wishlist.length ? html`<div class="grid grid-small">${p.wishlist.map((a) => tile(a, { gl: false }))}</div>` : html`<p class="empty-note">Rien en attente.</p>`}
    </section>

    <section id="listes" class="profile-section" aria-labelledby="lists-t">
      <h2 id="lists-t" class="h-section">Listes</h2>
      ${p.lists.length ? html`<ul class="plain-list">${p.lists.map((l) => html`<li><a href="/liste/${l.id}">${l.title} <span>${l.count} album${l.count > 1 ? 's' : ''}</span></a></li>`)}</ul>` : html`<p class="empty-note">Aucune liste.</p>`}
      ${p.isMe ? html`<form class="form form-inline" data-new-list novalidate>
        <div class="field"><label for="list-title">Nouvelle liste</label>
          <input id="list-title" name="title" required maxlength="80" placeholder="Mes classiques de 1997">
          <p class="field-error" data-error-for="title"></p></div>
        <button class="btn btn-quiet" type="submit">Créer</button>
      </form>` : ''}
    </section>

    <section id="amis" class="profile-section" aria-labelledby="friends-t">
      <h2 id="friends-t" class="h-section">Amis</h2>
      <p class="field-help">Un ami, c'est quelqu'un que tu suis et qui te suit.</p>
      ${p.friends.length ? html`<ul class="people">${p.friends.map((f) => html`<li><a href="/membre/${f.username}">${avatar(f)} <span>${f.display_name}</span></a></li>`)}</ul>` : html`<p class="empty-note">Pas encore d'amis ici.</p>`}
    </section>
  </article>`;
}

export function followPage({ profile, users, direction }) {
  const title = direction === 'followers' ? 'Abonnés' : 'Abonnements';
  return html`
  <section class="page-head">
    <p class="kick-link"><a href="/membre/${profile.username}">${icon('chevron-left')} ${profile.display_name}</a></p>
    <h1 class="display">${title}.</h1>
  </section>
  <section class="page-body">
    ${users.length ? html`<ul class="people people-lg">${users.map((f) => html`<li><a href="/membre/${f.username}">${avatar(f)} <span>${f.display_name} <small>@${f.username}</small></span></a></li>`)}</ul>`
      : html`<p class="empty-note">Personne pour l'instant.</p>`}
  </section>`;
}

export function listPage({ list, user }) {
  const mine = user && user.username === list.username;
  return html`
  <section class="page-head page-head-dark">
    <p class="kick-link">Liste de <a href="/membre/${list.username}">${list.display_name}</a></p>
    <h1 class="display">${list.title}</h1>
    ${list.description ? html`<p class="lede">${list.description}</p>` : ''}
  </section>
  <section class="catalogue">
    ${list.albums.length ? html`<ol class="grid ranked" data-list="${list.id}">${list.albums.map((a) => html`<li>
      ${tile(a)}
      ${mine ? html`<button type="button" class="text-btn" data-remove-item="${a.slug}">Retirer</button>` : ''}
    </li>`)}</ol>` : html`<p class="empty-note">Cette liste est vide. ${mine ? 'Ajoute des albums depuis leur page.' : ''}</p>`}
    ${mine ? html`<p><button type="button" class="text-btn text-danger" data-delete-list="${list.id}">Supprimer la liste</button></p>` : ''}
  </section>`;
}

export function feedPage({ feed, recent, user }) {
  return html`
  <section class="page-head page-head-dark">
    <h1 class="display" data-split>Fil d'actu.</h1>
    <p class="lede">Les dernières écoutes des membres que tu suis.</p>
  </section>
  <section class="feed">
    ${feed.length ? feed.map((r) => review(r, { showAlbum: true, viewer: user }))
      : html`<div class="empty-block">
          <p class="empty-note">Ton fil est vide. Suis des membres pour voir leurs écoutes ici.</p>
          ${recent.length ? html`<h2 class="h-section">Chroniques récentes sur MyRapFr</h2>${recent.map((r) => review(r, { showAlbum: true }))}` : ''}
        </div>`}
  </section>`;
}
