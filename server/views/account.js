import { html, raw } from '../html.js';
import { antiSpamFields } from './components.js';

const field = ({ id, label, type = 'text', autocomplete, help, attrs = '', value = '' }) => html`
  <div class="field">
    <label for="${id}">${label}</label>
    <input id="${id}" name="${id}" type="${type}" ${raw(autocomplete ? `autocomplete="${autocomplete}"` : '')} value="${value}" ${raw(attrs)}
      aria-describedby="${id}-error${help ? ` ${id}-help` : ''}">
    ${help ? html`<p class="field-help" id="${id}-help">${help}</p>` : ''}
    <p class="field-error" id="${id}-error" data-error-for="${id}"></p>
  </div>`;

const authShell = (title, intro, form, aside = '') => html`
  <section class="auth">
    <div class="auth-card">
      <h1 class="auth-title">${title}</h1>
      ${intro ? html`<p class="auth-intro">${intro}</p>` : ''}
      ${form}
      ${aside}
    </div>
  </section>`;

export function registerPage({ formToken }) {
  return authShell('Créer ton compte', 'Gratuit, sans publicité. Il te faut juste un pseudo et une adresse e-mail.', html`
    <form class="form" data-form="register" novalidate>
      <p class="form-error" role="alert" data-form-error></p>
      ${field({ id: 'username', label: 'Pseudo', autocomplete: 'username', help: '3 à 24 caractères : lettres, chiffres et _.', attrs: 'required minlength="3" maxlength="24" pattern="[A-Za-z0-9_]+" autocapitalize="off" spellcheck="false"' })}
      ${field({ id: 'email', label: 'Adresse e-mail', type: 'email', autocomplete: 'email', attrs: 'required maxlength="254"' })}
      ${field({ id: 'password', label: 'Mot de passe', type: 'password', autocomplete: 'new-password', help: '10 caractères minimum. Une phrase courte est plus sûre et plus facile à retenir.', attrs: 'required minlength="10" maxlength="200"' })}
      <div class="field field-check">
        <input id="terms" name="terms" type="checkbox" required aria-describedby="terms-error">
        <label for="terms">J'accepte les <a href="/cgu" target="_blank">conditions d'utilisation</a> et j'ai lu la <a href="/confidentialite" target="_blank">politique de confidentialité</a>.</label>
        <p class="field-error" id="terms-error" data-error-for="terms"></p>
      </div>
      ${antiSpamFields(formToken)}
      <button class="btn btn-primary btn-block" type="submit">Créer mon compte</button>
    </form>`, html`<p class="auth-switch">Déjà inscrit ? <a href="/connexion">Connecte-toi</a></p>`);
}

export function loginPage({ formToken, back }) {
  return authShell('Connexion', '', html`
    <form class="form" data-form="login" data-back="${back}" novalidate>
      <p class="form-error" role="alert" data-form-error></p>
      ${field({ id: 'login', label: 'Pseudo ou e-mail', autocomplete: 'username', attrs: 'required maxlength="254" autocapitalize="off" spellcheck="false"' })}
      ${field({ id: 'password', label: 'Mot de passe', type: 'password', autocomplete: 'current-password', attrs: 'required maxlength="200"' })}
      ${antiSpamFields(formToken)}
      <button class="btn btn-primary btn-block" type="submit">Se connecter</button>
      <p class="auth-small"><a href="/mot-de-passe-oublie">Mot de passe oublié ?</a></p>
    </form>`, html`<p class="auth-switch">Pas encore de compte ? <a href="/inscription">Crée-le en une minute</a></p>`);
}

export function forgotPage({ formToken }) {
  return authShell('Mot de passe oublié', "Indique ton adresse : si un compte existe, tu recevras un lien pour choisir un nouveau mot de passe.", html`
    <form class="form" data-form="forgot" novalidate>
      <p class="form-error" role="alert" data-form-error></p>
      <p class="form-success" role="status" data-form-success></p>
      ${field({ id: 'email', label: 'Adresse e-mail', type: 'email', autocomplete: 'email', attrs: 'required maxlength="254"' })}
      ${antiSpamFields(formToken)}
      <button class="btn btn-primary btn-block" type="submit">Envoyer le lien</button>
    </form>`);
}

