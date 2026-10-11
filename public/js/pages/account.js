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

