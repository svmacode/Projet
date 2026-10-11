// Tests de bout en bout de l'API : comptes, sécurité, activité, amis, RGPD.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.DB_FILE = ':memory:';
const { createApp } = await import('../server/app.js');
const { outbox } = await import('../server/mailer.js');

let server;
let base;
before(async () => {
  const app = createApp({ dbFile: ':memory:' });
  await new Promise((resolve) => { server = app.listen(0, resolve); });
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

// Petit client qui garde son cookie de session et son jeton CSRF, comme un navigateur.
function client() {
  let cookie = '';
  let csrf = '';
  const call = async (method, path, body, { noCsrf = false, headers = {} } = {}) => {
    const res = await fetch(base + path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(cookie ? { Cookie: cookie } : {}),
        ...(csrf && !noCsrf ? { 'X-CSRF-Token': csrf } : {}),
        ...headers,
      },
      body: body ? JSON.stringify(body) : undefined,
      redirect: 'manual',
    });
    const set = res.headers.get('set-cookie');
    if (set) cookie = set.split(';')[0];
    const type = res.headers.get('content-type') || '';
    const data = type.includes('json') ? await res.json() : await res.text();
    if (data && data.csrf) csrf = data.csrf;
    return { status: res.status, data, headers: res.headers };
  };
  return { call, get cookie() { return cookie; } };
}

async function register(c, username) {
  const r = await c.call('POST', '/api/v1/auth/register', { username, email: `${username}@exemple.fr`, password: 'une phrase de passe solide', terms: true });
  assert.equal(r.status, 201, JSON.stringify(r.data));
  // Confirmation de l'adresse avec le lien « envoyé ».
  const mail = outbox.findLast((m) => m.to === `${username}@exemple.fr`);
  const token = new URL(mail.text.match(/https?:\/\/\S+/)[0]).searchParams.get('token');
  assert.equal((await c.call('POST', '/api/v1/auth/verify', { token })).status, 200);
}

