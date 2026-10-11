// Inscription, connexion, mot de passe, paramètres du compte et préférences cookies.
import { api } from '../lib/api.js';
import { toast, validateForm, liveValidation, showServerErrors, busy, formData, setFormError, clearErrors } from '../lib/ui.js';
import { readConsent, writeConsent } from '../app.js';
import { storedUtm } from '../lib/extras.js';

function bind(name, handler) {
  const form = document.querySelector(`[data-form="${name}"]`);
  if (!form) return;
  liveValidation(form);
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!validateForm(form)) return;
    const btn = form.querySelector('[type="submit"]');
    busy(btn, true);
    try {
      await handler(formData(form), form);
    } catch (err) {
      showServerErrors(form, err);
    } finally {
      busy(btn, false);
    }
  });
}

const success = (form, message) => {
  const el = form.querySelector('[data-form-success]');
  if (el) el.textContent = message; else toast(message);
};

bind('register', async (d) => {
  const { user } = await api('/auth/register', {
    method: 'POST',
    body: { username: d.username, email: d.email, password: d.password, terms: d.terms, formToken: d.formToken, website: d.website, utm: storedUtm() },
  });
  location.href = `/membre/${user.username}?bienvenue=1`;
});

bind('login', async (d, form) => {
  await api('/auth/login', { method: 'POST', body: { login: d.login, password: d.password, formToken: d.formToken, website: d.website } });
  location.href = form.dataset.back || '/';
});

bind('forgot', async (d, form) => {
  await api('/auth/forgot', { method: 'POST', body: { email: d.email, formToken: d.formToken, website: d.website } });
  success(form, 'Si un compte existe avec cette adresse, un lien vient d’être envoyé. Pense à vérifier tes indésirables.');
  form.reset();
});

bind('reset', async (d, form) => {
  await api('/auth/reset', { method: 'POST', body: { token: d.token, password: d.password } });
  form.innerHTML = '<p class="form-success">Mot de passe modifié. <a href="/connexion">Connecte-toi</a> avec ton nouveau mot de passe.</p>';
});

bind('profile', async (d, form) => {
  // Les favoris sont saisis par titre : on retrouve l'identifiant de l'album dans la liste proposée.
  const options = [...document.querySelectorAll('#albums-list option')];
  const favorites = [];
  for (const input of form.querySelectorAll('[name="favorite"]')) {
    const value = input.value.trim();
    if (!value) continue;
    const match = options.find((o) => o.value === value);
    if (!match) {
      setFormError(form, `« ${value} » ne fait pas partie du catalogue. Choisis un album dans la liste.`);
      input.focus();
      return;
    }
    favorites.push(match.dataset.slug);
  }
  await api('/me', { method: 'PUT', body: { displayName: d.displayName, bio: d.bio, favorites } });
  clearErrors(form);
  toast('Profil enregistré');
});

bind('password', async (d, form) => {
  await api('/me/password', { method: 'PUT', body: { current: d.current, password: d.password } });
  form.reset();
  success(form, 'Mot de passe modifié. Tes autres appareils ont été déconnectés.');
});

bind('delete', async (d) => {
  if (!confirm('Dernière confirmation : supprimer ton compte et toutes tes données ?')) return;
  try {
    await api('/me', { method: 'DELETE', body: { password: d['delete-password'] } });
  } catch (err) {
    // Le serveur nomme le champ « password » ; dans ce formulaire il s'appelle « delete-password ».
    if (err.fields?.password) err.fields = { 'delete-password': err.fields.password };
    throw err;
  }
  location.href = '/?compte-supprime=1';
});

document.querySelector('[data-logout]')?.addEventListener('click', async () => {
  await api('/auth/logout', { method: 'POST' }).catch(() => {});
  location.href = '/';
});
document.querySelector('[data-logout-all]')?.addEventListener('click', async () => {
  if (!confirm('Te déconnecter de tous tes appareils ?')) return;
  await api('/auth/logout-all', { method: 'POST' }).catch(() => {});
  location.href = '/connexion';
});
document.querySelector('[data-resend]')?.addEventListener('click', async (e) => {
  try {
    await api('/auth/resend', { method: 'POST' });
    toast('Lien de confirmation renvoyé');
    e.target.disabled = true;
  } catch (err) { toast(err.message, { error: true }); }
});

// Confirmation de l'adresse e-mail depuis le lien reçu.
const confirmBox = document.querySelector('[data-confirm]');
if (confirmBox) {
  const status = confirmBox.querySelector('[data-confirm-status]');
  api('/auth/verify', { method: 'POST', body: { token: confirmBox.dataset.confirm } })
    .then(() => { status.innerHTML = 'Adresse confirmée. Tu peux maintenant publier tes chroniques. <a href="/albums">Explorer les albums</a>'; })
    .catch((err) => { status.textContent = err.message; });
}

