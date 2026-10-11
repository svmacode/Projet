// Import d'historique : aperçu des albums reconnus, puis confirmation.
import { api, loginRedirect } from '../lib/api.js';
import { toast, busy } from '../lib/ui.js';

const root = document.querySelector('[data-import]');
if (root) {
  const preview = root.querySelector('[data-import-preview]');
  const applyBtn = root.querySelector('[data-import-apply]');
  let pending = null; // fonction qui relance la même requête avec ?apply=1
  const fail = (err) => (err.status === 401 ? loginRedirect() : toast(err.message, { error: true }));

  // Excel sous Windows enregistre souvent en Windows-1252 : on essaie UTF-8, puis cet encodage.
  const readText = async (file) => {
    const buf = await file.arrayBuffer();
    try { return new TextDecoder('utf-8', { fatal: true }).decode(buf); } catch { return new TextDecoder('windows-1252').decode(buf); }
  };

  const item = (text) => { const li = document.createElement('li'); li.textContent = text; return li; };
  const show = (d) => {
    root.querySelector('[data-import-summary]').textContent = `${d.matched.length} album${d.matched.length > 1 ? 's' : ''} reconnu${d.matched.length > 1 ? 's' : ''} sur ${d.total} ligne${d.total > 1 ? 's' : ''}.`;
    root.querySelector('[data-import-matched]').replaceChildren(...d.matched.slice(0, 60).map((m) => item(`${m.artist} — ${m.title}${m.rating ? ` · ${m.rating / 2}/5` : ''}${m.date ? ` · ${m.date.split('-').reverse().join('/')}` : ''}`)),
      ...(d.matched.length > 60 ? [item(`… et ${d.matched.length - 60} autres`)] : []));
    const missingBox = root.querySelector('[data-import-missing-box]');
    missingBox.hidden = !d.unmatchedCount;
    root.querySelector('[data-import-missing-title]').textContent = `${d.unmatchedCount} non reconnu${d.unmatchedCount > 1 ? 's' : ''} (absents du catalogue ou orthographe différente)`;
    root.querySelector('[data-import-missing]').replaceChildren(...d.unmatched.map((m) => item(`${m.artist} — ${m.album}`)));
    applyBtn.disabled = !d.matched.length;
    applyBtn.textContent = `Importer ${d.matched.length} album${d.matched.length > 1 ? 's' : ''}`;
    preview.hidden = false;
    preview.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  root.querySelector('[data-import-file]').addEventListener('change', async (e) => {
    const file = e.target.files[0];
    e.target.value = '';
    if (!file) return;
    if (file.size > 2 * 1024 * 1024) return toast('Fichier trop lourd : 2 Mo maximum.', { error: true });
    const blob = new Blob([await readText(file)], { type: 'text/csv' });
    pending = () => api('/import/csv?apply=1', { method: 'POST', file: blob });
    try { show(await api('/import/csv', { method: 'POST', file: blob })); } catch (err) { fail(err); }
  });

  root.querySelector('[data-import-lastfm]')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const form = e.currentTarget;
    const btn = form.querySelector('[type="submit"]');
    const body = { username: form.username.value.trim() };
    busy(btn, true);
    pending = () => api('/import/lastfm?apply=1', { method: 'POST', body });
    try { show(await api('/import/lastfm', { method: 'POST', body })); } catch (err) { fail(err); }
    busy(btn, false);
  });

  applyBtn.addEventListener('click', async () => {
    if (!pending) return;
    busy(applyBtn, true);
    try {
      const { added } = await pending();
      toast(`${added} album${added > 1 ? 's' : ''} ajouté${added > 1 ? 's' : ''} à ton carnet`);
      preview.hidden = true;
      pending = null;
    } catch (err) { fail(err); }
    busy(applyBtn, false);
  });
  root.querySelector('[data-import-cancel]').addEventListener('click', () => { preview.hidden = true; pending = null; });
}
