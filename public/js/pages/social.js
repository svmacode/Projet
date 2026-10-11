// Profils, page Amis et listes : suivre un membre, en chercher un, créer une liste, la modifier.
import { api, loginRedirect } from '../lib/api.js';
import { toast, validateForm, liveValidation, showServerErrors, busy } from '../lib/ui.js';
import { initFollow, followLabel } from '../lib/follow.js';

const fail = (err) => (err.status === 401 ? loginRedirect() : toast(err.message, { error: true }));

initFollow();

// ---------- Bloquer et signaler un membre (profil) ----------
document.querySelector('[data-block]')?.addEventListener('click', async (e) => {
  const btn = e.currentTarget;
  const blocked = btn.getAttribute('aria-pressed') === 'true';
  if (!blocked && !confirm(`Bloquer @${btn.dataset.block} ? Vos abonnements mutuels seront retirés, vous ne verrez plus vos chroniques respectives et ce membre ne pourra plus te suivre ni voir ton profil.`)) return;
  busy(btn, true);
  try {
    await api(`/users/${btn.dataset.block}/block`, { method: blocked ? 'DELETE' : 'POST' });
    toast(blocked ? 'Membre débloqué' : 'Membre bloqué');
    setTimeout(() => location.reload(), 400);
  } catch (err) { fail(err); busy(btn, false); }
});

document.querySelector('[data-report-user]')?.addEventListener('click', async (e) => {
  const btn = e.currentTarget;
  const reason = prompt('Pourquoi signaler ce profil ? (photo, nom ou bio inappropriés, usurpation…)');
  if (reason === null) return;
  if (reason.trim().length < 3) return toast('Précise la raison.', { error: true });
  try {
    await api(`/users/${btn.dataset.reportUser}/report`, { method: 'POST', body: { reason: reason.trim() } });
    btn.disabled = true;
    btn.textContent = 'Profil signalé';
    toast('Merci, la modération va examiner ce profil.');
  } catch (err) { fail(err); }
});

// ---------- Page Amis : recherche de membres ----------
const search = document.querySelector('[data-member-search]');
if (search) {
  const results = document.querySelector('[data-member-results]');
  const status = document.querySelector('[data-member-status]');
  let timer;
  const row = (u) => {
    const li = document.createElement('li');
    li.className = 'person';
    const link = document.createElement('a');
    link.className = 'person-id';
    link.href = `/membre/${u.username}`;
    const av = document.createElement('span');
    av.className = `avatar avatar-lg${u.avatar ? ' avatar-img' : ''}`;
    av.setAttribute('aria-hidden', 'true');
    if (u.avatar) {
      const img = document.createElement('img');
      img.src = u.avatar; img.alt = ''; img.width = 96; img.height = 96;
      av.append(img);
    } else av.textContent = (u.displayName || u.username).slice(0, 1).toUpperCase();
    const text = document.createElement('span');
    const name = document.createElement('strong');
    name.textContent = u.displayName;
    const meta = document.createElement('small');
    meta.textContent = `@${u.username} · ${u.listened} album${u.listened > 1 ? 's' : ''}${u.followsMe ? ' · te suit' : ''}`;
    text.append(name, ' ', meta);
    link.append(av, text);
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `btn btn-sm ${u.isFollowing ? 'btn-quiet' : 'btn-primary'}`;
    btn.dataset.follow = u.username;
    btn.dataset.followsMe = u.followsMe ? '1' : '0';
    btn.setAttribute('aria-pressed', String(u.isFollowing));
    btn.textContent = followLabel(u.isFollowing, u.followsMe);
    li.append(link, btn);
    return li;
  };
  search.addEventListener('input', () => {
    clearTimeout(timer);
    const text = search.value.trim();
    if (text.length < 2) { results.replaceChildren(); status.textContent = ''; return; }
    timer = setTimeout(async () => {
      try {
        const { users } = await api(`/users?q=${encodeURIComponent(text)}`);
        results.replaceChildren(...users.map(row));
        status.textContent = users.length ? `${users.length} membre${users.length > 1 ? 's' : ''} trouvé${users.length > 1 ? 's' : ''}` : 'Aucun membre ne correspond.';
      } catch (err) { fail(err); }
    }, 250);
  });
}

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