// Page cookies : afficher et modifier le choix.
const consentStatus = document.querySelector('[data-consent-status]');
if (consentStatus) {
  const show = () => {
    const c = readConsent();
    consentStatus.textContent = `Choix actuel : ${c ? (c.choice === 'accept' ? 'accepté' : 'refusé') : 'non défini'}.`;
  };
  show();
  document.addEventListener('consent-change', show);
  document.querySelector('[data-consent-reset]')?.addEventListener('click', () => {
    try { localStorage.removeItem('mrf-consent'); } catch { /* ignoré */ }
    const banner = document.querySelector('[data-consent]');
    if (banner) {
      banner.hidden = false;
      banner.addEventListener('click', (e) => {
        const btn = e.target.closest('[data-consent-choice]');
        if (!btn) return;
        writeConsent(btn.dataset.consentChoice);
        banner.hidden = true;
        show();
      }, { once: true });
    }
    show();
  });
}


// ---------- Photo de profil ----------
const editor = document.querySelector('[data-avatar-editor]');
if (editor) {
  const preview = editor.querySelector('[data-avatar-preview]');
  const removeBtn = editor.querySelector('[data-avatar-remove]');
  const fileInput = editor.querySelector('[data-avatar-file]');
  const results = editor.querySelector('[data-avatar-results]');
  const initial = preview.textContent.trim();

  // Met à jour l'aperçu, le rond du menu et l'état des pochettes.
  const show = (url, album = null) => {
    const html = (cls) => (url
      ? `<span class="avatar avatar-img ${cls}" aria-hidden="true"><img src="${url}" alt="" width="96" height="96"></span>`
      : `<span class="avatar ${cls}" aria-hidden="true">${initial}</span>`);
    preview.innerHTML = html('avatar-xxl');
    const me = document.querySelector('.gnav-me');
    if (me) me.innerHTML = url ? `<img src="${url}" alt="" width="64" height="64">` : (document.querySelector('[name="displayName"]')?.value || initial).slice(0, 1).toUpperCase();
    removeBtn.hidden = !url;
    editor.querySelectorAll('[data-avatar-album]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.avatarAlbum === album)));
  };

  fileInput.addEventListener('change', async () => {
    const file = fileInput.files[0];
    fileInput.value = '';
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) return toast('Image trop lourde : 5 Mo maximum.', { error: true });
    const label = editor.querySelector('label[for="avatar-file"]');
    busy(label, true);
    try {
      const { avatar } = await api('/me/avatar', { method: 'POST', file });
      show(avatar);
      toast('Photo de profil mise à jour');
    } catch (err) { toast(err.message, { error: true }); }
    busy(label, false);
  });

  editor.addEventListener('click', async (e) => {
    const pick = e.target.closest('[data-avatar-album]');
    if (!pick) return;
    try {
      const { avatar } = await api('/me/avatar', { method: 'PUT', body: { album: pick.dataset.avatarAlbum } });
      show(avatar, pick.dataset.avatarAlbum);
      toast('Pochette choisie comme photo de profil');
    } catch (err) { toast(err.message, { error: true }); }
  });

  removeBtn.addEventListener('click', async () => {
    try {
      await api('/me/avatar', { method: 'DELETE' });
      show(null);
      toast('Photo de profil retirée');
    } catch (err) { toast(err.message, { error: true }); }
  });

  // Recherche d'une autre pochette dans tout le catalogue.
  let timer;
  editor.querySelector('[data-avatar-search]').addEventListener('input', (e) => {
    clearTimeout(timer);
    const text = e.target.value.trim();
    if (text.length < 2) { results.replaceChildren(); return; }
    timer = setTimeout(async () => {
      try {
        const { albums } = await api(`/albums?q=${encodeURIComponent(text)}&par=18&tri=popular`);
        results.replaceChildren(...albums.map((a) => {
          const b = document.createElement('button');
          b.type = 'button';
          b.className = 'avatar-pick';
          b.dataset.avatarAlbum = a.slug;
          b.setAttribute('aria-pressed', 'false');
          b.setAttribute('aria-label', `${a.title}, ${a.artist.name}`);
          b.title = `${a.title} — ${a.artist.name}`;
          const img = document.createElement('img');
          img.src = `${a.cover}-300.webp${a.v || ''}`;
          img.alt = '';
          img.width = 64;
          img.height = 64;
          img.loading = 'lazy';
          b.append(img);
          return b;
        }));
        if (!albums.length) results.textContent = 'Aucun album trouvé.';
      } catch { /* recherche indisponible : on n'insiste pas */ }
    }, 250);
  });
}

// ---------- Membres bloqués ----------
document.querySelector('[data-blocked-panel]')?.addEventListener('click', async (e) => {
  const btn = e.target.closest('[data-unblock]');
  if (!btn) return;
  busy(btn, true);
  try {
    await api(`/users/${btn.dataset.unblock}/block`, { method: 'DELETE' });
    btn.closest('li').remove();
    toast('Membre débloqué');
  } catch (err) { toast(err.message, { error: true }); busy(btn, false); }
});

// ---------- Résumé hebdomadaire ----------
document.querySelector('[data-digest]')?.addEventListener('change', async (e) => {
  const box = e.currentTarget;
  try {
    const { enabled } = await api('/me/digest', { method: 'PUT', body: { enabled: box.checked } });
    toast(enabled ? 'Tu recevras le résumé chaque lundi' : 'Résumé hebdomadaire désactivé');
  } catch (err) {
    box.checked = !box.checked;
    toast(err.message, { error: true });
  }
});
