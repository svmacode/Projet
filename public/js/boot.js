// Chargé en premier, de façon bloquante, avant l'affichage :
// thème choisi par le visiteur, JavaScript et mouvement disponibles, écran de chargement.
(function () {
  var html = document.documentElement;
  html.classList.remove('no-js');
  html.classList.add('js');

  // Thème imposé par le visiteur (bouton lune / soleil) : appliqué avant le premier rendu, sans flash.
  try {
    var theme = localStorage.getItem('mrf-theme');
    if (theme === 'dark' || theme === 'light') {
      html.dataset.theme = theme;
      html.classList.remove('theme-dark', 'theme-light');
      html.classList.add('theme-' + theme);
    }
  } catch (e) { /* stockage indisponible */ }

  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  html.classList.add(reduce ? 'reduce-motion' : 'has-motion');

  // Écran de chargement : seulement à la première page de la visite, et jamais plus de 2,5 s.
  try {
    if (!reduce && !sessionStorage.getItem('mrf-visited')) {
      html.classList.add('is-loading');
      sessionStorage.setItem('mrf-visited', '1');
      setTimeout(function () { html.classList.remove('is-loading'); }, 2500);
    }
  } catch (e) { /* stockage indisponible : pas d'écran de chargement */ }

  // Filet de sécurité : si les scripts d'animation ne démarrent pas, tout le contenu reste visible.
  setTimeout(function () {
    if (!window.__mrfReady) { html.classList.remove('has-motion'); html.classList.add('reduce-motion'); }
  }, 4000);
})();
