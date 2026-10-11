// Affiche les visites et inscriptions venues de liens de campagne (paramètres UTM), sur 90 jours.
// Usage : npm run stats:utm
import { openDb } from '../server/db.js';

const db = openDb();
const visits = db.prepare(`
  SELECT source, medium, campaign, SUM(visits) AS visites FROM utm_stats
  WHERE day >= date('now', '-90 days') GROUP BY source, medium, campaign ORDER BY visites DESC`).all();
const signups = db.prepare(`
  SELECT utm_source AS source, utm_medium AS medium, utm_campaign AS campaign, COUNT(*) AS inscriptions FROM users
  WHERE utm_source IS NOT NULL AND created_at >= datetime('now', '-90 days') GROUP BY 1, 2, 3 ORDER BY inscriptions DESC`).all();
console.log('Visites par campagne (90 derniers jours) :');
console.table(visits.length ? visits : [{ info: 'aucune visite avec paramètres UTM' }]);
console.log("Inscriptions par campagne (visiteurs ayant accepté la mesure d'audience) :");
console.table(signups.length ? signups : [{ info: 'aucune inscription attribuée' }]);
db.close();
