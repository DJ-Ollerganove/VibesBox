/**
 * Lokale Sprachliste für PWA & Erdkugel-Menü (kein Firestore).
 * Muss vor firebase-init.js geladen werden.
 * Anzeigenamen in der Sprachwahl: einheitlich Englisch; Flagge über icon (flags.svg#flag-*).
 */
(function () {
  /* Reihenfolge: alphabetisch nach englischem Anzeigenamen */
  window.DEFAULT_PWA_LANGUAGES = [
    { code: 'zh', name: 'Chinese', icon: 'zh', js_path: '/vb/lang/zh.js' },
    { code: 'en', name: 'English', icon: 'en', js_path: '/vb/lang/en.js' },
    { code: 'fr', name: 'French', icon: 'fr', js_path: '/vb/lang/fr.js' },
    { code: 'de', name: 'German', icon: 'de', js_path: '/vb/lang/de.js' },
    { code: 'hi', name: 'Hindi', icon: 'hi', js_path: '/vb/lang/hi.js' },
    { code: 'it', name: 'Italian', icon: 'it', js_path: '/vb/lang/it.js' },
    { code: 'pt', name: 'Portuguese', icon: 'pt', js_path: '/vb/lang/pt.js' },
    { code: 'ru', name: 'Russian', icon: 'ru', js_path: '/vb/lang/ru.js' },
    { code: 'es', name: 'Spanish', icon: 'es', js_path: '/vb/lang/es.js' },
    { code: 'tr', name: 'Turkish', icon: 'tr', js_path: '/vb/lang/tr.js' },
    { code: 'uk', name: 'Ukrainian', icon: 'uk', js_path: '/vb/lang/uk.js' }
  ];
  window.pwaAvailableLanguages = window.DEFAULT_PWA_LANGUAGES.filter(function (e) {
    return e && e.code && e.code !== 'ar';
  });
})();
