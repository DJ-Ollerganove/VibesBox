#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate tool/_en_gap_patch_translations.py"""
from pathlib import Path

FK = [
    "party_floor_add_dialog_hint", "party_floor_add_dialog_title", "party_floor_add_new",
    "party_floor_default_option", "party_floor_label", "party_floor_mode_none",
    "party_floor_mode_select", "party_floor_name_required", "party_floor_occupied_hint",
    "party_floor_select_hint", "party_floor_swap_accept", "party_floor_swap_accepted",
    "party_floor_swap_after_save_hint", "party_floor_swap_dialog_body",
    "party_floor_swap_dialog_title", "party_floor_swap_dialog_your_floor",
    "party_floor_swap_failed", "party_floor_swap_incoming_body",
    "party_floor_swap_incoming_title", "party_floor_swap_reject", "party_floor_swap_request",
    "party_floor_swap_sent", "party_public_location_coords_required",
    "guest_floor_ended_redirect_message", "guest_floor_main_area", "guest_floor_picker_choose",
    "guest_floor_picker_title", "guest_floor_switch_button", "venue_bookmarks_title",
    "venue_bookmarks_use", "party_wizard_step_number_only",
]
SK = [
    "social_hint_account", "social_hint_facebook", "social_hint_instagram",
    "social_hint_soundcloud", "social_hint_spotify", "social_hint_tiktok",
    "social_hint_website", "social_hint_whatsapp", "social_hint_youtube",
]
BK = [
    "referral_redeem_body_b2b", "referral_redeem_title_b2b", "referral_code_hint_b2b",
    "referral_code_length_b2b", "referral_code_saved_b2b", "paywall_start_trial_button_b2b",
    "paywall_trial_b2b_hint", "paywall_trial_confirm_title_b2b",
    "paywall_trial_confirm_message_b2b", "paywall_trial_confirm_message_no_b2b",
    "trial_activated_snackbar_b2b",
]
RK = ["recognition_lock_takeover_button", "invalid_whatsapp_phone", "labelDjId"]


def pack(f, s, b, r):
    return {**dict(zip(FK, f)), **dict(zip(SK, s)), **dict(zip(BK, b)), **dict(zip(RK, r))}


FLOOR = {}
SOCIAL = {}
B2B = {}
RECOGNITION = {}
MAIN = {}
EXTRA = {}

LOCALE_DATA = {}

