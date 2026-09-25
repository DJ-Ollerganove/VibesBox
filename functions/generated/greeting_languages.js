'use strict';
/** AUTO-GENERIERT — nicht bearbeiten. Quelle: l10n/languages.json · node scripts/sync-language-registry.js */

const GREETING_LANGUAGE_CODES = Object.freeze([
  "de",
  "en",
  "fr",
  "ru",
  "zh",
  "es",
  "tr",
  "pt",
  "it",
  "uk",
  "hi",
  "sq",
  "vi",
  "ja",
  "el",
  "nl",
  "pl",
  "cs",
  "th",
  "ar"
]);

const GREETING_LANG_LABELS = Object.freeze({
  "de": "German",
  "en": "English",
  "fr": "French",
  "ru": "Russian",
  "zh": "Chinese",
  "es": "Spanish",
  "tr": "Turkish",
  "pt": "Portuguese",
  "it": "Italian",
  "uk": "Ukrainian",
  "hi": "Hindi",
  "sq": "Albanian",
  "vi": "Vietnamese",
  "ja": "Japanese",
  "el": "Greek",
  "nl": "Dutch",
  "pl": "Polish",
  "cs": "Czech",
  "th": "Thai",
  "ar": "Arabic"
});

const _greetingLangSet = new Set(GREETING_LANGUAGE_CODES);

/** Aliase → kanonischer Code (wie LocaleHelper.mapToSupportedOrEnglish). */
const GREETING_LANG_ALIASES = Object.freeze({
  ua: 'uk',
  al: 'sq',
  jp: 'ja',
  gr: 'el',
  cz: 'cs',
});

const _PREFIX_CANONICAL = [
  'zh', 'es', 'tr', 'pt', 'it', 'uk', 'hi', 'sq', 'vi', 'ja', 'el', 'nl', 'pl', 'cs', 'th', 'ar',
];

/**
 * Normalisiert App-/Geräte-Locale auf einen Eintrag aus languages.json.
 * Unbekannt → en (Fallback für Gemini-Prompt).
 * @param {string} code
 * @returns {string}
 */
function normalizeGreetingLang(code) {
  const raw = String(code || '')
    .toLowerCase()
    .trim()
    .split(/[-_]/)[0];
  if (!raw) return 'en';
  let canonical = GREETING_LANG_ALIASES[raw] || raw;
  for (const prefix of _PREFIX_CANONICAL) {
    if (canonical.startsWith(prefix) && _greetingLangSet.has(prefix)) {
      return prefix;
    }
  }
  if (_greetingLangSet.has(canonical)) return canonical;
  return 'en';
}

module.exports = {
  GREETING_LANGUAGE_CODES,
  GREETING_LANG_LABELS,
  normalizeGreetingLang,
};
