// Membres de démonstration (notes, chroniques, listes, amitiés) pour voir le site « vivant » en local.
// Créés au démarrage par `npm run demo`. À ne pas utiliser sur le site en ligne.
import { hashPassword } from './security.js';

export const DEMO_PASSWORD = 'demo-myrapfr-2026';

export async function seedDemo(db) {
  const hash = await hashPassword(DEMO_PASSWORD);

  const members = [
    { username: 'sofia_demo', name: 'Sofia', bio: 'Marseille dans le cœur, Paris dans les oreilles.' },
    { username: 'karim_demo', name: 'Karim', bio: 'Collectionneur de vinyles des années 90.' },
    { username: 'lina_demo', name: 'Lina', bio: 'Drill, mélo et albums-concepts.' },
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
  ];

  const ids = {};
  for (const m of members) {
    db.prepare(`INSERT INTO users (username, email, password_hash, display_name, bio, email_verified_at, terms_accepted_at)
                VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))
                ON CONFLICT(username) DO UPDATE SET bio = excluded.bio`)
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

  for (const [a, b] of [['sofia_demo', 'karim_demo'], ['karim_demo', 'sofia_demo'], ['lina_demo', 'sofia_demo'], ['sofia_demo', 'lina_demo'], ['karim_demo', 'lina_demo']]) {
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
  return members.map((m) => m.username);
}