# fmt: off
LOCALE_DATA["ar"] = pack(
    ["مثال: الطابق الأول، الشرفة", "Floor جديد", "إضافة Floor", "بدون Floors منفصلة (المنطقة الرئيسية)", "Floor / منطقة", "بدون تحديد Floor", "اختر Floor", "يُرجى إدخال اسم Floor.", "مشغول", "اختر Floor", "قبول", "تم التبديل", "هذا Floor مشغول. اختر Floorًا فارغًا. يمكنك طلب التبديل بعد الحفظ في تعديل الحفلة.", "{djName} يستخدم {floorLabel}. هل تريد طلب التبديل؟", "طلب تبديل Floor", "Floor الحالي: {floorLabel}", "تعذّر إرسال طلب التبديل", "{djName} يريد تبديل Floors معك ({yourFloor} ↔ {theirFloor}).", "طلب تبديل Floor", "رفض", "طلب تبديل", "تم إرسال طلب التبديل", "الحفلات العامة تتطلب موقعًا بإحداثيات على الخريطة.", "انتهت الحفلة في {floorLabel}. يُرجى اختيار غرفة أخرى.", "المنطقة الرئيسية", "اختر الغرفة لطلباتك الموسيقية.", "اختر غرفة", "تغيير الغرفة", "الأماكن المحفوظة", "استخدام", "الخطوة {current}"],
    ["اسم الحساب (بدون رابط كامل)", "اسم الملف الشخصي، مثل dj.max", "اسم الملف الشخصي، مثل dj.max", "اسم الملف الشخصي، مثل dj-max", "اسم الملف الشخصي أو artist/your-name", "اسم الملف الشخصي بدون @", "النطاق، مثل your-domain.com", "491701234567 (بدون مسافات، مع رمز الدولة 49)", "اسم القناة، مثل @yourchannel"],
    ["هل لديك رمز DJ B2B من DJ آخر؟", "استرداد رمز DJ B2B", "رمز DJ B2B (DJ######)", "يجب أن يطابق الرمز DJ######.", "تم حفظ رمز DJ B2B", "ابدأ 7 أيام مجانًا", "مع رمز DJ B2B تحصل على 7 أيام تجريبية بدلًا من 2.", "بدء التجربة المجانية؟", "مع رمز DJ B2B تحصل على 7 أيام VibesBox Pro. بدون رمز: يومان.", "هل تريد بدء تجربتك لمرة واحدة لمدة يومين؟ تحصل فورًا على VibesBox Pro. بعد انتهائها، تعود حدود النسخة المجانية.", "تم تفعيل VibesBox Pro لمدة 7 أيام!"],
    ["ابدأ من هنا", "أدخل رقم الجوال مع رمز الدولة 49 – بدون 0 في البداية أو 0049.", "معرّف DJ"],
)
LOCALE_DATA["cs"] = pack(
    ["např. 1. patro, terasa", "Nový Floor", "Přidat Floor", "Žádné samostatné Floory (hlavní oblast)", "Floor / oblast", "Neuvádět Floor", "Vybrat Floor", "Zadej prosím název Flooru.", "obsazeno", "Vyber Floor", "Přijmout", "Výměna dokončena", "Tento Floor je obsazený. Vyber volný Floor. O výměnu můžeš požádat po uložení v úpravách party.", "{djName} používá {floorLabel}. Chceš požádat o výměnu?", "Požádat o výměnu Flooru", "Tvůj aktuální Floor: {floorLabel}", "Požadavek na výměnu se nepodařilo odeslat", "{djName} s tebou chce vyměnit Floory ({yourFloor} ↔ {theirFloor}).", "Žádost o výměnu Flooru", "Odmítnout", "Požádat o výměnu", "Žádost o výměnu odeslána", "Veřejné party vyžadují místo se souřadnicemi na mapě.", "Party v {floorLabel} skončila. Vyber prosím jiný sál.", "Hlavní oblast", "Vyber sál pro své hudební přání.", "Vybrat sál", "Změnit sál", "Uložená místa", "Použít", "Krok {current}"],
    ["Název účtu (bez celého odkazu)", "Jméno profilu, např. dj.max", "Jméno profilu, např. dj.max", "Jméno profilu, např. dj-max", "Jméno profilu nebo artist/tvoje-jmeno", "Jméno profilu bez @", "Doména, např. tvoje-domena.cz", "491701234567 (bez mezer, s kódem země 49)", "Název kanálu, např. @tvujkanal"],
    ["Máš DJ B2B kód od jiného DJe?", "Uplatnit DJ B2B kód", "DJ B2B kód (DJ######)", "Kód musí odpovídat DJ######.", "DJ B2B kód uložen", "Spustit 7 dní zdarma", "S DJ B2B kódem dostaneš 7 místo 2 zkušebních dnů.", "Spustit zkušební verzi zdarma?", "S DJ B2B kódem dostaneš 7 dní VibesBox Pro. Bez kódu: 2 dny.", "Chceš spustit jednorázovou 2denní zkušební verzi? Hned dostaneš VibesBox Pro. Po skončení platí znovu free limity.", "VibesBox Pro aktivováno na 7 dní!"],
    ["Spustit zde", "Zadej mobilní číslo s kódem země 49 – bez úvodní 0 nebo 0049.", "ID DJ"],
)
LOCALE_DATA["el"] = pack(
    ["π.χ. 1ος όροφος, βεράντα", "Νέο Floor", "Προσθήκη Floor", "Χωρίς ξεχωριστά Floors (κύρια περιοχή)", "Floor / περιοχή", "Χωρίς καθορισμό Floor", "Επίλεξε Floor", "Παρακαλώ εισήγαγε όνομα Floor.", "κατειλημμένο", "Επίλεξε Floor", "Αποδοχή", "Η ανταλλαγή ολοκληρώθηκε", "Αυτό το Floor είναι κατειλημμένο. Διάλεξε ένα ελεύθερο Floor. Μπορείς να ζητήσεις ανταλλαγή μετά την αποθήκευση στην επεξεργασία πάρτι.", "{djName} χρησιμοποιεί {floorLabel}. Θέλεις να ζητήσεις ανταλλαγή;", "Αίτημα ανταλλαγής Floor", "Το τρέχον Floor σου: {floorLabel}", "Δεν ήταν δυνατή η αποστολή του αιτήματος ανταλλαγής", "{djName} θέλει να ανταλλάξει Floors μαζί σου ({yourFloor} ↔ {theirFloor}).", "Αίτημα ανταλλαγής Floor", "Απόρριψη", "Αίτημα ανταλλαγής", "Το αίτημα ανταλλαγής στάλθηκε", "Οι δημόσιες πάρτι απαιτούν τοποθεσία με συντεταγμένες στον χάρτη.", "Η πάρτι στο {floorLabel} τελείωσε. Διάλεξε άλλο δωμάτιο.", "Κύρια περιοχή", "Διάλεξε το δωμάτιο για τα μουσικά σου αιτήματα.", "Επίλεξε δωμάτιο", "Αλλαγή δωματίου", "Αποθηκευμένοι χώροι", "Χρήση", "Βήμα {current}"],
    ["Όνομα λογαριασμού (χωρίς πλήρες link)", "Όνομα προφίλ, π.χ. dj.max", "Όνομα προφίλ, π.χ. dj.max", "Όνομα προφίλ, π.χ. dj-max", "Όνομα προφίλ ή artist/tο-όνομά-σου", "Όνομα προφίλ χωρίς @", "Domain, π.χ. your-domain.gr", "491701234567 (χωρίς κενά, με κωδικό χώρας 49)", "Όνομα καναλιού, π.χ. @yourchannel"],
    ["Έχεις κωδικό DJ B2B από άλλον DJ;", "Εξαργύρωση κωδικού DJ B2B", "Κωδικός DJ B2B (DJ######)", "Ο κωδικός πρέπει να ταιριάζει με DJ######.", "Ο κωδικός DJ B2B αποθηκεύτηκε", "Ξεκίνα 7 ημέρες δωρεάν", "Με κωδικό DJ B2B παίρνεις 7 αντί για 2 ημέρες δοκιμής.", "Ξεκίνα δωρεάν δοκιμή;", "Με τον κωδικό DJ B2B παίρνεις 7 ημέρες VibesBox Pro. Χωρίς κωδικό: 2 ημέρες.", "Θέλεις να ξεκινήσεις την εφάπαξ 2ήμερη δοκιμή; Παίρνεις αμέσως VibesBox Pro. Μετά ισχύουν ξανά τα free όρια.", "Το VibesBox Pro ενεργοποιήθηκε για 7 ημέρες!"],
    ["Ξεκίνα εδώ", "Εισήγαγε κινητό με κωδικό χώρας 49 – χωρίς αρχικό 0 ή 0049.", "ΑΝΑΓΝΩΡΙΣΤΙΚΌ DJ"],
)
LOCALE_DATA["es"] = pack(
    ["p. ej. 1.º piso, terraza", "Nuevo Floor", "Añadir Floor", "Sin Floors separados (zona principal)", "Floor / zona", "Sin Floor especificado", "Elige un Floor", "Introduce un nombre de Floor.", "ocupado", "Selecciona un Floor", "Aceptar", "Intercambio completado", "Este Floor está ocupado. Elige uno libre. Puedes solicitar un intercambio tras guardar en la edición de la fiesta.", "{djName} usa {floorLabel}. ¿Quieres solicitar un intercambio?", "Solicitar intercambio de Floor", "Tu Floor actual: {floorLabel}", "No se pudo enviar la solicitud de intercambio", "{djName} quiere intercambiar Floors contigo ({yourFloor} ↔ {theirFloor}).", "Solicitud de intercambio de Floor", "Rechazar", "Solicitar intercambio", "Solicitud de intercambio enviada", "Las fiestas públicas requieren una ubicación con coordenadas en el mapa.", "La fiesta en {floorLabel} ha terminado. Elige otra sala.", "Zona principal", "Elige la sala para tus peticiones musicales.", "Elige una sala", "Cambiar sala", "Lugares guardados", "Usar", "Paso {current}"],
    ["Nombre de cuenta (sin enlace completo)", "Nombre de perfil, p. ej. dj.max", "Nombre de perfil, p. ej. dj.max", "Nombre de perfil, p. ej. dj-max", "Nombre de perfil o artist/tu-nombre", "Nombre de perfil sin @", "Dominio, p. ej. tu-dominio.com", "491701234567 (sin espacios, con prefijo 49)", "Nombre del canal, p. ej. @tucanal"],
    ["¿Tienes un código DJ B2B de otro DJ?", "Canjear código DJ B2B", "Código DJ B2B (DJ######)", "El código debe coincidir con DJ######.", "Código DJ B2B guardado", "Empezar 7 días gratis", "Con un código DJ B2B obtienes 7 días de prueba en lugar de 2.", "¿Empezar prueba gratis?", "Con tu código DJ B2B obtienes 7 días de VibesBox Pro. Sin código: 2 días.", "¿Quieres empezar tu prueba única de 2 días? Obtienes VibesBox Pro al instante. Después vuelven los límites gratuitos.", "¡VibesBox Pro activado durante 7 días!"],
    ["Empezar aquí", "Introduce el móvil con prefijo 49 – sin 0 inicial ni 0049.", "ID de DJ"],
)
LOCALE_DATA["fr"] = pack(
    ["p. ex. 1er étage, terrasse", "Nouveau Floor", "Ajouter un Floor", "Pas de Floors séparés (zone principale)", "Floor / zone", "Aucun Floor indiqué", "Choisir un Floor", "Entre un nom de Floor.", "occupé", "Sélectionne un Floor", "Accepter", "Échange effectué", "Ce Floor est occupé. Choisis un Floor libre. Tu peux demander un échange après l'enregistrement dans la modification de la fête.", "{djName} utilise {floorLabel}. Veux-tu demander un échange ?", "Demander un échange de Floor", "Ton Floor actuel : {floorLabel}", "Impossible d'envoyer la demande d'échange", "{djName} veut échanger de Floor avec toi ({yourFloor} ↔ {theirFloor}).", "Demande d'échange de Floor", "Refuser", "Demander un échange", "Demande d'échange envoyée", "Les fêtes publiques nécessitent un lieu avec des coordonnées sur la carte.", "La fête dans {floorLabel} est terminée. Choisis une autre salle.", "Zone principale", "Choisis la salle pour tes demandes musicales.", "Choisir une salle", "Changer de salle", "Lieux enregistrés", "Utiliser", "Étape {current}"],
    ["Nom du compte (sans lien complet)", "Nom de profil, p. ex. dj.max", "Nom de profil, p. ex. dj.max", "Nom de profil, p. ex. dj-max", "Nom de profil ou artist/ton-nom", "Nom de profil sans @", "Domaine, p. ex. ton-domaine.fr", "491701234567 (sans espaces, avec indicatif 49)", "Nom de chaîne, p. ex. @tachaine"],
    ["Tu as un code DJ B2B d'un autre DJ ?", "Utiliser un code DJ B2B", "Code DJ B2B (DJ######)", "Le code doit correspondre à DJ######.", "Code DJ B2B enregistré", "Commencer 7 jours gratuits", "Avec un code DJ B2B tu obtiens 7 jours d'essai au lieu de 2.", "Commencer l'essai gratuit ?", "Avec ton code DJ B2B tu obtiens 7 jours de VibesBox Pro. Sans code : 2 jours.", "Veux-tu lancer ton essai unique de 2 jours ? Tu obtiens VibesBox Pro immédiatement. Ensuite, les limites gratuites s'appliquent à nouveau.", "VibesBox Pro activé pendant 7 jours !"],
    ["Démarrer ici", "Entre le numéro mobile avec l'indicatif 49 – sans 0 initial ni 0049.", "ID DJ"],
)
LOCALE_DATA["hi"] = pack(
    ["उदा. पहली मंज़िल, छत", "नया Floor", "Floor जोड़ें", "अलग Floors नहीं (मुख्य क्षेत्र)", "Floor / क्षेत्र", "कोई Floor निर्दिष्ट नहीं", "Floor चुनें", "कृपया Floor का नाम दर्ज करें।", "व्यस्त", "Floor चुनें", "स्वीकार करें", "स्वैप पूरा हुआ", "यह Floor व्यस्त है। कोई खाली Floor चुनें। पार्टी संपादन में सहेजने के बाद स्वैप का अनुरोध कर सकते हो।", "{djName} {floorLabel} उपयोग कर रहा है। क्या तुम स्वैप का अनुरोध करना चाहते हो?", "Floor स्वैप का अनुरोध", "तुम्हारा वर्तमान Floor: {floorLabel}", "स्वैप अनुरोध भेजा नहीं जा सका", "{djName} तुम्हारे साथ Floors स्वैप करना चाहता है ({yourFloor} ↔ {theirFloor})।", "Floor स्वैप अनुरोध", "अस्वीकार", "स्वैप अनुरोध", "स्वैप अनुरोध भेजा गया", "सार्वजनिक पार्टियों के लिए मानचित्र निर्देशांक वाला स्थान ज़रूरी है।", "{floorLabel} में पार्टी समाप्त हो गई। कृपया दूसरा कमरा चुनें।", "मुख्य क्षेत्र", "अपने संगीत अनुरोधों के लिए कमरा चुनें।", "कमरा चुनें", "कमरा बदलें", "सहेजे गए स्थान", "उपयोग करें", "चरण {current}"],
    ["खाता नाम (पूरा लिंक नहीं)", "प्रोफ़ाइल नाम, जैसे dj.max", "प्रोफ़ाइल नाम, जैसे dj.max", "प्रोफ़ाइल नाम, जैसे dj-max", "प्रोफ़ाइल नाम या artist/your-name", "प्रोफ़ाइल नाम बिना @", "डोमेन, जैसे your-domain.com", "491701234567 (बिना स्पेस, देश कोड 49)", "चैनल नाम, जैसे @yourchannel"],
    ["क्या तुम्हारे पास किसी अन्य DJ का DJ B2B कोड है?", "DJ B2B कोड रिडीम करें", "DJ B2B कोड (DJ######)", "कोड DJ###### से मेल खाना चाहिए।", "DJ B2B कोड सहेजा गया", "7 दिन मुफ़्त शुरू करें", "DJ B2B कोड से तुम्हें 2 की बजाय 7 ट्रायल दिन मिलते हैं।", "मुफ़्त ट्रायल शुरू करें?", "अपने DJ B2B कोड से तुम्हें 7 दिन VibesBox Pro मिलता है। बिना कोड: 2 दिन।", "क्या तुम अपना एक बार का 2-दिन का ट्रायल शुरू करना चाहते हो? तुम्हें तुरंत VibesBox Pro मिलेगा। समाप्ति के बाद फिर से free सीमाएँ लागू होंगी।",     "VibesBox Pro 7 दिनों के लिए सक्रिय!"],
    ["यहाँ शुरू करें", "देश कोड 49 के साथ मोबाइल नंबर दर्ज करें – शुरुआती 0 या 0049 नहीं।", "DJ-ID"],
)
LOCALE_DATA["it"] = pack(
    ["es. 1° piano, terrazza", "Nuovo Floor", "Aggiungi Floor", "Nessun Floor separato (area principale)", "Floor / zona", "Nessun Floor indicato", "Scegli un Floor", "Inserisci un nome Floor.", "occupato", "Seleziona un Floor", "Accetta", "Scambio completato", "Questo Floor è occupato. Scegli un Floor libero. Puoi richiedere uno scambio dopo il salvataggio nella modifica festa.", "{djName} usa {floorLabel}. Vuoi richiedere uno scambio?", "Richiedi scambio Floor", "Il tuo Floor attuale: {floorLabel}", "Impossibile inviare la richiesta di scambio", "{djName} vuole scambiare Floor con te ({yourFloor} ↔ {theirFloor}).", "Richiesta scambio Floor", "Rifiuta", "Richiedi scambio", "Richiesta di scambio inviata", "Le feste pubbliche richiedono un luogo con coordinate sulla mappa.", "La festa in {floorLabel} è terminata. Scegli un'altra sala.", "Area principale", "Scegli la sala per le tue richieste musicali.", "Scegli una sala", "Cambia sala", "Luoghi salvati", "Usa", "Passo {current}"],
    ["Nome account (senza link completo)", "Nome profilo, es. dj.max", "Nome profilo, es. dj.max", "Nome profilo, es. dj-max", "Nome profilo o artist/tuo-nome", "Nome profilo senza @", "Dominio, es. tuo-dominio.it", "491701234567 (senza spazi, con prefisso 49)", "Nome canale, es. @tuocanale"],
    ["Hai un codice DJ B2B di un altro DJ?", "Riscatta codice DJ B2B", "Codice DJ B2B (DJ######)", "Il codice deve corrispondere a DJ######.", "Codice DJ B2B salvato", "Inizia 7 giorni gratis", "Con un codice DJ B2B ottieni 7 invece di 2 giorni di prova.", "Iniziare la prova gratuita?", "Con il tuo codice DJ B2B ottieni 7 giorni di VibesBox Pro. Senza codice: 2 giorni.", "Vuoi avviare la prova una tantum di 2 giorni? Ottieni subito VibesBox Pro. Poi tornano i limiti free.",     "VibesBox Pro attivato per 7 giorni!"],
    ["Avvia qui", "Inserisci il numero mobile con prefisso 49 – senza 0 iniziale o 0049.", "ID DJ"],
)
LOCALE_DATA["ja"] = pack(
    ["例：1階、テラス", "新しいFloor", "Floorを追加", "Floorを分けない（メインエリア）", "Floor / エリア", "Floorを指定しない", "Floorを選ぶ", "Floor名を入力してください。", "使用中", "Floorを選択", "承認", "入れ替え完了", "このFloorは使用中です。空いているFloorを選んでください。パーティー編集で保存後、入れ替えをリクエストできます。", "{djName}が{floorLabel}を使用中です。入れ替えをリクエストしますか？", "Floor入れ替えをリクエスト", "現在のFloor：{floorLabel}", "入れ替えリクエストを送信できませんでした", "{djName}がFloorの入れ替えを希望しています（{yourFloor} ↔ {theirFloor}）。", "Floor入れ替えリクエスト", "拒否", "入れ替えをリクエスト", "入れ替えリクエストを送信しました", "公開パーティーには地図座標のある場所が必要です。", "{floorLabel}のパーティーは終了しました。別のルームを選んでください。", "メインエリア", "音楽リクエスト用のルームを選んでください。", "ルームを選ぶ", "ルームを変更", "保存した会場", "使用", "ステップ {current}"],
    ["アカウント名（フルリンクなし）", "プロフィール名、例：dj.max", "プロフィール名、例：dj.max", "プロフィール名、例：dj-max", "プロフィール名または artist/your-name", "プロフィール名（@なし）", "ドメイン、例：your-domain.com", "491701234567（スペースなし、国番号49）", "チャンネル名、例：@yourchannel"],
    ["他のDJからDJ B2Bコードを持っていますか？", "DJ B2Bコードを利用", "DJ B2Bコード（DJ######）", "コードはDJ######形式である必要があります。", "DJ B2Bコードを保存しました", "7日間無料で開始", "DJ B2Bコードで試用は2日ではなく7日間。", "無料トライアルを開始しますか？", "DJ B2BコードでVibesBox Proが7日間。コードなし：2日間。", "一度限りの2日間トライアルを開始しますか？すぐにVibesBox Proが使えます。終了後は無料版の制限に戻ります。",     "VibesBox Proを7日間有効化しました！"],
    ["ここで開始", "国番号49付きの携帯番号を入力 – 先頭0や0049は不可。", "DJ-ID"],
)
LOCALE_DATA["nl"] = pack(
    ["bijv. 1e verdieping, terras", "Nieuwe Floor", "Floor toevoegen", "Geen aparte Floors (hoofdgebied)", "Floor / gebied", "Geen Floor opgeven", "Kies een Floor", "Voer een Floor-naam in.", "bezet", "Selecteer een Floor", "Accepteren", "Ruil voltooid", "Deze Floor is bezet. Kies een vrije Floor. Je kunt na opslaan in party-bewerking een ruil aanvragen.", "{djName} gebruikt {floorLabel}. Wil je een ruil aanvragen?", "Floor-ruil aanvragen", "Je huidige Floor: {floorLabel}", "Ruilverzoek kon niet worden verzonden", "{djName} wil Floors met je ruilen ({yourFloor} ↔ {theirFloor}).", "Floor-ruilverzoek", "Weigeren", "Ruil aanvragen", "Ruilverzoek verzonden", "Openbare party's vereisen een locatie met kaartcoördinaten.", "De party in {floorLabel} is afgelopen. Kies een andere ruimte.", "Hoofdgebied", "Kies de ruimte voor je muziekverzoeken.", "Kies een ruimte", "Ruimte wisselen", "Opgeslagen locaties", "Gebruiken", "Stap {current}"],
    ["Accountnaam (geen volledige link)", "Profielnaam, bijv. dj.max", "Profielnaam, bijv. dj.max", "Profielnaam, bijv. dj-max", "Profielnaam of artist/jouw-naam", "Profielnaam zonder @", "Domein, bijv. jouw-domein.nl", "491701234567 (zonder spaties, met landcode 49)", "Kanaalnaam, bijv. @jouwkanaal"],
    ["Heb je een DJ B2B-code van een andere DJ?", "DJ B2B-code inwisselen", "DJ B2B-code (DJ######)", "Code moet overeenkomen met DJ######.", "DJ B2B-code opgeslagen", "Start 7 dagen gratis", "Met een DJ B2B-code krijg je 7 in plaats van 2 proefdagen.", "Gratis proefperiode starten?", "Met je DJ B2B-code krijg je 7 dagen VibesBox Pro. Zonder code: 2 dagen.", "Wil je je eenmalige proefperiode van 2 dagen starten? Je krijgt meteen VibesBox Pro. Daarna gelden weer de free-limieten.",     "VibesBox Pro 7 dagen geactiveerd!"],
    ["Hier starten", "Voer mobiel nummer in met landcode 49 – geen leading 0 of 0049.", "DJ-ID"],
)
LOCALE_DATA["pl"] = pack(
    ["np. 1. piętro, taras", "Nowy Floor", "Dodaj Floor", "Bez osobnych Floorów (główny obszar)", "Floor / obszar", "Bez podawania Flooru", "Wybierz Floor", "Podaj nazwę Flooru.", "zajęty", "Wybierz Floor", "Akceptuj", "Wymiana zakończona", "Ten Floor jest zajęty. Wybierz wolny Floor. O wymianę możesz poprosić po zapisaniu w edycji imprezy.", "{djName} używa {floorLabel}. Chcesz poprosić o wymianę?", "Poproś o wymianę Flooru", "Twój aktualny Floor: {floorLabel}", "Nie udało się wysłać prośby o wymianę", "{djName} chce wymienić się Floorami ({yourFloor} ↔ {theirFloor}).", "Prośba o wymianę Flooru", "Odrzuć", "Poproś o wymianę", "Prośba o wymianę wysłana", "Imprezy publiczne wymagają lokalizacji ze współrzędnymi na mapie.", "Impreza w {floorLabel} się zakończyła. Wybierz inną salę.", "Główny obszar", "Wybierz salę dla swoich próśb muzycznych.", "Wybierz salę", "Zmień salę", "Zapisane miejsca", "Użyj", "Krok {current}"],
    ["Nazwa konta (bez pełnego linku)", "Nazwa profilu, np. dj.max", "Nazwa profilu, np. dj.max", "Nazwa profilu, np. dj-max", "Nazwa profilu lub artist/twoja-nazwa", "Nazwa profilu bez @", "Domena, np. twoja-domena.pl", "491701234567 (bez spacji, z kodem kraju 49)", "Nazwa kanału, np. @twojkanal"],
    ["Masz kod DJ B2B od innego DJ-a?", "Wykorzystaj kod DJ B2B", "Kod DJ B2B (DJ######)", "Kod musi pasować do DJ######.", "Kod DJ B2B zapisany", "Rozpocznij 7 dni za darmo", "Z kodem DJ B2B dostajesz 7 zamiast 2 dni próbnych.", "Rozpocząć darmowy okres próbny?", "Z kodem DJ B2B masz 7 dni VibesBox Pro. Bez kodu: 2 dni.", "Chcesz rozpocząć jednorazowy 2-dniowy okres próbny? Od razu masz VibesBox Pro. Potem wracają limity free.",     "VibesBox Pro aktywowane na 7 dni!"],
    ["Rozpocznij tutaj", "Podaj numer komórkowy z kodem kraju 49 – bez wiodącego 0 lub 0049.", "ID DJ"],
)
LOCALE_DATA["pt"] = pack(
    ["ex.: 1.º andar, esplanada", "Novo Floor", "Adicionar Floor", "Sem Floors separados (área principal)", "Floor / área", "Sem Floor indicado", "Escolhe um Floor", "Introduz um nome de Floor.", "ocupado", "Seleciona um Floor", "Aceitar", "Troca concluída", "Este Floor está ocupado. Escolhe um Floor livre. Podes pedir uma troca após guardar na edição da festa.", "{djName} usa {floorLabel}. Queres pedir uma troca?", "Pedir troca de Floor", "O teu Floor atual: {floorLabel}", "Não foi possível enviar o pedido de troca", "{djName} quer trocar Floors contigo ({yourFloor} ↔ {theirFloor}).", "Pedido de troca de Floor", "Recusar", "Pedir troca", "Pedido de troca enviado", "Festas públicas exigem um local com coordenadas no mapa.", "A festa em {floorLabel} terminou. Escolhe outra sala.", "Área principal", "Escolhe a sala para os teus pedidos musicais.", "Escolhe uma sala", "Mudar de sala", "Locais guardados", "Usar", "Passo {current}"],
    ["Nome da conta (sem link completo)", "Nome do perfil, ex. dj.max", "Nome do perfil, ex. dj.max", "Nome do perfil, ex. dj-max", "Nome do perfil ou artist/teu-nome", "Nome do perfil sem @", "Domínio, ex. teu-dominio.pt", "491701234567 (sem espaços, com indicativo 49)", "Nome do canal, ex. @teucanal"],
    ["Tens um código DJ B2B de outro DJ?", "Resgatar código DJ B2B", "Código DJ B2B (DJ######)", "O código tem de corresponder a DJ######.", "Código DJ B2B guardado", "Começar 7 dias grátis", "Com um código DJ B2B obténs 7 em vez de 2 dias de teste.", "Começar teste grátis?", "Com o teu código DJ B2B tens 7 dias de VibesBox Pro. Sem código: 2 dias.", "Queres iniciar o teu teste único de 2 dias? Recebes VibesBox Pro de imediato. Depois voltam os limites free.",     "VibesBox Pro ativado durante 7 dias!"],
    ["Começar aqui", "Introduz o telemóvel com indicativo 49 – sem 0 inicial ou 0049.", "ID do DJ"],
)
LOCALE_DATA["ru"] = pack(
    ["напр. 1-й этаж, терраса", "Новый Floor", "Добавить Floor", "Без отдельных Floors (основная зона)", "Floor / зона", "Floor не указан", "Выбери Floor", "Введи название Floor.", "занято", "Выбери Floor", "Принять", "Обмен выполнен", "Этот Floor занят. Выбери свободный Floor. Запросить обмен можно после сохранения в редактировании вечеринки.", "{djName} использует {floorLabel}. Хочешь запросить обмен?", "Запросить обмен Floor", "Твой текущий Floor: {floorLabel}", "Не удалось отправить запрос на обмен", "{djName} хочет поменяться Floor с тобой ({yourFloor} ↔ {theirFloor}).", "Запрос на обмен Floor", "Отклонить", "Запросить обмен", "Запрос на обмен отправлен", "Публичные вечеринки требуют место с координатами на карте.", "Вечеринка в {floorLabel} завершилась. Выбери другой зал.", "Основная зона", "Выбери зал для своих музыкальных пожеланий.", "Выбрать зал", "Сменить зал", "Сохранённые места", "Использовать", "Шаг {current}"],
    ["Имя аккаунта (без полной ссылки)", "Имя профиля, напр. dj.max", "Имя профиля, напр. dj.max", "Имя профиля, напр. dj-max", "Имя профиля или artist/твоё-имя", "Имя профиля без @", "Домен, напр. tvoy-domain.ru", "491701234567 (без пробелов, с кодом страны 49)", "Имя канала, напр. @tvoykanal"],
    ["Есть DJ B2B-код от другого DJ?", "Активировать DJ B2B-код", "DJ B2B-код (DJ######)", "Код должен соответствовать DJ######.", "DJ B2B-код сохранён", "Начать 7 дней бесплатно", "С DJ B2B-кодом ты получаешь 7 вместо 2 пробных дней.", "Начать бесплатный пробный период?", "С DJ B2B-кодом ты получаешь 7 дней VibesBox Pro. Без кода: 2 дня.", "Хочешь начать одноразовый 2-дневный пробный период? Сразу получишь VibesBox Pro. После окончания снова действуют free-лимиты.",     "VibesBox Pro активирован на 7 дней!"],
    ["Начать здесь", "Введи мобильный номер с кодом страны 49 – без ведущего 0 или 0049.", "ID DJ"],
)
LOCALE_DATA["sq"] = pack(
    ["p.sh. kati i 1., tarraca", "Floor i ri", "Shto Floor", "Pa Floors të ndara (zonë kryesore)", "Floor / zonë", "Pa Floor të specifikuar", "Zgjidh një Floor", "Shkruaj emrin e Floor-it.", "i zënë", "Zgjidh një Floor", "Prano", "Shkëmbimi u krye", "Ky Floor është i zënë. Zgjidh një Floor të lirë. Mund të kërkosh shkëmbim pas ruajtjes në redaktimin e festës.", "{djName} përdor {floorLabel}. Dëshiron të kërkosh shkëmbim?", "Kërko shkëmbim Floor", "Floor-i yt aktual: {floorLabel}", "Kërkesa e shkëmbimit nuk u dërgua", "{djName} dëshiron të shkëmbejë Floors me ty ({yourFloor} ↔ {theirFloor}).", "Kërkesë shkëmbimi Floor", "Refuzo", "Kërko shkëmbim", "Kërkesa e shkëmbimit u dërgua", "Festat publike kërkojnë një vend me koordinata në hartë.", "Festa në {floorLabel} përfundoi. Zgjidh një dhomë tjetër.", "Zona kryesore", "Zgjidh dhomën për kërkesat e tua muzikore.", "Zgjidh një dhomë", "Ndrysho dhomën", "Vende të ruajtura", "Përdor", "Hapi {current}"],
    ["Emri i llogarisë (pa link të plotë)", "Emri i profilit, p.sh. dj.max", "Emri i profilit, p.sh. dj.max", "Emri i profilit, p.sh. dj-max", "Emri i profilit ose artist/emri-yt", "Emri i profilit pa @", "Domain, p.sh. domaini-yt.com", "491701234567 (pa hapësira, me kod shteti 49)", "Emri i kanalit, p.sh. @kanali-yt"],
    ["Ke një kod DJ B2B nga një DJ tjetër?", "Përdor kodin DJ B2B", "Kod DJ B2B (DJ######)", "Kodi duhet të përputhet me DJ######.", "Kodi DJ B2B u ruajt", "Fillo 7 ditë falas", "Me kod DJ B2B merr 7 në vend të 2 ditëve prove.", "Të fillosh provën falas?", "Me kodin DJ B2B merr 7 ditë VibesBox Pro. Pa kod: 2 ditë.", "Dëshiron të fillosh provën njëherëshe 2-ditore? Merr VibesBox Pro menjëherë. Pas përfundimit vlejnë përsëri limitet free.",     "VibesBox Pro u aktivizua për 7 ditë!"],
    ["Fillo këtu", "Shkruaj numrin celular me kod shteti 49 – pa 0 në fillim ose 0049.", "ID DJ"],
)
LOCALE_DATA["tr"] = pack(
    ["örn. 1. kat, teras", "Yeni Floor", "Floor ekle", "Ayrı Floor yok (ana alan)", "Floor / alan", "Floor belirtilmedi", "Floor seç", "Lütfen bir Floor adı gir.", "dolu", "Floor seç", "Kabul et", "Değişim tamamlandı", "Bu Floor dolu. Boş bir Floor seç. Parti düzenlemede kaydettikten sonra değişim isteyebilirsin.", "{djName} {floorLabel} kullanıyor. Değişim istemek ister misin?", "Floor değişimi iste", "Mevcut Floor'un: {floorLabel}", "Değişim isteği gönderilemedi", "{djName} seninle Floor değiştirmek istiyor ({yourFloor} ↔ {theirFloor}).", "Floor değişim isteği", "Reddet", "Değişim iste", "Değişim isteği gönderildi", "Herkese açık partiler harita koordinatlı bir konum gerektirir.", "{floorLabel} partisi bitti. Lütfen başka bir oda seç.", "Ana alan", "Müzik isteklerin için odayı seç.", "Oda seç", "Odayı değiştir", "Kayıtlı mekanlar", "Kullan", "Adım {current}"],
    ["Hesap adı (tam link yok)", "Profil adı, örn. dj.max", "Profil adı, örn. dj.max", "Profil adı, örn. dj-max", "Profil adı veya artist/adin", "Profil adı @ olmadan", "Alan adı, örn. alan-adin.com", "491701234567 (boşluksuz, ülke kodu 49)", "Kanal adı, örn. @kanalin"],
    ["Başka bir DJ'den DJ B2B kodun var mı?", "DJ B2B kodunu kullan", "DJ B2B kodu (DJ######)", "Kod DJ###### ile eşleşmeli.", "DJ B2B kodu kaydedildi", "7 gün ücretsiz başlat", "DJ B2B koduyla 2 yerine 7 deneme günü alırsın.", "Ücretsiz denemeyi başlat?", "DJ B2B kodunla 7 gün VibesBox Pro alırsın. Kod yoksa: 2 gün.", "Tek seferlik 2 günlük denemeni başlatmak ister misin? Hemen VibesBox Pro alırsın. Bitince free limitler tekrar geçerli olur.",     "VibesBox Pro 7 gün için etkinleştirildi!"],
    ["Burada başlat", "Ülke kodu 49 ile cep numarası gir – başta 0 veya 0049 olmadan.", "DJ Kimliği"],
)
LOCALE_DATA["uk"] = pack(
    ["напр. 1-й поверх, тераса", "Новий Floor", "Додати Floor", "Без окремих Floors (головна зона)", "Floor / зона", "Floor не вказано", "Обери Floor", "Введи назву Floor.", "зайнято", "Обери Floor", "Прийняти", "Обмін виконано", "Цей Floor зайнятий. Обери вільний Floor. Запросити обмін можна після збереження в редагуванні вечірки.", "{djName} використовує {floorLabel}. Хочеш запросити обмін?", "Запросити обмін Floor", "Твій поточний Floor: {floorLabel}", "Не вдалося надіслати запит на обмін", "{djName} хоче обмінятися Floors з тобою ({yourFloor} ↔ {theirFloor}).", "Запит на обмін Floor", "Відхилити", "Запросити обмін", "Запит на обмін надіслано", "Публічні вечірки потребують місце з координатами на карті.", "Вечірка в {floorLabel} завершилася. Обери іншу кімнату.", "Головна зона", "Обери кімнату для своїх музичних побажань.", "Обери кімнату", "Змінити кімнату", "Збережені місця", "Використати", "Крок {current}"],
    ["Ім'я акаунта (без повного посилання)", "Ім'я профілю, напр. dj.max", "Ім'я профілю, напр. dj.max", "Ім'я профілю, напр. dj-max", "Ім'я профілю або artist/твоє-ім'я", "Ім'я профілю без @", "Домен, напр. tviy-domain.com", "491701234567 (без пробілів, з кодом країни 49)", "Ім'я каналу, напр. @tviykanal"],
    ["Є DJ B2B-код від іншого DJ?", "Активувати DJ B2B-код", "DJ B2B-код (DJ######)", "Код має відповідати DJ######.", "DJ B2B-код збережено", "Почати 7 днів безкоштовно", "З DJ B2B-кодом ти отримуєш 7 замість 2 пробних днів.", "Почати безкоштовний пробний період?", "З DJ B2B-кодом ти отримуєш 7 днів VibesBox Pro. Без коду: 2 дні.", "Хочеш розпочати одноразовий 2-денний пробний період? Одразу отримаєш VibesBox Pro. Після завершення знову діють free-ліміти.",     "VibesBox Pro активовано на 7 днів!"],
    ["Почати тут", "Введи мобільний номер з кодом країни 49 – без початкового 0 або 0049.", "ID DJ"],
)
LOCALE_DATA["vi"] = pack(
    ["vd. tầng 1, sân thượng", "Floor mới", "Thêm Floor", "Không tách Floor (khu chính)", "Floor / khu vực", "Không chỉ định Floor", "Chọn Floor", "Vui lòng nhập tên Floor.", "đã có người dùng", "Chọn Floor", "Chấp nhận", "Hoán đổi hoàn tất", "Floor này đã có người dùng. Chọn Floor trống. Bạn có thể yêu cầu hoán đổi sau khi lưu trong chỉnh sửa party.", "{djName} đang dùng {floorLabel}. Bạn muốn yêu cầu hoán đổi?", "Yêu cầu hoán đổi Floor", "Floor hiện tại của bạn: {floorLabel}", "Không gửi được yêu cầu hoán đổi", "{djName} muốn hoán đổi Floor với bạn ({yourFloor} ↔ {theirFloor}).", "Yêu cầu hoán đổi Floor", "Từ chối", "Yêu cầu hoán đổi", "Đã gửi yêu cầu hoán đổi", "Party công khai cần địa điểm có tọa độ trên bản đồ.", "Party ở {floorLabel} đã kết thúc. Vui lòng chọn phòng khác.", "Khu chính", "Chọn phòng cho yêu cầu nhạc của bạn.", "Chọn phòng", "Đổi phòng", "Địa điểm đã lưu", "Dùng", "Bước {current}"],
    ["Tên tài khoản (không có link đầy đủ)", "Tên hồ sơ, vd. dj.max", "Tên hồ sơ, vd. dj.max", "Tên hồ sơ, vd. dj-max", "Tên hồ sơ hoặc artist/ten-ban", "Tên hồ sơ không có @", "Tên miền, vd. ten-mien.com", "491701234567 (không khoảng trắng, mã quốc gia 49)", "Tên kênh, vd. @kenhban"],
    ["Bạn có mã DJ B2B từ DJ khác?", "Đổi mã DJ B2B", "Mã DJ B2B (DJ######)", "Mã phải khớp DJ######.", "Đã lưu mã DJ B2B", "Bắt đầu 7 ngày miễn phí", "Với mã DJ B2B bạn được 7 thay vì 2 ngày dùng thử.", "Bắt đầu dùng thử miễn phí?", "Với mã DJ B2B bạn có 7 ngày VibesBox Pro. Không có mã: 2 ngày.", "Bạn muốn bắt đầu dùng thử một lần 2 ngày? Bạn nhận VibesBox Pro ngay. Sau đó áp dụng lại giới hạn free.",     "VibesBox Pro đã kích hoạt 7 ngày!"],
    ["Bắt đầu tại đây", "Nhập số di động với mã quốc gia 49 – không có số 0 đầu hoặc 0049.", "ID DJ"],
)
LOCALE_DATA["zh"] = pack(
    ["例如：1 楼、露台", "新 Floor", "添加 Floor", "不区分 Floor（主区域）", "Floor / 区域", "不指定 Floor", "选择 Floor", "请输入 Floor 名称。", "已占用", "选择 Floor", "接受", "交换完成", "此 Floor 已被占用。请选择一个空闲 Floor。在派对编辑中保存后可请求交换。", "{djName} 正在使用 {floorLabel}。要请求交换吗？", "请求交换 Floor", "你当前的 Floor：{floorLabel}", "无法发送交换请求", "{djName} 想与你交换 Floor（{yourFloor} ↔ {theirFloor}）。", "Floor 交换请求", "拒绝", "请求交换", "交换请求已发送", "公开派对需要带有地图坐标的位置。", "{floorLabel} 的派对已结束。请选择其他房间。", "主区域", "选择用于音乐请求的房间。", "选择房间", "更换房间", "已保存的场地", "使用", "步骤 {current}"],
    ["账户名（非完整链接）", "个人资料名，如 dj.max", "个人资料名，如 dj.max", "个人资料名，如 dj-max", "个人资料名或 artist/你的名字", "个人资料名不含 @", "域名，如 your-domain.com", "491701234567（无空格，含国家代码 49）", "频道名，如 @yourchannel"],
    ["你有其他 DJ 的 DJ B2B 码吗？", "兑换 DJ B2B 码", "DJ B2B 码（DJ######）", "码必须匹配 DJ######。", "DJ B2B 码已保存", "开始 7 天免费试用", "使用 DJ B2B 码可获得 7 天而非 2 天试用。", "开始免费试用？", "使用 DJ B2B 码可获得 7 天 VibesBox Pro。无码：2 天。", "要开始一次性 2 天试用吗？你将立即获得 VibesBox Pro。结束后恢复免费版限制。",     "VibesBox Pro 已激活 7 天！"],
    ["在此开始", "请输入带国家代码 49 的手机号 – 不要以 0 或 0049 开头。", "DJ-ID"],
)
LOCALE_DATA["th"] = {
    "recognition_lock_takeover_button": "เริ่มที่นี่",
    "labelDjId": "DJ-ID",
}

