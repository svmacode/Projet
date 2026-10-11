// Membres de démonstration (notes, chroniques, listes, amitiés) pour voir le site « vivant » en local.
// Créés au démarrage par `npm run demo`. À ne pas utiliser sur le site en ligne.
import { hashPassword } from './security.js';
import { badgeEngine } from './badges.js';
import { notifier } from './notify.js';

export const DEMO_PASSWORD = 'demo-myrapfr-2026';

export async function seedDemo(db) {
  const hash = await hashPassword(DEMO_PASSWORD);

  const members = [
    { username: 'sofia_demo', name: 'Sofia', bio: 'Marseille dans le cœur, Paris dans les oreilles.' },
    { username: 'karim_demo', name: 'Karim', bio: 'Collectionneur de vinyles des années 90.' },
    { username: 'lina_demo', name: 'Lina', bio: 'Drill, mélo et albums-concepts.' },
    { username: 'nadir_demo', name: 'Nadir', bio: 'Rap lyonnais et boom-bap avant tout.' },
    { username: 'ines_demo', name: 'Inès', bio: 'Je découvre le rap français album par album.' },
  ];

  const reviews = [
    ['sofia_demo', 'iam-l-ecole-du-micro-d-argent', 10, "Chaque morceau est une nouvelle. Demain c'est loin reste le plus beau récit du rap français."],
    ['sofia_demo', 'fonky-family-art-de-rue', 9, 'Le son du Panier en 2001. Brut et généreux.'],
    ['sofia_demo', 'jul-my-world', 7, ''],
    ['karim_demo', 'lunatic-mauvais-oeil', 10, 'Sorti en indépendant et pourtant intouchable. Le meilleur duo de sa génération.'],
    ['karim_demo', 'arsenik-quelques-gouttes-suffisent', 9, 'Sombre, technique, parfait de bout en bout.'],
    ['karim_demo', 'oxmo-puccino-opera-puccino', 10, 'Un polar en musique. Le Black Desperado à son sommet.'],
    ['lina_demo', 'pnl-dans-la-legende', 9, "Une bulle de mélancolie. On l'écoute la nuit, fenêtre ouverte."],
    ['lina_demo', 'laylow-trinity', 9, 'Un film plus qu’un album. La production est folle.'],
    ['lina_demo', 'tiakola-melo', 8, 'Des refrains qui restent des semaines.'],
    ['lina_demo', 'iam-l-ecole-du-micro-d-argent', 8, 'Je comprends enfin pourquoi tout le monde en parle.'],
    ['nadir_demo', 'ntm-paris-sous-les-bombes', 9, 'Le son de Paris en 1995, sans filtre.'],
    ['nadir_demo', 'mc-solaar-prose-combat', 8, ''],
    ['ines_demo', 'pnl-dans-la-legende', 8, 'Mon premier album de PNL, et sûrement pas le dernier.'],
  ];

  const ids = {};
  for (const m of members) {
    db.prepare(`INSERT INTO users (username, email, password_hash, display_name, bio, email_verified_at, terms_accepted_at)
                VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))
                ON CONFLICT(username) DO UPDATE SET bio = excluded.bio, password_hash = excluded.password_hash`)
      .run(m.username, `${m.username}@exemple.invalid`, hash, m.name, m.bio);
    ids[m.username] = db.prepare('SELECT id FROM users WHERE username = ?').get(m.username).id;
  }
  const album = (slug) => db.prepare('SELECT id FROM albums WHERE slug = ?').get(slug).id;

  reviews.forEach(([user, slug, rating, body], i) => {
    const exists = db.prepare('SELECT 1 FROM reviews WHERE user_id = ? AND album_id = ?').get(ids[user], album(slug));
    if (!exists) {
      db.prepare("INSERT INTO reviews (user_id, album_id, rating, body, listened_on, created_at) VALUES (?, ?, ?, ?, date('now', ?), datetime('now', ?))")
        .run(ids[user], album(slug), rating, body, `-${i * 3} days`, `-${i * 3} days`);
    }
    db.prepare(`INSERT INTO user_albums (user_id, album_id, rating, liked, listened) VALUES (?, ?, ?, ?, 1)
                ON CONFLICT(user_id, album_id) DO UPDATE SET rating = excluded.rating, liked = excluded.liked, listened = 1`)
      .run(ids[user], album(slug), rating, rating === 10 ? 1 : 0);
  });

  for (const [a, b] of [['sofia_demo', 'karim_demo'], ['karim_demo', 'sofia_demo'], ['lina_demo', 'sofia_demo'], ['sofia_demo', 'lina_demo'], ['karim_demo', 'lina_demo'], ['nadir_demo', 'sofia_demo'], ['nadir_demo', 'karim_demo']]) {
    db.prepare('INSERT OR IGNORE INTO follows (follower_id, followee_id) VALUES (?, ?)').run(ids[a], ids[b]);
  }

  const favs = { sofia_demo: ['iam-l-ecole-du-micro-d-argent', 'fonky-family-art-de-rue', 'psy4-block-party', 'keny-arkana-entre-ciment-et-belle-etoile'] };
  for (const [user, list] of Object.entries(favs)) {
    db.prepare('DELETE FROM favorites WHERE user_id = ?').run(ids[user]);
    list.forEach((slug, i) => db.prepare('INSERT INTO favorites (user_id, album_id, position) VALUES (?, ?, ?)').run(ids[user], album(slug), i + 1));
  }

  if (!db.prepare('SELECT 1 FROM lists WHERE user_id = ?').get(ids.karim_demo)) {
    const { lastInsertRowid } = db.prepare('INSERT INTO lists (user_id, title, description) VALUES (?, ?, ?)')
      .run(ids.karim_demo, 'Les fondations', 'Dix disques sans lesquels rien de ce qui a suivi n’existerait.');
    ['ntm-paris-sous-les-bombes', 'iam-l-ecole-du-micro-d-argent', 'mc-solaar-prose-combat', 'lunatic-mauvais-oeil', 'arsenik-quelques-gouttes-suffisent', 'oxmo-puccino-opera-puccino', 'ideal-j-le-combat-continue', '113-les-princes-de-la-ville']
      .forEach((slug, i) => db.prepare('INSERT INTO list_items (list_id, album_id, position) VALUES (?, ?, ?)').run(lastInsertRowid, album(slug), i + 1));
  }
  // Liste à plusieurs : Karim invite Sofia (ils sont amis) à compléter « Les fondations ».
  const foundations = db.prepare('SELECT id FROM lists WHERE user_id = ? ORDER BY id LIMIT 1').get(ids.karim_demo);
  if (foundations) {
    db.prepare('INSERT OR IGNORE INTO list_collaborators (list_id, user_id) VALUES (?, ?)').run(foundations.id, ids.sofia_demo);
    db.prepare("UPDATE list_items SET note = 'Le disque qui a tout lancé en 1997.' WHERE list_id = ? AND note = '' AND album_id = (SELECT id FROM albums WHERE slug = 'iam-l-ecole-du-micro-d-argent')").run(foundations.id);
  }

  // Badges mérités par l'activité de démonstration.
  const badges = badgeEngine(db, notifier(db));
  for (const id of Object.values(ids)) badges.check(id);

  // Sofia est administratrice, avec un signalement d'exemple à traiter dans « Modération ».
  db.prepare("UPDATE users SET role = 'admin' WHERE username = 'sofia_demo'").run();
  const reported = db.prepare(`SELECT r.id FROM reviews r JOIN albums al ON al.id = r.album_id
    WHERE r.user_id = ? AND al.slug = 'oxmo-puccino-opera-puccino'`).get(ids.karim_demo);
  if (reported) {
    db.prepare('INSERT OR IGNORE INTO reports (reporter_id, review_id, reason) VALUES (?, ?, ?)')
      .run(ids.ines_demo, reported.id, "Exemple de signalement : propos à vérifier (démo).");
  }

  return members.map((m) => m.username);
}
