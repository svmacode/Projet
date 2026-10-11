// Fiche rappeur : artistes similaires et featurings (Deezer), chargés après l'affichage de la page.
import { api } from '../lib/api.js';

const box = document.querySelector('[data-artist-extra]');
if (box) {
  const chips = (list) => list.map((x) => {
    const el = document.createElement(x.slug ? 'a' : 'span');
    el.className = 'chip';
    if (x.slug) el.href = `/rappeur/${x.slug}`;
    el.textContent = x.n ? `${x.name} · ${x.n}` : x.name;
    return el;
  });
  api(`/artists/${box.dataset.artistExtra}/extra`).then(({ similar, featurings }) => {
    if (similar?.length) {
      box.querySelector('[data-extra-similar-list]').replaceChildren(...chips(similar));
      box.querySelector('[data-extra-similar]').hidden = false;
    }
    if (featurings?.length) {
      box.querySelector('[data-extra-feats-list]').replaceChildren(...chips(featurings));
      box.querySelector('[data-extra-feats]').hidden = false;
    }
    box.hidden = !(similar?.length || featurings?.length);
  }).catch(() => {});
}
