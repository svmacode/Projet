// Conversation privée : envoyer, recevoir (vérification toutes les 8 s quand l'onglet est visible),
// effacer sa copie d'un message, signaler un message reçu.
import { api, loginRedirect } from '../lib/api.js';
import { toast, busy } from '../lib/ui.js';

const root = document.querySelector('[data-dm]');
if (root) {
  const peer = root.dataset.dm;
  const list = root.querySelector('[data-dm-list]');
  const form = root.querySelector('[data-dm-form]');
  const fail = (err) => (err.status === 401 ? loginRedirect() : toast(err.message, { error: true }));
  const lastId = () => Number(list.lastElementChild?.dataset.msg || 0);
  const toBottom = () => scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });

  // Message construit avec textContent : le texte n'est jamais interprété comme du HTML.
  const render = (m) => {
    const li = document.createElement('li');
    li.className = `dm-msg is-new${m.mine ? ' is-mine' : ''}`;
    li.dataset.msg = m.id;
    const body = document.createElement('p');
    body.className = 'dm-body';
    body.textContent = m.body;
    const meta = document.createElement('span');
    meta.className = 'dm-meta';
    const time = document.createElement('time');
    time.textContent = 'à l\'instant';
    const del = document.createElement('button');
    del.type = 'button';
    del.className = 'text-btn';
    del.dataset.dmDelete = m.id;
    del.textContent = 'Effacer';
    meta.append(time, ' ', del);
    if (!m.mine) {
      const rep = document.createElement('button');
      rep.type = 'button';
      rep.className = 'text-btn';
      rep.dataset.dmReport = m.id;
      rep.textContent = 'Signaler';
      meta.append(' ', rep);
    }
    li.append(body, meta);
    return li;
  };

  const poll = async () => {
    if (document.hidden) return;
    try {
      const { messages } = await api(`/messages/${peer}?after=${lastId()}`);
      if (messages.length) {
        root.querySelector('[data-dm-empty]')?.remove();
        list.append(...messages.map(render));
        toBottom();
      }
    } catch { /* réseau coupé : on réessaiera */ }
  };
  setInterval(poll, 8000);
  document.addEventListener('visibilitychange', poll);
  toBottom();

  form?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const text = form.body.value.trim();
    if (!text) return;
    const btn = form.querySelector('[type="submit"]');
    busy(btn, true);
    try {
      const { message } = await api(`/messages/${peer}`, { method: 'POST', body: { body: text } });
      root.querySelector('[data-dm-empty]')?.remove();
      list.append(render(message));
      form.reset();
      toBottom();
    } catch (err) { fail(err); }
    busy(btn, false);
    form.body.focus();
  });
  // Entrée envoie, Maj+Entrée va à la ligne.
  form?.body.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); form.requestSubmit(); }
  });

  list.addEventListener('click', async (e) => {
    const del = e.target.closest('[data-dm-delete]');
    if (del) {
      if (!confirm('Effacer ce message de ta conversation ? Ton ami le garde dans la sienne.')) return;
      try {
        await api(`/message/${del.dataset.dmDelete}`, { method: 'DELETE' });
        del.closest('li').remove();
      } catch (err) { fail(err); }
      return;
    }
    const rep = e.target.closest('[data-dm-report]');
    if (rep) {
      const reason = prompt('Pourquoi signales-tu ce message ? (harcèlement, menace, spam…) Il sera transmis à la modération.');
      if (!reason || reason.trim().length < 3) return;
      try {
        await api(`/message/${rep.dataset.dmReport}/report`, { method: 'POST', body: { reason: reason.trim() } });
        rep.disabled = true;
        rep.textContent = 'Signalé';
        toast('Merci, la modération va examiner ce message.');
      } catch (err) { fail(err); }
    }
  });
}
