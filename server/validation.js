import { z } from 'zod';

// Liste courte des mots de passe les plus utilisés (complétée par la longueur minimale).
const COMMON = new Set([
  'motdepasse', 'motdepasse1', 'password', 'password1', 'password123', '1234567890',
  'azertyuiop', 'qwertyuiop', '0123456789', 'azerty1234', 'iloveyou12', 'soleil1234',
  'marseille13', 'bonjour1234', 'football10', 'doudou1234', 'chocolat12', 'loulou1234',
]);

const username = z.string().trim()
  .min(3, 'Ton pseudo doit faire au moins 3 caractères.')
  .max(24, 'Ton pseudo doit faire 24 caractères maximum.')
  .regex(/^[a-zA-Z0-9_]+$/, 'Lettres, chiffres et _ uniquement.')
  .refine((v) => !RESERVED.has(v.toLowerCase()), 'Ce pseudo est réservé.');

const RESERVED = new Set(['admin', 'administrateur', 'moderateur', 'myrapfr', 'support', 'contact', 'api', 'root']);

const email = z.string().trim().toLowerCase()
  .max(254, 'Adresse trop longue.')
  .email('Adresse e-mail invalide.');

const password = z.string()
  .min(10, 'Au moins 10 caractères.')
  .max(200, 'Mot de passe trop long.')
  .refine((v) => !COMMON.has(v.toLowerCase()), 'Ce mot de passe est trop courant.');

const antiSpam = {
  formToken: z.string().max(100).optional(),
  website: z.string().max(200).optional(),
};

export const schemas = {
  register: z.object({
    username,
    email,
    password,
    terms: z.literal(true, { message: 'Tu dois accepter les CGU.' }),
    utm: z.object({
      source: z.string().max(40).nullish(),
      medium: z.string().max(40).nullish(),
      campaign: z.string().max(40).nullish(),
    }).partial().nullish(),
    ...antiSpam,
  }),
  login: z.object({
    login: z.string().trim().min(1, 'Indique ton pseudo ou ton e-mail.').max(254),
    password: z.string().min(1, 'Indique ton mot de passe.').max(200),
    ...antiSpam,
  }),
  forgot: z.object({ email, ...antiSpam }),
  reset: z.object({ token: z.string().min(10).max(200), password }),
  verify: z.object({ token: z.string().min(10).max(200) }),
  albumState: z.object({
    rating: z.number().int().min(1).max(10).nullable().optional(),
    liked: z.boolean().optional(),
    listened: z.boolean().optional(),
    wishlist: z.boolean().optional(),
  }),
  review: z.object({
    rating: z.number().int().min(1).max(10).nullable().optional(),
    body: z.string().trim().max(5000, '5 000 caractères maximum.').default(''),
    listenedOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date invalide.').optional(),
    ...antiSpam,
  }),
  report: z.object({ reason: z.string().trim().min(3, 'Précise la raison.').max(500) }),
  comment: z.object({ body: z.string().trim().min(1, 'Écris un commentaire.').max(1000, '1 000 caractères maximum.') }),
  profile: z.object({
    displayName: z.string().trim().min(1, 'Indique un nom.').max(40, '40 caractères maximum.'),
    bio: z.string().trim().max(300, '300 caractères maximum.').default(''),
    favorites: z.array(z.string().max(120)).max(4, '4 albums favoris maximum.').default([]),
  }),
  changePassword: z.object({ current: z.string().min(1).max(200), password }),
  deleteAccount: z.object({ password: z.string().min(1, 'Confirme avec ton mot de passe.').max(200) }),
  list: z.object({
    title: z.string().trim().min(1, 'Donne un titre à ta liste.').max(80),
    description: z.string().trim().max(1000).default(''),
  }),
  listItem: z.object({ album: z.string().min(1).max(120) }),
};

// Valide le corps de la requête ; renvoie les données ou répond 400 avec les erreurs par champ.
export function validate(schema, req, res) {
  const parsed = schema.safeParse(req.body ?? {});
  if (parsed.success) return parsed.data;
  const fields = {};
  for (const issue of parsed.error.issues) {
    const key = issue.path[0] ?? 'form';
    fields[key] ??= issue.message;
  }
  res.status(400).json({ error: 'Certains champs sont à corriger.', fields });
  return null;
}