# MAIN landing (ar, sq gaps)
MAIN["ar"] = {
    "main_social_title": "تابعنا",
    "main_social_intro": "الأخبار والرؤى هنا:",
    "main_feature_auto_body": "VIBESBOX يربط كل الخيوط في الخلفية – من قائمة الأمنيات الذكية إلى التوثيق التلقائي للأمسية.",
    "main_feature_dj_title": "للـ DJs",
    "main_features_title": "للضيوف و DJs والتشغيل السلس",
    "main_philosophy_title": "الفلسفة",
    "main_feature_guest_body": "وصول سريع عبر رمز QR مباشرة في المتصفح. لا حاجة لتثبيت التطبيق. أرسل طلبات الموسيقى بسهولة وبدون عوائق.",
    "main_feature_guest_title": "للضيوف",
    "main_features_accent": "3 مجالات، منصة واحدة",
    "main_feature_dj_body": "إدارة احترافية لجميع طلبات الأغاني عبر التطبيق. تحكم كامل في تدفق الحفلة وتفاعل فوري مع حلبة الرقص.",
    "main_feature_auto_title": "الأتمتة",
    "main_philosophy_body": "VIBESBOX يحسّن التفاعل بين DJ والضيوف – لتكون الحفلة التجربة المشتركة في المركز. <strong>الحفلة ت belong للحظة.</strong>",
    "main_hero_title": "VIBESBOX – الصلة بين DJ والضيف.",
    "main_hero_btn_code": "أدخل رمز الحفلة",
    "main_hero_tagline": "القلب الرقمي لكل حفلة. حديث ومباشر وبدون حواجز.",
    "main_intro_title": "ما الذي تميز VIBESBOX",
}
# Fix Arabic philosophy - typo
MAIN["ar"]["main_philosophy_body"] = "VIBESBOX يحسّن التفاعل بين DJ والضيوف – لتكون الحفلة التجربة المشتركة في المركز. <strong>الحفلة للحظة.</strong>"

