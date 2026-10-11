import fs from 'node:fs';
import path from 'node:path';
import express from 'express';
import { config } from './config.js';
import { html } from './html.js';
import { catalogStatus } from './auto-images.js';
import { streamCss } from './views/stream.js';
import { issueFormToken } from './security.js';
import { layout } from './views/layout.js';
import { homePage } from './views/home.js';
import { albumsPage, albumPage, artistsPage, artistPage, searchPage, catalogueUrl } from './views/catalog.js';
import { profilePage, followPage, listPage, feedPage, friendsPage, reviewPage, notificationsPage } from './views/social.js';
import { registerPage, loginPage, forgotPage, resetPage, confirmPage, settingsPage } from './views/account.js';
import { adminPage } from './views/admin.js';
import { statsPage, yearPage } from './views/stats.js';
import { statsQueries } from './stats.js';
import { chartsQueries } from './charts.js';
import { badgeEngine } from './badges.js';
import { badgesPage } from './views/stats.js';
import { recommender } from './recommend.js';
import { messaging } from './messages.js';
import { inboxPage, threadPage } from './views/messages.js';
import { importPage } from './views/account.js';
import { artistInsights } from './artist-insights.js';
import { checkUnsubscribe } from './digest.js';
import { mailEnabled } from './mailer.js';
import { chartsPage, challengePage, challengeCard } from './views/charts.js';
import { moderation } from './moderation.js';
import { listenLinks } from './album-details.js';
import { loadCatalog } from './catalog.js';
import { privacyPage, cookiesPage, termsPage, legalNoticePage, sitemapPage, notFoundPage, offlinePage } from './views/legal.js';

// Filtres du catalogue lus dans l'adresse, avec des valeurs sûres.
export function readFilters(query) {
  const decade = Number(query.decennie);
  return {
    q: String(query.q || '').trim().slice(0, 60),
    decade: [1990, 2000, 2010, 2020].includes(decade) ? decade : 0,
    kind: ['album', 'ep'].includes(query.type) ? query.type : '',
    sort: ['year', 'recent', 'title', 'rating', 'popular'].includes(query.tri) ? query.tri : 'year',
    page: Math.max(1, Math.min(1000, Number.parseInt(query.page, 10) || 1)),
  };
}

const truncate = (s, n = 155) => (s.length > n ? `${s.slice(0, n - 1).trimEnd()}…` : s);

