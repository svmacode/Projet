import { html } from '../html.js';
import { avatar, formatDate } from './components.js';

// Bouton d'action de modération (public/js/pages/admin.js) : `ask` demande une raison, `confirm` une confirmation.
const action = (label, url, { ask, confirm, danger = false } = {}) => html`<button type="button" class="btn btn-sm ${danger ? 'btn-danger' : 'btn-quiet'}"
  data-mod-url="${url}" ${ask ? html`data-mod-ask="${ask}"` : ''} ${confirm ? html`data-mod-confirm="${confirm}"` : ''}>${label}</button>`;

const reasons = (list) => html`<ul class="mod-reasons">${list.map((r) => html`<li><strong>@${r.by}</strong> · ${formatDate(r.at)} : ${r.reason}</li>`)}</ul>`;

export function adminPage({ stats, reviewReports, userReports, commentReports = [], members, query, journal }) {
  return html`
  <section class="page-head">
    <h1 class="display">Modération.</h1>
    <p class="lede">Traite les signalements rapidement : la loi demande de retirer un contenu manifestement illicite dès qu'on en a connaissance.</p>
  </section>
  <section class="page-body admin">
    <dl class="admin-stats">
      <div><dt>Membres</dt><dd>${stats.members}</dd></div>
      <div><dt>Nouveaux (7 jours)</dt><dd>${stats.newThisWeek}</dd></div>
      <div><dt>Chroniques</dt><dd>${stats.reviews}</dd></div>
      <div><dt>Masquées</dt><dd>${stats.hidden}</dd></div>
      <div><dt>Comptes suspendus</dt><dd>${stats.suspended}</dd></div>
    </dl>

    <section aria-labelledby="rr-t">
      <h2 id="rr-t" class="h-section">Chroniques signalées <span class="count">${reviewReports.length}</span></h2>
      ${reviewReports.length ? reviewReports.map((r) => html`
        <article class="mod-card panel">
          <p class="mod-meta"><a href="/membre/${r.author}">@${r.author}</a> sur <a href="/album/${r.album_slug}">${r.album_title}</a> · ${formatDate(r.review_at)} · <strong>${r.count} signalement${r.count > 1 ? 's' : ''}</strong>${r.hidden_at ? ' · déjà masquée' : ''}</p>
          <blockquote class="mod-quote">${r.body}</blockquote>
          ${reasons(r.reasons)}
          <div class="mod-actions">
            ${r.hidden_at
              ? action('Rétablir la chronique', `/admin/reviews/${r.review_id}/restore`)
              : action('Masquer la chronique', `/admin/reviews/${r.review_id}/hide`, { ask: 'Raison du masquage (visible dans le journal) :', danger: true })}
            ${action('Laisser en ligne', `/admin/reviews/${r.review_id}/dismiss`, { confirm: 'Rejeter ces signalements ? La chronique reste en ligne.' })}
            ${r.author_suspended ? '' : action(`Suspendre @${r.author}`, `/admin/users/${r.author}/suspend`, { ask: `Raison de la suspension de @${r.author} :`, danger: true })}
          </div>
        </article>`) : html`<p class="empty-note">Aucune chronique signalée. Tout va bien.</p>`}
    </section>

    <section aria-labelledby="cr-t">
      <h2 id="cr-t" class="h-section">Commentaires signalés <span class="count">${commentReports.length}</span></h2>
      ${commentReports.length ? commentReports.map((c) => html`
        <article class="mod-card panel">
          <p class="mod-meta"><a href="/membre/${c.author}">@${c.author}</a> sous <a href="/chronique/${c.review_id}">une chronique</a> · ${formatDate(c.comment_at)} · <strong>${c.count} signalement${c.count > 1 ? 's' : ''}</strong></p>
          <blockquote class="mod-quote">${c.body}</blockquote>
          ${reasons(c.reasons)}
          <div class="mod-actions">
            ${action('Masquer le commentaire', `/admin/comments/${c.comment_id}/hide`, { ask: 'Raison du masquage :', danger: true })}
            ${action('Laisser en ligne', `/admin/comments/${c.comment_id}/dismiss`, { confirm: 'Rejeter ces signalements ?' })}
            ${c.author_suspended ? '' : action(`Suspendre @${c.author}`, `/admin/users/${c.author}/suspend`, { ask: `Raison de la suspension de @${c.author} :`, danger: true })}
          </div>
        </article>`) : html`<p class="empty-note">Aucun commentaire signalé.</p>`}
    </section>

    <section aria-labelledby="ur-t">
      <h2 id="ur-t" class="h-section">Profils signalés <span class="count">${userReports.length}</span></h2>
      ${userReports.length ? userReports.map((u) => html`
        <article class="mod-card panel">
          <div class="mod-profile">${avatar(u, 'avatar-lg')} <div><a href="/membre/${u.username}"><strong>${u.display_name}</strong> @${u.username}</a>${u.bio ? html`<p class="mod-bio">${u.bio}</p>` : ''}</div></div>
          <p class="mod-meta"><strong>${u.count} signalement${u.count > 1 ? 's' : ''}</strong></p>
          ${reasons(u.reasons)}
          <div class="mod-actions">
            ${action('Effacer photo, nom et bio', `/admin/users/${u.username}/clear`, { confirm: `Effacer la photo, le nom affiché et la bio de @${u.username} ?`, danger: true })}
            ${action('Rejeter', `/admin/users/${u.username}/dismiss`, { confirm: 'Rejeter ces signalements ?' })}
            ${u.suspended_at ? '' : action('Suspendre', `/admin/users/${u.username}/suspend`, { ask: `Raison de la suspension de @${u.username} :`, danger: true })}
          </div>
        </article>`) : html`<p class="empty-note">Aucun profil signalé.</p>`}
    </section>

    <section aria-labelledby="m-t">
      <h2 id="m-t" class="h-section">Membres</h2>
      <form class="admin-search" method="get" action="/admin" role="search">
        <label class="visually-hidden" for="admin-q">Chercher un membre</label>
        <input id="admin-q" name="q" type="search" value="${query}" placeholder="Pseudo ou nom">
        <button class="btn btn-quiet" type="submit">Chercher</button>
      </form>
      <div class="table-wrap">
        <table class="admin-table">
          <thead><tr><th scope="col">Membre</th><th scope="col">Inscrit le</th><th scope="col">Chroniques</th><th scope="col">Signalées</th><th scope="col">Statut</th><th scope="col"><span class="visually-hidden">Actions</span></th></tr></thead>
          <tbody>${members.map((m) => html`<tr>
            <td><a class="admin-member" href="/membre/${m.username}">${avatar(m)} <span>${m.display_name} <small>@${m.username}</small></span></a></td>
            <td>${formatDate(m.created_at)}</td>
            <td>${m.reviews}</td>
            <td>${m.reported}</td>
            <td>${m.suspended_at ? html`<span class="tag tag-danger" title="${m.suspended_reason || ''}">Suspendu</span>` : m.role === 'admin' ? html`<span class="tag">Admin</span>` : 'Actif'}</td>
            <td>${m.role === 'admin' ? '' : m.suspended_at
              ? action('Réactiver', `/admin/users/${m.username}/unsuspend`, { confirm: `Réactiver le compte de @${m.username} ?` })
              : action('Suspendre', `/admin/users/${m.username}/suspend`, { ask: `Raison de la suspension de @${m.username} :`, danger: true })}</td>
          </tr>`)}</tbody>
        </table>
      </div>
    </section>

    <section aria-labelledby="j-t">
      <h2 id="j-t" class="h-section">Journal de modération</h2>
      <p class="field-help">Conservé un an. Il prouve que les signalements ont été examinés.</p>
      ${journal.length ? html`<ul class="mod-journal">${journal.map((j) => html`<li><time>${formatDate(j.created_at)}</time> <strong>${j.action}</strong> · ${j.target}${j.detail ? html` · <em>${j.detail}</em>` : ''} <small>par @${j.admin || 'compte supprimé'}</small></li>`)}</ul>`
        : html`<p class="empty-note">Aucune action pour l'instant.</p>`}
    </section>
  </section>`;
}