MAIN["sq"] = {
    "main_social_title": "Na ndiq",
    "main_social_intro": "Lajme dhe njohuri këtu:",
    "main_feature_auto_body": "VIBESBOX mban gjithçka së bashku në sfond – nga lista inteligjente e dëshirave deri te dokumentimi automatik i mbrëmjes.",
    "main_feature_dj_title": "Për DJ-të",
    "main_features_title": "Për mysafirë, DJ dhe operim të qetë",
    "main_philosophy_title": "Filozofia",
    "main_feature_guest_body": "Qasje e shpejtë me kod QR direkt në shfletues. Nuk nevojitet instalim aplikacioni. Dërgo kërkesa muzikore lehtë dhe pa pengesa.",
    "main_feature_guest_title": "Për mysafirët",
    "main_features_accent": "3 fusha, një platformë",
    "main_feature_dj_body": "Menaxhim profesional i të gjitha kërkesave për këngë përmes aplikacionit. Kontroll i plotë mbi rrjedhën e festës dhe reagim i menjëhershëm ndaj pistës.",
    "main_feature_auto_title": "Automatizimi",
    "main_philosophy_body": "VIBESBOX përmirëson ndërveprimin midis DJ-së dhe mysafirëve – që festa të jetë përvoja e përbashkët në qendër. <strong>Festa i përket momentit.</strong>",
}

