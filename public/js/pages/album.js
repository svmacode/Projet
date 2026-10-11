// Page album : écouté, coup de cœur, à écouter, note, chronique, listes, j'aime et signalements.
import { api, loginRedirect } from '../lib/api.js';
import { toast, validateForm, liveValidation, showServerErrors, busy, formData } from '../lib/ui.js';

const album = document.querySelector('[data-album]');
const slug = album?.dataset.album;

function handleError(err) {
  if (err.status === 401) return loginRedirect();
  toast(err.message, { error: true });
}

// ---------- Boutons d'état ----------
album?.querySelectorAll('[data-toggle]').forEach((btn) => {
  btn.addEventListener('click', async () => {
    const key = btn.dataset.toggle;
    const next = btn.getAttribute('aria-pressed') !== 'true';
    btn.setAttribute('aria-pressed', String(next));
    try {
      const { state } = await api(`/albums/${slug}/state`, { method: 'PUT', body: { [key]: next } });
      syncState(state);
      toast({
        listened: next ? 'Marqué comme écouté' : 'Retiré de tes écoutes',
        liked: next ? 'Ajouté à tes coups de cœur' : 'Retiré de tes coups de cœur',
        wishlist: next ? 'Ajouté à « À écouter »' : 'Retiré de « À écouter »',
      }[key]);
    } catch (err) {
      btn.setAttribute('aria-pressed', String(!next));
      handleError(err);
    }
  });
});

function syncState(state) {
  for (const key of ['listened', 'liked', 'wishlist']) {
    album.querySelector(`[data-toggle="${key}"]`)?.setAttribute('aria-pressed', String(Boolean(state[key])));
  }
  setRating(state.rating || 0);
}

// ---------- Note en demi-étoiles ----------
const rate = album?.querySelector('[data-rate]');
const rateOn = rate?.querySelector('[data-rate-on]');
const clearBtn = rate?.querySelector('[data-rate-clear]');

function setRating(value, preview = false) {
  if (!rate) return;
  rateOn.style.width = `${value * 18}px`;
  if (!preview) {
    rate.dataset.value = value;
    rate.querySelectorAll('input').forEach((i) => { i.checked = Number(i.value) === value; });
    clearBtn.hidden = !value;
  }
}

if (rate) {
  setRating(Number(rate.dataset.value) || 0);
  const stars = rate.querySelector('.rate-stars');
  rate.querySelectorAll('.rate-half').forEach((label) => {
    const v = Number(label.querySelector('input').value);
    label.addEventListener('pointerenter', () => setRating(v, true));
  });
  stars.addEventListener('pointerleave', () => setRating(Number(rate.dataset.value) || 0, true));

  let saving = null;
  rate.addEventListener('change', async (e) => {
    const value = Number(e.target.value);
    setRating(value);
    saving = value;
    try {
      const { state } = await api(`/albums/${slug}/state`, { method: 'PUT', body: { rating: value } });
      if (saving === value) syncState(state);
      toast(`Noté ${String(value / 2).replace('.', ',')} sur 5`);
    } catch (err) { handleError(err); }
  });
  clearBtn.addEventListener('click', async () => {
    try {
      const { state } = await api(`/albums/${slug}/state`, { method: 'PUT', body: { rating: null } });
      syncState(state);
      toast('Note effacée');
    } catch (err) { handleError(err); }
  });
}

// ---------- Chronique ----------
const form = document.querySelector('[data-review-form]');
const opener = document.querySelector('[data-open-review]');
opener?.addEventListener('click', () => {
  form.hidden = !form.hidden;
  opener.setAttribute('aria-expanded', String(!form.hidden));
  if (!form.hidden) {
    form.querySelector('textarea').focus();
    window.ScrollTrigger?.refresh();
  }
});

if (form) {
  liveValidation(form);
  const textarea = form.querySelector('textarea');
  const counter = form.querySelector('[data-count-for="body"]');
  textarea.addEventListener('input', () => { counter.textContent = textarea.value.length.toLocaleString('fr-FR'); });

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!validateForm(form)) return;
    const data = formData(form);
    const btn = form.querySelector('[type="submit"]');
    busy(btn, true);
    try {
      const rating = Number(rate?.dataset.value) || null;
      await api(`/albums/${slug}/reviews`, {
        method: 'POST',
        body: { body: data.body, listenedOn: data.listenedOn, rating, formToken: data.formToken, website: data.website },
      });
      toast('Chronique publiée');
      setTimeout(() => location.reload(), 600);
    } catch (err) {
      if (err.status === 401) return loginRedirect();
      showServerErrors(form, err);
    } finally {
      busy(btn, false);
    }
  });
}

// ---------- Listes ----------
document.querySelector('[data-add-to-list]')?.addEventListener('change', async (e) => {
  const select = e.target;
  if (!select.value) return;
  try {
    await api(`/lists/${select.value}/items`, { method: 'POST', body: { album: slug } });
    toast(`Ajouté à « ${select.selectedOptions[0].textContent} »`);
  } catch (err) { handleError(err); }
  select.value = '';
});

// ---------- Chroniques : j'aime, signaler, supprimer (aussi utilisé sur le fil d'actu) ----------
document.addEventListener('click', async (e) => {
  const like = e.target.closest('[data-like]:not([data-auth])');
  if (like) {
    try {
      const { liked, likes } = await api(`/reviews/${like.dataset.like}/like`, { method: 'POST' });
      like.setAttribute('aria-pressed', String(liked));
      like.querySelector('.like-count').textContent = likes;
    } catch (err) { handleError(err); }
    return;
  }
  const report = e.target.closest('[data-report]');
  if (report) {
    const reason = prompt('Pourquoi signales-tu cette chronique ? (propos haineux, spam, harcèlement…)');
    if (!reason) return;
    try {
      await api(`/reviews/${report.dataset.report}/report`, { method: 'POST', body: { reason } });
      toast('Merci, le signalement a été transmis.');
      report.disabled = true;
    } catch (err) { handleError(err); }
    return;
  }
  const del = e.target.closest('[data-delete-review]');
  if (del) {
    if (!confirm('Supprimer définitivement cette chronique ?')) return;
    try {
      await api(`/reviews/${del.dataset.deleteReview}`, { method: 'DELETE' });
      del.closest('.review').remove();
      toast('Chronique supprimée');
    } catch (err) { handleError(err); }
    return;
  }
  const resend = e.target.closest('[data-resend]');
  if (resend) {
    try {
      await api('/auth/resend', { method: 'POST' });
      toast('E-mail de confirmation renvoyé');
    } catch (err) { handleError(err); }
  }
});
