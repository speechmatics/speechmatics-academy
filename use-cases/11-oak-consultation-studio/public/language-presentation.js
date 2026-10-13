import { LANGUAGES } from './demo-data.js';

const BRAND_TONES = {
  '#F76B15': { ink: '#9F3A06', soft: '#FFF1E7', border: '#F8D3B9' },
  '#29A383': { ink: '#146B55', soft: '#E7F5EF', border: '#C9E9DD' },
  '#0D3C48': { ink: '#0D3C48', soft: '#E8F3F5', border: '#C2E0E6' },
  '#FFC53D': { ink: '#805E10', soft: '#FFF6D9', border: '#F3E0AC' },
};
const EXTRA_TONES = {
  ru: { color: '#8E4EC6', ink: '#5D268C', soft: '#F4EEFA', border: '#DECEEE' },
  lv: { color: '#3E63DD', ink: '#2845A0', soft: '#EDF2FE', border: '#C6D4FA' },
  und: { color: '#758581', ink: '#405550', soft: '#F1F5F4', border: '#DCE7E3' },
};
const RTL_LANGUAGES = new Set(['ar', 'arc', 'ckb', 'dv', 'fa', 'he', 'nqo', 'ps', 'sd', 'syr', 'ug', 'ur', 'yi']);
const PRIMARY_BRAND_LANGUAGES = new Set(['en', 'es', 'ar', 'fr']);
let languageNames;
try { languageNames = new Intl.DisplayNames(['en'], { type: 'language', fallback: 'none' }); } catch { /* Codes remain usable without DisplayNames. */ }

/** Regional/script variants share the same language identity and presentation. */
export function normalizeLanguageCode(code) {
  if (typeof code !== 'string') return 'und';
  const tag = code.trim().replaceAll('_', '-').toLowerCase();
  if (!/^[a-z]{2,8}(?:-[a-z0-9]{1,8})*$/u.test(tag)) return 'und';
  try { return Intl.getCanonicalLocales(tag)[0].split('-')[0].toLowerCase(); }
  catch { return 'und'; }
}

function preferredTones(code) {
  if (Object.hasOwn(LANGUAGES, code)) {
    const color = LANGUAGES[code].color;
    return { color, ...BRAND_TONES[color] };
  }
  return EXTRA_TONES[code];
}

function languageName(code) {
  if (code === 'und') return 'Unspecified';
  if (Object.hasOwn(LANGUAGES, code)) return LANGUAGES[code].name;
  try { return languageNames?.of(code) || code.toUpperCase(); }
  catch { return code.toUpperCase(); }
}

function hashCode(code) {
  let hash = 2166136261;
  for (const character of code) hash = Math.imul(hash ^ character.charCodeAt(0), 16777619);
  return hash >>> 0;
}

function hslToHex(hue, saturation, lightness) {
  const chroma = (1 - Math.abs(2 * lightness - 1)) * saturation;
  const secondary = chroma * (1 - Math.abs((hue / 60) % 2 - 1));
  const offset = lightness - chroma / 2;
  const sectors = [[chroma, secondary, 0], [secondary, chroma, 0], [0, chroma, secondary], [0, secondary, chroma], [secondary, 0, chroma], [chroma, 0, secondary]];
  return '#' + sectors[Math.floor(hue / 60)].map(channel => Math.round((channel + offset) * 255).toString(16).padStart(2, '0')).join('').toUpperCase();
}

function generatedTones(code, attempt = 0) {
  const hue = (hashCode(code) % 360 + attempt * 137.508) % 360;
  return {
    color: hslToHex(hue, 0.68, 0.46),
    // This dark lightness keeps text readable even for bright green/yellow hues.
    ink: hslToHex(hue, 0.68, 0.24),
    soft: hslToHex(hue, 0.65, 0.96),
    border: hslToHex(hue, 0.45, 0.82),
  };
}

function colorDistanceSquared(first, second) {
  const channels = color => [1, 3, 5].map(start => parseInt(color.slice(start, start + 2), 16));
  const secondChannels = channels(second);
  return channels(first).reduce((total, channel, index) => total + (channel - secondChannels[index]) ** 2, 0);
}

function separatedTones(code, usedColors) {
  let best;
  let bestDistance = -1;
  // Keep crowded sessions bounded; if no candidate clears the spacing target,
  // use the candidate with the greatest separation from its nearest neighbor.
  for (let attempt = 0; attempt < 48; attempt++) {
    const tones = generatedTones(code, attempt);
    const distance = Math.min(...[...usedColors].map(color => colorDistanceSquared(tones.color, color)));
    if (distance >= 60 ** 2) return tones;
    if (distance > bestDistance) { best = tones; bestDistance = distance; }
  }
  return best;
}

export function getLanguagePresentation(code) {
  const normalized = normalizeLanguageCode(code);
  return {
    name: languageName(normalized),
    dir: RTL_LANGUAGES.has(normalized) ? 'rtl' : 'ltr',
    ...(preferredTones(normalized) || generatedTones(normalized)),
  };
}

/** Create once from the full consultation so filtering cannot reassign colors. */
export function createLanguagePalette(codes) {
  const normalized = [...new Set(codes.map(normalizeLanguageCode))].sort();
  const assignments = new Map();
  const usedColors = new Set();
  const generated = [];
  const priority = code => PRIMARY_BRAND_LANGUAGES.has(code) ? 0 : preferredTones(code) ? 1 : 2;
  const assignmentOrder = [...normalized].sort((first, second) => priority(first) - priority(second) || (first < second ? -1 : first > second ? 1 : 0));
  // Reserve preferred accents before selecting generated alternatives, so a
  // fallback for one language cannot crowd out a later preferred language.
  for (const code of assignmentOrder) {
    const metadata = getLanguagePresentation(code);
    if (!preferredTones(code) || usedColors.has(metadata.color)) { generated.push(code); continue; }
    usedColors.add(metadata.color);
    assignments.set(code, metadata);
  }
  for (const code of generated.sort()) {
    const metadata = { ...getLanguagePresentation(code), ...separatedTones(code, usedColors) };
    usedColors.add(metadata.color);
    assignments.set(code, metadata);
  }
  return new Map(normalized.map(code => [code, assignments.get(code)]));
}

/** Words are sorted by start. Interior gaps retain the last language; outer gaps are neutral. */
export function getWaveformLanguage(words, time) {
  if (!Number.isFinite(time) || !words.length || time < words[0].start) return null;
  // An earlier speaker's overlapping word can extend beyond the last word's end.
  if (time >= words.at(-1).end && !words.some(word => word.end > time)) return null;
  let low = 0;
  let high = words.length;
  while (low < high) {
    const middle = Math.floor((low + high) / 2);
    if (words[middle].start <= time) low = middle + 1;
    else high = middle;
  }
  return low ? normalizeLanguageCode(words[low - 1].language) : null;
}
