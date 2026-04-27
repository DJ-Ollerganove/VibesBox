const admin = require('firebase-admin');

if (admin.apps.length === 0) {
admin.initializeApp({
projectId: 'dj-ollerganove'
});
}

const db = admin.firestore();

const data = {
languages: {
de: { name: "German", js_path: "/vb/lang/de.js", dart_file: "app_localizations_de.dart", active: true },
en: { name: "English", js_path: "/vb/lang/en.js", dart_file: "app_localizations_en.dart", active: true },
fr: { name: "French", js_path: "/vb/lang/fr.js", dart_file: "app_localizations_fr.dart", active: true },
ru: { name: "Russian", js_path: "/vb/lang/ru.js", dart_file: "app_localizations_ru.dart", active: true },
es: { name: "Spanish", js_path: "/vb/lang/es.js", dart_file: "app_localizations_es.dart", active: true },
pt: { name: "Portuguese", js_path: "/vb/lang/pt.js", dart_file: "app_localizations_pt.dart", active: true },
tr: { name: "Turkish", js_path: "/vb/lang/tr.js", dart_file: "app_localizations_tr.dart", active: true },
zh: { name: "Chinese", js_path: "/vb/lang/zh.js", dart_file: "app_localizations_zh.dart", active: true },
it: { name: "Italian", js_path: "/vb/lang/it.js", dart_file: "app_localizations_it.dart", active: true },
uk: { name: "Ukrainian", js_path: "/vb/lang/uk.js", dart_file: "app_localizations_uk.dart", active: true },
ar: { name: "Arabic", js_path: null, dart_file: "app_localizations_ar.dart", active: true }
}
};

async function run() {
try {
await db.collection('settings').doc('languages').set(data);
console.log('ERFOLG: settings/languages wurde in Firestore angelegt.');
process.exit(0);
} catch (e) {
console.error('FEHLER:', e);
process.exit(1);
}
}

run();
