import { html } from '../html.js';
import { tile, review, avatar, icon, cover } from './components.js';

// Carte du défi du mois (page Classements, fil d'actu).
export function challengeCard(c) {
  return html`<a class="challenge-card" href="/defi">
    <span class="challenge-covers" aria-hidden="true">${c.albums.slice(0, 4).map((a) => cover(a, { sizes: '64px' }))}</span>
    <span class="challenge-text"><small>Défi de ${c.month}</small><strong>${c.title}</strong>
      <span>${c.total ? `${c.progress}/${c.total} écoutés` : ''} · encore ${c.daysLeft} jour${c.daysLeft > 1 ? 's' : ''}</span></span>
    ${icon('chevron-right')}
  </a>`;
}

export function chartsPage({ topRated, trending, trendingDays, topReviews, members, challenge, user }) {
  return html`
  <section class="page-head page-head-dark">
    <h1 class="display" data-split>Classements.</h1>
    <p class="lede">Ce que les membres de MyRapFr écoutent, notent et aiment.</p>
  </section>
  <section class="page-body charts">
    ${challengeCard(challenge)}

    <section aria-labelledby="trend-t">
      <h2 id="trend-t" class="h-section">En ce moment <small>${trendingDays === 7 ? 'les 7 derniers jours' : 'les 30 derniers jours'}</small></h2>
      ${trending.length ? html`<ol class="grid ranked">${trending.map((a) => html`<li>${tile(a, { gl: false })}<span class="chart-note">${a.listeners} membre${a.listeners > 1 ? 's' : ''}</span></li>`)}</ol>`
        : html`<p class="empty-note">Pas encore d'écoutes récentes. Tiens ton journal pour lancer le classement !</p>`}
    </section>

    <section aria-labelledby="top-t">
      <h2 id="top-t" class="h-section">Les mieux notés <small>de tous les temps</small></h2>
      ${topRated.length ? html`<ol class="grid ranked">${topRated.map((a) => html`<li>${tile(a, { gl: false })}<span class="chart-note">${(a.avg / 2).toFixed(1).replace('.', ',')}/5 · ${a.ratings} note${a.ratings > 1 ? 's' : ''}</span></li>`)}</ol>`
        : html`<p class="empty-note">Aucune note pour l'instant.</p>`}
    </section>

    <div class="charts-columns">
      <section aria-labelledby="rev-t">
        <h2 id="rev-t" class="h-section">Chroniques les plus aimées <small>ce mois-ci</small></h2>
        ${topReviews.length ? topReviews.map((r) => review(r, { showAlbum: true, viewer: user })) : html`<p class="empty-note">Aucune chronique ce mois-ci.</p>`}
      </section>
      <section aria-labelledby="mem-t">
        <h2 id="mem-t" class="h-section">Membres les plus actifs <small>30 jours</small></h2>
        ${members.length ? html`<ol class="persons ranked-people">${members.map((m) => html`<li class="person">
          <a class="person-id" href="/membre/${m.username}">${avatar(m, 'avatar-lg')} <span><strong>${m.display_name}</strong> <small>${m.n} écoute${m.n > 1 ? 's' : ''} · ${m.reviews} chronique${m.reviews > 1 ? 's' : ''}</small></span></a>
        </li>`)}</ol>` : html`<p class="empty-note">Personne pour l'instant.</p>`}
      </section>
    </div>
  </section>`;
}

export function challengePage({ c, user }) {
  const doneAll = c.total && c.progress === c.total;
  return html`
  <section class="page-head page-head-dark">
    <p class="kick-link">Défi de ${c.month}</p>
    <h1 class="display">${c.title}.</h1>
    <p class="lede">${c.text} Marque-les comme écoutés d'ici la fin du mois (encore ${c.daysLeft} jour${c.daysLeft > 1 ? 's' : ''}).</p>
  </section>
  <section class="page-body challenge">
    ${user ? html`<div class="challenge-progress ${doneAll ? 'is-done' : ''}">
      <svg viewBox="0 0 100 6" preserveAspectRatio="none" aria-hidden="true"><rect class="track" x="0" y="0" width="100" height="6" rx="3"></rect><rect x="0" y="0" height="6" rx="3" width="${c.total ? ((c.progress / c.total) * 100).toFixed(1) : 0}"></rect></svg>
      <p>${doneAll ? html`<strong>Défi réussi !</strong> Bravo, tu as écouté les ${c.total} albums.` : html`<strong>${c.progress}/${c.total}</strong> albums écoutés.`}
        ${c.finishers ? html` ${c.finishers} membre${c.finishers > 1 ? 's ont' : ' a'} déjà relevé le défi.` : ''}</p>
    </div>` : html`<p class="notice"><a href="/connexion?retour=/defi">Connecte-toi</a> pour suivre ta progression.</p>`}
    <ol class="grid challenge-grid">${c.albums.map((a) => html`<li class="${a.done ? 'is-done' : ''}">
      ${tile(a, { gl: false })}
      ${a.done ? html`<span class="challenge-check">${icon('check')} Écouté</span>` : ''}
    </li>`)}</ol>
    <p class="field-help">Ouvre un album et clique sur « Écouté » pour le cocher. Un nouveau défi commence chaque mois.</p>
  </section>`;
}
