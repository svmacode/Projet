import express from 'express';
import { config } from './config.js';
import { catalogStatus } from './auto-images.js';
import { streamCss } from './views/stream.js';
import { issueFormToken } from './security.js';
import { layout } from './views/layout.js';
import { homePage } from './views/home.js';
import { albumsPage, albumPage, artistsPage, artistPage, searchPage, catalogueUrl } from './views/catalog.js';
import { profilePage, followPage, listPage, feedPage, friendsPage } from './views/social.js';
import { registerPage, loginPage, forgotPage, resetPage, confirmPage, settingsPage } from './views/account.js';
import { privacyPage, cookiesPage, termsPage, legalNoticePage, sitemapPage, notFoundPage } from './views/legal.js';

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

  const send = (req, res, opts) => {
    res.set('Cache-Control', 'no-cache');
    res.status(opts.status || 200).send(layout({ ...opts, user: req.user ? { ...req.user } : null, csrf: req.csrfToken }));
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
      body: artistPage({ artist }),
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
    const profile = q.profile(req.params.username, req.user?.id || 0);
    if (!profile) return notFound(req, res);
    send(req, res, {
      title: `${profile.display_name} (@${profile.username})`, path: `/membre/${profile.username}`, theme: 'dark',
      description: truncate(profile.bio || `Le carnet d'écoute de ${profile.display_name} sur MyRapFr : ${profile.stats.listened} albums écoutés.`),
      body: profilePage({ profile, user: req.user }), scripts: ['/js/pages/social.js'],
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
      body: listPage({ list, user: req.user }), scripts: ['/js/pages/social.js'],
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
      body: feedPage({ feed: q.feed(req.user.id), recent: q.recentReviews(), user: req.user }),
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
    const me = db.prepare('SELECT username, email, display_name, avatar, bio, email_verified_at FROM users WHERE id = ?').get(req.user.id);
    me.favorites = db.prepare('SELECT al.slug FROM favorites f JOIN albums al ON al.id = f.album_id WHERE f.user_id = ? ORDER BY position')
      .all(req.user.id).map((x) => x.slug);
    send(req, res, {
      title: 'Paramètres', path: '/compte', theme: 'light', noindex: true,
      body: settingsPage({ me, albums: q.albums({ sort: 'title' }), picks: q.avatarPicks(req.user.id) }), scripts: ['/js/pages/account.js'],
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
      url('/', '1.0', 'daily'), url('/albums', '0.9', 'daily'), url('/rappeurs', '0.8'),
      ...albums.map((s) => url(`/album/${s}`, '0.7', 'daily')),
      ...artists.map((s) => url(`/rappeur/${s}`, '0.6')),
      url('/plan-du-site', '0.3', 'monthly'),
      ...['/confidentialite', '/cgu', '/mentions-legales', '/cookies'].map((p) => url(p, '0.2', 'yearly')),
    ];
    res.type('application/xml').send(`<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join('\n')}\n</urlset>\n`);
  });

  r.get('/site.webmanifest', (req, res) => {
    res.type('application/manifest+json').json({
      name: 'MyRapFr', short_name: 'MyRapFr', lang: 'fr', start_url: '/', display: 'standalone',
      background_color: '#000000', theme_color: '#000000',
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
