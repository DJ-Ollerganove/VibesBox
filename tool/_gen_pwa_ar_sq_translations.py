#!/usr/bin/env python3
"""Generate PWA translation patch files for Arabic and Albanian."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

PRIVACY_AR = (
    '<div style="margin-bottom: 24px;"><h2 style="font-weight: bold; margin-bottom: 16px;">'
    "سياسة الخصوصية للموقع: vibesbox.app (اعتبارًا من: 28.01.2026)</h2></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "1. المسؤول عن البيانات</h3><p style=\"margin-bottom: 12px;\">"
    "المسؤول عن معالجة البيانات وفقًا للائحة العامة لحماية البيانات (GDPR) هو:</p>"
    '<p style="margin-bottom: 12px;"><strong>VibesBox by Swen Steller</strong><br>'
    "Neefestr. 9<br>09119 Chemnitz<br>ألمانيا<br>"
    'البريد الإلكتروني: <a href="mailto:info@vibesbox.app">info@vibesbox.app</a></p>'
    '<p style="margin-bottom: 12px;">'
    "لم يتم تعيين مسؤول لحماية البيانات حاليًا وفقًا للمتطلبات القانونية.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "2. معلومات عامة</h3><p style=\"margin-bottom: 12px;\">"
    "نحن نأخذ حماية بياناتك الشخصية على محمل الجد. "
    "نعامل بياناتك الشخصية بسرية ووفقًا للوائح حماية البيانات القانونية وسياسة الخصوصية هذه.</p>"
    '<p style="margin-bottom: 12px;">'
    "يمكن استخدام موقعنا عمومًا دون تقديم بيانات شخصية. "
    "عند جمع بيانات شخصية (مثل الاسم أو العنوان أو عناوين البريد الإلكتروني) على صفحاتنا، "
    "يتم ذلك دائمًا على أساس طوعي حيثما أمكن ذلك.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "3. الاستضافة والبنية التحتية</h3><p style=\"margin-bottom: 12px;\">"
    "نستضيف محتوى موقعنا وتطبيقنا لدى المزود التالي:</p>"
    '<p style="margin-bottom: 12px;"><strong>Google Cloud</strong></p>'
    '<p style="margin-bottom: 12px;">'
    "المزود هو Google Ireland Limited، Gordon House، Barrow Street، Dublin 4، أيرلندا.</p>"
    '<p style="margin-bottom: 12px;"><strong>غرض المعالجة:</strong> '
    "توفير واستضافة البنية التحتية التقنية لتطبيقنا وموقعنا.</p>"
    '<p style="margin-bottom: 12px;"><strong>ملفات سجل الخادم:</strong> '
    "عند الوصول إلى الموقع، تجمع Google تلقائيًا البيانات التي ينقلها متصفحك إلينا "
    "(عنوان IP، تاريخ/وقت الوصول، إلخ).</p>"
    '<p style="margin-bottom: 12px;"><strong>الأساس القانوني:</strong> '
    "المادة 6 الفقرة 1 بند f من GDPR.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "4. التواصل</h3><p style=\"margin-bottom: 12px;\">"
    "إذا تواصلت معنا عبر البريد الإلكتروني أو نموذج اتصال، "
    "سيتم تخزين معلوماتك بما في ذلك بيانات الاتصال التي تقدمها "
    "لغرض معالجة استفسارك.</p>"
    '<p style="margin-bottom: 12px;"><strong>الأساس القانوني:</strong> '
    "المادة 6 الفقرة 1 بند b من GDPR.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "5. ملفات تعريف الارتباط (Cookies)</h3><p style=\"margin-bottom: 12px;\">"
    "يستخدم موقعنا فقط ملفات تعريف الارتباط الضرورية تقنيًا.</p>"
    '<p style="margin-bottom: 12px;"><strong>الأساس القانوني:</strong> '
    "المادة 6 الفقرة 1 بند f من GDPR.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    '6. الرابط بتطبيق VibesBox</h3><p style="margin-bottom: 12px;">'
    'يخدم هذا الموقع بشكل أساسي كبوابة معلومات ومرجع لتطبيق "VibesBox". '
    "تسري سياسة الخصوصية المنفصلة للتطبيق، ويمكن الاطلاع عليها داخل التطبيق.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "7. حقوقك كصاحب بيانات</h3><p style=\"margin-bottom: 12px;\">"
    "لديك الحق في الاطلاع والتصحيح والحذف وتقييد المعالجة وقابلية نقل البيانات والاعتراض. "
    "كما لديك الحق في تقديم شكوى إلى السلطة الإشرافية المختصة.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "8. التحديث والتغييرات</h3><p style=\"margin-bottom: 12px;\">"
    "يمكن الوصول إلى النسخة الحالية على هذا الموقع في أي وقت.</p></div>"
)

TERMS_AR = (
    "<h2>1. نطاق التطبيق</h2><p>"
    'تحكم هذه الشروط والأحكام العامة استخدام موقع vibesbox.app (يشار إليه فيما يلي بـ "الموقع"). '
    "مشغل الموقع هو:</p>"
    '<p><strong>Swen Steller</strong>، Neefestr. 9، 09119 Chemnitz، '
    '<a href="mailto:info@vibesbox.app">info@vibesbox.app</a> (يشار إليه فيما يلي بـ "المشغل").</p>'
    "<p>باستخدام الموقع، يوافق الضيف على هذه الشروط.</p>"
    "<h2>2. وصف الخدمات والاستخدام</h2><p>"
    "يتيح الموقع للضيوف إرسال طلبات الأغاني والتحيات إلى DJ المعني أثناء الفعاليات. "
    "يمكن الاستخدام دون تسجيل أو إنشاء حساب مستخدم عن طريق إدخال رمز الفعالية أو الوصول عبر رمز QR. "
    "لا يوجد حق في تشغيل طلب الأغنية فعليًا.</p>"
    "<h2>3. التزامات الضيوف</h2><p>"
    "يتعهد الضيوف بعدم إرسال أي محتوى (طلبات/تحيات) مسيء أو عنصري أو إباحي أو غير قانوني "
    "أو ينتهك حقوق الغير. لا يقوم المشغل بفحص المحتوى المرسل مسبقًا. "
    "تقع المسؤولية على المستخدم وحده.</p>"
    "<h2>4. تحديد المسؤولية</h2><p>"
    "لا يتحمل المشغل المسؤولية عن التنفيذ الفعلي لطلبات الأغاني من قبل DJ "
    "أو عن الانقطاعات التقنية للموقع. "
    "توجد مسؤولية عن الأضرار فقط في حالات القصد أو الإهمال الجسيم من جانب المشغل.</p>"
    "<h2>5. أحكام ختامية</h2><p>"
    "يسري القانون الألماني. "
    "مكان الاختصاص القضائي لجميع المسائل التقنية المتعلقة بالموقع هو مقر المشغل. "
    "إذا كان أي حكم من هذه الشروط باطلًا، تظل صحة الأحكام المتبقية دون تأثر.</p>"
)

PRIVACY_SQ = (
    '<div style="margin-bottom: 24px;"><h2 style="font-weight: bold; margin-bottom: 16px;">'
    "Politika e privatësisë për faqen: vibesbox.app (Nga data: 28.01.2026)</h2></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "1. Përgjegjësi për të dhënat</h3><p style=\"margin-bottom: 12px;\">"
    "Përgjegjës për përpunimin e të dhënave sipas Rregullores së Përgjithshme "
    " për Mbrojtjen e të Dhënave (GDPR) është:</p>"
    '<p style="margin-bottom: 12px;"><strong>VibesBox by Swen Steller</strong><br>'
    "Neefestr. 9<br>09119 Chemnitz<br>Gjermani<br>"
    'Email: <a href="mailto:info@vibesbox.app">info@vibesbox.app</a></p>'
    '<p style="margin-bottom: 12px;">'
    "Një zyrtar për mbrojtjen e të dhënave nuk është emëruar aktualisht sipas kërkesave ligjore.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "2. Informacion i përgjithshëm</h3><p style=\"margin-bottom: 12px;\">"
    "Ne e marrim shumë seriozisht mbrojtjen e të dhënave tuaja personale. "
    "I trajtojmë të dhënat tuaja personale me konfidencialitet dhe në përputhje "
    "me rregulloret ligjore të mbrojtjes së të dhënave dhe këtë politikë privatësie.</p>"
    '<p style="margin-bottom: 12px;">'
    "Në përgjithësi është e mundur të përdoret faqja jonë pa dhënë të dhëna personale. "
    "Kur mblidhen të dhëna personale (si emri, adresa ose adresat e emailit) në faqet tona, "
    "kjo bëhet gjithmonë vullnetarisht, kur është e mundur.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "3. Hostimi dhe infrastruktura</h3><p style=\"margin-bottom: 12px;\">"
    "Ne hostojmë përmbajtjen e faqes dhe aplikacionit tonë te ofruesi i mëposhtëm:</p>"
    '<p style="margin-bottom: 12px;"><strong>Google Cloud</strong></p>'
    '<p style="margin-bottom: 12px;">'
    "Ofruesi është Google Ireland Limited, Gordon House, Barrow Street, Dublin 4, Irlandë.</p>"
    '<p style="margin-bottom: 12px;"><strong>Qëllimi i përpunimit:</strong> '
    "Ofrimi dhe hostimi i infrastrukturës teknike të aplikacionit dhe faqes sonë.</p>"
    '<p style="margin-bottom: 12px;"><strong>Skedarët e regjistrit të serverit:</strong> '
    "Kur aksesoni faqen, Google mbledh automatikisht të dhënat që shfletuesi juaj na transmeton "
    "(adresa IP, data/ora e aksesit, etj.).</p>"
    '<p style="margin-bottom: 12px;"><strong>Baza ligjore:</strong> '
    "Neni 6 paragrafi 1 lit. f GDPR.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "4. Kontakti</h3><p style=\"margin-bottom: 12px;\">"
    "Nëse na kontaktoni me email ose përmes një formulari kontakti, "
    "informacioni juaj, duke përfshirë të dhënat e kontaktit që jepni aty, "
    "do të ruhet për qëllimin e përpunimit të kërkesës suaj.</p>"
    '<p style="margin-bottom: 12px;"><strong>Baza ligjore:</strong> '
    "Neni 6 paragrafi 1 lit. b GDPR.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "5. Cookies</h3><p style=\"margin-bottom: 12px;\">"
    "Faqja jonë përdor vetëm cookies që janë teknologjikisht të nevojshme.</p>"
    '<p style="margin-bottom: 12px;"><strong>Baza ligjore:</strong> '
    "Neni 6 paragrafi 1 lit. f GDPR.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    '6. Lidhja me aplikacionin VibesBox</h3><p style="margin-bottom: 12px;">'
    'Kjo faqe shërben kryesisht si portal informacioni dhe referencë për aplikacionin "VibesBox". '
    "Zbatohet politika e veçantë e privatësisë së aplikacionit, e cila mund të shihet brenda aplikacionit.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "7. Të drejtat tuaja si subjekt i të dhënave</h3><p style=\"margin-bottom: 12px;\">"
    "Keni të drejtë për informacion, korrigjim, fshirje, kufizim të përpunimit, "
    "portabilitet të të dhënave dhe kundërshtim. "
    "Gjithashtu keni të drejtë të paraqisni ankesë te autoriteti mbikëqyrës kompetent.</p></div>"
    '<div style="margin-bottom: 24px;"><h3 style="font-weight: bold; margin-bottom: 12px;">'
    "8. Aktualiteti dhe ndryshimet</h3><p style=\"margin-bottom: 12px;\">"
    "Versioni aktual mund të aksesohet në këtë faqe në çdo kohë.</p></div>"
)

TERMS_SQ = (
    "<h2>1. Fusha e zbatimit</h2><p>"
    'Këto Kushte të Përgjithshme rregullojnë përdorimin e faqes vibesbox.app (në vazhdim "Faqja"). '
    "Operatori i Faqes është:</p>"
    '<p><strong>Swen Steller</strong>, Neefestr. 9, 09119 Chemnitz, '
    '<a href="mailto:info@vibesbox.app">info@vibesbox.app</a> (në vazhdim "Operatori").</p>'
    "<p>Duke përdorur Faqen, mysafiri pranon këto kushte.</p>"
    "<h2>2. Përshkrimi i shërbimeve dhe përdorimi</h2><p>"
    "Faqja u mundëson mysafirëve të dërgojnë kërkesa këngësh dhe urime te DJ-i përkatës gjatë eventeve. "
    "Përdorimi është i mundur pa regjistrim ose krijim llogarie duke futur një kod eventi ose akses me kod QR. "
    "Nuk ka të drejtë për luajtjen aktuale të një kërkese kënge.</p>"
    "<h2>3. Detyrimet e mysafirëve</h2><p>"
    "Mysafirët angazhohen të mos dërgojnë përmbajtje (kërkesa/urime) fyese, raciste, pornografike ose të paligjshme, "
    "ose që cenon të drejtat e palëve të treta. Operatori nuk kontrollon paraprakisht përmbajtjen e dërguar. "
    "Përgjegjësia bie vetëm mbi përdoruesin.</p>"
    "<h2>4. Kufizimi i përgjegjësisë</h2><p>"
    "Operatori nuk mban përgjegjësi për zbatimin aktual të kërkesave të këngëve nga DJ-i "
    "ose për ndërprerjet teknike të Faqes. "
    "Përgjegjësia për dëme ekziston vetëm në rastet e qëllimit ose pakujdesisë së rëndë nga ana e operatorit.</p>"
    "<h2>5. Dispozitat përfundimtare</h2><p>"
    "Zbatohet ligji gjerman. "
    "Vendi i juridiksionit për të gjitha çështjet teknike që lidhen me Faqen është vendi i biznesit të operatorit. "
    "Nëse ndonjë dispozitë e këtyre Kushteve është e pavlefshme, vlefshmëria e dispozitave të mbetura mbetet e paprekur.</p>"
)

AR = {
  "about_important": "مهم:",
  "about_important_text": "طلباتك الموسيقية مرحب بها! يسعدني تشغيلها ما دامت متوفرة، تنشّط حلبة الرقص، ومتوافقة مع إرشادات المضيفين. شكرًا لثقتك بالمزيج المناسب!",
  "about_step1_text": "اكتب أغنيتك مباشرة هنا.",
  "about_step1_title": "🎵 إرسال طلب",
  "about_step2_text": "استمتع بجميع المزايا مع ملفك الشخصي – مجانًا بالطبع. التسجيل متاح فقط عبر تطبيق VibesBox، الذي سيكون متاحًا قريبًا.",
  "about_step2_title": "👤 سجّل وكن جزءًا من التجربة",
  "about_step3_text": "عدّل طلباتك لاحقًا واحصل على إشعار فوري عندما تكون أغنيتك التالية.",
  "about_step3_title": "🔔 ابقَ على اطلاع",
  "about_subtitle": "طلبك مهم! مع VibesBox ترسل أغانيك المفضلة مباشرة إلى شاشة DJ – بدون تزاحم عند المنصة أو أوراق. أرسل تحية مع أغنيتك واستمتع بالحفلة. نتمنى لك وقتًا رائعًا!",
  "about_title": "VibesBox – خطك المباشر إلى DJ",
  "back_button": "← رجوع",
  "branding_text": "هذا هو",
  "button_close": "إغلاق",
  "button_imprint": "البيانات القانونية",
  "button_privacy": "الخصوصية",
  "button_sending": "جارٍ الإرسال...",
  "button_terms": "الشروط",
  "checking_limit": "جارٍ التحقق من الحد...",
  "contact_cooldown_30": "يرجى الانتظار 30 ثانية بين الرسائل.",
  "contact_error_email_or_phone_required": "يرجى إدخال البريد الإلكتروني أو الهاتف.",
  "contact_error_invalid_email": "يرجى إدخال عنوان بريد إلكتروني صالح.",
  "contact_error_message_required": "يرجى إدخال رسالة.",
  "contact_error_name_required": "يرجى إدخال اسمك.",
  "contact_error_recaptcha": "يرجى التأكيد أنك لست روبوتًا (reCAPTCHA).",
  "contact_error_recaptcha_token_missing": "رمز reCAPTCHA مفقود. يرجى إعادة تحميل الصفحة والمحاولة مرة أخرى.",
  "contact_error_recaptcha_validation_failed": "فشل التحقق من reCAPTCHA. يرجى المحاولة مرة أخرى.",
  "contact_subtitle": "أرسل لي رسالة",
  "contact_title": "تواصل",
  "cookie_accept_button": "قبول",
  "cookie_notice_text": "يستخدم هذا الموقع ملفات تعريف الارتباط (Cookies) لتوفير الوظائف الأساسية. ملف تعريف الارتباط المعني ضروري تقنيًا. أي بيانات شخصية في ملفات تعريف الارتباط تُخزَّن محليًا ومشفرة فقط. إذا كنت لا توافق على استخدام ملفات تعريف الارتباط، يرجى مغادرة هذا الموقع.",
  "delete_account_email_html": '<p>بدلاً من ذلك، يمكنك طلب حذف الحساب عبر البريد الإلكتروني. يرجى إرسال رسالة من عنوان البريد الإلكتروني المسجل لدينا إلى: <a href="mailto:info@vibesbox.app">info@vibesbox.app</a>.</p>',
  "delete_account_heading": "حذف الحساب",
  "delete_account_intro_html": '<p>يمكنك حذف حساب VibesBox في أي وقت داخل التطبيق من &quot;الملف الشخصي&quot; → &quot;حذف الحساب&quot;. سيتم حذف جميع بياناتك الشخصية والحفلات والإعدادات فورًا ولا يمكن استردادها.</p>',
  "delete_account_meta_description": "كيفية حذف حساب VibesBox: في التطبيق من الملف الشخصي، أو عبر البريد الإلكتروني إلى info@vibesbox.app.",
  "delete_account_meta_title": "حذف الحساب",
  "delete_account_nav_home": "الرئيسية",
  "delete_account_note": "ستتم معالجة طلبك خلال 48 ساعة. ستتلقى تأكيدًا عند اكتمال الحذف.",
  "dj_links_connect": "تواصل مع {djName}.",
  "error_greeting_max_200": "يجب ألا تتجاوز التحية 200 حرفًا.",
  "error_load_failed_message": "يرجى إعادة تحميل الصفحة أو إدخال رمز الحفلة مرة أخرى.",
  "error_load_failed_title": "تعذر تحميل البيانات",
  "error_saving_wish": "خطأ في حفظ الطلب. يرجى المحاولة مرة أخرى.",
  "error_submitting": "خطأ أثناء الإرسال. يرجى المحاولة مرة أخرى.",
  "error_wish_name_required": "يرجى إدخال اسمك.",
  "error_wish_title_artist_required": "يرجى إدخال العنوان والفنان معًا.",
  "go_to_code_entry": "الانتقال إلى إدخال الرمز",
  "greeting_placeholder": "بحد أقصى 160 حرفًا",
  "history_days_ago": "منذ ${diffDays} يومًا",
  "history_empty": "لا توجد أغاني في السجل بعد",
  "history_error": "خطأ في تحميل السجل",
  "history_hours_ago": "منذ ${diffHours} ساعة",
  "history_just_now": "الآن",
  "history_loading": "جارٍ تحميل السجل...",
  "history_minutes_ago": "منذ ${diffMins} دقيقة",
  "history_pagination_next": "التالي",
  "history_pagination_prev": "السابق",
  "history_subtitle": "هنا يمكنك رؤية جميع الأغاني التي تم تشغيلها بالفعل.",
  "imprint_title": "البيانات القانونية",
  "label_artist": "الفنان *",
  "label_artist_placeholder": "أدخل اسم الفنان",
  "label_contact_email_placeholder": "عنوان البريد الإلكتروني",
  "label_contact_message": "الرسالة *",
  "label_contact_message_placeholder": "رسالتك",
  "label_contact_name": "الاسم الأول والأخير *",
  "label_contact_name_placeholder": "الاسم الأول والأخير",
  "label_contact_phone": "الهاتف",
  "label_contact_phone_placeholder": "رقم الهاتف",
  "label_contact_subject": "الموضوع",
  "label_contact_subject_placeholder": "الموضوع (اختياري)",
  "label_greeting": "تحية (اختياري)",
  "label_name_placeholder": "اسمك",
  "label_phone": "الهاتف",
  "label_title": "العنوان *",
  "label_title_placeholder": "أدخل العنوان",
  "legal_language_notice": "يتم توفير البيانات القانونية وسياسة الخصوصية باللغة الألمانية فقط، وفقًا للمتطلبات القانونية في ألمانيا. في حال وجود أي تعارض، تسود النسخة الألمانية.",
  "limit_already_used": "لقد أرسلت بالفعل {limit} طلبات هذه الساعة.",
  "limit_reached_message": "لقد وصلت إلى حدك بالساعة. عد لاحقًا! 🎉",
  "loading_connection_checking": "جارٍ التحقق من الاتصال...",
  "loading_data": "جارٍ تحميل البيانات...",
  "loading_party_connection": "جارٍ الاتصال بالحفلة...",
  "logout_confirm_message": "هل تريد حقًا مغادرة الحفلة؟",
  "logout_confirm_title": "مغادرة الحفلة؟",
  "logout_confirm_yes": "نعم",
  "logout_party": "مغادرة الحفلة",
  "main_code_error_8_digits": "يرجى إدخال 8 أرقام بالضبط.",
  "main_code_error_invalid": "رمز الحفلة هذا غير موجود.",
  "main_code_error_rate_limit": "محاولات فاشلة كثيرة جدًا. يرجى المحاولة مرة أخرى خلال 30 ثانية.",
  "main_code_error_reload": "يرجى إعادة تحميل الصفحة والمحاولة مرة أخرى.",
  "main_code_error_timeout": "الاتصال بطيء جدًا أو انقطع. يرجى المحاولة مرة أخرى.",
  "main_contact_btn_sending": "جارٍ الإرسال...",
  "main_contact_btn_submit": "إرسال الرسالة",
  "main_contact_error_email_too_long": "البريد الإلكتروني طويل جدًا (بحد أقصى 200 حرف).",
  "main_contact_error_message_too_long": "يجب ألا تتجاوز الرسالة 1500 حرفًا.",
  "main_contact_error_phone_too_long": "رقم الهاتف طويل جدًا (بحد أقصى 50 حرفًا).",
  "main_contact_error_subject_too_long": "الموضوع طويل جدًا (بحد أقصى 100 حرف).",
  "main_contact_hint_contact_required": "يرجى تقديم البريد الإلكتروني أو الهاتف على الأقل (مطلوب).",
  "main_contact_intro": "أسئلة أو ملاحظات؟ اكتب إلينا. يرجى تقديم البريد الإلكتروني أو الهاتف على الأقل.",
  "main_contact_label_email": "البريد الإلكتروني",
  "main_contact_label_message": "الرسالة *",
  "main_contact_label_name": "الاسم الأول والأخير *",
  "main_contact_label_phone": "الهاتف",
  "main_contact_label_subject": "الموضوع",
  "main_contact_placeholder_email": "عنوان البريد الإلكتروني",
  "main_contact_placeholder_message": "رسالتك",
  "main_contact_placeholder_name": "الاسم الأول والأخير",
  "main_contact_placeholder_phone": "رقم الهاتف",
  "main_contact_placeholder_subject": "الموضوع (اختياري)",
  "main_contact_success_message": "تم إرسال رسالتك بنجاح.",
  "main_contact_success_title": "شكرًا لك!",
  "main_contact_title": "تواصل",
  "main_footer_app": "إلى التطبيق",
  "main_footer_imprint": "البيانات القانونية",
  "main_footer_privacy": "الخصوصية",
  "main_footer_terms": "الشروط",
  "main_nav_delete_account": "حذف الحساب",
  "main_nav_uber": "حول",
  "main_overlay_btn_checking": "جارٍ التحقق…",
  "main_overlay_btn_close": "إغلاق",
  "main_overlay_code_placeholder": "مثال: 12345678",
  "main_overlay_code_title": "أدخل رمز الحفلة",
  "main_party_not_started_intro": "لم تبدأ هذه الحفلة بعد.",
  "main_party_start_in": "تبدأ خلال: {countdown}",
  "main_party_starts_at": "تبدأ في {time} (التوقيت المحلي)",
  "main_visual_placeholder": "عنصر نائب للصورة",
  "message_sent_message": "شكرًا لرسالتك. سأرد عليك في أقرب وقت ممكن.",
  "message_sent_title": "تم إرسال الرسالة بنجاح!",
  "nav_about": "حول VibesBox",
  "nav_contact": "تواصل",
  "no_active_party_msg": "لم يتم العثور على حفلة نشطة. يرجى إدخال رمز لإلغاء قفل المحتوى.",
  "no_email_provided": "لم يتم تقديم بريد إلكتروني",
  "no_social_links_provided": "لم يتم تقديم روابط وسائل التواصل",
  "no_socials_available": "لا تتوفر روابط وسائل التواصل",
  "party_code_ambiguous": "عدة حفلات تطابق هذا الرمز. يرجى مسح رمز QR أو سؤال DJ.",
  "party_code_check": "تحقق",
  "party_code_enter": "أدخل رمز الحفلة:",
  "party_code_length": "يجب أن يتكون رمز الحفلة من 8 أرقام بالضبط.",
  "party_code_required": "يرجى إدخال رمز حفلة.",
  "party_finished_msg": "شكرًا لطلباتك الموسيقية. نأمل أن تكون قد قضيت وقتًا رائعًا!",
  "party_finished_title": "انتهت الحفلة!",
  "party_local_time": "التوقيت المحلي",
  "party_not_started": "لم تبدأ هذه الحفلة بعد.",
  "party_paused_msg": "استراحة قصيرة في البرنامج: سيعود VibesBox قريبًا لطلباتك الموسيقية!",
  "party_registered_future": "أنت مسجل. تبدأ الحفلة خلال",
  "party_starts_now": "تبدأ الآن",
  "party_starts_soon": "الحفلة تبدأ قريبًا.",
  "party_unknown": "هذه الحفلة غير معروفة. يرجى التحقق من إدخالك.",
  "pre_party_days": "أيام",
  "pre_party_hours": "ساعات",
  "pre_party_minutes": "دقائق",
  "pre_party_seconds": "ثوانٍ",
  "pre_party_title": "الحفلة تبدأ قريبًا!",
  "pre_party_title_with_name": "{name} تبدأ قريبًا!",
  "privacy_html_content": PRIVACY_AR,
  "required_field": "* حقل مطلوب",
  "required_field_info": "الحقول المميزة بـ * مطلوبة",
  "send_another_wish": "إرسال طلب آخر",
  "send_message": "إرسال رسالة",
  "settings_duplicate_threshold_label": "عتبة التكرار (%)",
  "settings_duplicate_title": "إعدادات التكرار",
  "settings_ignored_keywords_hint": "مفصولة بفواصل. يتم تجاهل هذه المصطلحات عند مقارنة العناوين (مثل \"Club Mix\"، \"Remix\").",
  "settings_ignored_keywords_label": "مصطلحات متجاهلة (لفحص التكرار)",
  "settings_menu_title": "الإعدادات",
  "settings_menu_tooltip": "عتبة التكرار والمصطلحات المتجاهلة",
  "settings_save_btn": "حفظ",
  "settings_save_error": "فشل الحفظ.",
  "social_media_subtitle": "تابعني على قنوات التواصل الاجتماعي",
  "social_pro_only_message": "هذا القسم مرئي فقط لـ DJs من VibesBox Pro.",
  "tap_for_suggestions": "اضغط للاقتراحات",
  "terms_html_content": TERMS_AR,
  "terms_placeholder": "المحتوى قريبًا.",
  "terms_title": "الشروط",
  "testphase_warning": "مرحلة تجريبية: إذا واجهت صعوبات، يرجى التواصل مع DJ",
  "time_day": "يوم",
  "time_days": "أيام",
  "time_hour": "ساعة",
  "time_hours": "ساعات",
  "time_minute": "دقيقة",
  "time_minutes": "دقائق",
  "time_week": "أسبوع",
  "time_weeks": "أسابيع",
  "title_main": "VibesBox – تجربة فعالية تفاعلية",
  "title_vb_join": "VibesBox – انضم إلى الحفلة",
  "user_banned_title": "تم حظر الوصول",
  "vibesbox_subtitle": "تريد أغنية؟ 🎧 أرسلها! أحاول تشغيل أكبر عدد ممكن من الطلبات. لنجاح الحفلة، أُرشّح حسب التوفر وقابلية الرقص وإرشادات المضيف. شكرًا لتفهمك!",
  "wish_limit_default": "2 من 2 طلبات متاحة هذه الساعة",
  "wish_limit_hour_reached": "لقد أرسلت بالفعل {limit} طلبات هذه الساعة. يرجى الانتظار حتى الساعة الكاملة التالية.",
  "wish_limit_loading": "جارٍ تحميل معلومات الحد...",
  "wish_limit_none": "يمكن إرسال طلب آخر في الساعة الكاملة التالية.",
  "wish_limit_plural": "{remaining} من {limit} طلبات متاحة لكل ساعة كاملة",
  "wish_limit_reached": "تم الوصول إلى الحد",
  "wish_limit_singular": "1 من {limit} طلب متاح لكل ساعة كاملة",
  "wish_limit_wait": "يمكنك إرسال الطلبات مرة أخرى في الساعة الكاملة التالية.",
  "saved_tracks_added_snackbar": "تم حفظ الأغنية في قائمتك.",
  "saved_tracks_col_title": "العنوان",
  "saved_tracks_col_artist": "الفنان",
  "saved_tracks_col_party": "اسم الحفلة",
  "saved_tracks_col_wishers": "الطلبات",
}

SQ = {
  "about_important": "E rëndësishme:",
  "about_important_text": "Kërkesat tuaja muzikore janë të mirëpritura! Me kënaqësi i luaj, për sa kohë janë të disponueshme, nxisin pistën e kërcimit dhe janë në përputhje me udhëzimet e hostëve. Faleminderit që i besoni mix-it të duhur!",
  "about_step1_text": "Shkruani këngën tuaj direkt këtu.",
  "about_step1_title": "🎵 Dërgo kërkesë",
  "about_step2_text": "Shijoni të gjitha përfitimet me profilin tuaj personal – plotësisht falas, sigurisht. Regjistrimi është i mundur vetëm përmes aplikacionit VibesBox, i cili do të jetë së shpejti i disponueshëm.",
  "about_step2_title": "👤 Regjistrohu dhe bëhu pjesë",
  "about_step3_text": "Redaktoni kërkesat tuaja më vonë dhe merrni njoftim push kur kënga juaj është radhës.",
  "about_step3_title": "🔔 Qëndro i përditësuar",
  "about_subtitle": "Kërkesa juaj ka rëndësi! Me VibesBox dërgoni këngët tuaja të preferuara direkt në ekranin e DJ-së – pa shtyrje te kabina apo letra. Dërgoni një urim me këngën tuaj dhe shijoni festën. Kalofshi mirë!",
  "auth_reset_password_confirm": "Konfirmo fjalëkalimin",
  "auth_reset_password_hint": "Të paktën 6 karaktere.",
  "auth_reset_password_new": "Fjalëkalim i ri",
  "auth_reset_password_submit": "Vendos fjalëkalimin",
  "auth_verify_error": "Diçka shkoi keq. Ju lutemi kërkoni një lidhje të re.",
  "auth_verify_invalid_link": "Lidhje e pavlefshme ose e skaduar.",
  "auth_verify_processing": "Duke përpunuar…",
  "auth_verify_success_email": "Adresa juaj e emailit u verifikua.",
  "auth_verify_success_password": "Fjalëkalimi juaj u ndryshua me sukses.",
  "auth_verify_title": "Konfirmo llogarinë",
  "button_close": "Mbyll",
  "button_sending": "Duke dërguar...",
  "checking_limit": "Duke kontrolluar limitin...",
  "contact_cooldown_30": "Ju lutemi prisni 30 sekonda midis mesazheve.",
  "contact_error_email_or_phone_required": "Ju lutemi jepni email ose telefon.",
  "contact_error_invalid_email": "Ju lutemi shkruani një adresë emaili të vlefshme.",
  "contact_error_message_required": "Ju lutemi shkruani një mesazh.",
  "contact_error_name_required": "Ju lutemi shkruani emrin tuaj.",
  "contact_error_recaptcha": "Ju lutemi konfirmoni që nuk jeni robot (reCAPTCHA).",
  "contact_error_recaptcha_token_missing": "Mungon tokeni reCAPTCHA. Ju lutemi ringarkoni faqen dhe provoni përsëri.",
  "contact_error_recaptcha_validation_failed": "Verifikimi reCAPTCHA dështoi. Ju lutemi provoni përsëri.",
  "cookie_notice_text": "Kjo faqe përdor cookies për të ofruar funksione thelbësore. Cookie përkatëse është teknologjikisht e nevojshme. Çdo të dhënë personale në cookies ruhet vetëm lokalisht dhe të enkriptuara. Nëse nuk pranoni përdorimin e cookies, ju lutemi largohuni nga kjo faqe.",
  "delete_account_email_html": '<p>Alternativisht, mund të kërkoni fshirjen e llogarisë me email. Ju lutemi dërgoni një mesazh nga adresa e emailit të regjistruar tek ne në: <a href="mailto:info@vibesbox.app">info@vibesbox.app</a>.</p>',
  "delete_account_heading": "Fshi llogarinë",
  "delete_account_intro_html": '<p>Mund të fshini llogarinë tuaj VibesBox në çdo kohë në aplikacion te &quot;Profili&quot; → &quot;Fshi llogarinë&quot;. Të gjitha të dhënat tuaja personale, festat dhe cilësimet do të hiqen menjëherë dhe nuk mund të rikuperohen.</p>',
  "delete_account_meta_description": "Si të fshini llogarinë tuaj VibesBox: në aplikacion te Profili, ose me email në info@vibesbox.app.",
  "delete_account_meta_title": "Fshi llogarinë",
  "delete_account_nav_home": "Kryefaqja",
  "delete_account_note": "Kërkesa juaj do të përpunohet brenda 48 orëve. Do të merrni një konfirmim pasi fshirja të përfundojë.",
  "dj_links_connect": "Lidhu me {djName}.",
  "error_greeting_max_200": "Urimit duhet t'i përkasin jo më shumë se 200 karaktere.",
  "error_saving_wish": "Gabim gjatë ruajtjes së kërkesës. Ju lutemi provoni përsëri.",
  "error_submitting": "Gabim gjatë dërgimit. Ju lutemi provoni përsëri.",
  "error_wish_name_required": "Ju lutemi shkruani emrin tuaj.",
  "error_wish_title_artist_required": "Ju lutemi shkruani si titullin ashtu edhe artistin.",
  "error_wishbox_inactive": "Kërkesat muzikore nuk janë aktive aktualisht. Ju lutemi provoni përsëri më vonë.",
  "label_contact_email_placeholder": "Adresa e emailit",
  "label_contact_message": "Mesazhi *",
  "label_contact_message_placeholder": "Mesazhi juaj",
  "label_contact_name": "Emri dhe mbiemri *",
  "label_contact_name_placeholder": "Emri dhe mbiemri",
  "label_contact_phone": "Telefoni",
  "label_contact_phone_placeholder": "Numri i telefonit",
  "label_contact_subject": "Subjekti",
  "label_contact_subject_placeholder": "Subjekti (opsional)",
  "label_phone": "Telefoni",
  "limit_already_used": "Këtë orë keni dërguar tashmë {limit} kërkesa.",
  "limit_reached_message": "Keni arritur limitin tuaj për orë. Kthehuni më vonë! 🎉",
  "main_code_error_8_digits": "Ju lutemi shkruani saktësisht 8 shifra.",
  "main_code_error_rate_limit": "Shumë përpjekje të dështuara. Ju lutemi provoni përsëri pas 30 sekondash.",
  "main_code_error_reload": "Ju lutemi ringarkoni faqen dhe provoni përsëri.",
  "main_code_error_timeout": "Lidhja shumë e ngadaltë ose u ndërpre. Ju lutemi provoni përsëri.",
  "main_contact_btn_sending": "Duke dërguar...",
  "main_contact_btn_submit": "Dërgo mesazh",
  "main_contact_error_email_too_long": "Emaili është shumë i gjatë (maks. 200 karaktere).",
  "main_contact_error_message_too_long": "Mesazhi nuk mund të kalojë 1500 karaktere.",
  "main_contact_error_phone_too_long": "Telefoni është shumë i gjatë (maks. 50 karaktere).",
  "main_contact_error_subject_too_long": "Subjekti është shumë i gjatë (maks. 100 karaktere).",
  "main_contact_hint_contact_required": "Ju lutemi jepni të paktën email ose telefon (e detyrueshme).",
  "main_contact_intro": "Pyetje ose feedback? Shkruani neve. Ju lutemi jepni të paktën email ose telefon.",
  "main_contact_label_email": "E-mail",
  "main_contact_label_message": "Mesazhi *",
  "main_contact_label_name": "Emri dhe mbiemri *",
  "main_contact_label_phone": "Telefoni",
  "main_contact_label_subject": "Subjekti",
  "main_contact_placeholder_email": "Adresa e emailit",
  "main_contact_placeholder_message": "Mesazhi juaj",
  "main_contact_placeholder_name": "Emri dhe mbiemri",
  "main_contact_placeholder_phone": "Numri i telefonit",
  "main_contact_placeholder_subject": "Subjekti (opsional)",
  "main_contact_success_message": "Mesazhi juaj u dërgua me sukses.",
  "main_contact_success_title": "Faleminderit!",
  "main_contact_title": "Kontakt",
  "main_footer_app": "Te aplikacioni",
  "main_footer_imprint": "Informacion ligjor",
  "main_footer_privacy": "Privatësia",
  "main_hero_btn_party": "Shko te festa",
  "main_nav_delete_account": "Fshi llogarinë",
  "main_nav_uber": "RRETH",
  "main_overlay_btn_checking": "Duke kontrolluar…",
  "main_overlay_btn_close": "Mbyll",
  "main_overlay_btn_submit": "Te kërkesat muzikore",
  "main_overlay_code_placeholder": "p.sh. 12345678",
  "main_party_not_started_intro": "Kjo festë ende nuk ka filluar.",
  "main_party_start_in": "Fillon pas: {countdown}",
  "main_party_starts_at": "Fillon në {time} (ora lokale)",
  "main_visual_placeholder": "Placeholder i imazhit",
  "message_sent_message": "Faleminderit për mesazhin tuaj. Do t'ju përgjigjem sa më shpejt të jetë e mundur.",
  "message_sent_title": "Mesazhi u dërgua me sukses!",
  "no_email_provided": "Nuk u dha email",
  "no_social_links_provided": "Nuk u dhanë lidhje të rrjeteve sociale",
  "no_socials_available": "Nuk ka lidhje të rrjeteve sociale",
  "party_code_ambiguous": "Disa festa përputhen me këtë kod. Ju lutemi skanoni kodin QR ose pyesni DJ-në.",
  "party_local_time": "Ora lokale",
  "party_not_started": "Kjo festë ende nuk ka filluar.",
  "party_registered_future": "Jeni regjistruar. Festa fillon pas",
  "party_starts_now": "Fillon tani",
  "party_starts_soon": "Festa fillon së shpejti.",
  "pre_party_days": "Ditë",
  "pre_party_hours": "Orë",
  "pre_party_minutes": "Minuta",
  "pre_party_seconds": "Sekonda",
  "pre_party_subtitle": "Kërkesat muzikore do të hapen automatikisht",
  "pre_party_title": "Festa fillon së shpejti!",
  "pre_party_title_with_name": "{name} fillon së shpejti!",
  "privacy_html_content": PRIVACY_SQ,
  "settings_duplicate_intro": "Këto vlera kontrollojnë zbulimin e dublikatave për kërkesat e këngëve. Ruhen te party_settings/current.",
  "settings_duplicate_threshold_label": "Pragu i dublikatave (%)",
  "settings_duplicate_title": "Cilësimet e dublikatave",
  "settings_ignored_keywords_hint": "Të ndara me presje. Këto terma injorohen kur krahasohen titujt (p.sh. \"Club Mix\", \"Remix\").",
  "settings_ignored_keywords_label": "Terma të injoruar (për kontrollin e dublikatave)",
  "settings_menu_title": "Cilësimet",
  "settings_menu_tooltip": "Pragu i dublikatave dhe termat e injoruar",
  "settings_save_error": "Ruajtja dështoi.",
  "social_media_dj_fallback_name": "DJ-në",
  "social_media_dj_no_links": "Fatkeqësisht, {djName} nuk ka shtuar ende asnjë lidhje të rrjeteve sociale.",
  "social_pro_only_message": "Ky seksion është i dukshëm vetëm për DJ-të VibesBox Pro.",
  "terms_html_content": TERMS_SQ,
  "terms_placeholder": "Përmbajtja do të ndjekë.",
  "testphase_warning": "Faza testuese: Nëse keni vështirësi, ju lutemi kontaktoni DJ-në",
  "time_day": "ditë",
  "time_days": "ditë",
  "time_hour": "orë",
  "time_hours": "orë",
  "time_minute": "minutë",
  "time_minutes": "minuta",
  "time_week": "javë",
  "time_weeks": "javë",
  "title_main": "VibesBox – Përvojë interaktive eventi",
  "title_vb_join": "VibesBox – Bashkohu me festën",
  "wish_limit_hour_reached": "Këtë orë keni dërguar tashmë {limit} kërkesa. Ju lutemi prisni deri në orën e plotë të ardhshme.",
  "wish_limit_reached": "Limiti u arrit",
  "saved_tracks_added_snackbar": "Kënga u ruajt në listën tuaj.",
  "saved_tracks_col_title": "Titulli",
  "saved_tracks_col_artist": "Artisti",
  "saved_tracks_col_party": "Emri i festës",
  "saved_tracks_col_wishers": "Kërkesat",
}


def main():
    ar_need = json.loads(Path("/tmp/pwa_ar_need.json").read_text(encoding="utf-8"))
    sq_need = json.loads(Path("/tmp/pwa_sq_need.json").read_text(encoding="utf-8"))

    ar_out = ROOT / "tool" / "_pwa_ar_translations.json"
    sq_out = ROOT / "tool" / "_pwa_sq_translations.json"

    ar_missing = sorted(set(ar_need) - set(AR))
    sq_missing = sorted(set(sq_need) - set(SQ))
    if ar_missing:
        raise SystemExit(f"AR missing translations: {ar_missing}")
    if sq_missing:
        raise SystemExit(f"SQ missing translations: {sq_missing}")

    ar_data = {k: AR[k] for k in ar_need}
    sq_data = {k: SQ[k] for k in sq_need}

    ar_out.write_text(json.dumps(ar_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    sq_out.write_text(json.dumps(sq_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    ar_keys = set(ar_data)
    sq_keys = set(sq_data)
    need_ar = set(ar_need)
    need_sq = set(sq_need)

    print(f"AR: wrote {len(ar_data)} keys -> {ar_out}")
    print(f"  need match: {ar_keys == need_ar}")
    print(f"  extra: {ar_keys - need_ar}")
    print(f"  missing: {need_ar - ar_keys}")

    print(f"SQ: wrote {len(sq_data)} keys -> {sq_out}")
    print(f"  need match: {sq_keys == need_sq}")
    print(f"  extra: {sq_keys - need_sq}")
    print(f"  missing: {need_sq - sq_keys}")

    untranslated_ar = [k for k, v in ar_data.items() if v == ar_need[k]]
    untranslated_sq = [k for k, v in sq_data.items() if v == sq_need[k]]
    print(f"AR still English: {len(untranslated_ar)} {untranslated_ar}")
    print(f"SQ still English: {len(untranslated_sq)} {untranslated_sq}")


if __name__ == "__main__":
    main()
