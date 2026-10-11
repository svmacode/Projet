// Catalogue : dédoublonnage des discographies, pagination, images à la demande.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
const { baseTitle } = await import('../server/catalog.js');
const { pickProjects } = await import('../server/discover.js');
const { createApp } = await import('../server/app.js');

let server;
let base;
before(async () => {
  const app = createApp({ dbFile: ':memory:' });
  await new Promise((resolve) => { server = app.listen(0, resolve); });
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

test('les rééditions sont reconnues comme le même projet', () => {
  assert.equal(baseTitle('Trône (Deluxe)'), baseTitle('Trône'));
  assert.equal(baseTitle('Dans la légende - Édition Collector'), baseTitle('Dans la légende'));
  assert.equal(baseTitle('Or Noir Part 2'), 'or noir part 2');
  assert.notEqual(baseTitle('JVLIVS'), baseTitle('JVLIVS II'));
});

test('discographie : ni singles, ni lives, ni compilations, une seule édition par projet', () => {
  const raw = [
    { id: 1, title: 'Ipséité', record_type: 'album', release_date: '2017-04-28', cover_xl: 'a' },
    { id: 2, title: 'Ipséité (Deluxe)', record_type: 'album', release_date: '2017-11-03', cover_xl: 'b' },
    { id: 3, title: 'Θ. Macarena', record_type: 'single', release_date: '2017-02-01' },
    { id: 4, title: 'Live à Forest National', record_type: 'album', release_date: '2019-01-01' },
    { id: 5, title: 'Best Of', record_type: 'compile', release_date: '2020-01-01' },
    { id: 6, title: 'Smog', record_type: 'ep', release_date: '2016-02-01', cover_xl: 'c' },
  ];
  const kept = pickProjects('damso', raw);
  assert.deepEqual(kept.map((p) => [p.title, p.year, p.kind]), [['Ipséité', 2017, 'album'], ['Smog', 2016, 'ep']]);
});

test('API du catalogue : filtres et pagination', async () => {
  const all = await (await fetch(`${base}/api/v1/albums?par=50`)).json();
  assert.equal(all.page, 1);
  assert.ok(all.total >= 148);
  assert.equal(all.albums.length, 50);
  const page2 = await (await fetch(`${base}/api/v1/albums?par=50&page=2`)).json();
  assert.notEqual(page2.albums[0].slug, all.albums[0].slug);
  const nineties = await (await fetch(`${base}/api/v1/albums?decennie=1990&par=200`)).json();
  assert.ok(nineties.albums.every((a) => a.year >= 1990 && a.year < 2000));
  const search = await (await fetch(`${base}/api/v1/albums?q=${encodeURIComponent('ecole micro')}`)).json();
  assert.equal(search.albums[0].slug, 'iam-l-ecole-du-micro-d-argent');
  const html = await (await fetch(`${base}/albums?decennie=2010&tri=recent`)).text();
  assert.match(html, /aria-current="true" data-chip>10’s/);
});

test('les images manquantes sont fabriquées à la demande', async () => {
  const res = await fetch(`${base}/img/covers/nekfeu-feu-300.webp`);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('content-type'), 'image/webp');
  assert.equal((await fetch(`${base}/img/covers/album-inexistant-300.webp`)).status, 404);
  assert.equal((await fetch(`${base}/img/covers/nekfeu-feu-123.webp`)).status, 404);
});
