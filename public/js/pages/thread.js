// Page d'une chronique : publier, supprimer et signaler des commentaires.
import { api, loginRedirect } from '../lib/api.js';
import { toast, validateForm, liveValidation, showServerErrors, busy } from '../lib/ui.js';

const list = document.querySelector('[data-comments]');
const counter = document.querySelector('[data-comment-count]');
const fail = (err) => (err.status === 401 ? loginRedirect() : toast(err.message, { error: true }));
const bump = (n) => { if (counter) counter.textContent = Math.max(0, Number(counter.textContent) + n); };

const form = document.querySelector('[data-comment-form]');
if (form) {
  liveValidation(form);
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!validateForm(form)) return;
    const btn = form.querySelector('[type="submit"]');
    busy(btn, true);
    try {
      const { comment } = await api(`/reviews/${form.dataset.commentForm}/comments`, { method: 'POST', body: { body: form.body.value } });
      // Ajout immédiat dans la liste (texte inséré comme texte, jamais comme HTML).
      const li = document.createElement('li');
      li.className = 'comment is-new';
      li.dataset.comment = comment.id;
      const author = document.createElement('a');
      author.className = 'comment-author';
      author.href = `/membre/${comment.username}`;
      const av = document.createElement('span');
      av.className = `avatar${comment.avatar ? ' avatar-img' : ''}`;
      av.setAttribute('aria-hidden', 'true');
      if (comment.avatar) { const img = document.createElement('img'); img.src = comment.avatar; img.alt = ''; av.append(img); } else av.textContent = comment.displayName.slice(0, 1).toUpperCase();
      const name = document.createElement('strong');
      name.textContent = comment.displayName;
      author.append(av, ' ', name);
      const time = document.createElement('time');
      time.textContent = 'à l\'instant';
      const body = document.createElement('p');
      body.className = 'comment-body';
      body.textContent = comment.body;
      const actions = document.createElement('div');
      actions.className = 'comment-actions';
      const del = document.createElement('button');
      del.type = 'button';
      del.className = 'text-btn';
      del.dataset.deleteComment = comment.id;
      del.textContent = 'Supprimer';
      actions.append(del);
      li.append(author, time, body, actions);
      list.append(li);
      document.querySelector('[data-no-comment]')?.remove();
      bump(1);
      form.reset();
      toast('Commentaire publié');
    } catch (err) {
      if (err.status === 401) return loginRedirect();
      showServerErrors(form, err);
    }
    busy(btn, false);
  });
}

list?.addEventListener('click', async (e) => {
  const del = e.target.closest('[data-delete-comment]');
  if (del) {
    if (!confirm('Supprimer ce commentaire ?')) return;
    try {
      await api(`/comments/${del.dataset.deleteComment}`, { method: 'DELETE' });
      del.closest('.comment').remove();
      bump(-1);
      toast('Commentaire supprimé');
    } catch (err) { fail(err); }
    return;
  }
  const report = e.target.closest('[data-report-comment]');
  if (report) {
    const reason = prompt('Pourquoi signales-tu ce commentaire ? (insulte, harcèlement, spam…)');
    if (!reason || reason.trim().length < 3) return;
    try {
      await api(`/comments/${report.dataset.reportComment}/report`, { method: 'POST', body: { reason: reason.trim() } });
      report.disabled = true;
      report.textContent = 'Signalé';
      toast('Merci, le signalement a été transmis.');
    } catch (err) { fail(err); }
  }
});
