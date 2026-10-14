// Keep this catalog aligned with the Flutter omni-v1 demo's LangCatalog.
export const HINT_LANGUAGES = Object.freeze([
  { code: 'ar', name: 'Arabic' },
  { code: 'ba', name: 'Bashkir' },
  { code: 'eu', name: 'Basque' },
  { code: 'be', name: 'Belarusian' },
  { code: 'bn', name: 'Bengali' },
  { code: 'bg', name: 'Bulgarian' },
  { code: 'yue', name: 'Cantonese' },
  { code: 'ca', name: 'Catalan' },
  { code: 'hr', name: 'Croatian' },
  { code: 'cs', name: 'Czech' },
  { code: 'da', name: 'Danish' },
  { code: 'nl', name: 'Dutch' },
  { code: 'en', name: 'English' },
  { code: 'eo', name: 'Esperanto' },
  { code: 'et', name: 'Estonian' },
  { code: 'fi', name: 'Finnish' },
  { code: 'fr', name: 'French' },
  { code: 'gl', name: 'Galician' },
  { code: 'de', name: 'German' },
  { code: 'el', name: 'Greek' },
  { code: 'he', name: 'Hebrew' },
  { code: 'hi', name: 'Hindi' },
  { code: 'hu', name: 'Hungarian' },
  { code: 'id', name: 'Indonesian' },
  { code: 'ia', name: 'Interlingua' },
  { code: 'ga', name: 'Irish' },
  { code: 'it', name: 'Italian' },
  { code: 'ja', name: 'Japanese' },
  { code: 'ko', name: 'Korean' },
  { code: 'lv', name: 'Latvian' },
  { code: 'lt', name: 'Lithuanian' },
  { code: 'ms', name: 'Malay' },
  { code: 'mt', name: 'Maltese' },
  { code: 'cmn', name: 'Mandarin' },
  { code: 'mr', name: 'Marathi' },
  { code: 'mn', name: 'Mongolian' },
  { code: 'no', name: 'Norwegian' },
  { code: 'fa', name: 'Persian' },
  { code: 'pl', name: 'Polish' },
  { code: 'pt', name: 'Portuguese' },
  { code: 'ro', name: 'Romanian' },
  { code: 'ru', name: 'Russian' },
  { code: 'sk', name: 'Slovak' },
  { code: 'sl', name: 'Slovenian' },
  { code: 'es', name: 'Spanish' },
  { code: 'sw', name: 'Swahili' },
  { code: 'sv', name: 'Swedish' },
  { code: 'tl', name: 'Tagalog' },
  { code: 'ta', name: 'Tamil' },
  { code: 'th', name: 'Thai' },
  { code: 'tr', name: 'Turkish' },
  { code: 'uk', name: 'Ukrainian' },
  { code: 'ur', name: 'Urdu' },
  { code: 'ug', name: 'Uyghur' },
  { code: 'vi', name: 'Vietnamese' },
  { code: 'cy', name: 'Welsh' },
].map(language => Object.freeze(language)));

export const LANGUAGE_HINTS_STORAGE = 'speechmatics.oak.languageHints';
const supportedCodes = new Set(HINT_LANGUAGES.map(language => language.code));

function normalizeHints(value) {
  if (!Array.isArray(value)) throw new Error('Choose expected languages from the list.');
  const codes = value.map(code => {
    const normalized = typeof code === 'string' ? code.trim().toLowerCase() : '';
    if (!supportedCodes.has(normalized)) throw new Error('Choose expected languages from the list.');
    return normalized;
  });
  return [...new Set(codes)];
}

export function createLanguagePreferences(storage) {
  if (arguments.length === 0) {
    try { storage = globalThis.localStorage; } catch { storage = null; }
  }
  let hints = [];
  function refresh() {
    try {
      const stored = storage.getItem(LANGUAGE_HINTS_STORAGE);
      hints = stored === null ? [] : normalizeHints(JSON.parse(stored));
    } catch { hints = []; }
  }
  refresh();
  return {
    refresh,
    get: () => [...hints],
    save(value) {
      const next = normalizeHints(value);
      try { storage.setItem(LANGUAGE_HINTS_STORAGE, JSON.stringify(next)); }
      catch { throw new Error('Browser storage is unavailable. Allow site storage to save your expected languages.'); }
      hints = next;
    },
  };
}

export const languagePreferences = createLanguagePreferences();
