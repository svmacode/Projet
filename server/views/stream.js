// « Corridor » de pochettes du héros : deux rails de cartes qui arrivent du fond vers le
// visiteur. Transposition sans React du composant ImageStreamHero : même géométrie, même
// échantillonnage de la trajectoire, mais les images-clés sont générées une fois côté serveur
// dans une feuille de style statique (la CSP interdit les <style> en ligne).
//
// Rappel du principe (voir le composant d'origine) :
//  1. la profondeur est exprimée en taille apparente, géométriquement : chaque carte est un
//     rapport constant plus grande que celle de derrière, le ruban reste plein aux deux bouts ;
//  2. les rails s'ouvrent fort au début puis se stabilisent (`fan` > 1) : le ruban quitte le
//     centre à plat, se courbe une fois, puis file en diagonale ;
//  3. aucune extrémité de la boucle n'est visible : une carte naît de l'autre côté de l'axe
//     (`railBirth` négatif) et meurt au-delà du bord du cadre.
// Toutes les longueurs sont en cqw (pourcentage de la largeur du conteneur).

export const STREAM = {
  perspective: 30,
  cardWidth: 21, // pochettes carrées : largeur = hauteur
  cardHeight: 21,
  cardRadius: 0.5,
  birthHeight: 2.6,
  exitHeight: 46,
  railBirth: -11,
  railExit: 44,
  fan: 3.3,
  turnBirth: 6,
  turnExit: 28,
  stops: 24,
  cards: 11, // cartes par rail
  speed: 24, // secondes pour traverser tout le corridor
  axis: 52, // position verticale de l'axe, en % de la hauteur
};

const SLOW = 3; // facteur de ralentissement quand le visiteur préfère moins de mouvement

// Position d'une carte à l'instant u (0 = au fond, 1 = sortie du cadre).
function place(dir, u, p) {
  const scale = (p.birthHeight / p.cardHeight) * Math.pow(p.exitHeight / p.birthHeight, u);
  const z = p.perspective * (1 - 1 / scale);
  const rail = p.railExit - (p.railExit - p.railBirth) * Math.pow(1 - u, p.fan);
  const turn = p.turnBirth + (p.turnExit - p.turnBirth) * u;
  return `transform:translate3d(${(dir * rail).toFixed(2)}cqw,0,${z.toFixed(2)}cqw) rotateY(${(-dir * turn).toFixed(2)}deg)`;
}

function keyframes(dir, name, p) {
  const steps = [];
  for (let s = 0; s <= p.stops; s++) {
    const u = s / p.stops;
    steps.push(`${(u * 100).toFixed(2)}%{${place(dir, u, p)}}`);
  }
  return `@keyframes ${name}{${steps.join('')}}`;
}

// Feuille de style complète du corridor, servie sur /css/stream.css.
export function streamCss(p = STREAM) {
  const delays = Array.from({ length: p.cards }, (_, i) => `.ish-i${i}{animation-delay:${(-(i * p.speed) / p.cards).toFixed(3)}s}`).join('');
  return [
    '.ish{position:absolute;inset:0;overflow:hidden;container-type:inline-size;pointer-events:none}',
    `.ish-stage{position:absolute;inset:0;perspective:${p.perspective}cqw;perspective-origin:50% ${p.axis}%}`,
    '.ish-3d{position:absolute;inset:0;transform-style:preserve-3d}',
    `.ish-card{position:absolute;left:50%;top:${p.axis}%;width:${p.cardWidth}cqw;height:${p.cardHeight}cqw;`
      + `margin-left:${-p.cardWidth / 2}cqw;margin-top:${-p.cardHeight / 2}cqw;border-radius:${p.cardRadius}cqw;`
      + `overflow:hidden;backface-visibility:hidden;background:#111;animation:${p.speed}s linear infinite;will-change:transform}`,
    '.ish-card img{width:100%;height:100%;object-fit:cover;display:block;user-select:none}',
    '.ish-r{animation-name:ish-r}.ish-l{animation-name:ish-l}',
    delays,
    keyframes(1, 'ish-r', p),
    keyframes(-1, 'ish-l', p),
    // Pause demandée par le visiteur (bouton du héros).
    '.ish.is-paused .ish-card{animation-play-state:paused}',
    // Mouvement réduit : le couloir défile trois fois plus lentement (dérive douce, sans à-coup),
    // et le bouton pause permet de l'arrêter. Les décalages sont recalculés pour la nouvelle durée,
    // sinon les cartes se regrouperaient.
    `@media (prefers-reduced-motion: reduce){.ish-card{animation-duration:${p.speed * SLOW}s}${
      Array.from({ length: p.cards }, (_, i) => `.ish-i${i}{animation-delay:${(-(i * p.speed * SLOW) / p.cards).toFixed(3)}s}`).join('')}}`,
  ].join('\n');
}
