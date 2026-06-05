/**
 * Lokale Sprachliste für PWA & Erdkugel-Menü (kein Firestore).
 * AUTO-GENERIERT — nicht von Hand editieren.
 * Quelle: public/vb/babel/pwa-languages.json
 * Erzeugen: node scripts/pwa-lang-sync-registry.js
 */
(function () {
  window.DEFAULT_PWA_LANGUAGES = [
    { code: "sq", name: "Albanian", icon: "sq", js_path: "/vb/lang/sq.js" },
    { code: "ar", name: "Arabic", icon: "ar", js_path: "/vb/lang/ar.js" },
    { code: "zh", name: "Chinese", icon: "zh", js_path: "/vb/lang/zh.js" },
    { code: "cs", name: "Czech", icon: "cs", js_path: "/vb/lang/cs.js" },
    { code: "nl", name: "Dutch", icon: "nl", js_path: "/vb/lang/nl.js" },
    { code: "en", name: "English", icon: "en", js_path: "/vb/lang/en.js" },
    { code: "fr", name: "French", icon: "fr", js_path: "/vb/lang/fr.js" },
    { code: "de", name: "German", icon: "de", js_path: "/vb/lang/de.js" },
    { code: "el", name: "Greek", icon: "el", js_path: "/vb/lang/el.js" },
    { code: "hi", name: "Hindi", icon: "hi", js_path: "/vb/lang/hi.js" },
    { code: "it", name: "Italian", icon: "it", js_path: "/vb/lang/it.js" },
    { code: "ja", name: "Japanese", icon: "ja", js_path: "/vb/lang/ja.js" },
    { code: "pl", name: "Polish", icon: "pl", js_path: "/vb/lang/pl.js" },
    { code: "pt", name: "Portuguese", icon: "pt", js_path: "/vb/lang/pt.js" },
    { code: "ru", name: "Russian", icon: "ru", js_path: "/vb/lang/ru.js" },
    { code: "es", name: "Spanish", icon: "es", js_path: "/vb/lang/es.js" },
    { code: "tr", name: "Turkish", icon: "tr", js_path: "/vb/lang/tr.js" },
    { code: "uk", name: "Ukrainian", icon: "uk", js_path: "/vb/lang/uk.js" },
    { code: "vi", name: "Vietnamese", icon: "vi", js_path: "/vb/lang/vi.js" },
  ];
  var _pwaLangExclude = ["ar"];
  window.pwaAvailableLanguages = window.DEFAULT_PWA_LANGUAGES.filter(function (e) {
    return e && e.code && _pwaLangExclude.indexOf(e.code) === -1;
  });
  window.PWA_LANGUAGE_NAME_KEYS = {
      "de": "lang_german",
      "en": "lang_english",
      "fr": "lang_french",
      "ru": "lang_russian",
      "zh": "lang_chinese",
      "es": "lang_spanish",
      "tr": "lang_turkish",
      "pt": "lang_portuguese",
      "it": "lang_italian",
      "uk": "lang_ukrainian",
      "hi": "lang_hindi",
      "sq": "lang_albanian",
      "vi": "lang_vietnamese",
      "ja": "lang_japanese",
      "el": "lang_greek",
      "nl": "lang_dutch",
      "pl": "lang_polish",
      "cs": "lang_czech",
      "ar": "lang_arabic"
  };
})();
