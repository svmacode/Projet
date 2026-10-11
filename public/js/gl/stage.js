// Scène WebGL unique, en coordonnées écran (1 unité = 1 pixel CSS).
// Elle ne tourne que lorsqu'un effet est actif, pour ne pas consommer de batterie inutilement.
import {
  WebGLRenderer, Scene, OrthographicCamera, TextureLoader, LinearFilter,
} from '/vendor/three-lite.js';

let stage = null;

export function getStage() {
  if (stage) return stage;
  const canvas = document.createElement('canvas');
  canvas.className = 'gl-layer';
  canvas.setAttribute('aria-hidden', 'true');
  document.body.appendChild(canvas);

  const renderer = new WebGLRenderer({ canvas, alpha: true, antialias: true, powerPreference: 'low-power' });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  const scene = new Scene();
  const camera = new OrthographicCamera(0, 1, 0, 1, -1000, 1000);
  const loader = new TextureLoader();
  const cache = new Map();
  const updaters = new Set();

  function resize() {
    const w = innerWidth;
    const h = innerHeight;
    renderer.setSize(w, h, false);
    camera.left = -w / 2; camera.right = w / 2; camera.top = h / 2; camera.bottom = -h / 2;
    camera.updateProjectionMatrix();
  }
  resize();
  addEventListener('resize', resize);

  let running = false;
  function tick(time) {
    for (const fn of updaters) fn(time);
    renderer.render(scene, camera);
  }

  stage = {
    scene,
    // Convertit un rectangle DOM en position au centre de l'écran.
    place(mesh, rect) {
      mesh.position.set(rect.left + rect.width / 2 - innerWidth / 2, innerHeight / 2 - rect.top - rect.height / 2, 0);
      mesh.scale.set(rect.width, rect.height, 1);
    },
    texture(url) {
      if (!cache.has(url)) {
        cache.set(url, new Promise((resolve, reject) => loader.load(url, (t) => {
          // Pas de conversion de couleur : les shaders renvoient les pixels tels quels, comme le navigateur.
          t.minFilter = LinearFilter;
          t.generateMipmaps = false;
          resolve(t);
        }, undefined, reject)));
      }
      return cache.get(url);
    },
    add(fn) {
      updaters.add(fn);
      if (!running) { running = true; window.gsap.ticker.add(tick); }
    },
    remove(fn) {
      updaters.delete(fn);
      if (!updaters.size && running) {
        running = false;
        window.gsap.ticker.remove(tick);
        renderer.render(scene, camera);
      }
    },
  };
  return stage;
}
