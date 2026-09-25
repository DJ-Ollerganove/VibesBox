/// Texte für Startbildschirm, Verbindungssperre, Rechtliches und Updates.
/// Gleiche Schlüssel in jeder Sprache. Fehlt eine Sprache, gilt Englisch.
const toolGatePacks = <String, Map<String, String>>{
  'de': {
    'gateBody':
        'Dieses Tool ist Teil der VibesBox-App und funktioniert nur zusammen mit einem verbundenen DJ-Konto.',
    'gateAcceptLead': 'Bitte lesen und zustimmen',
    'gatePrivacy': 'Datenschutz',
    'gateImprint': 'Impressum',
    'gateTerms': 'Nutzungsbedingungen',
    'gateMustCheck': 'Bitte allen drei Punkten zustimmen.',
    'gateContinue': 'Weiter',
    'gateConnectTitle': 'Verbindung nötig',
    'gateConnectBody':
        'Dieses Tool läuft nur mit einem verbundenen VibesBox-DJ-Konto.',
    'settingsVersion': 'Version',
    'settingsLegal': 'Rechtliches',
    'updateRequiredTitle': 'Update nötig',
    'updateOptionalTitle': 'Update verfügbar',
    'updateRequiredBody':
        'Diese Version funktioniert nicht mehr. Bitte die neue Version laden.',
    'updateOptionalBody':
        'Es gibt eine neuere Version. Du kannst sie laden oder später weitermachen.',
    'updateDownload': 'Herunterladen',
    'updateLater': 'Später',
  },
  'en': {
    'gateBody':
        'This tool is part of the VibesBox app and only works together with a connected DJ account.',
    'gateAcceptLead': 'Please read and agree',
    'gatePrivacy': 'Privacy',
    'gateImprint': 'Imprint',
    'gateTerms': 'Terms of use',
    'gateMustCheck': 'Please agree to all three.',
    'gateContinue': 'Continue',
    'gateConnectTitle': 'Connection required',
    'gateConnectBody':
        'This tool only runs with a connected VibesBox DJ account.',
    'settingsVersion': 'Version',
    'settingsLegal': 'Legal',
    'updateRequiredTitle': 'Update required',
    'updateOptionalTitle': 'Update available',
    'updateRequiredBody':
        'This version no longer works. Please download the new version.',
    'updateOptionalBody':
        'A newer version is available. You can download it or continue later.',
    'updateDownload': 'Download',
    'updateLater': 'Later',
  },
  'es': {
    'gateBody':
        'Esta herramienta forma parte de la app VibesBox y solo funciona con una cuenta de DJ conectada.',
    'gateAcceptLead': 'Lee y acepta',
    'gatePrivacy': 'Privacidad',
    'gateImprint': 'Aviso legal',
    'gateTerms': 'Condiciones de uso',
    'gateMustCheck': 'Acepta los tres puntos.',
    'gateContinue': 'Continuar',
    'gateConnectTitle': 'Conexión necesaria',
    'gateConnectBody':
        'Esta herramienta solo funciona con una cuenta de DJ de VibesBox conectada.',
    'settingsVersion': 'Versión',
    'settingsLegal': 'Legal',
    'updateRequiredTitle': 'Actualización necesaria',
    'updateOptionalTitle': 'Actualización disponible',
    'updateRequiredBody':
        'Esta versión ya no funciona. Descarga la nueva versión.',
    'updateOptionalBody':
        'Hay una versión más nueva. Puedes descargarla o seguir más tarde.',
    'updateDownload': 'Descargar',
    'updateLater': 'Más tarde',
  },
  'fr': {
    'gateBody':
        'Cet outil fait partie de l’application VibesBox et ne fonctionne qu’avec un compte DJ connecté.',
    'gateAcceptLead': 'Lis et accepte',
    'gatePrivacy': 'Confidentialité',
    'gateImprint': 'Mentions légales',
    'gateTerms': 'Conditions d’utilisation',
    'gateMustCheck': 'Accepte les trois points.',
    'gateContinue': 'Continuer',
    'gateConnectTitle': 'Connexion requise',
    'gateConnectBody':
        'Cet outil ne fonctionne qu’avec un compte DJ VibesBox connecté.',
    'settingsVersion': 'Version',
    'settingsLegal': 'Mentions légales',
    'updateRequiredTitle': 'Mise à jour requise',
    'updateOptionalTitle': 'Mise à jour disponible',
    'updateRequiredBody':
        'Cette version ne fonctionne plus. Télécharge la nouvelle version.',
    'updateOptionalBody':
        'Une version plus récente est disponible. Tu peux la télécharger ou continuer plus tard.',
    'updateDownload': 'Télécharger',
    'updateLater': 'Plus tard',
  },
  'it': {
    'gateBody':
        'Questo strumento fa parte dell’app VibesBox e funziona solo con un account DJ collegato.',
    'gateAcceptLead': 'Leggi e accetta',
    'gatePrivacy': 'Privacy',
    'gateImprint': 'Note legali',
    'gateTerms': 'Condizioni d’uso',
    'gateMustCheck': 'Accetta tutti e tre i punti.',
    'gateContinue': 'Continua',
    'gateConnectTitle': 'Connessione necessaria',
    'gateConnectBody':
        'Questo strumento funziona solo con un account DJ VibesBox collegato.',
    'settingsVersion': 'Versione',
    'settingsLegal': 'Note legali',
    'updateRequiredTitle': 'Aggiornamento necessario',
    'updateOptionalTitle': 'Aggiornamento disponibile',
    'updateRequiredBody':
        'Questa versione non funziona più. Scarica la nuova versione.',
    'updateOptionalBody':
        'C’è una versione più nuova. Puoi scaricarla o continuare più tardi.',
    'updateDownload': 'Scarica',
    'updateLater': 'Più tardi',
  },
  'pt': {
    'gateBody':
        'Esta ferramenta faz parte da app VibesBox e só funciona com uma conta de DJ ligada.',
    'gateAcceptLead': 'Lê e aceita',
    'gatePrivacy': 'Privacidade',
    'gateImprint': 'Impressum',
    'gateTerms': 'Termos de utilização',
    'gateMustCheck': 'Aceita os três pontos.',
    'gateContinue': 'Continuar',
    'gateConnectTitle': 'Ligação necessária',
    'gateConnectBody':
        'Esta ferramenta só funciona com uma conta de DJ VibesBox ligada.',
    'settingsVersion': 'Versão',
    'settingsLegal': 'Legal',
    'updateRequiredTitle': 'Atualização necessária',
    'updateOptionalTitle': 'Atualização disponível',
    'updateRequiredBody':
        'Esta versão já não funciona. Transfere a nova versão.',
    'updateOptionalBody':
        'Há uma versão mais recente. Podes transferi-la ou continuar mais tarde.',
    'updateDownload': 'Transferir',
    'updateLater': 'Mais tarde',
  },
  'nl': {
    'gateBody':
        'Deze tool hoort bij de VibesBox-app en werkt alleen met een verbonden DJ-account.',
    'gateAcceptLead': 'Lees en ga akkoord',
    'gatePrivacy': 'Privacy',
    'gateImprint': 'Impressum',
    'gateTerms': 'Gebruiksvoorwaarden',
    'gateMustCheck': 'Ga akkoord met alle drie.',
    'gateContinue': 'Verder',
    'gateConnectTitle': 'Verbinding nodig',
    'gateConnectBody':
        'Deze tool werkt alleen met een verbonden VibesBox-DJ-account.',
    'settingsVersion': 'Versie',
    'settingsLegal': 'Juridisch',
    'updateRequiredTitle': 'Update vereist',
    'updateOptionalTitle': 'Update beschikbaar',
    'updateRequiredBody':
        'Deze versie werkt niet meer. Download de nieuwe versie.',
    'updateOptionalBody':
        'Er is een nieuwere versie. Je kunt die downloaden of later doorgaan.',
    'updateDownload': 'Downloaden',
    'updateLater': 'Later',
  },
  'pl': {
    'gateBody':
        'To narzędzie jest częścią aplikacji VibesBox i działa tylko z połączonym kontem DJ-a.',
    'gateAcceptLead': 'Przeczytaj i zaakceptuj',
    'gatePrivacy': 'Prywatność',
    'gateImprint': 'Informacje prawne',
    'gateTerms': 'Warunki użytkowania',
    'gateMustCheck': 'Zaznacz wszystkie trzy punkty.',
    'gateContinue': 'Dalej',
    'gateConnectTitle': 'Wymagane połączenie',
    'gateConnectBody':
        'To narzędzie działa tylko z połączonym kontem DJ VibesBox.',
    'settingsVersion': 'Wersja',
    'settingsLegal': 'Informacje prawne',
    'updateRequiredTitle': 'Wymagana aktualizacja',
    'updateOptionalTitle': 'Dostępna aktualizacja',
    'updateRequiredBody':
        'Ta wersja już nie działa. Pobierz nową wersję.',
    'updateOptionalBody':
        'Jest nowsza wersja. Możesz ją pobrać albo kontynuować później.',
    'updateDownload': 'Pobierz',
    'updateLater': 'Później',
  },
  'cs': {
    'gateBody':
        'Tento nástroj je součástí aplikace VibesBox a funguje jen s připojeným DJ účtem.',
    'gateAcceptLead': 'Přečti a souhlas',
    'gatePrivacy': 'Ochrana údajů',
    'gateImprint': 'Impressum',
    'gateTerms': 'Podmínky použití',
    'gateMustCheck': 'Souhlas se všemi třemi body.',
    'gateContinue': 'Pokračovat',
    'gateConnectTitle': 'Je potřeba spojení',
    'gateConnectBody':
        'Tento nástroj běží jen s připojeným DJ účtem VibesBox.',
    'settingsVersion': 'Verze',
    'settingsLegal': 'Právní informace',
    'updateRequiredTitle': 'Nutná aktualizace',
    'updateOptionalTitle': 'Aktualizace k dispozici',
    'updateRequiredBody':
        'Tahle verze už nefunguje. Stáhni novou verzi.',
    'updateOptionalBody':
        'Je novější verze. Můžeš ji stáhnout nebo pokračovat později.',
    'updateDownload': 'Stáhnout',
    'updateLater': 'Později',
  },
  'tr': {
    'gateBody':
        'Bu araç VibesBox uygulamasının parçasıdır ve yalnızca bağlı bir DJ hesabıyla çalışır.',
    'gateAcceptLead': 'Oku ve kabul et',
    'gatePrivacy': 'Gizlilik',
    'gateImprint': 'Künye',
    'gateTerms': 'Kullanım koşulları',
    'gateMustCheck': 'Üçünü de kabul et.',
    'gateContinue': 'Devam',
    'gateConnectTitle': 'Bağlantı gerekli',
    'gateConnectBody':
        'Bu araç yalnızca bağlı bir VibesBox DJ hesabıyla çalışır.',
    'settingsVersion': 'Sürüm',
    'settingsLegal': 'Yasal',
    'updateRequiredTitle': 'Güncelleme gerekli',
    'updateOptionalTitle': 'Güncelleme var',
    'updateRequiredBody':
        'Bu sürüm artık çalışmıyor. Yeni sürümü indir.',
    'updateOptionalBody':
        'Daha yeni bir sürüm var. İndirebilir veya sonra devam edebilirsin.',
    'updateDownload': 'İndir',
    'updateLater': 'Sonra',
  },
  'ru': {
    'gateBody':
        'Этот инструмент — часть приложения VibesBox и работает только с подключённым DJ-аккаунтом.',
    'gateAcceptLead': 'Прочитай и согласись',
    'gatePrivacy': 'Конфиденциальность',
    'gateImprint': 'Выходные данные',
    'gateTerms': 'Условия использования',
    'gateMustCheck': 'Подтверди все три пункта.',
    'gateContinue': 'Далее',
    'gateConnectTitle': 'Нужно подключение',
    'gateConnectBody':
        'Инструмент работает только с подключённым DJ-аккаунтом VibesBox.',
    'settingsVersion': 'Версия',
    'settingsLegal': 'Правовая информация',
    'updateRequiredTitle': 'Нужно обновление',
    'updateOptionalTitle': 'Доступно обновление',
    'updateRequiredBody':
        'Эта версия больше не работает. Скачай новую.',
    'updateOptionalBody':
        'Есть более новая версия. Можно скачать её или продолжить позже.',
    'updateDownload': 'Скачать',
    'updateLater': 'Позже',
  },
  'uk': {
    'gateBody':
        'Цей інструмент є частиною застосунку VibesBox і працює лише з підключеним DJ-акаунтом.',
    'gateAcceptLead': 'Прочитай і погодься',
    'gatePrivacy': 'Конфіденційність',
    'gateImprint': 'Вихідні дані',
    'gateTerms': 'Умови використання',
    'gateMustCheck': 'Підтвердь усі три пункти.',
    'gateContinue': 'Далі',
    'gateConnectTitle': 'Потрібне з’єднання',
    'gateConnectBody':
        'Інструмент працює лише з підключеним DJ-акаунтом VibesBox.',
    'settingsVersion': 'Версія',
    'settingsLegal': 'Правова інформація',
    'updateRequiredTitle': 'Потрібне оновлення',
    'updateOptionalTitle': 'Є оновлення',
    'updateRequiredBody':
        'Ця версія більше не працює. Завантаж нову.',
    'updateOptionalBody':
        'Є новіша версія. Можна завантажити її або продовжити пізніше.',
    'updateDownload': 'Завантажити',
    'updateLater': 'Пізніше',
  },
  'el': {
    'gateBody':
        'Αυτό το εργαλείο είναι μέρος της εφαρμογής VibesBox και λειτουργεί μόνο με συνδεδεμένο λογαριασμό DJ.',
    'gateAcceptLead': 'Διάβασε και αποδέξου',
    'gatePrivacy': 'Απόρρητο',
    'gateImprint': 'Στοιχεία',
    'gateTerms': 'Όροι χρήσης',
    'gateMustCheck': 'Αποδέξου και τα τρία.',
    'gateContinue': 'Συνέχεια',
    'gateConnectTitle': 'Χρειάζεται σύνδεση',
    'gateConnectBody':
        'Το εργαλείο τρέχει μόνο με συνδεδεμένο λογαριασμό DJ της VibesBox.',
    'settingsVersion': 'Έκδοση',
    'settingsLegal': 'Νομικά',
    'updateRequiredTitle': 'Απαιτείται ενημέρωση',
    'updateOptionalTitle': 'Διαθέσιμη ενημέρωση',
    'updateRequiredBody':
        'Αυτή η έκδοση δεν λειτουργεί πια. Κατέβασε τη νέα.',
    'updateOptionalBody':
        'Υπάρχει νεότερη έκδοση. Μπορείς να την κατεβάσεις ή να συνεχίσεις αργότερα.',
    'updateDownload': 'Λήψη',
    'updateLater': 'Αργότερα',
  },
  'ar': {
    'gateBody':
        'هذه الأداة جزء من تطبيق VibesBox وتعمل فقط مع حساب دي جي متصل.',
    'gateAcceptLead': 'اقرأ ووافق',
    'gatePrivacy': 'الخصوصية',
    'gateImprint': 'البيانات القانونية',
    'gateTerms': 'شروط الاستخدام',
    'gateMustCheck': 'وافق على النقاط الثلاث.',
    'gateContinue': 'متابعة',
    'gateConnectTitle': 'الاتصال مطلوب',
    'gateConnectBody':
        'تعمل هذه الأداة فقط مع حساب دي جي VibesBox متصل.',
    'settingsVersion': 'الإصدار',
    'settingsLegal': 'قانوني',
    'updateRequiredTitle': 'التحديث مطلوب',
    'updateOptionalTitle': 'تحديث متاح',
    'updateRequiredBody':
        'هذا الإصدار لم يعد يعمل. حمّل الإصدار الجديد.',
    'updateOptionalBody':
        'يوجد إصدار أحدث. يمكنك تحميله أو المتابعة لاحقًا.',
    'updateDownload': 'تحميل',
    'updateLater': 'لاحقًا',
  },
  'hi': {
    'gateBody':
        'यह टूल VibesBox ऐप का हिस्सा है और केवल जुड़े DJ खाते के साथ चलता है।',
    'gateAcceptLead': 'पढ़ें और सहमत हों',
    'gatePrivacy': 'गोपनीयता',
    'gateImprint': 'कानूनी जानकारी',
    'gateTerms': 'उपयोग की शर्तें',
    'gateMustCheck': 'तीनों पर सहमति दें।',
    'gateContinue': 'आगे',
    'gateConnectTitle': 'कनेक्शन ज़रूरी',
    'gateConnectBody':
        'यह टूल केवल जुड़े VibesBox DJ खाते के साथ चलता है।',
    'settingsVersion': 'संस्करण',
    'settingsLegal': 'कानूनी',
    'updateRequiredTitle': 'अपडेट ज़रूरी',
    'updateOptionalTitle': 'अपडेट उपलब्ध',
    'updateRequiredBody':
        'यह संस्करण अब नहीं चलता। नया संस्करण डाउनलोड करें।',
    'updateOptionalBody':
        'नया संस्करण है। आप उसे डाउनलोड कर सकते हैं या बाद में जारी रख सकते हैं।',
    'updateDownload': 'डाउनलोड',
    'updateLater': 'बाद में',
  },
  'ja': {
    'gateBody':
        'このツールは VibesBox アプリの一部で、接続した DJ アカウントがあるときだけ動きます。',
    'gateAcceptLead': '読んで同意してください',
    'gatePrivacy': 'プライバシー',
    'gateImprint': '運営者情報',
    'gateTerms': '利用規約',
    'gateMustCheck': '3つすべてに同意してください。',
    'gateContinue': '続ける',
    'gateConnectTitle': '接続が必要です',
    'gateConnectBody':
        'このツールは接続した VibesBox の DJ アカウントがないと動きません。',
    'settingsVersion': 'バージョン',
    'settingsLegal': '法的情報',
    'updateRequiredTitle': '更新が必要です',
    'updateOptionalTitle': '更新があります',
    'updateRequiredBody':
        'このバージョンはもう動きません。新しい版をダウンロードしてください。',
    'updateOptionalBody':
        '新しいバージョンがあります。ダウンロードするか、あとで続けられます。',
    'updateDownload': 'ダウンロード',
    'updateLater': 'あとで',
  },
  'zh': {
    'gateBody': '此工具是 VibesBox 应用的一部分，只有连接 DJ 账号才能使用。',
    'gateAcceptLead': '请阅读并同意',
    'gatePrivacy': '隐私',
    'gateImprint': '法律信息',
    'gateTerms': '使用条款',
    'gateMustCheck': '请同意这三项。',
    'gateContinue': '继续',
    'gateConnectTitle': '需要连接',
    'gateConnectBody': '此工具只能在已连接 VibesBox DJ 账号时运行。',
    'settingsVersion': '版本',
    'settingsLegal': '法律信息',
    'updateRequiredTitle': '必须更新',
    'updateOptionalTitle': '有可用更新',
    'updateRequiredBody': '此版本已无法使用。请下载新版本。',
    'updateOptionalBody': '有新版本。你可以下载，或稍后再继续。',
    'updateDownload': '下载',
    'updateLater': '稍后',
  },
  'th': {
    'gateBody':
        'เครื่องมือนี้เป็นส่วนหนึ่งของแอป VibesBox และใช้ได้เมื่อเชื่อมบัญชีดีเจเท่านั้น',
    'gateAcceptLead': 'อ่านและยอมรับ',
    'gatePrivacy': 'ความเป็นส่วนตัว',
    'gateImprint': 'ข้อมูลทางกฎหมาย',
    'gateTerms': 'เงื่อนไขการใช้งาน',
    'gateMustCheck': 'โปรดยอมรับทั้งสามข้อ',
    'gateContinue': 'ต่อไป',
    'gateConnectTitle': 'ต้องเชื่อมต่อ',
    'gateConnectBody':
        'เครื่องมือนี้ทำงานได้เฉพาะเมื่อเชื่อมบัญชีดีเจ VibesBox',
    'settingsVersion': 'เวอร์ชัน',
    'settingsLegal': 'กฎหมาย',
    'updateRequiredTitle': 'ต้องอัปเดต',
    'updateOptionalTitle': 'มีอัปเดต',
    'updateRequiredBody':
        'เวอร์ชันนี้ใช้ไม่ได้อีกแล้ว กรุณาดาวน์โหลดเวอร์ชันใหม่',
    'updateOptionalBody':
        'มีเวอร์ชันใหม่กว่า คุณดาวน์โหลดได้หรือใช้ต่อภายหลัง',
    'updateDownload': 'ดาวน์โหลด',
    'updateLater': 'ภายหลัง',
  },
  'vi': {
    'gateBody':
        'Công cụ này là một phần của ứng dụng VibesBox và chỉ chạy khi đã kết nối tài khoản DJ.',
    'gateAcceptLead': 'Đọc và đồng ý',
    'gatePrivacy': 'Quyền riêng tư',
    'gateImprint': 'Thông tin pháp lý',
    'gateTerms': 'Điều khoản sử dụng',
    'gateMustCheck': 'Hãy đồng ý cả ba mục.',
    'gateContinue': 'Tiếp tục',
    'gateConnectTitle': 'Cần kết nối',
    'gateConnectBody':
        'Công cụ này chỉ chạy với tài khoản DJ VibesBox đã kết nối.',
    'settingsVersion': 'Phiên bản',
    'settingsLegal': 'Pháp lý',
    'updateRequiredTitle': 'Cần cập nhật',
    'updateOptionalTitle': 'Có bản cập nhật',
    'updateRequiredBody':
        'Phiên bản này không còn dùng được. Hãy tải bản mới.',
    'updateOptionalBody':
        'Có phiên bản mới hơn. Bạn có thể tải hoặc tiếp tục sau.',
    'updateDownload': 'Tải xuống',
    'updateLater': 'Để sau',
  },
  'sq': {
    'gateBody':
        'Ky mjet është pjesë e aplikacionit VibesBox dhe punon vetëm me një llogari DJ të lidhur.',
    'gateAcceptLead': 'Lexo dhe prano',
    'gatePrivacy': 'Privatësia',
    'gateImprint': 'Impressum',
    'gateTerms': 'Kushtet e përdorimit',
    'gateMustCheck': 'Prano të tre pikat.',
    'gateContinue': 'Vazhdo',
    'gateConnectTitle': 'Duhet lidhje',
    'gateConnectBody':
        'Ky mjet punon vetëm me një llogari DJ të VibesBox të lidhur.',
    'settingsVersion': 'Versioni',
    'settingsLegal': 'Ligjore',
    'updateRequiredTitle': 'Duhet përditësim',
    'updateOptionalTitle': 'Ka përditësim',
    'updateRequiredBody':
        'Ky version nuk punon më. Shkarko versionin e ri.',
    'updateOptionalBody':
        'Ka një version më të ri. Mund ta shkarkosh ose të vazhdosh më vonë.',
    'updateDownload': 'Shkarko',
    'updateLater': 'Më vonë',
  },
};

String? toolGateText(String lang, String key) {
  final en = toolGatePacks['en'];
  if (en == null || !en.containsKey(key)) return null;
  return toolGatePacks[lang]?[key] ?? en[key];
}
