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

// ---------- Page d'une liste (aussi à plusieurs) ----------
const listPage = document.querySelector('[data-list]');
if (listPage) {
  const id = listPage.dataset.list;
  const renumber = () => {
    const items = [...listPage.querySelectorAll('.list-item')];
    items.forEach((li, i) => {
      li.querySelector('.list-rank').textContent = i + 1;
      const up = li.querySelector('[data-move="up"]');
      const down = li.querySelector('[data-move="down"]');
      if (up) up.disabled = i === 0;
      if (down) down.disabled = i === items.length - 1;
    });
  };

  listPage.addEventListener('click', async (e) => {
    const remove = e.target.closest('[data-remove-item]');
    if (remove) {
      try {
        await api(`/lists/${id}/items/${remove.dataset.removeItem}`, { method: 'DELETE' });
        remove.closest('li').remove();
        renumber();
        toast('Album retiré de la liste');
      } catch (err) { fail(err); }
      return;
    }
    const move = e.target.closest('[data-move]');
    if (move) {
      const li = move.closest('.list-item');
      try {
        await api(`/lists/${id}/items/${li.dataset.item}/move`, { method: 'POST', body: { direction: move.dataset.move } });
        if (move.dataset.move === 'up' && li.previousElementSibling) li.previousElementSibling.before(li);
        if (move.dataset.move === 'down' && li.nextElementSibling) li.nextElementSibling.after(li);
        renumber();
        move.focus();
      } catch (err) { fail(err); }
      return;
    }
    const removeCollab = e.target.closest('[data-remove-collab]');
    if (removeCollab) {
      try {
        await api(`/lists/${id}/collaborators/${removeCollab.dataset.removeCollab}`, { method: 'DELETE' });
        removeCollab.closest('li').remove();
        toast('Invité retiré');
      } catch (err) { fail(err); }
      return;
    }
    const leave = e.target.closest('[data-leave-list]');
    if (leave && confirm('Quitter cette liste ? Tu ne pourras plus la modifier.')) {
      try {
        await api(`/lists/${id}/collaborators/${leave.dataset.leaveList}`, { method: 'DELETE' });
        location.reload();
      } catch (err) { fail(err); }
    }
  });

  // Notes : enregistrées automatiquement quand on quitte le champ.
  listPage.addEventListener('change', async (e) => {
    const note = e.target.closest('[data-note]');
    if (!note) return;
    try {
      await api(`/lists/${id}/items/${note.dataset.note}`, { method: 'PUT', body: { note: note.value } });
      toast('Note enregistrée');
    } catch (err) { fail(err); }
  });

  listPage.querySelector('[data-collab-form]')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const form = e.currentTarget;
    const btn = form.querySelector('[type="submit"]');
    busy(btn, true);
    try {
      await api(`/lists/${id}/collaborators`, { method: 'POST', body: { username: form.username.value } });
      toast('Invitation envoyée');
      location.reload();
    } catch (err) { fail(err); busy(btn, false); }
  });
}

document.querySelector('[data-delete-list]')?.addEventListener('click', async (e) => {
  if (!confirm('Supprimer définitivement cette liste ?')) return;
  try {
    await api(`/lists/${e.currentTarget.dataset.deleteList}`, { method: 'DELETE' });
    history.length > 1 ? history.back() : (location.href = '/');
  } catch (err) { fail(err); }
});
