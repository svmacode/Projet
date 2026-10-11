import { html } from '../html.js';
import { avatar, icon, formatDate } from './components.js';

const short = (s, n = 90) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);

export function inboxPage({ conversations, friends }) {
  const known = new Set(conversations.map((c) => c.username));
  const others = friends.filter((f) => !known.has(f.username));
  return html`
  <section class="page-head">
    <h1 class="display">Messages.</h1>
    <p class="lede">Tes conversations privées avec tes amis.</p>
  </section>
  <section class="page-body inbox">
    ${conversations.length ? html`<ul class="conv-list">${conversations.map((c) => html`<li class="conv ${c.unread ? 'is-unread' : ''}">
      <a href="/messages/${c.username}">
        ${avatar(c, 'avatar-lg')}
        <span class="conv-text"><strong>${c.display_name}</strong><span>${c.mine ? 'Toi : ' : ''}${short(c.last)}</span></span>
        <span class="conv-meta"><time datetime="${c.at}">${formatDate(c.at)}</time>${c.unread ? html`<span class="badge">${c.unread}</span>` : ''}</span>
      </a>
    </li>`)}</ul>` : html`<p class="empty-note">Aucune conversation pour l'instant.</p>`}

    <div class="panel">
      <h2 class="h-section">Nouveau message</h2>
      ${others.length || friends.length ? html`<ul class="persons">${(others.length ? others : friends).slice(0, 20).map((f) => html`<li class="person">
        <a class="person-id" href="/membre/${f.username}">${avatar(f)} <span><strong>${f.display_name}</strong> <small>@${f.username}</small></span></a>
        <a class="btn btn-sm btn-quiet" href="/messages/${f.username}">Écrire</a>
      </li>`)}</ul>` : html`<p class="empty-note">Tu peux écrire à tes amis : les membres que tu suis et qui te suivent. <a href="/amis">Trouver des amis</a></p>`}
    </div>
  </section>`;
}

export function threadPage({ peer, messages, canMessage, verified }) {
  return html`
  <section class="page-body dm" data-dm="${peer.username}">
    <header class="dm-head">
      <a class="kick-link" href="/messages">${icon('chevron-left')} Messages</a>
      <a class="dm-peer" href="/membre/${peer.username}">${avatar(peer, 'avatar-lg')} <strong>${peer.display_name}</strong> <small>@${peer.username}</small></a>
    </header>
    <ol class="dm-list" data-dm-list aria-live="polite">
      ${messages.map((m) => html`<li class="dm-msg ${m.mine ? 'is-mine' : ''}" data-msg="${m.id}">
        <p class="dm-body">${m.body}</p>
        <span class="dm-meta"><time datetime="${m.created_at}">${formatDate(m.created_at)}</time>${m.mine && m.read_at ? ' · Lu' : ''}
          <button type="button" class="text-btn" data-dm-delete="${m.id}">Effacer</button>
          ${m.mine ? '' : html`<button type="button" class="text-btn" data-dm-report="${m.id}">Signaler</button>`}</span>
      </li>`)}
    </ol>
    ${messages.length ? '' : html`<p class="empty-note" data-dm-empty>Aucun message. Lance la conversation !</p>`}
    ${canMessage && verified ? html`<form class="dm-form" data-dm-form novalidate>
      <label class="visually-hidden" for="dm-body">Ton message</label>
      <textarea id="dm-body" name="body" rows="2" maxlength="2000" required placeholder="Écris à ${peer.display_name}…"></textarea>
      <button class="btn btn-primary" type="submit">Envoyer</button>
    </form>` : html`<p class="notice">${verified ? 'Vous n\'êtes plus amis (abonnements réciproques) : tu peux lire cette conversation mais plus y répondre.' : 'Confirme ton adresse e-mail pour envoyer des messages.'}</p>`}
    <p class="field-help">Les messages sont privés. L'équipe de modération ne voit un message que si son destinataire le signale.</p>
  </section>`;
}
