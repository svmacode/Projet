// Modération : chaque bouton appelle l'API d'administration, après une raison ou une confirmation.
import { api } from '../lib/api.js';
import { toast, busy } from '../lib/ui.js';

document.addEventListener('click', async (e) => {
  const btn = e.target.closest('[data-mod-url]');
  if (!btn) return;
  let body;
  if (btn.dataset.modAsk) {
    const reason = prompt(btn.dataset.modAsk);
    if (reason === null) return;
    if (reason.trim().length < 3) return toast('Indique une raison (3 caractères minimum).', { error: true });
    body = { reason: reason.trim() };
  } else if (btn.dataset.modConfirm && !confirm(btn.dataset.modConfirm)) return;
  busy(btn, true);
  try {
    await api(btn.dataset.modUrl, { method: 'POST', body: body || {} });
    toast('C\'est fait.');
    setTimeout(() => location.reload(), 500);
  } catch (err) {
    toast(err.message, { error: true });
    busy(btn, false);
  }
});
