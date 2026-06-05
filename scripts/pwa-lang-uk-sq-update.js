#!/usr/bin/env node
/**
 * Einmalig: Ukrainisch (uk) ausbessern + Albanisch (sq) anlegen.
 * Danach: node scripts/pwa-lang-import-babel.js
 */
const fs = require('fs');
const path = require('path');

const LOCALES = path.join(__dirname, '../public/vb/babel/locales');
const META = path.join(__dirname, '../public/vb/babel/pwa-languages.json');

/** Ukrainische Korrekturen (deutsche Reste, „Party“ = вечірка, Modal, Sprachnamen). */
const UK_PATCHES = {
  nav_history: 'Історія',
  nav_contact: 'Контакт',
  history_title: 'Історія',
  party_code_enter: 'Введіть код вечірки:',
  party_code_check: 'Перевірити',
  party_unknown: 'Цю вечірку не знайдено. Перевірте введення.',
  party_code_length: 'Код вечірки має містити рівно 8 цифр.',
  party_code_required: 'Будь ласка, введіть код вечірки.',
  party_info_text: 'Ви на вечірці:',
  error_load_failed_message:
    'Оновіть сторінку або введіть код вечірки ще раз.',
  wish_limit_plural: 'Ще {remaining} з {limit} запитів доступно в цій годині',
  wish_limit_singular: 'Ще 1 з {limit} запитів доступно в цій годині',
  wish_limit_none: 'Наступний запит можливий у наступній повній годині.',
  send_another_wish: 'Надіслати ще один запит',
  modal_history_title: 'Пісню вже відтворювали',
  modal_history_message:
    'Пісню «{title}» виконавця {artist} сьогодні вже грали. Усе одно надіслати запит?',
  modal_pending_title: 'Пісня вже у списку бажань',
  modal_pending_message:
    'Пісня «{title}» виконавця {artist} уже у списку бажань. Усе одно надіслати запит?',
  modal_button_send_anyway: 'Усе одно надіслати',
  modal_button_cancel: 'Скасувати',
  social_media_introduction: 'У соцмережах ви знайдете {djName}.',
  contact_title: 'Контакт',
  label_contact_message: 'Повідомлення *',
  about_subtitle:
    'Ваш запит має значення! З VibesBox ви надсилаєте улюблені пісні прямо на дисплей діджея — без натовпі біля пульта. Додайте привітання до пісні та насолоджуйтесь вечіркою!',
  button_terms: 'Умови',
  terms_title: 'Умови використання',
  terms_placeholder: 'Текст буде додано.',
  lang_german: 'Німецька',
  lang_english: 'Англійська',
  lang_french: 'Французька',
  lang_russian: 'Російська',
  lang_chinese: 'Китайська',
  lang_spanish: 'Іспанська',
  lang_turkish: 'Турецька',
  lang_portuguese: 'Португальська',
  lang_italian: 'Італійська',
  lang_ukrainian: 'Українська',
  lang_hindi: 'Гінді',
  lang_arabic: 'Арабська',
  logout_confirm_no: 'Ні',
  no_active_party_msg:
    'Активну вечірку не знайдено. Введіть код, щоб відкрити вміст.',
  go_to_code_entry: 'До введення коду',
  button_ok: 'OK',
  button_close: 'Закрити',
  cookie_accept_button: 'Погоджуюсь',
  settings_save_btn: 'Зберегти',
  settings_ignored_keywords_placeholder:
    'Remix, Edit, Mix, Club, Radio, Extended, Video, Version',
  main_hero_btn_code: 'Ввести код вечірки',
  main_intro_paragraph2: '',
  main_feature_auto_title: 'Автоматизація',
  main_contact_title: 'Контакт',
  main_contact_label_message: 'Повідомлення *',
  main_contact_success_title: 'Дякуємо!',
  main_footer_terms: 'Умови',
  main_overlay_code_title: 'Ввести код вечірки',
  main_code_error_invalid: 'Цей код вечірки не існує.',
  label_party: 'Вечірка',
  label_message: 'Повідомлення',
  main_nav_uber: 'Про нас',
  pwa_request_header_text: 'Надішліть музичний запит для',
};

function loadJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function saveJson(p, obj) {
  fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n', 'utf8');
}

