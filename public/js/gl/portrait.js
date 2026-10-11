// Portrait qui suit le pointeur au-dessus de la liste des rappeurs.
// Passage d'un portrait à l'autre par un fondu ondulé, et légère inclinaison selon la vitesse.
import { Mesh, PlaneGeometry, ShaderMaterial, Vector2 } from '/vendor/three-lite.js';
import { getStage } from './stage.js';

const vertex = /* glsl */ `
  uniform vec2 uVel;
  varying vec2 vUv;
  void main() {
    vUv = uv;
    vec3 pos = position;
    // Le bas du plan traîne derrière le mouvement, comme une feuille tenue par le haut.
    pos.x -= uVel.x * 0.004 * (1.0 - uv.y) * (1.0 - uv.y);
    gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
  }
`;

const fragment = /* glsl */ `
  uniform sampler2D uFrom;
  uniform sampler2D uTo;
  uniform float uProgress;
  uniform float uAlpha;
  uniform float uTime;
  varying vec2 vUv;

  void main() {
    float wave = sin(vUv.y * 9.0 + uTime * 1.5) * 0.5 + 0.5;
    float p = smoothstep(0.0, 1.0, clamp(uProgress * 1.6 - wave * 0.6 + (1.0 - vUv.y) * 0.2, 0.0, 1.0));
    vec2 uvFrom = vUv + vec2(0.0, p * 0.08);
    vec2 uvTo = vUv - vec2(0.0, (1.0 - p) * 0.08);
    vec4 a = texture2D(uFrom, uvFrom);
    vec4 b = texture2D(uTo, uvTo);
    vec4 c = mix(a, b, p);
    vec2 edge = smoothstep(vec2(0.0), vec2(0.012), vUv) * smoothstep(vec2(0.0), vec2(0.012), 1.0 - vUv);
    gl_FragColor = vec4(c.rgb, uAlpha * edge.x * edge.y);
  }
`;

export function initPortraits(list) {
  const { gsap } = window;
  const stage = getStage();
  const items = list.querySelectorAll('[data-portrait]');
  if (!items.length) return;

  const W = Math.round(Math.min(300, innerWidth * 0.2));
  const H = Math.round(W * 1.25);
  const mat = new ShaderMaterial({
    vertexShader: vertex,
    fragmentShader: fragment,
    transparent: true,
    uniforms: {
      uFrom: { value: null }, uTo: { value: null },
      uProgress: { value: 1 }, uAlpha: { value: 0 }, uTime: { value: 0 },
      uVel: { value: new Vector2() },
    },
  });
  const mesh = new Mesh(new PlaneGeometry(1, 1, 16, 16), mat);
  mesh.visible = false;
  stage.scene.add(mesh);

  const pos = { x: innerWidth / 2, y: innerHeight / 2 };
  const target = { ...pos };
  let current = null;
  let running = false;

  const update = (time) => {
    const px = pos.x;
    pos.x += (target.x - pos.x) * 0.1;
    pos.y += (target.y - pos.y) * 0.1;
    mat.uniforms.uVel.value.set(pos.x - px, 0);
    mat.uniforms.uTime.value = time;
    stage.place(mesh, { left: pos.x - W / 2, top: pos.y - H / 2, width: W, height: H });
  };

  async function show(url) {
    if (url === current) return;
    const tex = await stage.texture(url);
    mat.uniforms.uFrom.value = mat.uniforms.uTo.value || tex;
    mat.uniforms.uTo.value = tex;
    current = url;
    mesh.visible = true;
    gsap.fromTo(mat.uniforms.uProgress, { value: 0 }, { value: 1, duration: 0.9, ease: 'power3.out', overwrite: true });
    gsap.to(mat.uniforms.uAlpha, { value: 1, duration: 0.4, overwrite: true });
    if (!running) { running = true; stage.add(update); }
  }

  function hide() {
    gsap.to(mat.uniforms.uAlpha, {
      value: 0, duration: 0.35, overwrite: true,
      onComplete: () => { mesh.visible = false; running = false; stage.remove(update); current = null; mat.uniforms.uTo.value = null; },
    });
  }

  list.addEventListener('pointermove', (e) => {
    target.x = e.clientX + W * 0.35;
    target.y = e.clientY;
    if (!running) { pos.x = target.x; pos.y = target.y; }
  }, { passive: true });
  items.forEach((item) => item.addEventListener('pointerenter', () => show(item.dataset.portrait)));
  list.addEventListener('pointerleave', hide);
  // Précharge discrètement les portraits pour des transitions instantanées.
  setTimeout(() => items.forEach((item) => stage.texture(item.dataset.portrait).catch(() => {})), 1500);
}