export function resetPage({ token }) {
  return authShell('Nouveau mot de passe', '', html`
    <form class="form" data-form="reset" novalidate>
      <p class="form-error" role="alert" data-form-error></p>
      <input type="hidden" name="token" value="${token}">
      ${field({ id: 'password', label: 'Nouveau mot de passe', type: 'password', autocomplete: 'new-password', help: '10 caractères minimum.', attrs: 'required minlength="10" maxlength="200"' })}
      <button class="btn btn-primary btn-block" type="submit">Enregistrer</button>
    </form>`);
}

export function confirmPage({ token }) {
  return authShell('Confirmation', '', html`
    <div data-confirm="${token}">
      <p class="auth-intro" role="status" data-confirm-status>Vérification en cours…</p>
    </div>`);
}

export function settingsPage({ me, albums }) {
  return html`
  <section class="page-head">
    <h1 class="display">Paramètres.</h1>
    <p class="lede">Ton profil, ta sécurité et tes données.</p>
  </section>
  <section class="settings">
    <form class="form panel" data-form="profile" novalidate>
      <h2 class="h-section">Profil public</h2>
      <p class="form-error" role="alert" data-form-error></p>
      ${field({ id: 'displayName', label: 'Nom affiché', value: me.display_name, attrs: 'required maxlength="40"' })}
      <div class="field">
        <label for="bio">Bio</label>
        <textarea id="bio" name="bio" rows="3" maxlength="300">${me.bio}</textarea>
        <p class="field-error" data-error-for="bio"></p>
      </div>
      <fieldset class="field">
        <legend>Tes 4 albums favoris</legend>
        <datalist id="albums-list">${albums.map((a) => html`<option value="${a.title} — ${a.artist.name}" data-slug="${a.slug}"></option>`)}</datalist>
        ${[0, 1, 2, 3].map((i) => {
          const a = albums.find((x) => x.slug === me.favorites[i]);
          return html`<input name="favorite" list="albums-list" aria-label="Favori ${i + 1}" placeholder="Favori ${i + 1}" value="${a ? `${a.title} — ${a.artist.name}` : ''}">`;
        })}
        <p class="field-error" data-error-for="favorites"></p>
      </fieldset>
      <button class="btn btn-primary" type="submit">Enregistrer</button>
    </form>

    <div class="panel">
      <h2 class="h-section">Adresse e-mail</h2>
      <p>${me.email} · ${me.email_verified_at ? 'confirmée' : html`<strong>non confirmée</strong> <button class="text-btn" type="button" data-resend>Renvoyer le lien</button>`}</p>
    </div>

    <form class="form panel" data-form="password" novalidate>
      <h2 class="h-section">Mot de passe</h2>
      <p class="form-error" role="alert" data-form-error></p>
      <p class="form-success" role="status" data-form-success></p>
      ${field({ id: 'current', label: 'Mot de passe actuel', type: 'password', autocomplete: 'current-password', attrs: 'required' })}
      ${field({ id: 'password', label: 'Nouveau mot de passe', type: 'password', autocomplete: 'new-password', help: '10 caractères minimum. Tes autres appareils seront déconnectés.', attrs: 'required minlength="10" maxlength="200"' })}
      <button class="btn btn-quiet" type="submit">Changer le mot de passe</button>
    </form>

    <div class="panel">
      <h2 class="h-section">Sessions</h2>
      <p>Déconnecte-toi de tous les appareils, y compris celui-ci.</p>
      <button class="btn btn-quiet" type="button" data-logout-all>Déconnecter partout</button>
      <button class="btn btn-quiet" type="button" data-logout>Se déconnecter</button>
    </div>

    <div class="panel">
      <h2 class="h-section">Tes données</h2>
      <p>Télécharge une copie de toutes tes données au format JSON (droit à la portabilité).</p>
      <a class="btn btn-quiet" href="/api/v1/me/export" download>Exporter mes données</a>
      <p><a href="/cookies">Préférences cookies</a></p>
    </div>

    <form class="form panel panel-danger" data-form="delete" novalidate>
      <h2 class="h-section">Supprimer mon compte</h2>
      <p>Ton compte, tes notes, chroniques, listes et abonnements seront effacés définitivement. Cette action est irréversible.</p>
      <p class="form-error" role="alert" data-form-error></p>
      ${field({ id: 'delete-password', label: 'Confirme avec ton mot de passe', type: 'password', autocomplete: 'current-password', attrs: 'required' })}
      <button class="btn btn-danger" type="submit">Supprimer définitivement</button>
    </form>
  </section>`;
}
