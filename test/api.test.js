// Tests de bout en bout de l'API : comptes, sécurité, activité, amis, RGPD.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.DB_FILE = ':memory:';
const { createApp } = await import('../server/app.js');
const { outbox } = await import('../server/mailer.js');

let server;
let base;
let app;
before(async () => {
  app = createApp({ dbFile: ':memory:' });
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
  return { call, get cookie() { return cookie; }, get csrf() { return csrf; } };
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

test('photo de profil : import recodé, pochette au choix, retrait et effacement du fichier', async () => {
  const fs = await import('node:fs');
  const path = await import('node:path');
  const sharp = (await import('sharp')).default;
  const { avatarDir } = await import('../server/avatars.js');
  const c = client();
  await register(c, 'photomembre');
  const upload = (body, type) => fetch(`${base}/api/v1/me/avatar`, {
    method: 'POST', body, headers: { 'Content-Type': type, Cookie: c.cookie, 'X-CSRF-Token': c.csrf },
  }).then(async (r) => ({ status: r.status, data: await r.json() }));

  // Un faux fichier image est refusé.
  const fake = await upload(Buffer.from('<script>alert(1)</script>'), 'image/png');
  assert.equal(fake.status, 400);
  // Une vraie image est recodée en WebP 400 × 400, sous un nom aléatoire.
  const png = await sharp({ create: { width: 900, height: 600, channels: 3, background: '#c33' } }).png().toBuffer();
  const ok = await upload(png, 'image/png');
  assert.equal(ok.status, 200, JSON.stringify(ok.data));
  assert.match(ok.data.avatar, /^\/img\/avatars\/[a-f0-9]{32}\.webp$/);
  const file = path.join(avatarDir, path.basename(ok.data.avatar));
  const meta = await sharp(file).metadata();
  assert.equal(meta.format, 'webp');
  assert.equal(meta.width, 400);
  assert.equal(meta.height, 400);
  const served = await fetch(base + ok.data.avatar);
  assert.equal(served.status, 200);
  assert.match((await c.call('GET', '/membre/photomembre')).data, new RegExp(ok.data.avatar));

  // Choisir une pochette efface l'ancienne photo du disque.
  const pick = await c.call('PUT', '/api/v1/me/avatar', { album: 'pnl-dans-la-legende' });
  assert.equal(pick.status, 200);
  assert.equal(pick.data.avatar, '/img/covers/pnl-dans-la-legende-300.webp');
  assert.equal(fs.existsSync(file), false);
  assert.equal((await c.call('PUT', '/api/v1/me/avatar', { album: '../../secret' })).status, 400);
  assert.equal((await c.call('DELETE', '/api/v1/me/avatar')).status, 200);
  assert.equal((await c.call('GET', '/api/v1/me')).data.me.avatar, null);
  // Un nom de fichier inventé n'est pas servi.
  assert.equal((await fetch(`${base}/img/avatars/..%2F..%2Fsecret.key`)).status, 404);
});

test('page Amis : recherche de membres, suivre en retour, amis', async () => {
  const a = client();
  const b = client();
  await register(a, 'amina');
  await register(b, 'bilal');
  assert.equal((await client().call('GET', '/api/v1/users?q=bil')).status, 401);
  const found = await a.call('GET', '/api/v1/users?q=bil');
  assert.equal(found.status, 200);
  assert.deepEqual(found.data.users.map((u) => u.username), ['bilal']);
  assert.equal(found.data.users[0].isFollowing, false);
  await b.call('POST', '/api/v1/users/amina/follow');
  const page = await a.call('GET', '/amis');
  assert.equal(page.status, 200);
  assert.match(page.data, /Ils te suivent/);
  assert.match(page.data, /Suivre en retour/);
  const back = await a.call('POST', '/api/v1/users/bilal/follow');
  assert.equal(back.data.friends, true);
  assert.match((await a.call('GET', '/amis')).data, /Tes amis[\s\S]*bilal/);
  assert.equal((await client().call('GET', '/amis')).status, 303);
});

test('modération : signalement, masquage, suspension, journal ; réservé aux admins', async () => {
  const admin = client();
  const author = client();
  const reporter = client();
  await register(admin, 'modo');
  await register(author, 'auteurx');
  await register(reporter, 'temoin');
  app.locals.db.prepare("UPDATE users SET role = 'admin' WHERE username = 'modo'").run();
  // Les droits d'admin sont lus à chaque requête : on se reconnecte pour être sûr.
  await admin.call('POST', '/api/v1/auth/login', { login: 'modo', password: 'une phrase de passe solide' });

  const posted = await author.call('POST', '/api/v1/albums/pnl-dans-la-legende/reviews', { rating: 2, body: 'Chronique problématique à modérer.' });
  assert.equal(posted.status, 201, JSON.stringify(posted.data));
  const reviewId = posted.data.review?.id ?? posted.data.id;
  assert.ok(reviewId);
  assert.equal((await reporter.call('POST', `/api/v1/reviews/${reviewId}/report`, { reason: 'Propos insultants' })).status, 200);
  assert.equal((await reporter.call('POST', '/api/v1/users/auteurx/report', { reason: 'Photo choquante' })).status, 200);

  // Un membre ordinaire n'a accès à rien.
  assert.equal((await reporter.call('GET', '/admin')).status, 404);
  assert.equal((await reporter.call('POST', `/api/v1/admin/reviews/${reviewId}/hide`, { reason: 'test' })).status, 403);

  const page = await admin.call('GET', '/admin');
  assert.equal(page.status, 200);
  assert.match(page.data, /Propos insultants/);
  assert.match(page.data, /Photo choquante/);

  // Masquer : la chronique disparaît de la page de l'album.
  assert.equal((await admin.call('POST', `/api/v1/admin/reviews/${reviewId}/hide`, { reason: 'Insultes' })).status, 200);
  assert.doesNotMatch((await client().call('GET', '/album/pnl-dans-la-legende')).data, /Chronique problématique/);
  // Suspendre : connexion refusée, profil introuvable, session fermée.
  assert.equal((await admin.call('POST', '/api/v1/admin/users/auteurx/suspend', { reason: 'Récidive' })).status, 200);
  assert.equal((await author.call('GET', '/api/v1/me')).status, 401);
  const login = await client().call('POST', '/api/v1/auth/login', { login: 'auteurx', password: 'une phrase de passe solide' });
  assert.equal(login.status, 403);
  assert.match(login.data.error, /suspendu/);
  assert.equal((await client().call('GET', '/membre/auteurx')).status, 404);
  assert.equal((await admin.call('GET', '/membre/auteurx')).status, 200);
  // Un admin ne peut pas se suspendre lui-même.
  assert.equal((await admin.call('POST', '/api/v1/admin/users/modo/suspend', { reason: 'test' })).status, 400);
  // Journal et réactivation.
  const after = await admin.call('GET', '/admin');
  assert.match(after.data, /chronique masquée/);
  assert.match(after.data, /compte suspendu/);
  assert.equal((await admin.call('POST', '/api/v1/admin/users/auteurx/unsuspend')).status, 200);
  assert.equal((await client().call('GET', '/membre/auteurx')).status, 200);
});

test('bloquer un membre : abonnements retirés, plus de suivi, profil caché, chroniques masquées', async () => {
  const a = client();
  const b = client();
  await register(a, 'bloqueuse');
  await register(b, 'importun');
  await a.call('POST', '/api/v1/users/importun/follow');
  await b.call('POST', '/api/v1/users/bloqueuse/follow');
  await b.call('POST', '/api/v1/albums/iam-l-ecole-du-micro-d-argent/reviews', { rating: 5, body: 'Chronique de l importun.' });
  assert.equal((await a.call('POST', '/api/v1/users/importun/block')).status, 200);
  // Plus aucun abonnement, et impossible de se suivre à nouveau.
  assert.equal((await b.call('POST', '/api/v1/users/bloqueuse/follow')).status, 403);
  assert.equal((await a.call('POST', '/api/v1/users/importun/follow')).status, 403);
  // Le membre bloqué ne voit plus le profil ; la bloqueuse le voit avec « Débloquer ».
  assert.equal((await b.call('GET', '/membre/bloqueuse')).status, 404);
  assert.match((await a.call('GET', '/membre/importun')).data, /Débloquer/);
  // Les chroniques du membre bloqué n'apparaissent plus pour la bloqueuse, mais restent visibles des autres.
  assert.doesNotMatch((await a.call('GET', '/album/iam-l-ecole-du-micro-d-argent')).data, /Chronique de l importun/);
  assert.match((await client().call('GET', '/album/iam-l-ecole-du-micro-d-argent')).data, /Chronique de l importun/);
  // Introuvable dans la recherche de membres.
  assert.equal((await a.call('GET', '/api/v1/users?q=importun')).data.users.length, 0);
  assert.match((await a.call('GET', '/compte')).data, /importun/);
  // Débloquer.
  assert.equal((await a.call('DELETE', '/api/v1/users/importun/block')).status, 200);
  assert.equal((await b.call('GET', '/membre/bloqueuse')).status, 200);
});

test('commentaires et notifications : publier, notifier, supprimer, signaler ; blocage respecté', async () => {
  const auteur = client();
  const lecteur = client();
  await register(auteur, 'chroniqueur');
  await register(lecteur, 'lectrice');
  const posted = await auteur.call('POST', '/api/v1/albums/laylow-trinity/reviews', { rating: 9, body: 'Un film plus qu un album.' });
  const reviewId = posted.data.review?.id ?? posted.data.id;
  // Suivre + aimer + commenter → trois notifications pour l'auteur.
  await lecteur.call('POST', '/api/v1/users/chroniqueur/follow');
  await lecteur.call('POST', `/api/v1/reviews/${reviewId}/like`);
  await lecteur.call('POST', `/api/v1/reviews/${reviewId}/like`); // retirer
  await lecteur.call('POST', `/api/v1/reviews/${reviewId}/like`); // ré-aimer : pas de doublon
  const c = await lecteur.call('POST', `/api/v1/reviews/${reviewId}/comments`, { body: 'Entièrement d accord <script>x</script>' });
  assert.equal(c.status, 201, JSON.stringify(c.data));
  assert.equal((await lecteur.call('POST', `/api/v1/reviews/${reviewId}/comments`, { body: '' })).status, 400);
  const notifs = await auteur.call('GET', '/api/v1/notifications');
  assert.equal(notifs.data.unread, 3);
  assert.deepEqual(notifs.data.notifications.map((n) => n.type).sort(), ['comment', 'follow', 'like']);
  // La page de la chronique affiche le commentaire, échappé.
  const page = await client().call('GET', `/chronique/${reviewId}`);
  assert.equal(page.status, 200);
  assert.match(page.data, /Entièrement d accord &lt;script&gt;/);
  // La page Notifications marque tout comme lu.
  assert.match((await auteur.call('GET', '/notifications')).data, /a commenté ta chronique/);
  assert.equal((await auteur.call('GET', '/api/v1/notifications')).data.unread, 0);
  // Signaler puis supprimer (par l'auteur de la chronique).
  assert.equal((await auteur.call('POST', `/api/v1/comments/${c.data.comment.id}/report`, { reason: 'Test de signalement' })).status, 200);
  assert.equal((await client().call('DELETE', `/api/v1/comments/${c.data.comment.id}`)).status, 401);
  assert.equal((await auteur.call('DELETE', `/api/v1/comments/${c.data.comment.id}`)).status, 200);
  // Bloqué : plus de commentaire possible ni de notification.
  await auteur.call('POST', '/api/v1/users/lectrice/block');
  assert.equal((await lecteur.call('POST', `/api/v1/reviews/${reviewId}/comments`, { body: 'Encore moi' })).status, 403);
  assert.equal((await lecteur.call('GET', `/chronique/${reviewId}`)).status, 404);
});
