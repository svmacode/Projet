// Chargé en premier, de façon bloquante : indique au CSS si le JS et le mouvement sont disponibles.
(function () {
  var html = document.documentElement;
  html.classList.remove('no-js');
  html.classList.add('js');
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  html.classList.add(reduce ? 'reduce-motion' : 'has-motion');
  // Filet de sécurité : si les scripts d'animation ne démarrent pas, tout le contenu reste visible.
  setTimeout(function () {
    if (!window.__mrfReady) { html.classList.remove('has-motion'); html.classList.add('reduce-motion'); }
  }, 4000);
})();