# EXTRA locale-specific gaps
EXTRA["cs"] = {
    "audio_format_seconds_only": "{seconds} s",
    "status_running": "AKTIVNÍ",
    "label_role": "Role",
    "party_delete_confirm_anyway": "PŘESTO SMAZAT",
    "admin_role_label": "Role",
    "admin_user_section_data": "Údaje",
}
EXTRA["el"] = {
    "interval_seconds_short": "Δευτ.",
    "audio_format_seconds_only": "{seconds} δευτ.",
    "status_running": "ΕΝΕΡΓΌ",
    "profile_email": "E-mail",
    "paywall_tip_badge": "ΣΥΜΒΟΥΛΉ",
    "live_party": "ΖΩΝΤΑΝΉ ΠΑΡΤΙ",
    "admin_start_view_saved": "Η αρχική προβολή αποθηκεύτηκε!",
}
EXTRA["es"] = {
    "spotify_admin_slider_minutes": "{minutes} min.",
    "update_local_label": "Local",
    "announcement_progress_original": "{label} (original)",
    "dj_home_stats_row_total": "Total:",
    "no": "No",
    "snackbar_error_details": "Error: {error}",
    "error": "Error",
    "party_error": "Error:",
    "error_with_message": "Error: {message}",
    "contact_error_title": "Error",
    "history_error_prefix": "Error:",
    "update_save_error": "Error: {error}",
    "todo_stream_error": "Error: {error}",
    "error_updating": "Error:",
}
EXTRA["fr"] = {
    "interval_seconds_short": "s",
    "spotify_admin_slider_minutes": "{minutes} min.",
    "update_local_label": "Local",
    "announcement_progress_original": "{label} (original)",
    "permanent": "Définitif",
    "dj_wish_tab_rejected": "Ref.",
    "contact_label": "Contact",
    "contact": "Contact",
    "party_minute": "minute",
    "connectionStable": "Stable",
    "announcement_field_message_label": "Message",
    "history_page": "Page",
    "party_type_public": "Publique",
    "label_date": "Date",
    "pre_wishes_pause": "Pause",
    "label_message": "Message",
    "settings_grace_period_minutes": "%1$s minutes",
    "dj_quickstart_h1_notifications": "Notifications",
    "party_public_location_badge": "publique",
    "party_minutes": "minutes",
    "contact_message_label": "Message *",
    "settings_section_notifications": "Notifications",
}
EXTRA["nl"] = {
    "labelDjId": "DJ-ID",
    "interval_seconds_short": "Sec.",
    "audio_format_seconds_only": "{seconds} sec.",
    "status_running": "ACTIEF",
    "permanent": "Vast",
    "contact_label": "Contact",
    "admin_device_platform": "Apparaatplatform",
    "party_pdf_poster_a4": "Poster (A4)",
    "start_label_new": "Start:",
    "party_begin": "Start:",
    "password_strength_medium": "Gemiddeld",
    "later_button": "Later",
    "dj_wish_tab_open": "Openstaand",
    "admin_user_shazam_interval_s": "Shazam-interval (s)",
    "open": "Openstaand",
    "open_songs_label": "Openstaand",
    "was_blocked": "werd",
    "latencyLabel": "Latentie",
    "databaseLabel": "Gegevensbank",
    "period_week_singular": "1 week",
}
EXTRA["it"] = {
    "spotify_admin_slider_minutes": "{minutes} min.",
    "no": "No",
    "login_password_label": "Password",
    "change_password_short": "Password",
}
EXTRA["pl"] = {
    "interval_seconds_short": "Sek.",
    "start_label_new": "Start:",
    "party_begin": "Start:",
    "referral_redeem_action": "Wykorzystaj",
}
EXTRA["pt"] = {
    "spotify_admin_slider_minutes": "{minutes} min.",
    "update_local_label": "Local",
    "announcement_progress_original": "{label} (original)",
    "dj_home_stats_row_total": "Total:",
    "dj_wish_tab_rejected": "Rejeit.",
}
EXTRA["sq"] = {
    "party_pdf_poster_a4": "Cartaz (A4)",
}
EXTRA["tr"] = {
    "admin_device_platform": "Cihaz platformu",
}
EXTRA["vi"] = {
    "profile_email": "E-mail",
    "email": "E-mail:",
    "profile_alternative_email_dialog_email": "E-mail",
    "contact_email_label": "E-mail",
    "pdf_checkbox_email": "E-mail",
}

# Split LOCALE_DATA into blocks
for loc, data in LOCALE_DATA.items():
    if loc == "th":
        RECOGNITION[loc] = data
        continue
    FLOOR[loc] = {k: data[k] for k in FK}
    SOCIAL[loc] = {k: data[k] for k in SK}
    B2B[loc] = {k: data[k] for k in BK}
    RECOGNITION[loc] = {k: data[k] for k in RK}

out = Path(__file__).resolve().parent / "_en_gap_patch_translations.py"
lines = [
    "# Auto-generated by _gen_translations.py",
    "FLOOR = " + repr(FLOOR),
    "SOCIAL = " + repr(SOCIAL),
    "B2B = " + repr(B2B),
    "RECOGNITION = " + repr(RECOGNITION),
    "MAIN = " + repr(MAIN),
    "EXTRA = " + repr(EXTRA),
    "",
]
out.write_text("\n".join(lines), encoding="utf-8")
print(f"Wrote {out}")
