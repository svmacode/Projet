// Vérifie le contraste (WCAG 2.2) de chaque couple texte / fond utilisé sur le site.
// AA : 4,5:1 pour le texte courant, 3:1 pour le grand texte (24 px, ou 19 px gras).
const PAIRS = [
  // [description, texte, fond, grand texte ?]
  ['Texte principal, thème sombre', '#f5f5f7', '#000000'],
  ['Texte secondaire, thème sombre', '#a1a1a6', '#000000'],
  ['Texte tertiaire, thème sombre', '#86868b', '#000000'],
  ['Lien, thème sombre', '#2997ff', '#000000'],
  ['Texte secondaire sur surface sombre', '#a1a1a6', '#1d1d1f'],
  ['Pied de page sombre', '#a1a1a6', '#161617'],
  ['Titres défilants (grand texte)', '#6e6e73', '#000000', true],
  ['Texte principal, thème clair', '#1d1d1f', '#ffffff'],
  ['Texte secondaire, thème clair', '#6e6e73', '#ffffff'],
  ['Texte secondaire sur gris clair', '#6e6e73', '#f5f5f7'],
  ['Lien, thème clair', '#0066cc', '#ffffff'],
  ['Lien sur gris clair', '#0066cc', '#f5f5f7'],
  ['Bouton principal', '#ffffff', '#0071e3'],
  ['Bouton suppression', '#ffffff', '#d70015'],
  ['Erreur, thème clair', '#d70015', '#ffffff'],
  ['Erreur, thème sombre', '#ff6961', '#000000'],
  ['Puce active (catalogue)', '#1d1d1f', '#f5f5f7'],
  ['Bandeau cookies', '#f5f5f7', '#1d1d1f'],
  ['Lien du bandeau cookies', '#2997ff', '#1d1d1f'],
  ['Notification', '#1d1d1f', '#f5f5f7'],
  ['Succès, thème clair', '#1b7a34', '#ffffff'],
  ['Écouté (vert)', '#30d158', '#000000'],
  ['Coup de cœur (rose)', '#ff375f', '#000000'],
];

const lum = (hex) => {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const ratio = (a, b) => {
  const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
};

let failures = 0;
for (const [name, fg, bg, large] of PAIRS) {
  const r = ratio(fg, bg);
  const min = large ? 3 : 4.5;
  const ok = r >= min;
  if (!ok) failures++;
  console.log(`${ok ? 'OK ' : 'NON'}  ${r.toFixed(2).padStart(5)}:1  (min ${min})  ${name}`);
}
console.log(failures ? `\n${failures} couple(s) insuffisant(s).` : '\nTous les contrastes respectent le niveau AA.');
process.exit(failures ? 1 : 0);