test('pages publiques, SEO et en-têtes de sécurité', async () => {
  const c = client();
  const home = await c.call('GET', '/');
  assert.equal(home.status, 200);
  assert.match(home.data, /<title>MyRapFr/);
  assert.match(home.data, /og:image/);
  const csp = home.headers.get('content-security-policy');
  assert.match(csp, /script-src 'self'/);
  assert.match(csp, /frame-ancestors 'none'/);
  assert.equal(home.headers.get('x-content-type-options'), 'nosniff');
  assert.equal((await c.call('GET', '/sitemap.xml')).status, 200);
  assert.match((await c.call('GET', '/robots.txt')).data, /Sitemap:/);
  const missing = await c.call('GET', '/page-qui-nexiste-pas');
  assert.equal(missing.status, 404);
  assert.match(missing.data, /Ce son n'existe pas/);
});

test('inscription : validation et doublons', async () => {
  const c = client();
  const bad = await c.call('POST', '/api/v1/auth/register', { username: 'a', email: 'pas-un-mail', password: 'court', terms: false });
  assert.equal(bad.status, 400);
  assert.ok(bad.data.fields.username && bad.data.fields.email && bad.data.fields.password && bad.data.fields.terms);
  await register(c, 'kenza');
  const dup = await client().call('POST', '/api/v1/auth/register', { username: 'KENZA', email: 'autre@exemple.fr', password: 'une phrase de passe solide', terms: true });
  assert.equal(dup.status, 409);
});

test('connexion : mauvais mot de passe refusé, message identique', async () => {
  const c = client();
  await register(c, 'yanis');
  const a = await client().call('POST', '/api/v1/auth/login', { login: 'yanis', password: 'mauvais mot de passe' });
  const b = await client().call('POST', '/api/v1/auth/login', { login: 'inconnu', password: 'mauvais mot de passe' });
  assert.equal(a.status, 401);
  assert.equal(b.status, 401);
  assert.equal(a.data.error, b.data.error);
  const ok = await client().call('POST', '/api/v1/auth/login', { login: 'yanis@exemple.fr', password: 'une phrase de passe solide' });
  assert.equal(ok.status, 200);
});

test('CSRF : une requête sans jeton ou venant d\'un autre site est refusée', async () => {
  const c = client();
  await register(c, 'ines');
  const noToken = await c.call('PUT', '/api/v1/albums/booba-temps-mort/state', { liked: true }, { noCsrf: true });
  assert.equal(noToken.status, 403);
  const crossSite = await c.call('PUT', '/api/v1/albums/booba-temps-mort/state', { liked: true }, { headers: { Origin: 'https://site-malveillant.example', 'Sec-Fetch-Site': 'cross-site' } });
  assert.equal(crossSite.status, 403);
});

test('noter, aimer, chroniquer un album', async () => {
  const c = client();
  await register(c, 'samir');
  const state = await c.call('PUT', '/api/v1/albums/iam-l-ecole-du-micro-d-argent/state', { rating: 10, liked: true });
  assert.equal(state.status, 200);
  assert.equal(state.data.state.listened, 1);
  assert.equal(state.data.album.avg, 10);
  const review = await c.call('POST', '/api/v1/albums/iam-l-ecole-du-micro-d-argent/reviews', { body: 'Un monument.', rating: 10 });
  assert.equal(review.status, 201);
  const spam = await c.call('POST', '/api/v1/albums/iam-l-ecole-du-micro-d-argent/reviews', { body: 'http://a.fr http://b.fr http://c.fr' });
  assert.equal(spam.status, 400);
  const page = await c.call('GET', '/album/iam-l-ecole-du-micro-d-argent');
  assert.match(page.data, /Un monument\./);
  // Le texte est échappé : pas d'injection HTML possible.
  await c.call('POST', '/api/v1/albums/booba-temps-mort/reviews', { body: '<script>alert(1)</script>' });
  const booba = await c.call('GET', '/album/booba-temps-mort');
  assert.ok(!booba.data.includes('<script>alert(1)</script>'));
  assert.match(booba.data, /&lt;script&gt;/);
});

test('une chronique demande une adresse confirmée', async () => {
  const c = client();
  const r = await c.call('POST', '/api/v1/auth/register', { username: 'nonconfirme', email: 'nc@exemple.fr', password: 'une phrase de passe solide', terms: true });
  assert.equal(r.status, 201);
  const review = await c.call('POST', '/api/v1/albums/booba-temps-mort/reviews', { body: 'Test' });
  assert.equal(review.status, 403);
});

test('amis : abonnements réciproques et fil d\'actu', async () => {
  const a = client();
  const b = client();
  await register(a, 'lea');
  await register(b, 'moussa');
  assert.equal((await a.call('POST', '/api/v1/users/moussa/follow')).data.friends, false);
  assert.equal((await b.call('POST', '/api/v1/users/lea/follow')).data.friends, true);
  await b.call('POST', '/api/v1/albums/pnl-dans-la-legende/reviews', { body: 'Hors du temps.', rating: 9 });
  const feed = await a.call('GET', '/api/v1/feed');
  assert.equal(feed.data.feed[0].body, 'Hors du temps.');
  const profile = await a.call('GET', '/api/v1/users/lea');
  assert.deepEqual(profile.data.profile.friends.map((f) => f.username), ['moussa']);
  assert.equal(profile.data.profile.email, undefined);
  assert.equal((await a.call('POST', '/api/v1/users/lea/follow')).status, 400);
});

test('listes et favoris', async () => {
  const c = client();
  await register(c, 'nadia');
  const list = await c.call('POST', '/api/v1/lists', { title: 'Classiques 1997' });
  assert.equal(list.status, 201);
  await c.call('POST', `/api/v1/lists/${list.data.id}/items`, { album: 'iam-l-ecole-du-micro-d-argent' });
  const got = await c.call('GET', `/api/v1/lists/${list.data.id}`);
  assert.equal(got.data.list.albums.length, 1);
  const other = client();
  await register(other, 'intrus');
  assert.equal((await other.call('DELETE', `/api/v1/lists/${list.data.id}`)).status, 403);
  const fav = await c.call('PUT', '/api/v1/me', { displayName: 'Nadia', bio: '', favorites: ['booba-temps-mort', 'nekfeu-feu'] });
  assert.equal(fav.status, 200);
  assert.deepEqual((await c.call('GET', '/api/v1/me')).data.me.favorites, ['booba-temps-mort', 'nekfeu-feu']);
});

test('RGPD : export puis suppression complète du compte', async () => {
  const c = client();
  await register(c, 'tom');
  await c.call('PUT', '/api/v1/albums/nekfeu-feu/state', { rating: 8 });
  const exp = await c.call('GET', '/api/v1/me/export');
  assert.equal(exp.status, 200);
  assert.equal(exp.data.account.email, 'tom@exemple.fr');
  assert.ok(!JSON.stringify(exp.data).includes('scrypt'));
  assert.equal((await c.call('DELETE', '/api/v1/me', { password: 'faux' })).status, 400);
  assert.equal((await c.call('DELETE', '/api/v1/me', { password: 'une phrase de passe solide' })).status, 200);
  assert.equal((await client().call('GET', '/api/v1/users/tom')).status, 404);
  assert.equal((await c.call('GET', '/api/v1/me')).status, 401);
});

test('mot de passe oublié : même réponse que l\'adresse existe ou non', async () => {
  const c = client();
  await register(c, 'awa');
  const known = await client().call('POST', '/api/v1/auth/forgot', { email: 'awa@exemple.fr' });
  const unknown = await client().call('POST', '/api/v1/auth/forgot', { email: 'personne@exemple.fr' });
  assert.deepEqual(known.data, unknown.data);
  const mail = outbox.findLast((m) => m.to === 'awa@exemple.fr' && /Réinitialise/.test(m.subject));
  const token = new URL(mail.text.match(/https?:\/\/\S+/)[0]).searchParams.get('token');
  assert.equal((await client().call('POST', '/api/v1/auth/reset', { token, password: 'nouvelle phrase solide' })).status, 200);
  assert.equal((await client().call('POST', '/api/v1/auth/reset', { token, password: 'nouvelle phrase solide' })).status, 400);
  assert.equal((await client().call('POST', '/api/v1/auth/login', { login: 'awa', password: 'nouvelle phrase solide' })).status, 200);
});