// N'accepte que les chemins internes pour la redirection après connexion.
const safeBack = (value) => (typeof value === 'string' && /^\/(?!\/)[\w\-/.?=&%#]*$/.test(value) ? value : '/');

export function pagesRouter(db, q) {
  const r = express.Router();
  const mod = moderation(db);
  const stats = statsQueries(db);
  const charts = chartsQueries(db);
  const badges = badgeEngine(db);
  const recommend = recommender(db);
  const dm = messaging(db);
  const insights = artistInsights(db);

  const send = (req, res, opts) => {
    res.set('Cache-Control', 'no-cache');
    const user = req.user
      ? { ...req.user, pendingReports: req.user.admin ? mod.counts() : 0, unread: q.unreadNotifications(req.user.id), unreadMessages: dm.unread(req.user.id) }
      : null;
    res.status(opts.status || 200).send(layout({ ...opts, user, csrf: req.csrfToken }));
  };

  const notFound = (req, res) => {
    const all = q.albums();
    const sample = Array.from({ length: 4 }, () => all[Math.floor(Math.random() * all.length)]);
    send(req, res, {
      status: 404, title: 'Page introuvable', path: req.path, noindex: true, theme: 'dark',
      body: notFoundPage({ albums: [...new Set(sample)] }), bodyClass: 'page-404',
    });
  };

  const needUser = (req, res) => {
    if (req.user) return true;
    res.redirect(303, `/connexion?retour=${encodeURIComponent(req.originalUrl)}`);
    return false;
  };

  r.get('/', (req, res) => send(req, res, {
    path: '/', theme: 'dark', bodyClass: 'page-home',
    body: homePage({ albums: q.albums(), artists: q.artists(), user: req.user }),
    scripts: ['/js/pages/home.js'],
    jsonLd: {
      '@context': 'https://schema.org', '@type': 'WebSite', name: 'MyRapFr', url: config.publicUrl,
      potentialAction: { '@type': 'SearchAction', target: `${config.publicUrl}/recherche?q={q}`, 'query-input': 'required name=q' },
    },
  }));

  r.get('/albums', (req, res) => {
    const filters = readFilters(req.query);
    const result = q.albumPage({ ...filters, perPage: 60 });
    const totalAll = q.count().n;
    const filtered = filters.q || filters.decade || filters.kind || filters.sort !== 'year';
    send(req, res, {
      title: result.page > 1 ? `Albums — page ${result.page}` : 'Albums', path: catalogueUrl({ ...filters, page: result.page }), theme: 'dark',
      noindex: Boolean(filters.q),
      description: `${totalAll.toLocaleString('fr-FR')} albums, mixtapes et EP du rap français, de 1991 à aujourd'hui. Note-les, chronique-les, partage-les.`,
      body: albumsPage({ result, filters, totalAll, filtered, status: catalogStatus() }), scripts: ['/js/pages/catalogue.js'],
    });
  });

  r.get('/album/:slug', (req, res) => {
    const album = q.album(req.params.slug);
    if (!album) return notFound(req, res);
    const viewer = req.user?.id || 0;
    const description = truncate(`${album.title}, l'album de ${album.artist.name} sorti en ${album.year}. ${album.ratings ? `Noté ${(album.avg / 2).toFixed(1)}/5 par ${album.ratings} membres.` : ''} Note-le et lis les chroniques sur MyRapFr.`);
    send(req, res, {
      title: `${album.title} — ${album.artist.name} (${album.year})`, description, path: `/album/${album.slug}`,
      image: `/img/og/${album.slug}.jpg`, imageAlt: `Pochette de ${album.title}`, theme: 'dark', bodyClass: 'page-album',
      body: albumPage({
        album, user: req.user,
        reviews: q.reviewsForAlbum(album.id, viewer),
        friendsReviews: viewer ? q.reviewsForAlbum(album.id, viewer, { friendsOnly: true }) : [],
        state: viewer ? q.userState(viewer, album.id) : null,
        lists: viewer ? q.myLists(viewer) : [],
        more: q.albumsByArtist(album.artist.slug).filter((a) => a.slug !== album.slug),
        formToken: issueFormToken(),
        links: listenLinks(album, loadCatalog().albums.find((a) => a.slug === album.slug)?.deezerId),
      }),
      scripts: ['/js/pages/album.js'],
      jsonLd: {
        '@context': 'https://schema.org', '@type': 'MusicAlbum', name: album.title,
        byArtist: { '@type': 'MusicGroup', name: album.artist.name, url: `${config.publicUrl}/rappeur/${album.artist.slug}` },
        datePublished: String(album.year), image: `${config.publicUrl}${album.cover}-1200.webp`, url: `${config.publicUrl}/album/${album.slug}`,
        ...(album.ratings ? { aggregateRating: { '@type': 'AggregateRating', ratingValue: (album.avg / 2).toFixed(1), bestRating: 5, worstRating: 0.5, ratingCount: album.ratings } } : {}),
      },
    });
  });

  r.get('/rappeurs', (req, res) => send(req, res, {
    title: 'Rappeurs', path: '/rappeurs', theme: 'light',
    description: 'Biographies et discographies des rappeurs et groupes qui ont marqué le rap français.',
    body: artistsPage({ artists: q.artists() }),
  }));

  r.get('/rappeur/:slug', (req, res) => {
    const artist = q.artist(req.params.slug);
    if (!artist) return notFound(req, res);
    send(req, res, {
      title: `${artist.name} — biographie et albums`, path: `/rappeur/${artist.slug}`, theme: 'light',
      description: truncate(artist.bio), image: artist.albums[0] ? `/img/og/${artist.albums[0].slug}.jpg` : undefined,
      body: artistPage({ artist, community: insights.community(artist.slug) }), scripts: ['/js/pages/artist.js'],
      jsonLd: { '@context': 'https://schema.org', '@type': 'MusicGroup', name: artist.name, description: artist.bio, url: `${config.publicUrl}/rappeur/${artist.slug}` },
    });
  });

  r.get('/recherche', (req, res) => {
    const term = String(req.query.q || '').trim().slice(0, 60);
    send(req, res, {
      title: term ? `Recherche : ${term}` : 'Recherche', path: '/recherche', theme: 'light', noindex: Boolean(term),
      body: searchPage({ term, results: term.length >= 2 ? q.search(term) : { albums: [], artists: [], users: [] } }),
    });
  });

  r.get('/membre/:username', (req, res) => {
    const profile = q.profile(req.params.username, req.user?.id || 0, { admin: Boolean(req.user?.admin) });
    if (!profile) return notFound(req, res);
    send(req, res, {
      title: `${profile.display_name} (@${profile.username})`, path: `/membre/${profile.username}`, theme: 'dark',
      description: truncate(profile.bio || `Le carnet d'écoute de ${profile.display_name} sur MyRapFr : ${profile.stats.listened} albums écoutés.`),
      body: profilePage({ profile, user: req.user, badges: badges.earned(profile.id) }), scripts: ['/js/pages/social.js'],
    });
  });

  // Statistiques et bilan de l'année : mêmes règles de visibilité que le profil.
  const visibleProfile = (req) => q.profile(req.params.username, req.user?.id || 0, { admin: Boolean(req.user?.admin) });

  r.get('/membre/:username/stats', (req, res) => {
    const profile = visibleProfile(req);
    if (!profile) return notFound(req, res);
    send(req, res, {
      title: `Statistiques de ${profile.display_name}`, path: req.path, theme: 'dark',
      description: `Le rap français de ${profile.display_name} en chiffres : décennies, rappeurs, notes.`,
      body: statsPage({ profile, s: stats.overview(profile.id), years: stats.years(profile.id) }),
    });
  });

  r.get('/membre/:username/badges', (req, res) => {
    const profile = visibleProfile(req);
    if (!profile) return notFound(req, res);
    const list = badges.all(profile.id);
    send(req, res, {
      title: `Badges de ${profile.display_name}`, path: req.path, theme: 'dark',
      description: `${list.filter((b) => b.earnedAt).length} badges obtenus par ${profile.display_name} sur MyRapFr.`,
      body: badgesPage({ profile, list }),
    });
  });

  r.get('/membre/:username/bilan/:year?', (req, res) => {
    const profile = visibleProfile(req);
    if (!profile) return notFound(req, res);
    const years = stats.years(profile.id);
    const year = /^\d{4}$/.test(req.params.year || '') ? req.params.year : years[0];
    if (!req.params.year && year) return res.redirect(302, `/membre/${profile.username}/bilan/${year}`);
    const b = year ? stats.year(profile.id, year) : null;
    if (!b) return notFound(req, res);
    send(req, res, {
      title: `L'année ${year} en rap de ${profile.display_name}`, path: req.path, theme: 'dark', bodyClass: 'page-wrapped',
      description: `${b.albums} albums écoutés en ${year}${b.best[0] ? `, avec ${b.best[0].album.title} en tête` : ''}. Le bilan de ${profile.display_name} sur MyRapFr.`,
      image: b.best[0] ? `/img/og/${b.best[0].album.slug}.jpg` : undefined,
      body: yearPage({ profile, b, years, isMe: profile.isMe }),
    });
  });

  for (const [slugPath, direction] of [['abonnes', 'followers'], ['abonnements', 'following']]) {
    r.get(`/membre/:username/${slugPath}`, (req, res) => {
      const profile = q.user(req.params.username);
      if (!profile) return notFound(req, res);
      send(req, res, {
        title: `${direction === 'followers' ? 'Abonnés' : 'Abonnements'} de ${profile.display_name}`, path: req.path, theme: 'light', noindex: true,
        body: followPage({ profile, users: q.followList(profile.id, direction), direction }),
      });
    });
  }

  r.get('/liste/:id', (req, res) => {
    const list = q.list(Number(req.params.id));
    if (!list) return notFound(req, res);
    send(req, res, {
      title: `${list.title}, une liste de ${list.display_name}`, path: `/liste/${list.id}`, theme: 'dark',
      description: truncate(list.description || `${list.albums.length} albums choisis par ${list.display_name} sur MyRapFr.`),
      image: list.albums[0] ? `/img/og/${list.albums[0].slug}.jpg` : undefined,
      body: listPage({ list, user: req.user, friends: req.user?.username === list.username ? q.friends(req.user.id) : [] }), scripts: ['/js/pages/social.js'],
    });
  });

  r.get('/admin', (req, res) => {
    if (!req.user?.admin) return notFound(req, res);
    const query = String(req.query.q || '').trim().slice(0, 40);
    send(req, res, {
      title: 'Modération', path: '/admin', theme: 'light', noindex: true,
      body: adminPage({
        stats: mod.stats(), reviewReports: mod.reviewReports(), userReports: mod.userReports(), commentReports: mod.commentReports(), messageReports: mod.messageReports(),
        members: mod.findMembers(query), query, journal: mod.journal(),
      }),
      scripts: ['/js/pages/admin.js'],
    });
  });

  r.get('/chronique/:id', (req, res) => {
    const id = Number.parseInt(req.params.id, 10);
    const r = Number.isSafeInteger(id) ? q.reviewThread(id, req.user?.id || 0, { admin: Boolean(req.user?.admin) }) : null;
    if (!r || !r.album) return notFound(req, res);
    const canComment = Boolean(req.user?.verified && !r.hidden_at && r.body);
    send(req, res, {
      title: `Chronique de ${r.display_name} sur ${r.album.title}`, path: `/chronique/${r.id}`, theme: 'dark',
      description: truncate(r.body || `${r.display_name} a noté ${r.album.title} de ${r.album.artist.name}.`),
      image: `/img/og/${r.album.slug}.jpg`, noindex: Boolean(r.hidden_at),
      body: reviewPage({ r, user: req.user, canComment }), scripts: ['/js/pages/album.js', '/js/pages/thread.js'],
    });
  });

  r.get('/messages', (req, res) => {
    if (!needUser(req, res)) return;
    send(req, res, {
      title: 'Messages', path: '/messages', theme: 'light', noindex: true,
      body: inboxPage({ conversations: dm.conversations(req.user.id), friends: q.friends(req.user.id) }),
    });
  });

  r.get('/messages/:username', (req, res) => {
    if (!needUser(req, res)) return;
    const peer = q.user(req.params.username);
    if (!peer || peer.suspended_at || peer.id === req.user.id) return notFound(req, res);
    const messages = dm.thread(req.user.id, peer.id);
    const canMessage = dm.canMessage(req.user.id, peer.id);
    if (!messages.length && !canMessage) return notFound(req, res);
    dm.markRead(req.user.id, peer.id);
    send(req, res, {
      title: `Conversation avec ${peer.display_name}`, path: '/messages', theme: 'light', noindex: true,
      body: threadPage({ peer, messages, canMessage, verified: req.user.verified }), scripts: ['/js/pages/messages.js'],
    });
  });

  r.get('/importer', (req, res) => {
    if (!needUser(req, res)) return;
    send(req, res, {
      title: 'Importer mon historique', path: '/importer', theme: 'light', noindex: true,
      body: importPage({ lastfm: Boolean(config.lastfmKey), username: req.user.username }), scripts: ['/js/pages/import.js'],
    });
  });

  r.get('/notifications', (req, res) => {
    if (!needUser(req, res)) return;
    const list = q.notifications(req.user.id);
    db.prepare("UPDATE notifications SET read_at = datetime('now') WHERE user_id = ? AND read_at IS NULL").run(req.user.id);
    send(req, res, {
      title: 'Notifications', path: '/notifications', theme: 'light', noindex: true,
      body: notificationsPage({ list }),
    });
  });

  // Désabonnement du résumé hebdomadaire, en un clic depuis l'e-mail (lien signé, sans connexion).
  r.get('/desabonnement', (req, res) => {
    const id = Number.parseInt(req.query.u, 10);
    const ok = Number.isSafeInteger(id) && checkUnsubscribe(id, req.query.t);
    if (ok) db.prepare('UPDATE users SET digest = 0 WHERE id = ?').run(id);
    send(req, res, {
      title: 'Désabonnement', path: '/desabonnement', theme: 'light', noindex: true, status: ok ? 200 : 400,
      body: html`<section class="page-head"><h1 class="display">${ok ? 'C\'est noté.' : 'Lien invalide.'}</h1>
        <p class="lede">${ok ? 'Tu ne recevras plus le résumé hebdomadaire. Tu peux le réactiver dans tes paramètres.' : 'Ce lien de désabonnement est incomplet. Désactive le résumé depuis tes paramètres.'}</p></section>`,
    });
  });

  // Album au hasard (dans « À écouter » avec ?liste=a-ecouter).
  r.get('/au-hasard', (req, res) => {
    const slug = recommend.random(req.user?.id || 0, { wishlist: req.query.liste === 'a-ecouter' }) || recommend.random();
    res.set('Cache-Control', 'no-store').redirect(302, slug ? `/album/${slug}` : '/albums');
  });

  r.get('/classements', (req, res) => {
    const viewer = req.user?.id || 0;
    let trendingDays = 7;
    let trending = charts.trending(7);
    if (trending.length < 4) { trendingDays = 30; trending = charts.trending(30); }
    send(req, res, {
      title: 'Classements', path: '/classements', theme: 'dark',
      description: 'Les albums de rap français les mieux notés et les plus écoutés par les membres de MyRapFr, et les chroniques les plus aimées du mois.',
      body: chartsPage({
        topRated: charts.topRated(), trending, trendingDays, topReviews: charts.topReviews(viewer),
        members: charts.activeMembers(), challenge: charts.challenge(viewer), user: req.user,
      }),
      scripts: ['/js/pages/album.js'],
    });
  });

  r.get('/defi', (req, res) => {
    const c = charts.challenge(req.user?.id || 0);
    send(req, res, {
      title: `Défi du mois : ${c.title}`, path: '/defi', theme: 'dark',
      description: `${c.text} Le défi d'écoute de ${c.month} sur MyRapFr.`,
      image: c.albums[0] ? `/img/og/${c.albums[0].slug}.jpg` : undefined,
      body: challengePage({ c, user: req.user }),
    });
  });

  r.get('/amis', (req, res) => {
    if (!needUser(req, res)) return;
    send(req, res, {
      title: 'Amis', path: '/amis', theme: 'light', noindex: true,
      body: friendsPage({
        hub: q.friendsHub(req.user.id),
        inviteUrl: `${config.publicUrl}/inscription?utm_source=invitation&utm_medium=lien&utm_campaign=amis`,
      }),
      scripts: ['/js/pages/social.js'],
    });
  });

  r.get('/fil', (req, res) => {
    if (!needUser(req, res)) return;
    send(req, res, {
      title: "Fil d'actu", path: '/fil', theme: 'dark', noindex: true,
      body: feedPage({ feed: q.feed(req.user.id), recent: q.recentReviews(12, req.user.id), user: req.user, challenge: challengeCard(charts.challenge(req.user.id)), forYou: recommend.forYou(req.user.id), dayAlbum: recommend.albumOfDay() }),
      scripts: ['/js/pages/album.js'],
    });
  });

  // ---------- Compte ----------
  const authPage = (path, title, view, opts = {}) => r.get(path, (req, res) => {
    if (opts.guestOnly && req.user) return res.redirect(303, `/membre/${req.user.username}`);
    send(req, res, {
      title, path, theme: 'light', noindex: true, bodyClass: 'page-auth',
      body: view(req), scripts: ['/js/pages/account.js'],
    });
  });

  authPage('/inscription', 'Créer un compte', () => registerPage({ formToken: issueFormToken() }), { guestOnly: true });
  authPage('/connexion', 'Connexion', (req) => loginPage({ formToken: issueFormToken(), back: safeBack(req.query.retour) }), { guestOnly: true });
  authPage('/mot-de-passe-oublie', 'Mot de passe oublié', () => forgotPage({ formToken: issueFormToken() }));
  authPage('/nouveau-mot-de-passe', 'Nouveau mot de passe', (req) => resetPage({ token: String(req.query.token || '').slice(0, 200) }));
  authPage('/confirmer', 'Confirmation', (req) => confirmPage({ token: String(req.query.token || '').slice(0, 200) }));

  r.get('/compte', (req, res) => {
    if (!needUser(req, res)) return;
    const me = db.prepare('SELECT username, email, display_name, avatar, bio, digest, email_verified_at FROM users WHERE id = ?').get(req.user.id);
    me.favorites = db.prepare('SELECT al.slug FROM favorites f JOIN albums al ON al.id = f.album_id WHERE f.user_id = ? ORDER BY position')
      .all(req.user.id).map((x) => x.slug);
    send(req, res, {
      title: 'Paramètres', path: '/compte', theme: 'light', noindex: true,
      body: settingsPage({ me, albums: q.albums({ sort: 'title' }), picks: q.avatarPicks(req.user.id), blocked: q.blockedBy(req.user.id), mailEnabled }), scripts: ['/js/pages/account.js'],
    });
  });

  // ---------- Légal ----------
  const legal = (path, title, view, description) => r.get(path, (req, res) => send(req, res, {
    title, path, theme: 'light', body: view(), description, scripts: path === '/cookies' ? ['/js/pages/account.js'] : [],
  }));
  legal('/confidentialite', 'Confidentialité', privacyPage, 'Comment MyRapFr protège tes données personnelles : données collectées, durées de conservation, droits RGPD.');
  legal('/cookies', 'Cookies', cookiesPage, "Les cookies utilisés par MyRapFr : uniquement ce qui est nécessaire, aucun pistage.");
  legal('/cgu', "Conditions d'utilisation", termsPage, "Les conditions générales d'utilisation de MyRapFr.");
  legal('/mentions-legales', 'Mentions légales', legalNoticePage, 'Mentions légales de MyRapFr : éditeur, hébergement, contact.');

  r.get('/plan-du-site', (req, res) => send(req, res, {
    title: 'Plan du site', path: '/plan-du-site', theme: 'light',
    description: 'Toutes les pages de MyRapFr : albums, rappeurs et informations.',
    body: sitemapPage({ albums: q.albums({ sort: 'title' }), artists: q.artists() }),
  }));

  // ---------- SEO ----------
  // Images-clés du corridor de pochettes, calculées une fois.
  const streamStyles = streamCss();
  r.get('/css/stream.css', (req, res) => {
    res.type('text/css').set('Cache-Control', config.isProd ? 'public, max-age=86400' : 'no-cache').send(streamStyles);
  });

  r.get('/robots.txt', (req, res) => {
    res.type('text/plain').send([
      'User-agent: *',
      'Allow: /',
      'Disallow: /api/',
      'Disallow: /compte',
      'Disallow: /fil',
      'Disallow: /recherche',
      'Disallow: /confirmer',
      'Disallow: /nouveau-mot-de-passe',
      '',
      `Sitemap: ${config.publicUrl}/sitemap.xml`,
      '',
    ].join('\n'));
  });

  r.get('/sitemap.xml', (req, res) => {
    const { albums, artists } = q.sitemapEntries();
    const today = new Date().toISOString().slice(0, 10);
    const url = (path, priority, freq = 'weekly') =>
      `  <url><loc>${config.publicUrl}${path}</loc><lastmod>${today}</lastmod><changefreq>${freq}</changefreq><priority>${priority}</priority></url>`;
    const urls = [
      url('/', '1.0', 'daily'), url('/albums', '0.9', 'daily'), url('/rappeurs', '0.8'), url('/classements', '0.7', 'daily'), url('/defi', '0.6', 'weekly'),
      ...albums.map((s) => url(`/album/${s}`, '0.7', 'daily')),
      ...artists.map((s) => url(`/rappeur/${s}`, '0.6')),
      url('/plan-du-site', '0.3', 'monthly'),
      ...['/confidentialite', '/cgu', '/mentions-legales', '/cookies'].map((p) => url(p, '0.2', 'yearly')),
    ];
    res.type('application/xml').send(`<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join('\n')}\n</urlset>\n`);
  });

  // Service worker : sa version change à chaque démarrage du serveur, les anciens caches sont alors vidés.
  const swVersion = `${process.env.npm_package_version || '0'}-${Date.now().toString(36)}`;
  const swSource = fs.readFileSync(path.join(config.root, 'server', 'sw.template.js'), 'utf8').replace('__VERSION__', swVersion);
  r.get('/sw.js', (req, res) => {
    res.set({ 'Cache-Control': 'no-cache', 'Service-Worker-Allowed': '/' }).type('application/javascript').send(swSource);
  });

  // Page affichée par l'application installée quand il n'y a pas de réseau (aucune donnée personnelle).
  r.get('/hors-ligne', (req, res) => {
    res.set('Cache-Control', 'no-cache').send(layout({
      title: 'Hors ligne', path: '/hors-ligne', theme: 'dark', noindex: true, user: null,
      body: offlinePage(),
    }));
  });

  r.get('/site.webmanifest', (req, res) => {
    res.type('application/manifest+json').json({
      id: '/', name: 'MyRapFr', short_name: 'MyRapFr', lang: 'fr', dir: 'ltr', start_url: '/?utm_source=app&utm_medium=pwa', scope: '/', display: 'standalone',
      description: "Le carnet d'écoute du rap français : note, chronique et partage tes albums avec tes amis.",
      categories: ['music', 'social', 'entertainment'],
      background_color: '#000000', theme_color: '#000000',
      shortcuts: [
        { name: 'Albums', url: '/albums', icons: [{ src: '/img/icon-192.png', sizes: '192x192' }] },
        { name: "Fil d'actu", url: '/fil', icons: [{ src: '/img/icon-192.png', sizes: '192x192' }] },
        { name: 'Classements', url: '/classements', icons: [{ src: '/img/icon-192.png', sizes: '192x192' }] },
        { name: 'Défi du mois', url: '/defi', icons: [{ src: '/img/icon-192.png', sizes: '192x192' }] },
      ],
      icons: [
        { src: '/img/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: '/img/icon-512.png', sizes: '512x512', type: 'image/png' },
        { src: '/img/icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
      ],
    });
  });

  r.get('/.well-known/security.txt', (req, res) => {
    const expires = new Date(Date.now() + 365 * 86400_000).toISOString();
    res.type('text/plain').send(`Contact: mailto:${config.contactEmail}\nExpires: ${expires}\nPreferred-Languages: fr, en\n`);
  });

  r.notFound = notFound;
  return r;
}
