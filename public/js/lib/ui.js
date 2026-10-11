// Petites briques d'interface partagées : notifications et validation des formulaires.
let toastTimer;
export function toast(message, { error = false } = {}) {
  const el = document.querySelector('[data-toast]');
  if (!el) return;
  el.textContent = message;
  el.classList.toggle('is-error', error);
  el.classList.add('is-visible');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('is-visible'), 3200);
}

// Messages en français, plus clairs que ceux du navigateur.
function messageFor(input) {
  const v = input.validity;
  if (v.valueMissing) return input.type === 'checkbox' ? 'Coche cette case pour continuer.' : 'Ce champ est obligatoire.';
  if (v.typeMismatch && input.type === 'email') return 'Adresse e-mail invalide (exemple : nom@domaine.fr).';
  if (v.tooShort) return `Au moins ${input.minLength} caractères (actuellement ${input.value.length}).`;
  if (v.tooLong) return `${input.maxLength} caractères maximum.`;
  if (v.patternMismatch) return input.name === 'username' ? 'Lettres, chiffres et _ uniquement.' : 'Format invalide.';
  if (v.rangeOverflow) return 'Cette date est dans le futur.';
  if (v.badInput) return 'Valeur invalide.';
  return '';
}

function errorSlot(form, name) {
  return form.querySelector(`[data-error-for="${name}"]`);
}

export function setFieldError(form, name, message) {
  const slot = errorSlot(form, name);
  const input = form.querySelector(`[name="${name}"]`) || form.querySelector(`#${CSS.escape(name)}`);
  if (slot) slot.textContent = message || '';
  if (input) input.setAttribute('aria-invalid', message ? 'true' : 'false');
}

export function clearErrors(form) {
  form.querySelectorAll('[data-error-for]').forEach((el) => { el.textContent = ''; });
  form.querySelectorAll('[aria-invalid]').forEach((el) => el.setAttribute('aria-invalid', 'false'));
  const general = form.querySelector('[data-form-error]');
  if (general) general.textContent = '';
}

export function setFormError(form, message) {
  const general = form.querySelector('[data-form-error]');
  if (general) general.textContent = message;
  else toast(message, { error: true });
}

// Validation côté navigateur, avant tout envoi. Retourne true si tout est bon.
export function validateForm(form) {
  clearErrors(form);
  let first = null;
  for (const input of form.querySelectorAll('input, textarea, select')) {
    if (input.type === 'hidden' || input.closest('.hp')) continue;
    if (!input.checkValidity()) {
      setFieldError(form, input.name || input.id, messageFor(input));
      first ??= input;
    }
  }
  if (first) first.focus();
  return !first;
}

// Valide chaque champ dès qu'on le quitte, puis en direct une fois en erreur.
export function liveValidation(form) {
  form.addEventListener('blur', (e) => {
    const input = e.target;
    if (!(input instanceof HTMLInputElement || input instanceof HTMLTextAreaElement) || input.type === 'hidden') return;
    if (input.value === '' && !input.required) return;
    setFieldError(form, input.name || input.id, input.checkValidity() ? '' : messageFor(input));
  }, true);
  form.addEventListener('input', (e) => {
    const input = e.target;
    if (input.getAttribute('aria-invalid') === 'true' && input.checkValidity()) setFieldError(form, input.name || input.id, '');
  });
}

export function showServerErrors(form, err) {
  if (err.fields && Object.keys(err.fields).length) {
    let first = null;
    for (const [name, message] of Object.entries(err.fields)) {
      setFieldError(form, name, message);
      first ??= form.querySelector(`[name="${name}"]`);
    }
    first?.focus();
  }
  setFormError(form, err.message);
}

export function busy(button, on) {
  if (!button) return;
  button.toggleAttribute('disabled', on);
  button.setAttribute('aria-busy', on ? 'true' : 'false');
}

export function formData(form) {
  const out = {};
  for (const el of form.elements) {
    if (!el.name || el.disabled) continue;
    if (el.type === 'checkbox') out[el.name] = el.checked;
    else if (el.type === 'radio') { if (el.checked) out[el.name] = el.value; }
    else out[el.name] = el.value;
  }
  return out;
}
