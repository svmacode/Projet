// Profils et listes : suivre un membre, créer une liste, la modifier.
import { api, loginRedirect } from '../lib/api.js';
import { toast, validateForm, liveValidation, showServerErrors, busy } from '../lib/ui.js';

const fail = (err) => (err.status === 401 ? loginRedirect() : toast(err.message, { error: true }));

const follow = document.querySelector('[data-follow]');
follow?.addEventListener('click', async () => {
  const following = follow.getAttribute('aria-pressed') === 'true';
  busy(follow, true);
  try {
    const res = await api(`/users/${follow.dataset.follow}/follow`, { method: following ? 'DELETE' : 'POST' });
    follow.setAttribute('aria-pressed', String(res.following));
    follow.textContent = res.following ? (res.friends ? 'Amis' : 'Abonné') : 'Suivre';
    follow.classList.toggle('btn-primary', !res.following);
    follow.classList.toggle('btn-quiet', res.following);
    const counter = document.querySelector('[data-followers]');
    if (counter) counter.textContent = Number(counter.textContent) + (res.following ? 1 : -1);
    toast(res.following ? (res.friends ? 'Vous êtes maintenant amis' : 'Abonnement ajouté') : 'Abonnement retiré');
  } catch (err) { fail(err); }
  busy(follow, false);
});

const newList = document.querySelector('[data-new-list]');
if (newList) {
  liveValidation(newList);
  newList.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!validateForm(newList)) return;
    const btn = newList.querySelector('[type="submit"]');
    busy(btn, true);
    try {
      const { id } = await api('/lists', { method: 'POST', body: { title: newList.title.value } });
      location.href = `/liste/${id}`;
    } catch (err) {
      if (err.status === 401) return loginRedirect();
      showServerErrors(newList, err);
    }
    busy(btn, false);
  });
}

const listGrid = document.querySelector('[data-list]');
listGrid?.addEventListener('click', async (e) => {
  const btn = e.target.closest('[data-remove-item]');
  if (!btn) return;
  try {
    await api(`/lists/${listGrid.dataset.list}/items/${btn.dataset.removeItem}`, { method: 'DELETE' });
    btn.closest('li').remove();
    toast('Album retiré de la liste');
  } catch (err) { fail(err); }
});

document.querySelector('[data-delete-list]')?.addEventListener('click', async (e) => {
  if (!confirm('Supprimer définitivement cette liste ?')) return;
  try {
    await api(`/lists/${e.currentTarget.dataset.deleteList}`, { method: 'DELETE' });
    history.length > 1 ? history.back() : (location.href = '/');
  } catch (err) { fail(err); }
});
