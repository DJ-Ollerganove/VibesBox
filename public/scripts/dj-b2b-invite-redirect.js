/**
 * DJ B2B Invite — Code anzeigen/kopieren, Hinweis 7-Tage-Pro, Store-Links.
 * Android: Play-URL mit Install-Referrer (utm_content=DJ######).
 * iOS: Zwischenablage-Bridge; App-Store-Button später freischaltbar.
 */
(function () {
  'use strict';

  var PLAY_STORE_ID = 'com.vibesbox.dj';
  /** Später true + echte App-ID, wenn die App im App Store live ist. */
  var IOS_INVITE_SHOW_APP_STORE = true;
  var APP_STORE_URL = 'https://apps.apple.com/app/vibesbox/id6767363203';

  var LS_CODE = 'vb_dj_b2b_code';
  var LS_CAPTURED = 'vb_dj_b2b_captured_at';
  var COOKIE_NAME = 'vb_dj_b2b';
  var CLIPBOARD_PREFIX = 'VibesBoxB2B:';

  var I18N = {
    de: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'VibesBox App herunterladen',
      body: 'Dein Werbercode ist bereit. Lade die App und gib den Code dort ein — oder lass ihn nach dem Install automatisch übernehmen.',
      codeLabel: 'Werbercode',
      trialHint:
        'Gib diesen Code in der App ein, um 7 Tage VibesBox Pro gratis zu testen.',
      copyCode: 'Code kopieren',
      codeCopied: 'Code kopiert',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody:
        'Die App erscheint in Kürze im App Store. Code kopieren und nach der Installation in der App eingeben.',
    },
    en: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Download the VibesBox app',
      body: 'Your referral code is ready. Download the app and enter the code there — or let the app pick it up after install.',
      codeLabel: 'Referral code',
      trialHint:
        'Enter this code in the app to try VibesBox Pro free for 7 days.',
      copyCode: 'Copy code',
      codeCopied: 'Code copied',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody:
        'The app will be on the App Store soon. Copy the code and enter it in the app after install.',
    },
    ar: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'حمّل تطبيق VibesBox',
      body: 'رمز الدعوة جاهز. حمّل التطبيق وأدخل الرمز هناك.',
      codeLabel: 'رمز الدعوة',
      trialHint:
        'أدخل هذا الرمز في التطبيق لتجربة VibesBox Pro مجانًا لمدة 7 أيام.',
      copyCode: 'نسخ الرمز',
      codeCopied: 'تم نسخ الرمز',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'التطبيق قريبًا في App Store. انسخ الرمز وأدخله بعد التثبيت.',
    },
    cs: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Stáhni aplikaci VibesBox',
      body: 'Tvůj doporučovací kód je připraven. Stáhni appku a zadej kód.',
      codeLabel: 'Doporučovací kód',
      trialHint:
        'Zadej tento kód v aplikaci a vyzkoušej VibesBox Pro 7 dní zdarma.',
      copyCode: 'Kopírovat kód',
      codeCopied: 'Kód zkopírován',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'Aplikace brzy v App Store. Zkopíruj kód a zadej ho po instalaci.',
    },
    el: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Κατέβασε την εφαρμογή VibesBox',
      body: 'Ο κωδικός πρόσκλησης είναι έτοιμος. Κατέβασε την εφαρμογή και εισήγαγέ τον.',
      codeLabel: 'Κωδικός πρόσκλησης',
      trialHint:
        'Εισήγαγε αυτόν τον κωδικό στην εφαρμογή για 7 ημέρες δωρεάν VibesBox Pro.',
      copyCode: 'Αντιγραφή κωδικού',
      codeCopied: 'Ο κωδικός αντιγράφηκε',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'Η εφαρμογή σύντομα στο App Store. Αντίγραψε τον κωδικό και εισήγαγέ τον μετά την εγκατάσταση.',
    },
    es: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Descarga la app VibesBox',
      body: 'Tu código de referido está listo. Descarga la app e introdúcelo allí.',
      codeLabel: 'Código de referido',
      trialHint:
        'Introduce este código en la app para probar VibesBox Pro gratis durante 7 días.',
      copyCode: 'Copiar código',
      codeCopied: 'Código copiado',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'La app estará pronto en el App Store. Copia el código e introdúcelo tras instalar.',
    },
    fr: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Télécharge l’app VibesBox',
      body: 'Ton code parrain est prêt. Télécharge l’app et saisis-le.',
      codeLabel: 'Code parrain',
      trialHint:
        'Saisis ce code dans l’app pour tester VibesBox Pro gratuitement pendant 7 jours.',
      copyCode: 'Copier le code',
      codeCopied: 'Code copié',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'L’app arrive bientôt sur l’App Store. Copie le code et saisis-le après l’installation.',
    },
    hi: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'VibesBox ऐप डाउनलोड करें',
      body: 'आपका रेफ़रल कोड तैयार है। ऐप डाउनलोड कर कोड दर्ज करें।',
      codeLabel: 'रेफ़रल कोड',
      trialHint:
        'ऐप में यह कोड दर्ज करें और 7 दिन मुफ़्त VibesBox Pro आज़माएँ।',
      copyCode: 'कोड कॉपी करें',
      codeCopied: 'कोड कॉपी हो गया',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'ऐप जल्द App Store पर आएगी। कोड कॉपी करें और इंस्टॉल के बाद दर्ज करें।',
    },
    it: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Scarica l’app VibesBox',
      body: 'Il tuo codice referral è pronto. Scarica l’app e inseriscilo.',
      codeLabel: 'Codice referral',
      trialHint:
        'Inserisci questo codice nell’app per provare VibesBox Pro gratis per 7 giorni.',
      copyCode: 'Copia codice',
      codeCopied: 'Codice copiato',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'L’app sarà presto sull’App Store. Copia il codice e inseriscilo dopo l’installazione.',
    },
    ja: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'VibesBoxアプリをダウンロード',
      body: '紹介コードの準備ができました。アプリを入れてコードを入力してください。',
      codeLabel: '紹介コード',
      trialHint:
        'このコードをアプリで入力すると、VibesBox Proを7日間無料で試せます。',
      copyCode: 'コードをコピー',
      codeCopied: 'コードをコピーしました',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'まもなくApp Storeに登場します。コードをコピーし、インストール後に入力してください。',
    },
    nl: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Download de VibesBox-app',
      body: 'Je doorverwijscode is klaar. Download de app en voer de code in.',
      codeLabel: 'Doorverwijscode',
      trialHint:
        'Voer deze code in de app in om VibesBox Pro 7 dagen gratis te proberen.',
      copyCode: 'Code kopiëren',
      codeCopied: 'Code gekopieerd',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'De app komt binnenkort in de App Store. Kopieer de code en voer die na installatie in.',
    },
    pl: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Pobierz aplikację VibesBox',
      body: 'Twój kod polecający jest gotowy. Pobierz aplikację i wpisz kod.',
      codeLabel: 'Kod polecający',
      trialHint:
        'Wpisz ten kod w aplikacji, aby wypróbować VibesBox Pro za darmo przez 7 dni.',
      copyCode: 'Kopiuj kod',
      codeCopied: 'Kod skopiowany',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'Aplikacja wkrótce w App Store. Skopiuj kod i wpisz go po instalacji.',
    },
    pt: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Descarrega a app VibesBox',
      body: 'O teu código de indicação está pronto. Descarrega a app e introduz o código.',
      codeLabel: 'Código de indicação',
      trialHint:
        'Introduz este código na app para experimentar o VibesBox Pro grátis durante 7 dias.',
      copyCode: 'Copiar código',
      codeCopied: 'Código copiado',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'A app chega em breve à App Store. Copia o código e introduz após a instalação.',
    },
    ru: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Скачай приложение VibesBox',
      body: 'Твой реферальный код готов. Скачай приложение и введи код.',
      codeLabel: 'Реферальный код',
      trialHint:
        'Введи этот код в приложении, чтобы бесплатно протестировать VibesBox Pro 7 дней.',
      copyCode: 'Скопировать код',
      codeCopied: 'Код скопирован',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'Приложение скоро в App Store. Скопируй код и введи его после установки.',
    },
    sq: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Shkarko aplikacionin VibesBox',
      body: 'Kodi yt i referimit është gati. Shkarko aplikacionin dhe fut kodin.',
      codeLabel: 'Kodi i referimit',
      trialHint:
        'Fut këtë kod në aplikacion për të provuar VibesBox Pro falas për 7 ditë.',
      copyCode: 'Kopjo kodin',
      codeCopied: 'Kodi u kopjua',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'Aplikacioni së shpejti në App Store. Kopjo kodin dhe futë pas instalimit.',
    },
    th: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'ดาวน์โหลดแอป VibesBox',
      body: 'รหัสแนะนำพร้อมแล้ว ดาวน์โหลดแอปแล้วใส่รหัส',
      codeLabel: 'รหัสแนะนำ',
      trialHint: 'ใส่รหัสนี้ในแอปเพื่อทดลอง VibesBox Pro ฟรี 7 วัน',
      copyCode: 'คัดลอกรหัส',
      codeCopied: 'คัดลอกรหัสแล้ว',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'แอปจะมาใน App Store เร็วๆ นี้ คัดลอกรหัสแล้วใส่หลังติดตั้ง',
    },
    tr: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'VibesBox uygulamasını indir',
      body: 'Davet kodun hazır. Uygulamayı indir ve kodu gir.',
      codeLabel: 'Davet kodu',
      trialHint:
        'Bu kodu uygulamaya girerek VibesBox Pro’yu 7 gün ücretsiz dene.',
      copyCode: 'Kodu kopyala',
      codeCopied: 'Kod kopyalandı',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'Uygulama yakında App Store’da. Kodu kopyala ve kurulumdan sonra gir.',
    },
    uk: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Завантаж додаток VibesBox',
      body: 'Твій реферальний код готовий. Завантаж додаток і введи код.',
      codeLabel: 'Реферальний код',
      trialHint:
        'Введи цей код у додатку, щоб безкоштовно спробувати VibesBox Pro на 7 днів.',
      copyCode: 'Копіювати код',
      codeCopied: 'Код скопійовано',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'Додаток незабаром в App Store. Скопіюй код і введи після встановлення.',
    },
    vi: {
      pageTitle: 'VibesBox – DJ B2B',
      title: 'Tải ứng dụng VibesBox',
      body: 'Mã giới thiệu đã sẵn sàng. Tải app và nhập mã.',
      codeLabel: 'Mã giới thiệu',
      trialHint:
        'Nhập mã này trong ứng dụng để dùng thử VibesBox Pro miễn phí 7 ngày.',
      copyCode: 'Sao chép mã',
      codeCopied: 'Đã sao chép mã',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: 'Ứng dụng sắp có trên App Store. Sao chép mã và nhập sau khi cài đặt.',
    },
    zh: {
      pageTitle: 'VibesBox – DJ B2B',
      title: '下载 VibesBox 应用',
      body: '你的推荐码已准备好。下载应用并输入代码。',
      codeLabel: '推荐码',
      trialHint: '在应用中输入此代码，即可免费试用 VibesBox Pro 7 天。',
      copyCode: '复制代码',
      codeCopied: '代码已复制',
      playStore: 'Google Play',
      appStore: 'App Store',
      iosBlockTitle: 'iOS / iPadOS',
      iosBlockBody: '应用即将登陆 App Store。请复制代码并在安装后输入。',
    },
  };

  var currentCode = null;

  function normalizeCode(raw) {
    if (raw == null) return null;
    var c = String(raw).trim().toUpperCase();
    return /^DJ\d{6}$/.test(c) ? c : null;
  }

  function extractCodeFromPath() {
    var path = (window.location.pathname || '').replace(/^\/+|\/+$/g, '');
    var parts = path.split('/');
    var idx = parts.indexOf('invite');
    if (idx !== -1 && parts[idx + 1]) {
      return normalizeCode(parts[idx + 1]);
    }
    try {
      var sp = new URLSearchParams(window.location.search || '');
      return normalizeCode(sp.get('code'));
    } catch (e0) {
      return null;
    }
  }

  function detectLang() {
    try {
      var stored = (
        localStorage.getItem('pwa_language') ||
        localStorage.getItem('language') ||
        ''
      )
        .trim()
        .split('-')[0]
        .toLowerCase();
      if (stored && I18N[stored]) return stored;
    } catch (eS) {}
    var nav = (navigator.language || 'en').split('-')[0].toLowerCase();
    return I18N[nav] ? nav : 'en';
  }

  function t(key) {
    var lang = detectLang();
    var pack = I18N[lang] || I18N.en;
    return pack[key] || I18N.en[key] || key;
  }

  function persistCode(code) {
    var ts = new Date().toISOString();
    try {
      localStorage.setItem(LS_CODE, code);
      localStorage.setItem(LS_CAPTURED, ts);
    } catch (e1) {}
    try {
      var maxAge = 60 * 60 * 24 * 90;
      document.cookie =
        COOKIE_NAME +
        '=' +
        encodeURIComponent(code + '|' + ts) +
        '; path=/; max-age=' +
        maxAge +
        '; SameSite=Lax';
    } catch (e2) {}
  }

  function clipboardPayload(code) {
    return CLIPBOARD_PREFIX + code;
  }

  function copyCodeToClipboard(code) {
    var payload = clipboardPayload(code);
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        return navigator.clipboard.writeText(payload);
      }
    } catch (e3) {}
    return Promise.resolve(fallbackCopy(payload));
  }

  function fallbackCopy(text) {
    try {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed';
      ta.style.left = '-9999px';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      return true;
    } catch (e4) {
      return false;
    }
  }

  function playStoreUrl(code) {
    var referrer = encodeURIComponent(
      'utm_source=vibesbox_b2b&utm_medium=invite&utm_content=' + code,
    );
    return (
      'https://play.google.com/store/apps/details?id=' +
      PLAY_STORE_ID +
      '&referrer=' +
      referrer
    );
  }

  function redirect(url) {
    window.location.replace(url);
  }

  function markCopyButton(btn, ok) {
    if (!btn) return;
    btn.textContent = ok ? t('codeCopied') : t('copyCode');
    if (ok) {
      btn.classList.add('copied');
      setTimeout(function () {
        btn.classList.remove('copied');
        btn.textContent = t('copyCode');
      }, 1800);
    }
  }

  function renderLanding(code) {
    document.title = t('pageTitle');
    document.documentElement.lang = detectLang();

    var root = document.getElementById('invite-root');
    if (!root) return;
    root.style.display = 'block';

    var titleEl = document.getElementById('invite-title');
    var bodyEl = document.getElementById('invite-body');
    var labelEl = document.getElementById('invite-code-label');
    var valueEl = document.getElementById('invite-code-value');
    var hintEl = document.getElementById('invite-trial-hint');
    var copyBtn = document.getElementById('invite-copy-btn');
    var playBtn = document.getElementById('invite-play-btn');
    var iosBtn = document.getElementById('invite-ios-btn');
    var iosBlock = document.getElementById('invite-ios-block');
    var iosTitle = document.getElementById('invite-ios-title');
    var iosBody = document.getElementById('invite-ios-text');

    if (titleEl) titleEl.textContent = t('title');
    if (bodyEl) bodyEl.textContent = t('body');
    if (labelEl) labelEl.textContent = t('codeLabel');
    if (valueEl) valueEl.textContent = code;
    if (hintEl) hintEl.textContent = t('trialHint');

    if (copyBtn) {
      copyBtn.textContent = t('copyCode');
      copyBtn.onclick = function () {
        copyCodeToClipboard(code)
          .then(function () {
            markCopyButton(copyBtn, true);
          })
          .catch(function () {
            markCopyButton(copyBtn, fallbackCopy(clipboardPayload(code)));
          });
      };
    }

    if (playBtn) {
      playBtn.href = playStoreUrl(code);
      playBtn.setAttribute('aria-label', t('playStore') || 'Google Play');
      playBtn.removeAttribute('hidden');
    }

    if (IOS_INVITE_SHOW_APP_STORE && iosBtn) {
      iosBtn.hidden = false;
      iosBtn.href = APP_STORE_URL;
      iosBtn.setAttribute('aria-label', t('appStore') || 'App Store');
      if (iosBlock) {
        iosBlock.hidden = true;
        iosBlock.style.display = 'none';
      }
    } else {
      if (iosBtn) {
        iosBtn.hidden = true;
        iosBtn.style.display = 'none';
      }
      if (iosBlock) {
        iosBlock.hidden = false;
        iosBlock.style.display = 'block';
      }
      if (iosTitle) iosTitle.textContent = t('iosBlockTitle');
      if (iosBody) iosBody.textContent = t('iosBlockBody');
    }
  }

  function run() {
    var code = extractCodeFromPath();
    if (!code) {
      redirect('/');
      return;
    }
    currentCode = code;
    persistCode(code);
    copyCodeToClipboard(code).catch(function () {});
    renderLanding(code);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }
})();
