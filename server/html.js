// Mini moteur de gabarits : `html` échappe automatiquement chaque valeur insérée.
const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

class Raw {
  constructor(value) { this.value = value; }
  toString() { return this.value; }
}

export const raw = (value) => new Raw(String(value));
export const escape = (value) => String(value).replace(/[&<>"']/g, (c) => ESC[c]);

function render(value) {
  if (value == null || value === false) return '';
  if (value instanceof Raw) return value.value;
  if (Array.isArray(value)) return value.map(render).join('');
  return escape(value);
}

export function html(strings, ...values) {
  let out = strings[0];
  for (let i = 0; i < values.length; i++) out += render(values[i]) + strings[i + 1];
  return new Raw(out);
}

// JSON sûr à placer dans une balise <script type="application/ld+json">.
export const jsonForScript = (data) => raw(JSON.stringify(data).replace(/</g, '\\u003c'));
