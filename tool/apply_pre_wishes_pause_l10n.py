#!/usr/bin/env python3
"""Vorab-Pause: Gäste-Text, DJ-Dialoge, Haken dauerhaft aktiv."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"
BABEL = ROOT / "public/vb/babel/locales"

KEYS = [
    "pre_wishes_paused_guest_message",
    "party_allow_pre_wishes_cannot_disable",
    "pre_wishes_pause",
    "pre_wishes_resume",
    "pre_wishes_pause_confirm_title",
    "pre_wishes_pause_confirm_body",
    "pre_wishes_resume_confirm_title",
    "pre_wishes_resume_confirm_body",
    "pre_wishes_paused_success",
    "pre_wishes_resumed_success",
]

TRANSLATIONS: dict[str, dict[str, str]] = {
    "de": {
        "pre_wishes_paused_guest_message": "Vorab-Wünsche können nicht mehr abgegeben werden.",
        "party_allow_pre_wishes_cannot_disable": "Vorab-Wünsche wurden aktiviert und können nicht mehr abgeschaltet werden.",
        "pre_wishes_pause": "Pausieren",
        "pre_wishes_resume": "Fortsetzen",
        "pre_wishes_pause_confirm_title": "Vorab-Wünsche pausieren?",
        "pre_wishes_pause_confirm_body": "Gäste können dann keine neuen Vorab-Wünsche mehr absenden.",
        "pre_wishes_resume_confirm_title": "Vorab-Wünsche fortsetzen?",
        "pre_wishes_resume_confirm_body": "Gäste können wieder Vorab-Wünsche absenden (bis 6 Stunden vor Partybeginn).",
        "pre_wishes_paused_success": "Vorab-Wünsche pausiert.",
        "pre_wishes_resumed_success": "Vorab-Wünsche fortgesetzt.",
    },
    "en": {
        "pre_wishes_paused_guest_message": "Advance requests can no longer be submitted.",
        "party_allow_pre_wishes_cannot_disable": "Advance requests have been enabled and can no longer be turned off.",
        "pre_wishes_pause": "Pause",
        "pre_wishes_resume": "Resume",
        "pre_wishes_pause_confirm_title": "Pause advance requests?",
        "pre_wishes_pause_confirm_body": "Guests will no longer be able to submit new advance requests.",
        "pre_wishes_resume_confirm_title": "Resume advance requests?",
        "pre_wishes_resume_confirm_body": "Guests can submit advance requests again (until 6 hours before the party starts).",
        "pre_wishes_paused_success": "Advance requests paused.",
        "pre_wishes_resumed_success": "Advance requests resumed.",
    },
    "fr": {
        "pre_wishes_paused_guest_message": "Les demandes anticipées ne peuvent plus être envoyées.",
        "party_allow_pre_wishes_cannot_disable": "Les demandes anticipées ont été activées et ne peuvent plus être désactivées.",
        "pre_wishes_pause": "Pause",
        "pre_wishes_resume": "Reprendre",
        "pre_wishes_pause_confirm_title": "Mettre en pause les demandes anticipées ?",
        "pre_wishes_pause_confirm_body": "Les invités ne pourront plus envoyer de nouvelles demandes anticipées.",
        "pre_wishes_resume_confirm_title": "Reprendre les demandes anticipées ?",
        "pre_wishes_resume_confirm_body": "Les invités pourront à nouveau envoyer des demandes anticipées (jusqu'à 6 heures avant le début).",
        "pre_wishes_paused_success": "Demandes anticipées en pause.",
        "pre_wishes_resumed_success": "Demandes anticipées reprises.",
    },
    "es": {
        "pre_wishes_paused_guest_message": "Ya no se pueden enviar solicitudes anticipadas.",
        "party_allow_pre_wishes_cannot_disable": "Las solicitudes anticipadas están activadas y ya no se pueden desactivar.",
        "pre_wishes_pause": "Pausar",
        "pre_wishes_resume": "Reanudar",
        "pre_wishes_pause_confirm_title": "¿Pausar solicitudes anticipadas?",
        "pre_wishes_pause_confirm_body": "Los invitados ya no podrán enviar nuevas solicitudes anticipadas.",
        "pre_wishes_resume_confirm_title": "¿Reanudar solicitudes anticipadas?",
        "pre_wishes_resume_confirm_body": "Los invitados podrán enviar solicitudes anticipadas de nuevo (hasta 6 horas antes del inicio).",
        "pre_wishes_paused_success": "Solicitudes anticipadas pausadas.",
        "pre_wishes_resumed_success": "Solicitudes anticipadas reanudadas.",
    },
    "it": {
        "pre_wishes_paused_guest_message": "Le richieste anticipate non possono più essere inviate.",
        "party_allow_pre_wishes_cannot_disable": "Le richieste anticipate sono state attivate e non possono più essere disattivate.",
        "pre_wishes_pause": "Pausa",
        "pre_wishes_resume": "Riprendi",
        "pre_wishes_pause_confirm_title": "Mettere in pausa le richieste anticipate?",
        "pre_wishes_pause_confirm_body": "Gli ospiti non potranno più inviare nuove richieste anticipate.",
        "pre_wishes_resume_confirm_title": "Riprendere le richieste anticipate?",
        "pre_wishes_resume_confirm_body": "Gli ospiti potranno di nuovo inviare richieste anticipate (fino a 6 ore prima dell'inizio).",
        "pre_wishes_paused_success": "Richieste anticipate in pausa.",
        "pre_wishes_resumed_success": "Richieste anticipate riprese.",
    },
    "nl": {
        "pre_wishes_paused_guest_message": "Verzoeken vooraf kunnen niet meer worden verstuurd.",
        "party_allow_pre_wishes_cannot_disable": "Verzoeken vooraf zijn ingeschakeld en kunnen niet meer worden uitgeschakeld.",
        "pre_wishes_pause": "Pauzeren",
        "pre_wishes_resume": "Hervatten",
        "pre_wishes_pause_confirm_title": "Verzoeken vooraf pauzeren?",
        "pre_wishes_pause_confirm_body": "Gasten kunnen dan geen nieuwe verzoeken vooraf meer versturen.",
        "pre_wishes_resume_confirm_title": "Verzoeken vooraf hervatten?",
        "pre_wishes_resume_confirm_body": "Gasten kunnen weer verzoeken vooraf versturen (tot 6 uur voor aanvang).",
        "pre_wishes_paused_success": "Verzoeken vooraf gepauzeerd.",
        "pre_wishes_resumed_success": "Verzoeken vooraf hervat.",
    },
    "pt": {
        "pre_wishes_paused_guest_message": "Os pedidos antecipados já não podem ser enviados.",
        "party_allow_pre_wishes_cannot_disable": "Os pedidos antecipados foram ativados e já não podem ser desativados.",
        "pre_wishes_pause": "Pausar",
        "pre_wishes_resume": "Retomar",
        "pre_wishes_pause_confirm_title": "Pausar pedidos antecipados?",
        "pre_wishes_pause_confirm_body": "Os convidados deixarão de poder enviar novos pedidos antecipados.",
        "pre_wishes_resume_confirm_title": "Retomar pedidos antecipados?",
        "pre_wishes_resume_confirm_body": "Os convidados poderão voltar a enviar pedidos antecipados (até 6 horas antes do início).",
        "pre_wishes_paused_success": "Pedidos antecipados pausados.",
        "pre_wishes_resumed_success": "Pedidos antecipados retomados.",
    },
    "pl": {
        "pre_wishes_paused_guest_message": "Wstępnych próśb nie można już wysyłać.",
        "party_allow_pre_wishes_cannot_disable": "Wstępne prośby zostały włączone i nie można ich już wyłączyć.",
        "pre_wishes_pause": "Wstrzymaj",
        "pre_wishes_resume": "Wznów",
        "pre_wishes_pause_confirm_title": "Wstrzymać wstępne prośby?",
        "pre_wishes_pause_confirm_body": "Goście nie będą mogli wysyłać nowych wstępnych próśb.",
        "pre_wishes_resume_confirm_title": "Wznowić wstępne prośby?",
        "pre_wishes_resume_confirm_body": "Goście znów będą mogli wysyłać wstępne prośby (do 6 godzin przed rozpoczęciem).",
        "pre_wishes_paused_success": "Wstępne prośby wstrzymane.",
        "pre_wishes_resumed_success": "Wstępne prośby wznowione.",
    },
    "cs": {
        "pre_wishes_paused_guest_message": "Předběžné požadavky již nelze odesílat.",
        "party_allow_pre_wishes_cannot_disable": "Předběžné požadavky byly aktivovány a nelze je již vypnout.",
        "pre_wishes_pause": "Pozastavit",
        "pre_wishes_resume": "Obnovit",
        "pre_wishes_pause_confirm_title": "Pozastavit předběžné požadavky?",
        "pre_wishes_pause_confirm_body": "Hosté již nebudou moci odesílat nové předběžné požadavky.",
        "pre_wishes_resume_confirm_title": "Obnovit předběžné požadavky?",
        "pre_wishes_resume_confirm_body": "Hosté budou moci znovu odesílat předběžné požadavky (do 6 hodin před začátkem).",
        "pre_wishes_paused_success": "Předběžné požadavky pozastaveny.",
        "pre_wishes_resumed_success": "Předběžné požadavky obnoveny.",
    },
    "uk": {
        "pre_wishes_paused_guest_message": "Попередні заявки більше не можна надсилати.",
        "party_allow_pre_wishes_cannot_disable": "Попередні заявки вже увімкнено — їх не можна вимкнути.",
        "pre_wishes_pause": "Пауза",
        "pre_wishes_resume": "Продовжити",
        "pre_wishes_pause_confirm_title": "Призупинити попередні заявки?",
        "pre_wishes_pause_confirm_body": "Гості більше не зможуть надсилати нові попередні заявки.",
        "pre_wishes_resume_confirm_title": "Відновити попередні заявки?",
        "pre_wishes_resume_confirm_body": "Гості знову зможуть надсилати попередні заявки (до 6 годин до початку).",
        "pre_wishes_paused_success": "Попередні заявки призупинено.",
        "pre_wishes_resumed_success": "Попередні заявки відновлено.",
    },
    "ru": {
        "pre_wishes_paused_guest_message": "Предварительные заявки больше нельзя отправить.",
        "party_allow_pre_wishes_cannot_disable": "Предварительные заявки включены и больше не отключаются.",
        "pre_wishes_pause": "Пауза",
        "pre_wishes_resume": "Продолжить",
        "pre_wishes_pause_confirm_title": "Приостановить предварительные заявки?",
        "pre_wishes_pause_confirm_body": "Гости больше не смогут отправлять новые предварительные заявки.",
        "pre_wishes_resume_confirm_title": "Возобновить предварительные заявки?",
        "pre_wishes_resume_confirm_body": "Гости снова смогут отправлять предварительные заявки (до 6 часов до начала).",
        "pre_wishes_paused_success": "Предварительные заявки приостановлены.",
        "pre_wishes_resumed_success": "Предварительные заявки возобновлены.",
    },
    "tr": {
        "pre_wishes_paused_guest_message": "Ön talepler artık gönderilemez.",
        "party_allow_pre_wishes_cannot_disable": "Ön talepler etkinleştirildi ve artık kapatılamaz.",
        "pre_wishes_pause": "Duraklat",
        "pre_wishes_resume": "Sürdür",
        "pre_wishes_pause_confirm_title": "Ön talepler duraklatılsın mı?",
        "pre_wishes_pause_confirm_body": "Konuklar artık yeni ön talep gönderemez.",
        "pre_wishes_resume_confirm_title": "Ön talepler sürdürülsün mü?",
        "pre_wishes_resume_confirm_body": "Konuklar tekrar ön talep gönderebilir (parti başlamadan 6 saat öncesine kadar).",
        "pre_wishes_paused_success": "Ön talepler duraklatıldı.",
        "pre_wishes_resumed_success": "Ön talepler sürdürüldü.",
    },
    "ja": {
        "pre_wishes_paused_guest_message": "事前リクエストはこれ以上送信できません。",
        "party_allow_pre_wishes_cannot_disable": "事前リクエストは有効化済みで、オフにできません。",
        "pre_wishes_pause": "一時停止",
        "pre_wishes_resume": "再開",
        "pre_wishes_pause_confirm_title": "事前リクエストを一時停止しますか？",
        "pre_wishes_pause_confirm_body": "ゲストは新しい事前リクエストを送信できなくなります。",
        "pre_wishes_resume_confirm_title": "事前リクエストを再開しますか？",
        "pre_wishes_resume_confirm_body": "ゲストは再び事前リクエストを送信できます（開始6時間前まで）。",
        "pre_wishes_paused_success": "事前リクエストを一時停止しました。",
        "pre_wishes_resumed_success": "事前リクエストを再開しました。",
    },
    "el": {
        "pre_wishes_paused_guest_message": "Τα εκ των προτέρων αιτήματα δεν μπορούν πλέον να υποβληθούν.",
        "party_allow_pre_wishes_cannot_disable": "Τα εκ των προτέρων αιτήματα ενεργοποιήθηκαν και δεν μπορούν να απενεργοποιηθούν.",
        "pre_wishes_pause": "Παύση",
        "pre_wishes_resume": "Συνέχεια",
        "pre_wishes_pause_confirm_title": "Παύση εκ των προτέρων αιτημάτων;",
        "pre_wishes_pause_confirm_body": "Οι καλεσμένοι δεν θα μπορούν να στείλουν νέα εκ των προτέρων αιτήματα.",
        "pre_wishes_resume_confirm_title": "Συνέχεια εκ των προτέρων αιτημάτων;",
        "pre_wishes_resume_confirm_body": "Οι καλεσμένοι θα μπορούν ξανά να στείλουν εκ των προτέρων αιτήματα (έως 6 ώρες πριν την έναρξη).",
        "pre_wishes_paused_success": "Τα εκ των προτέρων αιτήματα τέθηκαν σε παύση.",
        "pre_wishes_resumed_success": "Τα εκ των προτέρων αιτήματα συνεχίστηκαν.",
    },
    "ar": {
        "pre_wishes_paused_guest_message": "لم يعد بإمكانك إرسال طلبات مسبقة.",
        "party_allow_pre_wishes_cannot_disable": "تم تفعيل الطلبات المسبقة ولا يمكن إيقافها.",
        "pre_wishes_pause": "إيقاف مؤقت",
        "pre_wishes_resume": "استئناف",
        "pre_wishes_pause_confirm_title": "إيقاف الطلبات المسبقة مؤقتًا؟",
        "pre_wishes_pause_confirm_body": "لن يتمكن الضيوف من إرسال طلبات مسبقة جديدة.",
        "pre_wishes_resume_confirm_title": "استئناف الطلبات المسبقة؟",
        "pre_wishes_resume_confirm_body": "يمكن للضيوف إرسال طلبات مسبقة مرة أخرى (حتى 6 ساعات قبل البدء).",
        "pre_wishes_paused_success": "تم إيقاف الطلبات المسبقة مؤقتًا.",
        "pre_wishes_resumed_success": "تم استئناف الطلبات المسبقة.",
    },
    "vi": {
        "pre_wishes_paused_guest_message": "Không thể gửi thêm yêu cầu trước.",
        "party_allow_pre_wishes_cannot_disable": "Yêu cầu trước đã được bật và không thể tắt.",
        "pre_wishes_pause": "Tạm dừng",
        "pre_wishes_resume": "Tiếp tục",
        "pre_wishes_pause_confirm_title": "Tạm dừng yêu cầu trước?",
        "pre_wishes_pause_confirm_body": "Khách sẽ không thể gửi yêu cầu trước mới.",
        "pre_wishes_resume_confirm_title": "Tiếp tục yêu cầu trước?",
        "pre_wishes_resume_confirm_body": "Khách có thể gửi yêu cầu trước trở lại (đến 6 giờ trước khi bắt đầu).",
        "pre_wishes_paused_success": "Đã tạm dừng yêu cầu trước.",
        "pre_wishes_resumed_success": "Đã tiếp tục yêu cầu trước.",
    },
    "zh": {
        "pre_wishes_paused_guest_message": "无法再提交预先请求。",
        "party_allow_pre_wishes_cannot_disable": "预先请求已启用，无法关闭。",
        "pre_wishes_pause": "暂停",
        "pre_wishes_resume": "继续",
        "pre_wishes_pause_confirm_title": "暂停预先请求？",
        "pre_wishes_pause_confirm_body": "客人将无法再提交新的预先请求。",
        "pre_wishes_resume_confirm_title": "继续预先请求？",
        "pre_wishes_resume_confirm_body": "客人可以再次提交预先请求（至开始前 6 小时）。",
        "pre_wishes_paused_success": "预先请求已暂停。",
        "pre_wishes_resumed_success": "预先请求已继续。",
    },
    "hi": {
        "pre_wishes_paused_guest_message": "अब अग्रिम अनुरोध नहीं भेजे जा सकते।",
        "party_allow_pre_wishes_cannot_disable": "अग्रिम अनुरोध सक्षम हैं और अब बंद नहीं किए जा सकते।",
        "pre_wishes_pause": "रोकें",
        "pre_wishes_resume": "जारी रखें",
        "pre_wishes_pause_confirm_title": "अग्रिम अनुरोध रोकें?",
        "pre_wishes_pause_confirm_body": "मेहमान नए अग्रिम अनुरोध नहीं भेज पाएंगे।",
        "pre_wishes_resume_confirm_title": "अग्रिम अनुरोध जारी रखें?",
        "pre_wishes_resume_confirm_body": "मेहमान फिर अग्रिम अनुरोध भेज सकेंगे (शुरू होने से 6 घंटे पहले तक)।",
        "pre_wishes_paused_success": "अग्रिम अनुरोध रोक दिए गए।",
        "pre_wishes_resumed_success": "अग्रिम अनुरोध फिर शुरू।",
    },
    "sq": {
        "pre_wishes_paused_guest_message": "Kërkesat paraprake nuk mund të dërgohen më.",
        "party_allow_pre_wishes_cannot_disable": "Kërkesat paraprake janë aktivizuar dhe nuk mund të çaktivizohen.",
        "pre_wishes_pause": "Pauzë",
        "pre_wishes_resume": "Vazhdo",
        "pre_wishes_pause_confirm_title": "Të vendosen në pauzë kërkesat paraprake?",
        "pre_wishes_pause_confirm_body": "Mysafirët nuk do të mund të dërgojnë kërkesa të reja paraprake.",
        "pre_wishes_resume_confirm_title": "Të vazhdojnë kërkesat paraprake?",
        "pre_wishes_resume_confirm_body": "Mysafirët mund të dërgojnë përsëri kërkesa paraprake (deri 6 orë para fillimit).",
        "pre_wishes_paused_success": "Kërkesat paraprake u vendosën në pauzë.",
        "pre_wishes_resumed_success": "Kërkesat paraprake u vazhduan.",
    },
    "th": {
        "pre_wishes_paused_guest_message": "ไม่สามารถส่งคำขอล่วงหน้าได้อีก",
        "party_allow_pre_wishes_cannot_disable": "เปิดใช้คำขอล่วงหน้าแล้ว และไม่สามารถปิดได้",
        "pre_wishes_pause": "หยุดชั่วคราว",
        "pre_wishes_resume": "ดำเนินต่อ",
        "pre_wishes_pause_confirm_title": "หยุดคำขอล่วงหน้าชั่วคราว?",
        "pre_wishes_pause_confirm_body": "แขกจะไม่สามารถส่งคำขอล่วงหน้าใหม่ได้",
        "pre_wishes_resume_confirm_title": "ดำเนินคำขอล่วงหน้าต่อ?",
        "pre_wishes_resume_confirm_body": "แขกสามารถส่งคำขอล่วงหน้าได้อีกครั้ง (จนถึง 6 ชั่วโมงก่อนเริ่มงาน)",
        "pre_wishes_paused_success": "หยุดคำขอล่วงหน้าชั่วคราวแล้ว",
        "pre_wishes_resumed_success": "ดำเนินคำขอล่วงหน้าต่อแล้ว",
    },
}


def patch_json_file(path: Path, tr: dict[str, str], fallback: dict[str, str]) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    for key in KEYS:
        data[key] = tr.get(key, fallback[key])
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


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
        print(f"ARB OK {arb_path.name}")

    for json_path in sorted(BABEL.glob("*.json")):
        locale = json_path.stem
        tr = TRANSLATIONS.get(locale, en)
        patch_json_file(json_path, tr, en)
        print(f"Babel OK {json_path.name}")


if __name__ == "__main__":
    main()
