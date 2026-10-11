// Distorsion légère au survol des vignettes : la pochette se bombe sous le pointeur
// et s'étire un peu dans le sens du mouvement. Discret, jamais plus.
import { Mesh, PlaneGeometry, ShaderMaterial, Vector2 } from '/vendor/three-lite.js';
import { getStage } from './stage.js';

const vertex = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const fragment = /* glsl */ `
  uniform sampler2D uTex;
  uniform vec2 uMouse;
  uniform vec2 uVel;
  uniform vec2 uSize;
  uniform float uHover;
  uniform float uRadius;
  varying vec2 vUv;

  void main() {
    vec2 uv = vUv;
    vec2 d = uv - uMouse;
    float falloff = smoothstep(0.65, 0.0, length(d)) * uHover;
    uv -= d * falloff * 0.09;                    // effet loupe sous le pointeur
    uv -= uVel * falloff * 0.6;                  // traîne dans le sens du mouvement
    uv = (uv - 0.5) * (1.0 - 0.035 * uHover) + 0.5; // très léger zoom

    float shift = length(uVel) * 0.35 * uHover;
    vec4 c = texture2D(uTex, uv);
    c.r = texture2D(uTex, uv + uVel * shift).r;
    c.b = texture2D(uTex, uv - uVel * shift).b;
    // Reflet doux qui suit le pointeur, comme une lumière sur une pochette glacée.
    float glare = pow(max(0.0, 1.0 - length(d) * 1.6), 3.0) * 0.22 * uHover;
    c.rgb += glare;

    // Coins arrondis identiques à ceux de la vignette.
    vec2 p = (vUv - 0.5) * uSize;
    vec2 q = abs(p) - (uSize * 0.5 - uRadius);
    float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - uRadius;
    float alpha = 1.0 - smoothstep(-0.75, 0.75, sd);
    gl_FragColor = vec4(c.rgb, c.a * alpha);
  }
`;

export function initHover() {
  const { gsap } = window;
  const stage = getStage();
  const geometry = new PlaneGeometry(1, 1, 1, 1);
  const active = new Map();

  function enter(tile) {
    if (active.has(tile)) {
      const entry = active.get(tile);
      gsap.to(entry.mat.uniforms.uHover, { value: 1, duration: 0.6, ease: 'expo.out', overwrite: true });
      return;
    }
    const img = tile.querySelector('img');
    if (!img || !img.complete) return;
    const entry = { img, mouse: new Vector2(0.5, 0.5), target: new Vector2(0.5, 0.5), last: new Vector2(0.5, 0.5) };
    active.set(tile, entry);
    stage.texture(img.currentSrc || img.src).then((tex) => {
      if (!active.has(tile)) return;
      entry.mat = new ShaderMaterial({
        vertexShader: vertex,
        fragmentShader: fragment,
        transparent: true,
        uniforms: {
          uTex: { value: tex },
          uMouse: { value: entry.mouse },
          uVel: { value: new Vector2() },
          uSize: { value: new Vector2(1, 1) },
          uHover: { value: 0 },
          uRadius: { value: 8 },
        },
      });
      entry.mesh = new Mesh(geometry, entry.mat);
      stage.scene.add(entry.mesh);
      entry.update = () => {
        const r = img.getBoundingClientRect();
        stage.place(entry.mesh, r);
        entry.mat.uniforms.uSize.value.set(r.width, r.height);
        entry.mouse.lerp(entry.target, 0.12);
        const vel = entry.mat.uniforms.uVel.value;
        vel.set(entry.mouse.x - entry.last.x, entry.mouse.y - entry.last.y).multiplyScalar(0.9);
        entry.last.copy(entry.mouse);
      };
      entry.update();
      stage.add(entry.update);
      tile.classList.add('is-gl');
      gsap.to(entry.mat.uniforms.uHover, { value: 1, duration: 0.6, ease: 'expo.out' });
    }).catch(() => active.delete(tile));
  }

  function leave(tile) {
    const entry = active.get(tile);
    if (!entry?.mat) { active.delete(tile); return; }
    gsap.to(entry.mat.uniforms.uHover, {
      value: 0, duration: 0.5, ease: 'power2.out', overwrite: true,
      onComplete: () => {
        tile.classList.remove('is-gl');
        stage.remove(entry.update);
        stage.scene.remove(entry.mesh);
        entry.mat.dispose();
        active.delete(tile);
      },
    });
  }

  document.addEventListener('pointerover', (e) => {
    const tile = e.target.closest?.('[data-gl]');
    if (tile && !tile.contains(e.relatedTarget)) enter(tile);
  });
  document.addEventListener('pointerout', (e) => {
    const tile = e.target.closest?.('[data-gl]');
    if (tile && !tile.contains(e.relatedTarget)) leave(tile);
  });
  document.addEventListener('pointermove', (e) => {
    for (const [, entry] of active) {
      const r = entry.img.getBoundingClientRect();
      entry.target.set((e.clientX - r.left) / r.width, 1 - (e.clientY - r.top) / r.height);
    }
  }, { passive: true });
  // En quittant la page, on rend la main aux images normales.
  addEventListener('pagehide', () => active.forEach((_, tile) => tile.classList.remove('is-gl')));
}
