// Photos de profil. Deux choix possibles pour chaque membre :
//  - une photo importée : recodée en WebP carré de 400 px (les métadonnées, dont la position GPS,
//    disparaissent au passage), rangée dans data/avatars/ sous un nom aléatoire ;
//  - une pochette d'album du catalogue.
// En base, la colonne users.avatar vaut NULL, « p:<fichier> » (photo) ou « c:<album> » (pochette).
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import sharp from 'sharp';
import { config } from './config.js';

export const avatarDir = path.join(config.root, 'data', 'avatars');
export const AVATAR_FILE = /^[a-f0-9]{32}\.webp$/;
const FORMATS = new Set(['jpeg', 'png', 'webp', 'gif', 'heif', 'avif']);

// Adresse de l'image à afficher, ou null (initiale du nom à la place).
export function avatarUrl(avatar) {
  if (!avatar) return null;
  if (avatar.startsWith('p:') && AVATAR_FILE.test(avatar.slice(2))) return `/img/avatars/${avatar.slice(2)}`;
  if (avatar.startsWith('c:')) return `/img/covers/${avatar.slice(2)}-300.webp`;
  return null;
}

// Vérifie et recode une image envoyée. Renvoie la valeur à enregistrer en base.
export async function saveUpload(buffer) {
  let image;
  try {
    image = sharp(buffer, { limitInputPixels: 40_000_000, failOn: 'error' });
    const meta = await image.metadata();
    if (!FORMATS.has(meta.format)) throw new Error('format');
    if (!meta.width || !meta.height || meta.width < 64 || meta.height < 64) throw new Error('petite');
  } catch (err) {
    throw Object.assign(new Error(err.message === 'petite'
      ? 'Image trop petite : 64 × 64 pixels minimum.'
      : 'Fichier illisible. Choisis une image JPEG, PNG, WebP ou GIF.'), { status: 400 });
  }
  const out = await image.rotate().resize(400, 400, { fit: 'cover', position: 'attention' }).webp({ quality: 82 }).toBuffer();
  fs.mkdirSync(avatarDir, { recursive: true });
  const file = `${crypto.randomBytes(16).toString('hex')}.webp`;
  fs.writeFileSync(path.join(avatarDir, file), out);
  return `p:${file}`;
}

// Supprime le fichier d'une ancienne photo importée (rien à faire pour une pochette).
export function removeAvatarFile(avatar) {
  if (!avatar?.startsWith('p:') || !AVATAR_FILE.test(avatar.slice(2))) return;
  try { fs.unlinkSync(path.join(avatarDir, avatar.slice(2))); } catch { /* déjà supprimé */ }
}
