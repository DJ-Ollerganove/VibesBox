#!/usr/bin/env python3
"""Entfernt „spätestens“ / „at the latest“ aus Vorab-Wünsche-Deadline-Texten."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

KEYS = [
    "party_allow_pre_wishes_info_body",
    "party_allow_pre_wishes_settings_locked",
]

TRANSLATIONS: dict[str, dict[str, str]] = {
    "de": {
        "party_allow_pre_wishes_info_body": (
            "Wenn aktiviert, können Gäste mit dem Party-Code schon vor Partybeginn "
            "Musikwünsche senden. Das ist bis 6 Stunden vor Start möglich."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Diese Einstellung ist nur bis 6 Stunden vor Partybeginn änderbar."
        ),
    },
    "en": {
        "party_allow_pre_wishes_info_body": (
            "If activated, guests can use the party code to send music requests "
            "before the party starts. This is possible up to 6 hours before the start."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "This setting can only be changed until 6 hours before the party starts."
        ),
    },
    "fr": {
        "party_allow_pre_wishes_info_body": (
            "Lorsqu'il est activé, le code de fête permet aux invités d'envoyer "
            "leurs souhaits musicaux avant le début de la fête. "
            "Cela est possible jusqu'à 6 heures avant le début de la fête."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Ce paramètre ne peut être modifié que jusqu'à 6 heures avant le début de la fête."
        ),
    },
    "es": {
        "party_allow_pre_wishes_info_body": (
            "Si está activado, los invitados pueden utilizar el código de la fiesta "
            "para enviar solicitudes de música antes de que empiece la fiesta. "
            "Esto es posible hasta 6 horas antes del comienzo."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Este ajuste solo se puede cambiar hasta 6 horas antes del inicio de la fiesta."
        ),
    },
    "it": {
        "party_allow_pre_wishes_info_body": (
            "Se attivato, gli ospiti possono utilizzare il codice party per inviare "
            "richieste musicali prima dell'inizio della festa. "
            "Questo è possibile fino a 6 ore prima dell'inizio della festa."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Questa impostazione può essere modificata solo fino a 6 ore prima "
            "dell'inizio della festa."
        ),
    },
    "nl": {
        "party_allow_pre_wishes_info_body": (
            "Indien geactiveerd, kunnen gasten de feestcode gebruiken om muziekverzoeken "
            "te sturen voordat het feest begint. Dit is mogelijk tot 6 uur voor aanvang."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Deze instelling kan alleen worden gewijzigd tot 6 uur voor aanvang van het feest."
        ),
    },
    "pt": {
        "party_allow_pre_wishes_info_body": (
            "Se ativado, os convidados podem utilizar o código da festa para enviar "
            "pedidos de música antes do início da festa. "
            "Isto é possível até 6 horas antes do início da festa."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Esta definição só pode ser alterada até 6 horas antes do início da festa."
        ),
    },
    "pl": {
        "party_allow_pre_wishes_info_body": (
            "Po aktywacji goście mogą używać kodu imprezy do wysyłania próśb o muzykę "
            "przed rozpoczęciem imprezy. Jest to możliwe do 6 godzin przed rozpoczęciem imprezy."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "To ustawienie można zmienić tylko do 6 godzin przed rozpoczęciem imprezy."
        ),
    },
    "cs": {
        "party_allow_pre_wishes_info_body": (
            "Pokud je aktivován, mohou hosté před zahájením večírku použít kód "
            "pro zasílání požadavků na hudbu. To je možné 6 hodin před začátkem."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Toto nastavení lze změnit pouze do 6 hodin před začátkem večírku."
        ),
    },
    "uk": {
        "party_allow_pre_wishes_info_body": (
            "Якщо вона активована, гості можуть використовувати код вечірки "
            "для відправлення музичних запитів до початку вечірки. "
            "Це можливо за 6 годин до початку вечірки."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Це налаштування можна змінити лише за 6 годин до початку вечірки."
        ),
    },
    "ru": {
        "party_allow_pre_wishes_info_body": (
            "Если функция активирована, гости могут использовать код вечеринки, "
            "чтобы отправить музыкальные запросы до начала вечеринки. "
            "Это возможно за 6 часов до начала."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Этот параметр можно изменить только за 6 часов до начала вечеринки."
        ),
    },
    "tr": {
        "party_allow_pre_wishes_info_body": (
            "Etkinleştirilirse, konuklar parti başlamadan önce müzik istekleri "
            "göndermek için parti kodunu kullanabilir. "
            "Bu, partinin başlamasından 6 saat öncesine kadar mümkündür."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Bu ayar yalnızca partinin başlamasından 6 saat öncesine kadar değiştirilebilir."
        ),
    },
    "ja": {
        "party_allow_pre_wishes_info_body": (
            "有効化すると、ゲストはパーティーコードを使ってパーティー開始前に"
            "音楽のリクエストを送ることができます。開始の6時間前まで可能です。"
        ),
        "party_allow_pre_wishes_settings_locked": (
            "この設定はパーティー開始の6時間前まで変更できます。"
        ),
    },
    "el": {
        "party_allow_pre_wishes_info_body": (
            "Εάν ενεργοποιηθεί, οι καλεσμένοι μπορούν να χρησιμοποιήσουν τον κωδικό πάρτι "
            "για να στείλουν αιτήματα μουσικής πριν από την έναρξη του πάρτι. "
            "Αυτό είναι δυνατό 6 ώρες πριν από την έναρξη."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Αυτή η ρύθμιση μπορεί να αλλάξει μόνο έως 6 ώρες πριν από την έναρξη του πάρτι."
        ),
    },
    "ar": {
        "party_allow_pre_wishes_info_body": (
            "عند التفعيل، يمكن للضيوف إرسال طلبات موسيقية قبل بدء الحفلة "
            "باستخدام رمز الحفلة. ذلك ممكن حتى 6 ساعات قبل البدء."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "لا يمكن تغيير هذا الإعداد إلا حتى 6 ساعات قبل بدء الحفلة."
        ),
    },
    "vi": {
        "party_allow_pre_wishes_info_body": (
            "Nếu tính năng này được bật, khách mời có thể gửi yêu cầu bài hát "
            "bằng mã sự kiện ngay từ trước khi bữa tiệc bắt đầu. "
            "Yêu cầu có thể gửi đến 6 giờ trước khi sự kiện bắt đầu."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Cài đặt này chỉ có thể thay đổi cho đến 6 giờ trước khi bữa tiệc bắt đầu."
        ),
    },
    "zh": {
        "party_allow_pre_wishes_info_body": (
            "如果激活，客人可以在派对开始前使用派对代码发送音乐请求。"
            "可在开始前 6 小时发送。"
        ),
        "party_allow_pre_wishes_settings_locked": (
            "此设置仅可在派对开始前 6 小时之前更改。"
        ),
    },
    "hi": {
        "party_allow_pre_wishes_info_body": (
            "यदि सक्षम किया गया हो, तो मेहमान पार्टी शुरू होने से पहले पार्टी कोड का "
            "उपयोग करके संगीत अनुरोध सबमिट कर सकते हैं। "
            "यह पार्टी शुरू होने से 6 घंटे पहले तक किया जा सकता है।"
        ),
        "party_allow_pre_wishes_settings_locked": (
            "यह सेटिंग केवल पार्टी शुरू होने से 6 घंटे पहले तक बदली जा सकती है।"
        ),
    },
    "sq": {
        "party_allow_pre_wishes_info_body": (
            "Nëse është aktivizuar, mysafirët mund të përdorin kodin e festës "
            "për të dërguar kërkesa për muzikë para se festa të fillojë. "
            "Kjo mund të bëhet deri në 6 orë para fillimit."
        ),
        "party_allow_pre_wishes_settings_locked": (
            "Ky cilësim mund të ndryshohet vetëm deri në 6 orë para fillimit të festës."
        ),
    },
    "th": {
        "party_allow_pre_wishes_info_body": (
            "หากเปิดใช้งาน แขกสามารถใช้รหัสปาร์ตี้เพื่อส่งคำขอเพลงได้แม้ก่อนที่ปาร์ตี้จะเริ่มขึ้น "
            "สามารถทำได้จนถึง 6 ชั่วโมงก่อนเวลาเริ่มปาร์ตี้"
        ),
        "party_allow_pre_wishes_settings_locked": (
            "การตั้งค่านี้สามารถเปลี่ยนแปลงได้จนถึง 6 ชั่วโมงก่อนที่งานเลี้ยงจะเริ่ม"
        ),
    },
}


def main() -> None:
    en = TRANSLATIONS["en"]
    for arb_path in sorted(L10N.glob("app_*.arb")):
        locale = arb_path.stem.replace("app_", "")
        tr = TRANSLATIONS.get(locale, en)
        data = json.loads(arb_path.read_text(encoding="utf-8"))
        for key in KEYS:
            data[key] = tr.get(key, en[key])
        arb_path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"OK {arb_path.name}")


if __name__ == "__main__":
    main()
