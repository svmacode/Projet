// Appels à l'API de MyRapFr, avec le jeton CSRF de la session.
export class ApiError extends Error {
  constructor(message, status, fields = {}) {
    super(message);
    this.status = status;
    this.fields = fields;
  }
}

const csrf = () => document.querySelector('meta[name="csrf-token"]')?.content || '';

export async function api(path, { method = 'GET', body } = {}) {
  let res;
  try {
    res = await fetch(`/api/v1${path}`, {
      method,
      credentials: 'same-origin',
      headers: {
        Accept: 'application/json',
        ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        ...(method !== 'GET' ? { 'X-CSRF-Token': csrf() } : {}),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new ApiError('Connexion impossible. Vérifie ton réseau et réessaie.', 0);
  }
  let data = {};
  try { data = await res.json(); } catch { /* réponse vide */ }
  if (res.status === 401) {
    throw new ApiError(data.error || 'Connecte-toi pour continuer.', 401);
  }
  if (!res.ok) throw new ApiError(data.error || 'Une erreur est survenue.', res.status, data.fields);
  return data;
}

export function loginRedirect() {
  location.href = `/connexion?retour=${encodeURIComponent(location.pathname + location.search)}`;
}