function buildAlbanianFromEnglish(en) {
  const sq = { ...en };
  const AL = {
    nav_vibesbox: 'VibesBox',
    nav_history: 'Historiku',
    nav_social_media: 'Rrjetet sociale',
    nav_contact: 'Kontakt',
    nav_about: 'Rreth VibesBox',
    loading_data: 'Duke ngarkuar të dhënat...',
    loading_party_connection: 'Duke u lidhur me festën...',
    loading_connection_checking: 'Duke kontrolluar lidhjen...',
    history_title: 'Historiku',
    history_subtitle: 'Këtu shihni të gjitha këngët që janë luajtur tashmë.',
    history_loading: 'Duke ngarkuar historikun...',
    history_error: 'Gabim gjatë ngarkimit të historikut',
    error_load_failed_title: 'Të dhënat nuk u ngarkuan',
    error_load_failed_message:
      'Rifreskoni faqen ose vendosni përsëri kodin e festës.',
    history_empty: 'Ende pa këngë në historik',
    history_empty_subtitle:
      'Sapo këngët identifikohen, do të shfaqen këtu.',
    history_just_now: 'tani',
    history_minutes_ago: 'para ${diffMins} minutash',
    history_hours_ago: 'para ${diffHours} orësh',
    history_days_ago: 'para ${diffDays} ditësh',
    history_pagination_prev: 'Mbrapa',
    history_pagination_next: 'Përpara',
    history_pagination_of: 'nga',
    vibesbox_title: 'VibesBox',
    vibesbox_subtitle:
      'Dëshiron një këngë? 🎧 Dërgoje! Përpiqem të luaj sa më shumë kërkesa. Për një festë të suksesshme filtroj sipas disponueshmërisë, valës së kërcimit dhe udhëzimeve të hostit. Faleminderit për mirëkuptimin!',
    wishbox_inactive: 'Kërkesat muzikore janë joaktive për momentin.',
    wishbox_inactive_info:
      'Për të dërguar një kërkesë muzikore në festë, hyr me kodin e festës ose skano QR kodin në vend.',
    party_code_enter: 'Vendos kodin e festës:',
    party_code_placeholder: 'Kodi',
    party_code_check: 'Kontrollo',
    wishbox_blocked_title: 'Pushim për kërkesat e tua!',
    wishbox_blocked_message:
      'Meqenëse mesazhet e fundit nuk përputheshin me atmosferën e festës, kërkesat muzikore janë mbyllur për ty. Shihemi në parketin e kërcimit!',
    user_blocked_title: 'Je bllokuar',
    user_blocked_message:
      'Je bllokuar për këtë festë. Kërkesat muzikore janë çaktivizuar.',
    wish_limit_loading: 'Duke ngarkuar informacionin e limitit...',
    wish_limit_remaining:
      'Ende {remaining} nga {limit} kërkesa të disponueshme këtë orë',
    wish_limit_default: 'Ende 2 nga 2 kërkesa të disponueshme këtë orë',
    wish_limit_wait:
      'Mund të dërgosh përsëri kërkesa në orën e plotë të ardhshme.',
    wish_limit_plural:
      '{remaining} nga {limit} kërkesa të lira për orë të plotë',
    wish_limit_singular: '1 nga {limit} kërkesë e lirë për orë të plotë',
    wish_limit_none: 'Një kërkesë tjetër është e mundur në orën e plotë të ardhshme.',
    party_paused_msg:
      'Pushim i shkurtër: Vibesbox do të kthehet së shpejti për kërkesat tuaja muzikore!',
    party_finished_title: 'Festa ka përfunduar!',
    party_finished_msg:
      'Faleminderit për kërkesat muzikore. Shpresojmë që keni kaluar mirë!',
    user_banned_title: 'Qasja u bllokua',
    user_banned_msg:
      'Qasja në kërkesat muzikore është bllokuar. Kontaktoni DJ-n.',
    party_info_text: 'Je në festën:',
    pwa_request_header_text: 'Dërgo kërkesën tënde muzikore për',
    branding_text: 'Kjo është',
    branding_text_von: 'nga',
    label_name: 'Emri yt *',
    label_name_placeholder: 'Emri yt',
    label_title: 'Titulli *',
    label_title_placeholder: 'Vendos titullin',
    label_artist: 'Interpreti *',
    label_artist_placeholder: 'Vendos interpretin',
    label_greeting: 'Përshëndetje (opsionale)',
    greeting_placeholder: 'Maks. 160 karaktere',
    char_count: '/ 160',
    required_field: '* Fushë e detyrueshme',
    required_field_info: 'Fushat me * janë të detyrueshme',
    tap_for_suggestions: 'Prek për sugjerime',
    catalog_top_songs: 'Këngët kryesore të {artist}',
    submit_wish: 'Dërgo kërkesën',
    wish_sent_received: 'Kërkesa jote u mor',
    wish_sent_disclaimer:
      'Ki parasysh: DJ-ja mund të luajë vetëm këngët që ka aktualisht në koleksion. DJ-ja vendos nëse kënga përshtatet me atmosferën — jo çdo kërkesë përshtatet në çdo moment. Faleminderit për mirëkuptimin!',
    send_another_wish: 'Dërgo një kërkesë tjetër',
    modal_history_title: 'Kënga është luajtur tashmë',
    modal_history_message:
      'Kënga «{title}» e {artist} është luajtur sot. Dëshiron ta kërkosh përsëri?',
    modal_pending_title: 'Kënga është tashmë në listë',
    modal_pending_message:
      'Kënga «{title}» e {artist} është tashmë në listën e dëshirave. Dëshiron ta dërgosh gjithsesi?',
    modal_button_send_anyway: 'Dërgo gjithsesi',
    modal_button_cancel: 'Anulo',
    social_media_title: 'Rrjetet sociale',
    social_media_subtitle: 'Ndiqni kanalet tona sociale',
    social_media_introduction: 'Në këto rrjete sociale gjen {djName}.',
    contact_title: 'Kontakt',
    contact_subtitle: 'Më dërgo një mesazh',
    send_message: 'Dërgo mesazhin',
    about_title: 'VibesBox – Lidhja direkte me DJ-n',
    button_imprint: 'Impresum',
    button_privacy: 'Privatësia',
    button_terms: 'Kushtet',
    terms_title: 'Kushtet e përdorimit',
    back_button: '← Mbrapa',
    privacy_title: 'GDPR / Privatësia',
    imprint_title: 'Impresum',
    legal_language_notice:
      'Impresumi dhe politika e privatësisë ofrohen vetëm në gjermanisht sipas kërkesave ligjore në Gjermani. Në rast mospërputhjeje, versioni gjerman është zyrtar.',
    imprint_legal_note_non_de:
      'Informacioni i mëposhtëm jepet sipas ligjit gjerman (§ 5 DDG).',
    lang_german: 'Gjermanisht',
    lang_english: 'Anglisht',
    lang_french: 'Frëngjisht',
    lang_russian: 'Rusisht',
    lang_chinese: 'Kinezisht',
    lang_spanish: 'Spanjisht',
    lang_turkish: 'Turqisht',
    lang_portuguese: 'Portugezisht',
    lang_italian: 'Italisht',
    lang_ukrainian: 'Ukrainas',
    lang_hindi: 'Hindi',
    lang_albanian: 'Shqip',
    loading: 'Duke ngarkuar vibe të mira...',
    menu_by: 'nga',
    logout_party: 'Dil nga festa',
    logout_confirm_title: 'Të largohesh nga festa?',
    logout_confirm_message: 'A dëshiron vërtet të largohesh nga festa?',
    logout_confirm_yes: 'Po',
    logout_confirm_no: 'Jo',
    no_active_party_msg:
      'Nuk u gjet festë aktive. Vendos një kod për të hapur përmbajtjen.',
    go_to_code_entry: 'Te vendosja e kodit',
    language: 'Gjuha',
    party_code_required: 'Ju lutemi vendosni kodin e festës.',
    party_code_length: 'Kodi i festës duhet të ketë saktësisht 8 shifra.',
    party_unknown: 'Kjo festë nuk njihet. Kontrolloni të dhënat.',
    party_ended: 'Kjo festë ka përfunduar. Faleminderit për vizitën!',
    main_party_ended_returned_home:
      'Festa ka përfunduar. U ktheve në faqen kryesore. Faleminderit!',
    cookie_accept_button: 'Pranoj',
    settings_save_btn: 'Ruaj',
    main_hero_title: 'VIBESBOX – Lidhja midis DJ-së dhe mysafirit.',
    main_hero_tagline:
      'Zemra digjitale e çdo feste. Moderne, direkte dhe pa barrierë.',
    main_hero_btn_code: 'Vendos kodin e festës',
    main_intro_title: 'Çfarë është VIBESBOX',
    main_overlay_code_title: 'Vendos kodin e festës',
    main_code_error_invalid: 'Ky kod feste nuk ekziston.',
    main_footer_terms: 'Kushtet',
    label_party: 'Festa',
    guest: 'Mysafir',
    auth_back_to_app: 'Hap aplikacionin',
  };
  Object.assign(sq, AL);
  return sq;
}

function updateMetaForAlbanian() {
  const meta = loadJson(META);
  if (!meta.languages.find((e) => e.code === 'sq')) {
    meta.languages.push({
      code: 'sq',
      name: 'Albanian',
      icon: 'sq',
      langKey: 'lang_albanian',
    });
  }
  saveJson(META, meta);
}

function main() {
  const ukPath = path.join(LOCALES, 'uk.json');
  const enPath = path.join(LOCALES, 'en.json');
  const sqPath = path.join(LOCALES, 'sq.json');

  const uk = loadJson(ukPath);
  Object.assign(uk, UK_PATCHES);
  saveJson(ukPath, uk);
  console.log('✓ uk.json aktualisiert (' + Object.keys(UK_PATCHES).length + ' Korrekturen)');

  const en = loadJson(enPath);
  const sq = buildAlbanianFromEnglish(en);
  saveJson(sqPath, sq);
  console.log('✓ sq.json angelegt (Albanisch, ' + Object.keys(sq).length + ' Keys)');

  updateMetaForAlbanian();
  console.log('✓ pwa-languages.json: Albanisch eingetragen');
  console.log('\nAls Nächstes: node scripts/pwa-lang-import-babel.js');
}

main();
