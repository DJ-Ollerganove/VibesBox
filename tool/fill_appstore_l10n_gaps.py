#!/usr/bin/env python3
"""Füllt leere/fehlende App-L10n-Keys (Trial, Referral, Paywall-Hinweis, Impressum/DE) in alle ARBs."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / "l10n"

# Master-Texte (DE) — werden in app_de.arb gesetzt und als Fallback genutzt.
DE_FILL: dict[str, str] = {
    # Trial / Paywall
    "paywall_trial_confirm_message_no_b2b": (
        "Möchtest du die einmalige 2-Tage-Probezeit starten? "
        "Du erhältst sofort VibesBox Pro mit allen Funktionen. "
        "Danach automatisch wieder Free-Version – kein Abo, keine Zahlung."
    ),
    "paywall_trial_confirm_message_b2b": (
        "Mit deinem DJ-B2B-Code erhältst du 7 Tage VibesBox Pro. "
        "Danach automatisch wieder Free-Version – kein Abo, keine Zahlung."
    ),
    "paywall_trial_confirm_title_b2b": "Gratis-Probe starten?",
    "paywall_trial_b2b_hint": "Mit einem DJ-B2B-Code erhältst du 7 statt 2 Probetage.",
    "paywall_start_trial_button_b2b": "7 Tage Gratis starten",
    "trial_activated_snackbar_b2b": "VibesBox Pro für 7 Tage aktiviert!",
    "paywall_trial_no_subscription_hint": "Danach automatisch wieder Free-Version – kein Abo.",
    "paywall_privacy_link": "Datenschutz",
    "paywall_terms_link": "Nutzungsbedingungen (EULA)",
    "paywall_subscription_auto_renew_hint": (
        "Abos verlängern sich automatisch, sofern du sie nicht mindestens 24 Stunden "
        "vor Periodenende in den Einstellungen deines App Stores kündigst."
    ),
    # Update bestehender Confirm-Haupttext (schärfen)
    "paywall_trial_confirm_message": (
        "Möchtest du die einmalige 2-Tage-Probezeit starten? "
        "Du erhältst sofort VibesBox Pro mit allen Funktionen. "
        "Danach automatisch wieder Free-Version – kein Abo, keine Zahlung."
    ),
    # Referral B2B
    "referral_code_hint_b2b": "DJ-B2B-Code (DJ######)",
    "referral_code_length_b2b": "Code muss dem Format DJ###### entsprechen.",
    "referral_code_saved_b2b": "DJ-B2B-Code gespeichert",
    "referral_redeem_body_b2b": "Hast du einen DJ-B2B-Code von einem anderen DJ?",
    "referral_redeem_title_b2b": "DJ-B2B-Code einlösen",
    # Sonstige UI-Leerstellen
    "location_picker_title": "Standort wählen",
    "location_picker_empty": "Kein Standort gefunden",
    "party_code_ambiguous": "Mehrere Partys passen zu diesem Code. Bitte QR-Code scannen oder den DJ fragen.",
    "party_pre_wishes_public_unavailable": "Vorabwünsche sind bei öffentlichen Partys nicht verfügbar.",
    "payment_source_apple_store": "App Store",
    "payment_source_google_play": "Google Play",
    "payment_source_mac_app_store": "Mac App Store",
    "recognition_lock_takeover_button": "Hier starten",
    "thai": "Thailändisch",
    "wish_timeline_played": "Gespielt: {date} · {time}",
    "dj_home_widget_next_party_countdown": "Countdown zur nächsten Party",
    "dj_dashboard_header": "Dein DJ-Dashboard – volle Kontrolle über die Party",
    "main_intro_paragraph2": "",  # bewusst leer lassen (Layout)
    "imprint_name": "Swen Steller",
    "imprint_address": "Neefestr. 9",
    "imprint_city": "09119 Chemnitz / Deutschland",
    "imprint_email": "info@vibesbox.app",
    "imprint_phone": "+49 1525 4168549",
    "imprint_legal_notices": "1. Rechtliche Hinweise / Haftungsausschluss",
    "imprint_legal_note_non_de": (
        "Bei Abweichungen zwischen der deutschen Fassung und Übersetzungen gilt die deutsche Fassung."
    ),
    "imprint_section1_title": "§ 1 Hinweise zu Inhalten",
    "imprint_section1_text": (
        "(1) Die Inhalte dieser App und Website werden mit größtmöglicher Sorgfalt erstellt. "
        "Für Richtigkeit, Vollständigkeit und Aktualität wird jedoch keine Gewähr übernommen. "
        "(2) Die Nutzung kostenfreier Inhalte erfolgt auf eigene Gefahr. Der bloße Zugriff begründet "
        "kein Vertragsverhältnis. (3) Für kostenpflichtige Dienste gelten vorrangig die AGB."
    ),
    "imprint_section2_title": "§ 2 Externe Links",
    "imprint_section2_text": (
        "Diese App kann Links zu Websites Dritter enthalten. Für deren Inhalte sind die jeweiligen "
        "Betreiber verantwortlich. Bei Kenntnis von Rechtsverletzungen werden Links entfernt."
    ),
    "imprint_section3_title": "§ 3 Urheberrecht",
    "imprint_section3_text": (
        "(1) Die veröffentlichten Inhalte unterliegen dem deutschen Urheberrecht. "
        "(2) Nutzer, die eigene Inhalte hochladen, räumen die für den Betrieb nötigen Nutzungsrechte ein."
    ),
    "imprint_section4_title": "§ 4 Sprachklausel",
    "imprint_section4_text": (
        "Bei Abweichungen zwischen der deutschen Fassung und Übersetzungen gilt die deutsche Fassung."
    ),
    "privacy_title": "Datenschutzerklärung",
    "privacy_section1_title": "1. Allgemeine Informationen",
    "privacy_section1_text": (
        "Verantwortlich für die Datenverarbeitung ist der im Impressum genannte Anbieter. "
        "Wir nehmen den Schutz deiner personenbezogenen Daten sehr ernst."
    ),
    "privacy_section2_title": "2. Datenerhebung bei Registrierung (DJs & Locations)",
    "privacy_section2_text": (
        "Wir erheben Daten, die für dein Profil und die Abwicklung eines Abos erforderlich sind:\n\n"
        "Name, Adresse, E-Mail-Adresse\n\nZahlungsdaten (über externe Zahlungsdienstleister)\n\n"
        "Profilinhalte (Bilder, Beschreibungen)"
    ),
    "privacy_section3_title": "3. Datenaustausch in der App",
    "privacy_section3_text": (
        "Zur Vermittlung werden Daten von DJs und Locations für andere Nutzer sichtbar. "
        "Mit Anlegen eines Profils willigst du in diese Veröffentlichung ein."
    ),
    "privacy_section4_title": "4. Rechte der Nutzer",
    "privacy_section4_text": (
        "Du hast jederzeit das Recht auf Auskunft, Berichtigung, Löschung oder Einschränkung "
        "der Verarbeitung sowie auf Datenübertragbarkeit."
    ),
    "privacy_section5_title": "5. Datensicherheit",
    "privacy_section5_text": (
        "Wir nutzen moderne Verschlüsselung (SSL/TLS), um deine Daten bei der Übertragung zu schützen."
    ),
}

EN_FILL: dict[str, str] = {
    "paywall_trial_confirm_message_no_b2b": (
        "Do you want to start your one-time 2-day trial? "
        "You will immediately get VibesBox Pro with all features. "
        "Then automatically back to Free – no subscription, no payment."
    ),
    "paywall_trial_confirm_message_b2b": (
        "With your DJ B2B code you get 7 days of VibesBox Pro. "
        "Then automatically back to Free – no subscription, no payment."
    ),
    "paywall_trial_confirm_title_b2b": "Start free trial?",
    "paywall_trial_b2b_hint": "With a DJ B2B code you get 7 trial days instead of 2.",
    "paywall_start_trial_button_b2b": "Start 7 days free",
    "trial_activated_snackbar_b2b": "VibesBox Pro activated for 7 days!",
    "paywall_trial_no_subscription_hint": "Then automatically back to Free – no subscription.",
    "paywall_privacy_link": "Privacy Policy",
    "paywall_terms_link": "Terms of Use (EULA)",
    "paywall_subscription_auto_renew_hint": (
        "Subscriptions renew automatically unless you cancel at least 24 hours before "
        "the end of the current period in your App Store settings."
    ),
    "paywall_trial_confirm_message": (
        "Do you want to start your one-time 2-day trial? "
        "You will immediately get VibesBox Pro with all features. "
        "Then automatically back to Free – no subscription, no payment."
    ),
    "referral_code_hint_b2b": "DJ B2B code (DJ######)",
    "referral_code_length_b2b": "Code must match DJ######.",
    "referral_code_saved_b2b": "DJ B2B code saved",
    "referral_redeem_body_b2b": "Do you have a DJ B2B code from another DJ?",
    "referral_redeem_title_b2b": "Redeem DJ B2B code",
    "location_picker_title": "Choose location",
    "location_picker_empty": "No location found",
    "party_code_ambiguous": "Several parties match this code. Please scan the QR code or ask the DJ.",
    "party_pre_wishes_public_unavailable": "Advance wishes are not available for public parties.",
    "payment_source_apple_store": "App Store",
    "payment_source_google_play": "Google Play",
    "payment_source_mac_app_store": "Mac App Store",
    "recognition_lock_takeover_button": "Start here",
    "thai": "Thai",
    "wish_timeline_played": "Played: {date} · {time}",
    "dj_home_widget_next_party_countdown": "Countdown to next party",
    "time_suffix": "",
    "main_intro_paragraph2": "",
}

# Kurz-Übersetzungen für neue Keys (nicht DE/EN). Bestehende gute Locale-Texte bleiben.
NEW_KEYS_BY_LANG: dict[str, dict[str, str]] = {
    "ar": {
        "paywall_trial_no_subscription_hint": "بعدها تعود تلقائيًا للنسخة المجانية – بدون اشتراك.",
        "paywall_privacy_link": "سياسة الخصوصية",
        "paywall_terms_link": "شروط الاستخدام (EULA)",
        "paywall_subscription_auto_renew_hint": "تتجدد الاشتراكات تلقائيًا ما لم تُلغَ قبل 24 ساعة على الأقل من نهاية الفترة من إعدادات متجر التطبيقات.",
        "paywall_trial_confirm_message_no_b2b": "هل تريد بدء تجربتك لمرة واحدة لمدة يومين؟ تحصل فورًا على VibesBox Pro. بعدها تعود تلقائيًا للنسخة المجانية – بدون اشتراك وبدون دفع.",
        "paywall_trial_confirm_message_b2b": "مع رمز DJ B2B تحصل على 7 أيام VibesBox Pro. بعدها تعود تلقائيًا للنسخة المجانية – بدون اشتراك وبدون دفع.",
        "paywall_trial_confirm_message": "هل تريد بدء تجربتك لمرة واحدة لمدة يومين؟ تحصل فورًا على VibesBox Pro. بعدها تعود تلقائيًا للنسخة المجانية – بدون اشتراك وبدون دفع.",
    },
    "cs": {
        "paywall_trial_no_subscription_hint": "Poté se automaticky vrátí Free verze – žádné předplatné.",
        "paywall_privacy_link": "Ochrana soukromí",
        "paywall_terms_link": "Podmínky použití (EULA)",
        "paywall_subscription_auto_renew_hint": "Předplatné se automaticky obnovuje, pokud jej nezrušíte alespoň 24 hodin před koncem období v nastavení App Store.",
        "paywall_trial_confirm_message_no_b2b": "Chceš spustit jednorázovou 2denní zkušební verzi? Hned dostaneš VibesBox Pro. Poté se automaticky vrátí Free – žádné předplatné, žádná platba.",
        "paywall_trial_confirm_message_b2b": "S DJ B2B kódem dostaneš 7 dní VibesBox Pro. Poté se automaticky vrátí Free – žádné předplatné, žádná platba.",
        "paywall_trial_confirm_message": "Chceš spustit jednorázovou 2denní zkušební verzi? Hned dostaneš VibesBox Pro. Poté se automaticky vrátí Free – žádné předplatné, žádná platba.",
    },
    "el": {
        "paywall_trial_no_subscription_hint": "Μετά επιστρέφεις αυτόματα στη δωρεάν έκδοση – χωρίς συνδρομή.",
        "paywall_privacy_link": "Απόρρητο",
        "paywall_terms_link": "Όροι χρήσης (EULA)",
        "paywall_subscription_auto_renew_hint": "Οι συνδρομές ανανεώνονται αυτόματα, εκτός αν τις ακυρώσεις τουλάχιστον 24 ώρες πριν τη λήξη στην ενότητα ρυθμίσεων του App Store.",
        "paywall_trial_confirm_message_no_b2b": "Θέλεις να ξεκινήσεις την εφάπαξ 2ήμερη δοκιμή; Παίρνεις αμέσως VibesBox Pro. Μετά επιστρέφεις αυτόματα στη δωρεάν έκδοση – χωρίς συνδρομή και χωρίς χρέωση.",
        "paywall_trial_confirm_message_b2b": "Με κωδικό DJ B2B παίρνεις 7 ημέρες VibesBox Pro. Μετά επιστρέφεις αυτόματα στη δωρεάν έκδοση – χωρίς συνδρομή και χωρίς χρέωση.",
        "paywall_trial_confirm_message": "Θέλεις να ξεκινήσεις την εφάπαξ 2ήμερη δοκιμή; Παίρνεις αμέσως VibesBox Pro. Μετά επιστρέφεις αυτόματα στη δωρεάν έκδοση – χωρίς συνδρομή και χωρίς χρέωση.",
    },
    "es": {
        "paywall_trial_no_subscription_hint": "Después vuelves automáticamente a Free – sin suscripción.",
        "paywall_privacy_link": "Privacidad",
        "paywall_terms_link": "Términos de uso (EULA)",
        "paywall_subscription_auto_renew_hint": "Las suscripciones se renuevan automáticamente salvo que las canceles al menos 24 horas antes del fin del periodo en los ajustes de la App Store.",
        "paywall_trial_confirm_message_no_b2b": "¿Quieres empezar tu prueba única de 2 días? Obtienes VibesBox Pro al instante. Después vuelves automáticamente a Free – sin suscripción ni pago.",
        "paywall_trial_confirm_message_b2b": "Con tu código DJ B2B obtienes 7 días de VibesBox Pro. Después vuelves automáticamente a Free – sin suscripción ni pago.",
        "paywall_trial_confirm_message": "¿Quieres empezar tu prueba única de 2 días? Obtienes VibesBox Pro al instante. Después vuelves automáticamente a Free – sin suscripción ni pago.",
    },
    "fr": {
        "paywall_trial_no_subscription_hint": "Ensuite, retour automatique à la version Free – pas d’abonnement.",
        "paywall_privacy_link": "Confidentialité",
        "paywall_terms_link": "Conditions d’utilisation (EULA)",
        "paywall_subscription_auto_renew_hint": "Les abonnements se renouvellent automatiquement sauf annulation au moins 24 heures avant la fin de la période dans les réglages de l’App Store.",
        "paywall_trial_confirm_message_no_b2b": "Veux-tu lancer ton essai unique de 2 jours ? Tu obtiens VibesBox Pro immédiatement. Ensuite, retour automatique à Free – pas d’abonnement, pas de paiement.",
        "paywall_trial_confirm_message_b2b": "Avec ton code DJ B2B tu obtiens 7 jours de VibesBox Pro. Ensuite, retour automatique à Free – pas d’abonnement, pas de paiement.",
        "paywall_trial_confirm_message": "Veux-tu lancer ton essai unique de 2 jours ? Tu obtiens VibesBox Pro immédiatement. Ensuite, retour automatique à Free – pas d’abonnement, pas de paiement.",
    },
    "hi": {
        "paywall_trial_no_subscription_hint": "इसके बाद स्वचालित रूप से Free संस्करण – कोई सदस्यता नहीं।",
        "paywall_privacy_link": "गोपनीयता नीति",
        "paywall_terms_link": "उपयोग की शर्तें (EULA)",
        "paywall_subscription_auto_renew_hint": "सदस्यताएँ स्वतः नवीकृत होती हैं, जब तक आप उन्हें अवधि समाप्त होने से कम से कम 24 घंटे पहले App Store सेटिंग्स में रद्द नहीं करते।",
        "paywall_trial_confirm_message_no_b2b": "क्या तुम अपना एक बार का 2-दिन का ट्रायल शुरू करना चाहते हो? तुम्हें तुरंत VibesBox Pro मिलेगा। इसके बाद स्वचालित रूप से Free – कोई सदस्यता नहीं, कोई भुगतान नहीं।",
        "paywall_trial_confirm_message_b2b": "अपने DJ B2B कोड से तुम्हें 7 दिन VibesBox Pro मिलता है। इसके बाद स्वचालित रूप से Free – कोई सदस्यता नहीं, कोई भुगतान नहीं।",
        "paywall_trial_confirm_message": "क्या तुम अपना एक बार का 2-दिन का ट्रायल शुरू करना चाहते हो? तुम्हें तुरंत VibesBox Pro मिलेगा। इसके बाद स्वचालित रूप से Free – कोई सदस्यता नहीं, कोई भुगतान नहीं।",
    },
    "it": {
        "paywall_trial_no_subscription_hint": "Poi torni automaticamente a Free – nessun abbonamento.",
        "paywall_privacy_link": "Privacy",
        "paywall_terms_link": "Termini di utilizzo (EULA)",
        "paywall_subscription_auto_renew_hint": "Gli abbonamenti si rinnovano automaticamente salvo disdetta almeno 24 ore prima della fine del periodo nelle impostazioni dell’App Store.",
        "paywall_trial_confirm_message_no_b2b": "Vuoi avviare la prova una tantum di 2 giorni? Ottieni subito VibesBox Pro. Poi torni automaticamente a Free – nessun abbonamento, nessun pagamento.",
        "paywall_trial_confirm_message_b2b": "Con il tuo codice DJ B2B ottieni 7 giorni di VibesBox Pro. Poi torni automaticamente a Free – nessun abbonamento, nessun pagamento.",
        "paywall_trial_confirm_message": "Vuoi avviare la prova una tantum di 2 giorni? Ottieni subito VibesBox Pro. Poi torni automaticamente a Free – nessun abbonamento, nessun pagamento.",
    },
    "ja": {
        "paywall_trial_no_subscription_hint": "終了後は自動的に無料版へ戻ります。定期購読はありません。",
        "paywall_privacy_link": "プライバシーポリシー",
        "paywall_terms_link": "利用規約（EULA）",
        "paywall_subscription_auto_renew_hint": "サブスクリプションは、期間終了の24時間以上前に App Store の設定で解約しない限り自動更新されます。",
        "paywall_trial_confirm_message_no_b2b": "一度限りの2日間トライアルを開始しますか？すぐに VibesBox Pro が使えます。終了後は自動的に無料版へ戻ります。定期購読や課金はありません。",
        "paywall_trial_confirm_message_b2b": "DJ B2Bコードで VibesBox Pro が7日間使えます。終了後は自動的に無料版へ戻ります。定期購読や課金はありません。",
        "paywall_trial_confirm_message": "一度限りの2日間トライアルを開始しますか？すぐに VibesBox Pro が使えます。終了後は自動的に無料版へ戻ります。定期購読や課金はありません。",
    },
    "nl": {
        "paywall_trial_no_subscription_hint": "Daarna automatisch weer Free – geen abonnement.",
        "paywall_privacy_link": "Privacybeleid",
        "paywall_terms_link": "Gebruiksvoorwaarden (EULA)",
        "paywall_subscription_auto_renew_hint": "Abonnementen verlengen automatisch tenzij je ze minstens 24 uur voor het einde van de periode annuleert in de App Store-instellingen.",
        "paywall_trial_confirm_message_no_b2b": "Wil je je eenmalige proefperiode van 2 dagen starten? Je krijgt meteen VibesBox Pro. Daarna automatisch weer Free – geen abonnement, geen betaling.",
        "paywall_trial_confirm_message_b2b": "Met je DJ B2B-code krijg je 7 dagen VibesBox Pro. Daarna automatisch weer Free – geen abonnement, geen betaling.",
        "paywall_trial_confirm_message": "Wil je je eenmalige proefperiode van 2 dagen starten? Je krijgt meteen VibesBox Pro. Daarna automatisch weer Free – geen abonnement, geen betaling.",
    },
    "pl": {
        "paywall_trial_no_subscription_hint": "Potem automatycznie wraca wersja Free – bez subskrypcji.",
        "paywall_privacy_link": "Polityka prywatności",
        "paywall_terms_link": "Warunki użytkowania (EULA)",
        "paywall_subscription_auto_renew_hint": "Subskrypcje odnawiają się automatycznie, chyba że anulujesz je co najmniej 24 godziny przed końcem okresu w ustawieniach App Store.",
        "paywall_trial_confirm_message_no_b2b": "Chcesz rozpocząć jednorazowy 2-dniowy okres próbny? Od razu masz VibesBox Pro. Potem automatycznie wraca Free – bez subskrypcji i bez płatności.",
        "paywall_trial_confirm_message_b2b": "Z kodem DJ B2B masz 7 dni VibesBox Pro. Potem automatycznie wraca Free – bez subskrypcji i bez płatności.",
        "paywall_trial_confirm_message": "Chcesz rozpocząć jednorazowy 2-dniowy okres próbny? Od razu masz VibesBox Pro. Potem automatycznie wraca Free – bez subskrypcji i bez płatności.",
    },
    "pt": {
        "paywall_trial_no_subscription_hint": "Depois volta automaticamente para Free – sem subscrição.",
        "paywall_privacy_link": "Privacidade",
        "paywall_terms_link": "Termos de utilização (EULA)",
        "paywall_subscription_auto_renew_hint": "As subscrições renovam-se automaticamente, a menos que as cancels pelo menos 24 horas antes do fim do período nas definições da App Store.",
        "paywall_trial_confirm_message_no_b2b": "Queres iniciar o teu teste único de 2 dias? Recebes VibesBox Pro de imediato. Depois volta automaticamente para Free – sem subscrição nem pagamento.",
        "paywall_trial_confirm_message_b2b": "Com o teu código DJ B2B tens 7 dias de VibesBox Pro. Depois volta automaticamente para Free – sem subscrição nem pagamento.",
        "paywall_trial_confirm_message": "Queres iniciar o teu teste único de 2 dias? Recebes VibesBox Pro de imediato. Depois volta automaticamente para Free – sem subscrição nem pagamento.",
    },
    "ru": {
        "paywall_trial_no_subscription_hint": "Затем автоматически снова Free — без подписки.",
        "paywall_privacy_link": "Конфиденциальность",
        "paywall_terms_link": "Условия использования (EULA)",
        "paywall_subscription_auto_renew_hint": "Подписки продлеваются автоматически, если вы не отмените их минимум за 24 часа до конца периода в настройках App Store.",
        "paywall_trial_confirm_message_no_b2b": "Хочешь начать одноразовый 2-дневный пробный период? Сразу получишь VibesBox Pro. Затем автоматически снова Free — без подписки и без оплаты.",
        "paywall_trial_confirm_message_b2b": "С DJ B2B-кодом ты получаешь 7 дней VibesBox Pro. Затем автоматически снова Free — без подписки и без оплаты.",
        "paywall_trial_confirm_message": "Хочешь начать одноразовый 2-дневный пробный период? Сразу получишь VibesBox Pro. Затем автоматически снова Free — без подписки и без оплаты.",
    },
    "sq": {
        "paywall_trial_no_subscription_hint": "Pastaj kthehesh automatikisht te Free – pa abonim.",
        "paywall_privacy_link": "Privatësia",
        "paywall_terms_link": "Kushtet e përdorimit (EULA)",
        "paywall_subscription_auto_renew_hint": "Abonimet rinovohen automatikisht nëse nuk i anulon të paktën 24 orë para fundit të periodës te cilësimet e App Store.",
        "paywall_trial_confirm_message_no_b2b": "Dëshiron të fillosh provën njëherëshe 2-ditore? Merr VibesBox Pro menjëherë. Pastaj kthehesh automatikisht te Free – pa abonim dhe pa pagesë.",
        "paywall_trial_confirm_message_b2b": "Me kodin DJ B2B merr 7 ditë VibesBox Pro. Pastaj kthehesh automatikisht te Free – pa abonim dhe pa pagesë.",
        "paywall_trial_confirm_message": "Dëshiron të fillosh provën njëherëshe 2-ditore? Merr VibesBox Pro menjëherë. Pastaj kthehesh automatikisht te Free – pa abonim dhe pa pagesë.",
    },
    "th": {
        "paywall_trial_no_subscription_hint": "หลังจากนั้นจะกลับเป็นเวอร์ชันฟรีโดยอัตโนมัติ – ไม่มีสมัครสมาชิก",
        "paywall_privacy_link": "นโยบายความเป็นส่วนตัว",
        "paywall_terms_link": "ข้อกำหนดการใช้งาน (EULA)",
        "paywall_subscription_auto_renew_hint": "การสมัครสมาชิกจะต่ออายุอัตโนมัติ เว้นแต่คุณยกเลิกอย่างน้อย 24 ชั่วโมงก่อนสิ้นสุดรอบในตั้งค่า App Store",
        "paywall_trial_confirm_message_no_b2b": "ต้องการเริ่มทดลองใช้แบบครั้งเดียว 2 วันหรือไม่? คุณจะได้ VibesBox Pro ทันที จากนั้นจะกลับเป็นฟรีโดยอัตโนมัติ – ไม่มีสมัครสมาชิกและไม่มีการชำระเงิน",
        "paywall_trial_confirm_message_b2b": "ด้วยรหัส DJ B2B คุณจะได้ VibesBox Pro 7 วัน จากนั้นจะกลับเป็นฟรีโดยอัตโนมัติ – ไม่มีสมัครสมาชิกและไม่มีการชำระเงิน",
        "paywall_trial_confirm_message": "ต้องการเริ่มทดลองใช้แบบครั้งเดียว 2 วันหรือไม่? คุณจะได้ VibesBox Pro ทันที จากนั้นจะกลับเป็นฟรีโดยอัตโนมัติ – ไม่มีสมัครสมาชิกและไม่มีการชำระเงิน",
    },
    "tr": {
        "paywall_trial_no_subscription_hint": "Ardından otomatik olarak Free sürüme dönülür – abonelik yok.",
        "paywall_privacy_link": "Gizlilik",
        "paywall_terms_link": "Kullanım koşulları (EULA)",
        "paywall_subscription_auto_renew_hint": "Abonelikler, dönem bitiminden en az 24 saat önce App Store ayarlarından iptal etmezseniz otomatik yenilenir.",
        "paywall_trial_confirm_message_no_b2b": "Tek seferlik 2 günlük denemeni başlatmak ister misin? Hemen VibesBox Pro alırsın. Ardından otomatik olarak Free – abonelik yok, ödeme yok.",
        "paywall_trial_confirm_message_b2b": "DJ B2B kodunla 7 gün VibesBox Pro alırsın. Ardından otomatik olarak Free – abonelik yok, ödeme yok.",
        "paywall_trial_confirm_message": "Tek seferlik 2 günlük denemeni başlatmak ister misin? Hemen VibesBox Pro alırsın. Ardından otomatik olarak Free – abonelik yok, ödeme yok.",
    },
    "uk": {
        "paywall_trial_no_subscription_hint": "Потім автоматично знову Free — без підписки.",
        "paywall_privacy_link": "Конфіденційність",
        "paywall_terms_link": "Умови використання (EULA)",
        "paywall_subscription_auto_renew_hint": "Підписки поновлюються автоматично, якщо ви не скасуєте їх щонайменше за 24 години до кінця періоду в налаштуваннях App Store.",
        "paywall_trial_confirm_message_no_b2b": "Хочеш розпочати одноразовий 2-денний пробний період? Одразу отримаєш VibesBox Pro. Потім автоматично знову Free — без підписки й без оплати.",
        "paywall_trial_confirm_message_b2b": "З DJ B2B-кодом ти отримуєш 7 днів VibesBox Pro. Потім автоматично знову Free — без підписки й без оплати.",
        "paywall_trial_confirm_message": "Хочеш розпочати одноразовий 2-денний пробний період? Одразу отримаєш VibesBox Pro. Потім автоматично знову Free — без підписки й без оплати.",
    },
    "vi": {
        "paywall_trial_no_subscription_hint": "Sau đó tự động quay lại bản Free – không đăng ký.",
        "paywall_privacy_link": "Chính sách quyền riêng tư",
        "paywall_terms_link": "Điều khoản sử dụng (EULA)",
        "paywall_subscription_auto_renew_hint": "Gói đăng ký tự động gia hạn trừ khi bạn hủy ít nhất 24 giờ trước khi kết thúc kỳ trong cài đặt App Store.",
        "paywall_trial_confirm_message_no_b2b": "Bạn muốn bắt đầu dùng thử một lần 2 ngày? Bạn nhận VibesBox Pro ngay. Sau đó tự động quay lại Free – không đăng ký, không thanh toán.",
        "paywall_trial_confirm_message_b2b": "Với mã DJ B2B bạn có 7 ngày VibesBox Pro. Sau đó tự động quay lại Free – không đăng ký, không thanh toán.",
        "paywall_trial_confirm_message": "Bạn muốn bắt đầu dùng thử một lần 2 ngày? Bạn nhận VibesBox Pro ngay. Sau đó tự động quay lại Free – không đăng ký, không thanh toán.",
    },
    "zh": {
        "paywall_trial_no_subscription_hint": "之后自动回到免费版——无订阅。",
        "paywall_privacy_link": "隐私政策",
        "paywall_terms_link": "使用条款（EULA）",
        "paywall_subscription_auto_renew_hint": "订阅会自动续订，除非你在当期结束前至少 24 小时在 App Store 设置中取消。",
        "paywall_trial_confirm_message_no_b2b": "要开始一次性 2 天试用吗？你将立即获得 VibesBox Pro。之后自动回到免费版——无订阅、无扣款。",
        "paywall_trial_confirm_message_b2b": "使用 DJ B2B 码可获得 7 天 VibesBox Pro。之后自动回到免费版——无订阅、无扣款。",
        "paywall_trial_confirm_message": "要开始一次性 2 天试用吗？你将立即获得 VibesBox Pro。之后自动回到免费版——无订阅、无扣款。",
    },
}

# Keys die nie leer bleiben sollten (außer bewusste leere).
NEVER_EMPTY = set(DE_FILL) | set(EN_FILL) | {
    "paywall_trial_no_subscription_hint",
    "paywall_privacy_link",
    "paywall_terms_link",
    "paywall_subscription_auto_renew_hint",
}


def load_arb(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def save_arb(path: Path, data: dict) -> None:
    # Keep @@locale first-ish
    path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def main() -> None:
    de_path = L10N / "app_de.arb"
    en_path = L10N / "app_en.arb"
    de = load_arb(de_path)
    en = load_arb(en_path)

    for k, v in DE_FILL.items():
        if k == "main_intro_paragraph2":
            continue
        de[k] = v
    for k, v in EN_FILL.items():
        if k in ("main_intro_paragraph2", "time_suffix"):
            if k not in en:
                en[k] = v
            continue
        en[k] = v

    save_arb(de_path, de)
    save_arb(en_path, en)
    print("updated de + en")

    for path in sorted(L10N.glob("app_*.arb")):
        code = path.stem.replace("app_", "")
        if code in ("de", "en"):
            continue
        data = load_arb(path)
        lang_extra = NEW_KEYS_BY_LANG.get(code, {})
        for k, v in lang_extra.items():
            data[k] = v
        # Ensure all NEVER_EMPTY keys exist; fill from EN then DE if missing/empty
        for k in NEVER_EMPTY:
            cur = data.get(k)
            if cur is None or (isinstance(cur, str) and cur.strip() == ""):
                fill = en.get(k) or de.get(k) or ""
                if fill:
                    data[k] = fill
        # Fill other empty keys from EN then DE (except intentional empties)
        intentional_empty = {"main_intro_paragraph2", "time_suffix"}
        for k, v in list(data.items()):
            if k.startswith("@") or k == "@@locale":
                continue
            if k in intentional_empty:
                continue
            if isinstance(v, str) and v.strip() == "":
                fill = en.get(k) or de.get(k) or ""
                if fill:
                    data[k] = fill
        save_arb(path, data)
        print(f"updated {path.name}")


if __name__ == "__main__":
    main()
