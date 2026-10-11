// Boutons « Suivre » (profil, page Amis, résultats de recherche) : un seul gestionnaire pour tous.
import { api, loginRedirect } from './api.js';
import { toast, busy } from './ui.js';

export const followLabel = (following, followsMe) => (following ? (followsMe ? 'Amis' : 'Abonné') : followsMe ? 'Suivre en retour' : 'Suivre');

export function initFollow(root = document) {
  root.addEventListener('click', async (e) => {
    const btn = e.target.closest('[data-follow]');
    if (!btn) return;
    const following = btn.getAttribute('aria-pressed') === 'true';
    const followsMe = btn.dataset.followsMe === '1';
    if (following && followsMe && !confirm(`Ne plus suivre @${btn.dataset.follow} ? Vous ne serez plus amis.`)) return;
    busy(btn, true);
    try {
      const res = await api(`/users/${btn.dataset.follow}/follow`, { method: following ? 'DELETE' : 'POST' });
      btn.setAttribute('aria-pressed', String(res.following));
      btn.textContent = followLabel(res.following, followsMe);
      btn.classList.toggle('btn-primary', !res.following);
      btn.classList.toggle('btn-quiet', res.following);
      // Compteur d'abonnés du profil affiché.
      if (btn.hasAttribute('data-follow-count')) {
        const counter = document.querySelector('[data-followers]');
        if (counter) counter.textContent = Number(counter.textContent) + (res.following ? 1 : -1);
      }
      toast(res.following ? (res.friends ? `Vous êtes maintenant amis avec @${btn.dataset.follow}` : `Tu suis @${btn.dataset.follow}`) : 'Abonnement retiré');
    } catch (err) {
      if (err.status === 401) loginRedirect(); else toast(err.message, { error: true });
    }
    busy(btn, false);
  });
}
