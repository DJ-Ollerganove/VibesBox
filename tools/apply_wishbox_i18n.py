# -*- coding: utf-8 -*-
"""
Wendet translation_glossary.json (wishbox_term) + feste UI-Sätze auf
lib/l10n/app_localizations_*.dart und public/vb/lang/*.js an.

Ausführen (Projektroot):
  python tools/apply_wishbox_i18n.py
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GLOSSARY_PATH = ROOT / "translation_glossary.json"


def dart_enc(s: str) -> str:
    return (
        s.replace("\\", "\\\\")
        .replace("$", r"\$")
        .replace("'", "\\'")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
    )


def js_enc(s: str) -> str:
    return (
        s.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
    )


def replace_dart_map_value(content: str, key: str, logical: str) -> tuple[str, bool]:
    enc = dart_enc(logical)
    pat_ml = re.compile(
        rf"^([ \t]*'{re.escape(key)}':[ \t]*\n[ \t]*)'(?:\\.|[^'\\])*'([ \t]*,)[ \t]*$",
        re.MULTILINE,
    )
    m = pat_ml.search(content)
    if m:
        new = content[: m.start()] + m.group(1) + f"'{enc}'" + m.group(2) + content[m.end() :]
        return new, True
    pat_sl = re.compile(
        rf"^([ \t]*'{re.escape(key)}':[ \t]*)'(?:\\.|[^'\\])*'([ \t]*,)[ \t]*$",
        re.MULTILINE,
    )
    m = pat_sl.search(content)
    if m:
        new = content[: m.start()] + m.group(1) + f"'{enc}'" + m.group(2) + content[m.end() :]
        return new, True
    return content, False


def replace_js_value(content: str, key: str, logical: str) -> tuple[str, bool]:
    enc = js_enc(logical)
    pat = re.compile(
        rf"^([ \t]*'{re.escape(key)}':[ \t]*)'(?:\\.|[^'\\])*'(\s*,\s*)?(\s*//[^\n]*)?$",
        re.MULTILINE,
    )
    m = pat.search(content)
    if m:
        suffix = (m.group(2) or "") + (m.group(3) or "")
        new = content[: m.start()] + m.group(1) + f"'{enc}'" + suffix + content[m.end() :]
        return new, True
    return content, False


def load_terms() -> dict[str, str]:
    data = json.loads(GLOSSARY_PATH.read_text(encoding="utf-8"))
    return dict(data.get("wishbox_term") or {})


def flutter_messages(t: dict[str, str]) -> dict[str, dict[str, str]]:
    """t: locale -> Kurzbegriff aus Glossar."""
    en = t["en"]
    return {
        "en": {
            "wishbox": en,
            "wishbox_inactive_description": "Music requests are not available right now. They are only available during the party or when manually enabled.",
            "wish_blocked_body": "Since the last messages didn’t quite match the party vibe, music requests are currently closed for you. See you on the dancefloor!",
            "wishbox_blocked_message": "Since the last messages didn't quite match the vibe of the party, music requests are currently closed for you. See you on the dancefloor!",
            "user_blocked_message": "You are blocked for this party. Music requests are disabled.",
            "guest_banned_notice": "You are blocked for this party. Music requests are disabled.",
            "wishbox_paused": "Music requests paused",
            "wishbox_resumed": "Music requests resumed",
            "feature_dj_wishbox": "Auto-clearing song requests",
            "dialog_wishbox_confirm_pause": "Pause music requests?",
            "dialog_wishbox_confirm_resume": "Resume music requests?",
            "wishbox_pause_confirm_resume": 'Really resume music requests for "{partyName}"?',
            "wishbox_pause_confirm_pause": 'Really pause music requests for "{partyName}"? Guests will no longer be able to submit requests.',
        },
        "fr": {
            "wishbox": t["fr"],
            "wishbox_inactive_description": "Les demandes musicales ne sont pas actives pour le moment. Elles ne sont disponibles que pendant la soirée ou lorsqu’elles ont été activées manuellement.",
            "wish_blocked_body": "Comme les derniers messages ne correspondaient pas tout à fait à l’ambiance de la soirée, les demandes musicales sont momentanément fermées pour toi. On se voit sur le dancefloor !",
            "wishbox_blocked_message": "Comme les derniers messages ne correspondaient pas tout à fait à l’ambiance de la soirée, les demandes musicales sont momentanément fermées pour toi. On se voit sur le dancefloor !",
            "user_blocked_message": "Tu es bloqué pour cette soirée. Les demandes musicales sont désactivées.",
            "guest_banned_notice": "Tu es bloqué pour cette soirée. Les demandes musicales sont désactivées.",
            "wishbox_paused": "Demandes musicales en pause",
            "wishbox_resumed": "Demandes musicales reprises",
            "feature_dj_wishbox": "Demandes musicales avec effacement automatique",
            "dialog_wishbox_confirm_pause": "Mettre en pause les demandes musicales ?",
            "dialog_wishbox_confirm_resume": "Reprendre les demandes musicales ?",
            "wishbox_pause_confirm_resume": "Voulez-vous vraiment reprendre les demandes musicales pour « {partyName} » ?",
            "wishbox_pause_confirm_pause": "Voulez-vous vraiment mettre en pause les demandes musicales pour « {partyName} » ? Les invités ne pourront plus envoyer de demandes.",
        },
        "es": {
            "wishbox": t["es"],
            "wishbox_inactive_description": "Las peticiones musicales no están activas en este momento. Solo están disponibles durante la fiesta o cuando se activan manualmente.",
            "wish_blocked_body": "Como los últimos mensajes no encajaban del todo con el ambiente de la fiesta, las peticiones musicales están cerradas por ahora. ¡Nos vemos en la pista de baile!",
            "wishbox_blocked_message": "Como los últimos mensajes no encajaban del todo con el ambiente de la fiesta, las peticiones musicales están cerradas por ahora. ¡Nos vemos en la pista de baile!",
            "user_blocked_message": "Estás bloqueado para esta fiesta. Las peticiones musicales están desactivadas.",
            "guest_banned_notice": "Estás bloqueado para esta fiesta. Las peticiones musicales están desactivadas.",
            "wishbox_paused": "Peticiones musicales en pausa",
            "wishbox_resumed": "Peticiones musicales reanudadas",
            "feature_dj_wishbox": "Peticiones musicales con vaciado automático",
            "dialog_wishbox_confirm_pause": "¿Pausar las peticiones musicales?",
            "dialog_wishbox_confirm_resume": "¿Reanudar las peticiones musicales?",
            "wishbox_pause_confirm_resume": "¿Reanudar las peticiones musicales para «{partyName}»?",
            "wishbox_pause_confirm_pause": "¿Pausar las peticiones musicales para «{partyName}»? Los invitados ya no podrán enviar peticiones.",
        },
        "it": {
            "wishbox": t["it"],
            "wishbox_inactive_description": "Le richieste musicali non sono attive al momento. Sono disponibili solo durante la festa o se abilitate manualmente.",
            "wish_blocked_body": "Poiché gli ultimi messaggi non erano del tutto in linea con l’atmosfera della festa, le richieste musicali sono temporaneamente chiuse per te. Ci vediamo in pista!",
            "wishbox_blocked_message": "Poiché gli ultimi messaggi non erano del tutto in linea con l’atmosfera della festa, le richieste musicali sono temporaneamente chiuse per te. Ci vediamo in pista!",
            "user_blocked_message": "Sei bloccato per questa festa. Le richieste musicali sono disattivate.",
            "guest_banned_notice": "Sei bloccato per questa festa. Le richieste musicali sono disattivate.",
            "wishbox_paused": "Richieste musicali in pausa",
            "wishbox_resumed": "Richieste musicali riattivate",
            "feature_dj_wishbox": "Richieste musicali con svuotamento automatico",
            "dialog_wishbox_confirm_pause": "Mettere in pausa le richieste musicali?",
            "dialog_wishbox_confirm_resume": "Riprendere le richieste musicali?",
            "wishbox_pause_confirm_resume": "Riprendere davvero le richieste musicali per «{partyName}»?",
            "wishbox_pause_confirm_pause": "Mettere davvero in pausa le richieste musicali per «{partyName}»? Gli ospiti non potranno più inviare richieste.",
        },
        "pt": {
            "wishbox": t["pt"],
            "wishbox_inactive_description": "Os pedidos de música não estão ativos no momento. Estão disponíveis apenas durante a festa ou quando ativados manualmente.",
            "wish_blocked_body": "Como as últimas mensagens não combinaram muito com o clima da festa, os pedidos de música estão fechados para você no momento. Nos vemos na pista de dança!",
            "wishbox_blocked_message": "Como as últimas mensagens não combinaram muito com o clima da festa, os pedidos de música estão fechados para você no momento. Nos vemos na pista de dança!",
            "user_blocked_message": "Você está bloqueado para esta festa. Os pedidos de música estão desativados.",
            "guest_banned_notice": "Você está bloqueado para esta festa. Os pedidos de música estão desativados.",
            "wishbox_paused": "Pedidos de música pausados",
            "wishbox_resumed": "Pedidos de música retomados",
            "feature_dj_wishbox": "Pedidos de música com esvaziamento automático",
            "dialog_wishbox_confirm_pause": "Pausar os pedidos de música?",
            "dialog_wishbox_confirm_resume": "Retomar os pedidos de música?",
            "wishbox_pause_confirm_resume": "Retomar os pedidos de música para «{partyName}»?",
            "wishbox_pause_confirm_pause": "Pausar os pedidos de música para «{partyName}»? Convidados não poderão enviar pedidos.",
        },
        "ru": {
            "wishbox": t["ru"],
            "wishbox_inactive_description": "Музыкальные заявки сейчас неактивны. Они доступны только во время вечеринки или при ручном включении.",
            "wish_blocked_body": "Так как последние сообщения не совсем соответствовали атмосфере вечеринки, музыкальные заявки для вас временно закрыты. Увидимся на танцполе!",
            "wishbox_blocked_message": "Так как последние сообщения не совсем соответствовали атмосфере вечеринки, музыкальные заявки для вас временно закрыты. Увидимся на танцполе!",
            "user_blocked_message": "Вы заблокированы для этой вечеринки. Музыкальные заявки отключены.",
            "guest_banned_notice": "Вы заблокированы для этой вечеринки. Музыкальные заявки отключены.",
            "wishbox_paused": "Музыкальные заявки на паузе",
            "wishbox_resumed": "Музыкальные заявки возобновлены",
            "feature_dj_wishbox": "Музыкальные заявки с автоочисткой",
            "dialog_wishbox_confirm_pause": "Приостановить музыкальные заявки?",
            "dialog_wishbox_confirm_resume": "Возобновить музыкальные заявки?",
            "wishbox_pause_confirm_resume": "Возобновить музыкальные заявки для «{partyName}»?",
            "wishbox_pause_confirm_pause": "Приостановить музыкальные заявки для «{partyName}»? Гости не смогут отправлять заявки.",
        },
        "uk": {
            "wishbox": t["uk"],
            "wishbox_inactive_description": "Музичні запити зараз неактивні. Вони доступні лише під час вечірки або коли ввімкнено вручну.",
            "wish_blocked_body": "Оскільки останні повідомлення не зовсім відповідали атмосфері вечірки, музичні запити для вас тимчасово закриті. До зустрічі на танцмайданчику!",
            "wishbox_blocked_message": "Оскільки останні повідомлення не зовсім відповідали атмосфері вечірки, музичні запити для вас тимчасово закриті. До зустрічі на танцмайданчику!",
            "user_blocked_message": "Ви заблоковані для цієї вечірки. Музичні запити вимкнено.",
            "guest_banned_notice": "Ви заблоковані для цієї вечірки. Музичні запити вимкнено.",
            "wishbox_paused": "Музичні запити на паузі",
            "wishbox_resumed": "Музичні запити відновлено",
            "feature_dj_wishbox": "Музичні запити з автоочищенням",
            "dialog_wishbox_confirm_pause": "Призупинити музичні запити?",
            "dialog_wishbox_confirm_resume": "Відновити музичні запити?",
            "wishbox_pause_confirm_resume": "Справді відновити музичні запити для «{partyName}»?",
            "wishbox_pause_confirm_pause": "Справді призупинити музичні запити для «{partyName}»? Гості не зможуть надсилати запити.",
        },
        "tr": {
            "wishbox": t["tr"],
            "wishbox_inactive_description": "Müzik istekleri şu anda etkin değil. Yalnızca parti sırasında veya elle etkinleştirildiğinde kullanılabilir.",
            "wish_blocked_body": "Son mesajlar parti havasına pek uymadığı için müzik istekleri şu anda sizin için kapalı. Dans pistinde görüşürüz!",
            "wishbox_blocked_message": "Son mesajlar parti havasına pek uymadığı için müzik istekleri şu anda sizin için kapalı. Dans pistinde görüşürüz!",
            "user_blocked_message": "Bu parti için engellendiniz. Müzik istekleri devre dışı.",
            "guest_banned_notice": "Bu parti için engellendiniz. Müzik istekleri devre dışı.",
            "wishbox_paused": "Müzik istekleri duraklatıldı",
            "wishbox_resumed": "Müzik istekleri sürdürülüyor",
            "feature_dj_wishbox": "Otomatik temizlenen müzik istekleri",
            "dialog_wishbox_confirm_pause": "Müzik istekleri duraklatılsın mı?",
            "dialog_wishbox_confirm_resume": "Müzik istekleri sürdürülsün mü?",
            "wishbox_pause_confirm_resume": "«{partyName}» için müzik istekleri sürdürülsün mü?",
            "wishbox_pause_confirm_pause": "«{partyName}» için müzik istekleri duraklatılsın mı? Misafirler istek gönderemez.",
        },
        "zh": {
            "wishbox": t["zh"],
            "wishbox_inactive_description": "点歌当前未启用。仅在派对进行期间或手动开启时可用。",
            "wish_blocked_body": "由于最近的留言不太符合派对氛围，点歌功能暂时对你关闭。舞池见！",
            "wishbox_blocked_message": "由于最近的留言不太符合派对氛围，点歌功能暂时对你关闭。舞池见！",
            "user_blocked_message": "你在此派对上已被屏蔽，点歌功能已关闭。",
            "guest_banned_notice": "你在此派对上已被屏蔽，点歌功能已关闭。",
            "wishbox_paused": "点歌已暂停",
            "wishbox_resumed": "点歌已恢复",
            "feature_dj_wishbox": "点歌列表自动清空",
            "dialog_wishbox_confirm_pause": "暂停点歌？",
            "dialog_wishbox_confirm_resume": "恢复点歌？",
            "wishbox_pause_confirm_resume": "确定要恢复「{partyName}」的点歌吗？",
            "wishbox_pause_confirm_pause": "确定要暂停「{partyName}」的点歌吗？访客将无法再提交请求。",
        },
        "ar": {
            "wishbox": t["ar"],
            "wishbox_inactive_description": "الطلبات الموسيقية غير نشطة حاليًا. تتوفر فقط أثناء الحفلة أو عند تفعيلها يدويًا.",
            "wish_blocked_body": "لأن الرسائل الأخيرة لم تكن متوافقة تمامًا مع أجواء الحفلة، فإن الطلبات الموسيقية مغلقة لك حاليًا. نراك على حلبة الرقص!",
            "wishbox_blocked_message": "لأن الرسائل الأخيرة لم تكن متوافقة تمامًا مع أجواء الحفلة، فإن الطلبات الموسيقية مغلقة لك حاليًا. نراك على حلبة الرقص!",
            "user_blocked_message": "أنت محظور لهذه الحفلة. الطلبات الموسيقية معطّلة.",
            "guest_banned_notice": "أنت محظور لهذه الحفلة. الطلبات الموسيقية معطّلة.",
            "wishbox_paused": "الطلبات الموسيقية متوقفة مؤقتًا",
            "wishbox_resumed": "الطلبات الموسيقية مستأنفة",
            "feature_dj_wishbox": "طلبات موسيقية تُفرغ تلقائيًا",
            "dialog_wishbox_confirm_pause": "إيقاف الطلبات الموسيقية مؤقتًا؟",
            "dialog_wishbox_confirm_resume": "استئناف الطلبات الموسيقية؟",
            "wishbox_pause_confirm_resume": "استئناف الطلبات الموسيقية لـ «{partyName}»؟",
            "wishbox_pause_confirm_pause": "إيقاف الطلبات الموسيقية لـ «{partyName}» مؤقتًا؟ لن يتمكن الضيوف من إرسال طلبات.",
        },
    }


def pwa_messages(t: dict[str, str]) -> dict[str, dict[str, str]]:
    """Kurztexte Gäste-PWA (en.js-Logik, pro Sprache)."""
    return {
        "en": {
            "wishbox_inactive": "Music requests are currently inactive.",
            "wishbox_inactive_info": "If you want to submit a music request at the party, please log in with the party code or scan the QR code on site.",
            "wishbox_blocked_message": "Since the last messages didn't quite match the vibe of the party, music requests are currently closed for you. See you on the dancefloor!",
            "user_blocked_message": "You are blocked for this party. Music requests are disabled.",
            "user_banned_msg": "Your access to music requests has been blocked. Please contact the DJ for more information.",
            "error_wishbox_inactive": "Music requests are currently not active. Please try again later.",
            "settings_duplicate_intro": "These values control duplicate detection for song requests. Stored in party_settings/current.",
            "main_overlay_btn_submit": "To music requests",
            "pre_party_subtitle": "Music requests will be unlocked automatically",
        },
        "de": {
            "wishbox_inactive": "Wunschbox derzeit inaktiv.",
            "wishbox_inactive_info": "Wenn du auf der Party einen Musikwunsch absenden möchtest, logge dich bitte mit dem Party-Code ein oder scanne den QR-Code vor Ort.",
            "wishbox_blocked_message": "Da die letzten Nachrichten nicht ganz zum Vibe der Party gepasst haben, ist die Wunschbox für dich aktuell geschlossen. Wir sehen uns auf dem Dancefloor!",
            "user_blocked_message": "Du bist für diese Party gesperrt. Die Wunschbox ist deaktiviert.",
            "user_banned_msg": "Dein Zugriff auf die Wunschbox wurde gesperrt. Bitte kontaktiere den DJ für weitere Informationen.",
            "error_wishbox_inactive": "Die Wunschbox ist derzeit nicht aktiv. Bitte versuche es später erneut.",
            "settings_duplicate_intro": "Diese Werte steuern die Duplikat-Erkennung für Musikwünsche (Wunschbox). Gespeichert in party_settings/current.",
            "main_overlay_btn_submit": "Zur Wunschbox",
            "pre_party_subtitle": "Die Wunschbox wird automatisch freigeschaltet",
        },
        "fr": {
            "wishbox_inactive": "Demandes musicales actuellement inactives.",
            "wishbox_inactive_info": "Si vous souhaitez envoyer une demande musicale à la fête, connectez-vous avec le code ou scannez le QR code sur place.",
            "wishbox_blocked_message": "Comme les derniers messages ne correspondaient pas tout à fait à l'ambiance de la fête, les demandes musicales sont actuellement fermées pour vous. À bientôt sur la piste de danse !",
            "user_blocked_message": "Vous êtes bloqué pour cette fête. Les demandes musicales sont désactivées.",
            "user_banned_msg": "Votre accès aux demandes musicales a été bloqué. Contactez le DJ pour plus d'informations.",
            "error_wishbox_inactive": "Les demandes musicales ne sont pas actives pour le moment. Veuillez réessayer plus tard.",
            "settings_duplicate_intro": "Ces valeurs contrôlent la détection des doublons pour les demandes de titres. Stocké dans party_settings/current.",
            "main_overlay_btn_submit": "Vers les demandes musicales",
            "pre_party_subtitle": "Les demandes musicales seront débloquées automatiquement",
        },
        "es": {
            "wishbox_inactive": "Peticiones musicales inactivas por ahora.",
            "wishbox_inactive_info": "Si quieres enviar una petición musical en la fiesta, inicia sesión con el código o escanea el código QR en el lugar.",
            "wishbox_blocked_message": "Como los últimos mensajes no encajaban del todo con el ambiente de la fiesta, las peticiones musicales están cerradas para ti. ¡Nos vemos en la pista!",
            "user_blocked_message": "Estás bloqueado para esta fiesta. Las peticiones musicales están desactivadas.",
            "user_banned_msg": "Se ha bloqueado tu acceso a las peticiones musicales. Contacta al DJ para más información.",
            "error_wishbox_inactive": "Las peticiones musicales no están activas. Inténtalo más tarde.",
            "settings_duplicate_intro": "Estos valores controlan la detección de duplicados en las peticiones de canciones. Guardado en party_settings/current.",
            "main_overlay_btn_submit": "A las peticiones musicales",
            "pre_party_subtitle": "Las peticiones musicales se desbloquearán automáticamente",
        },
        "it": {
            "wishbox_inactive": "Richieste musicali attualmente non attive.",
            "wishbox_inactive_info": "Se desideri inviare una richiesta musicale alla festa, accedi con il codice festa o scansiona il codice QR sul posto.",
            "wishbox_blocked_message": "Poiché gli ultimi messaggi non erano del tutto in linea con l’atmosfera della festa, le richieste musicali sono chiuse per te. Ci vediamo in pista!",
            "user_blocked_message": "Sei bloccato per questa festa. Le richieste musicali sono disattivate.",
            "user_banned_msg": "L’accesso alle richieste musicali è stato bloccato. Contatta il DJ per maggiori informazioni.",
            "error_wishbox_inactive": "Le richieste musicali non sono attive. Riprova più tardi.",
            "settings_duplicate_intro": "Questi valori controllano il rilevamento dei duplicati per le richieste di brani. Memorizzato in party_settings/current.",
            "main_overlay_btn_submit": "Alle richieste musicali",
            "pre_party_subtitle": "Le richieste musicali si sbloccheranno automaticamente",
        },
        "pt": {
            "wishbox_inactive": "Pedidos de música inativos no momento.",
            "wishbox_inactive_info": "Se quiser enviar um pedido musical na festa, faça login com o código ou escaneie o QR code no local.",
            "wishbox_blocked_message": "Como as últimas mensagens não combinaram com o clima da festa, os pedidos de música estão fechados para você. Nos vemos na pista!",
            "user_blocked_message": "Você está bloqueado para esta festa. Os pedidos de música estão desativados.",
            "user_banned_msg": "Seu acesso aos pedidos de música foi bloqueado. Entre em contato com o DJ.",
            "error_wishbox_inactive": "Os pedidos de música não estão ativos. Tente novamente mais tarde.",
            "settings_duplicate_intro": "Estes valores controlam a detecção de duplicatas nos pedidos de músicas. Armazenado em party_settings/current.",
            "main_overlay_btn_submit": "Aos pedidos de música",
            "pre_party_subtitle": "Os pedidos de música serão desbloqueados automaticamente",
        },
        "ru": {
            "wishbox_inactive": "Музыкальные заявки сейчас неактивны.",
            "wishbox_inactive_info": "Чтобы отправить музыкальный запрос на вечеринке, войдите по коду или отсканируйте QR-код на месте.",
            "wishbox_blocked_message": "Так как последние сообщения не совсем подходили к атмосфере вечеринки, музыкальные заявки для вас закрыты. Увидимся на танцполе!",
            "user_blocked_message": "Вы заблокированы для этой вечеринки. Музыкальные заявки отключены.",
            "user_banned_msg": "Доступ к музыкальным заявкам заблокирован. Свяжитесь с DJ.",
            "error_wishbox_inactive": "Музыкальные заявки неактивны. Попробуйте позже.",
            "settings_duplicate_intro": "Эти значения управляют обнаружением дубликатов музыкальных заявок. Хранится в party_settings/current.",
            "main_overlay_btn_submit": "К музыкальным заявкам",
            "pre_party_subtitle": "Музыкальные заявки откроются автоматически",
        },
        "uk": {
            "wishbox_inactive": "Музичні запити зараз неактивні.",
            "wishbox_inactive_info": "Якщо ви хочете надіслати музичний запит на вечірці, увійдіть за допомогою коду вечірки або відскануйте QR-код на місці.",
            "wishbox_blocked_message": "Оскільки останні повідомлення не зовсім відповідали атмосфері вечірки, музичні запити для вас закриті. До зустрічі на танцмайданчику!",
            "user_blocked_message": "Ви заблоковані для цієї вечірки. Музичні запити вимкнено.",
            "user_banned_msg": "Доступ до музичних запитів заблоковано. Зв’яжіться з DJ.",
            "error_wishbox_inactive": "Музичні запити неактивні. Спробуйте пізніше.",
            "settings_duplicate_intro": "Ці значення керують виявленням дублікатів музичних запитів. Зберігається в party_settings/current.",
            "main_overlay_btn_submit": "До музичних запитів",
            "pre_party_subtitle": "Музичні запити буде розблоковано автоматично",
        },
        "tr": {
            "wishbox_inactive": "Müzik istekleri şu anda etkin değil.",
            "wishbox_inactive_info": "Partide müzik isteği göndermek için parti koduyla giriş yapın veya yerinde QR kodunu tarayın.",
            "wishbox_blocked_message": "Son mesajlar parti havasına uymadığı için müzik istekleri sizin için kapalı. Dans pistinde görüşürüz!",
            "user_blocked_message": "Bu parti için engellendiniz. Müzik istekleri devre dışı.",
            "user_banned_msg": "Müzik isteklerine erişiminiz engellendi. Bilgi için DJ ile iletişime geçin.",
            "error_wishbox_inactive": "Müzik istekleri etkin değil. Daha sonra tekrar deneyin.",
            "settings_duplicate_intro": "Bu değerler şarkı istekleri için mükerrer tespitini kontrol eder. party_settings/current içinde saklanır.",
            "main_overlay_btn_submit": "Müzik isteklerine",
            "pre_party_subtitle": "Müzik istekleri otomatik olarak açılacak",
        },
        "zh": {
            "wishbox_inactive": "点歌当前未激活。",
            "wishbox_inactive_info": "若要在派对上提交点歌，请使用派对代码登录或扫描现场二维码。",
            "wishbox_blocked_message": "由于最近的留言不太符合派对氛围，点歌功能暂时对你关闭。舞池见！",
            "user_blocked_message": "你在此派对上已被屏蔽，点歌功能已关闭。",
            "user_banned_msg": "你的点歌权限已被屏蔽。请联系 DJ。",
            "error_wishbox_inactive": "点歌暂不可用，请稍后再试。",
            "settings_duplicate_intro": "这些值控制歌曲请求的重复检测。存储在 party_settings/current。",
            "main_overlay_btn_submit": "前往点歌",
            "pre_party_subtitle": "点歌将自动解锁",
        },
        "ar": {
            "wishbox_inactive": "الطلبات الموسيقية غير نشطة حاليًا.",
            "wishbox_inactive_info": "لإرسال طلب موسيقي في الحفلة، سجّل الدخول برمز الحفلة أو امسح رمز QR في الموقع.",
            "wishbox_blocked_message": "لأن الرسائل الأخيرة لم تكن متوافقة مع أجواء الحفلة، الطلبات الموسيقية مغلقة لك حاليًا. نراك على حلبة الرقص!",
            "user_blocked_message": "أنت محظور لهذه الحفلة. الطلبات الموسيقية معطّلة.",
            "user_banned_msg": "تم حظر وصولك إلى الطلبات الموسيقية. يُرجى التواصل مع الـ DJ.",
            "error_wishbox_inactive": "الطلبات الموسيقية غير نشطة. حاول لاحقًا.",
            "settings_duplicate_intro": "تتحكم هذه القيم في اكتشاف التكرار لطلبات الأغاني. مُخزَّنة في party_settings/current.",
            "main_overlay_btn_submit": "إلى الطلبات الموسيقية",
            "pre_party_subtitle": "سيتم فتح الطلبات الموسيقية تلقائيًا",
        },
    }


def patch_flutter(terms: dict[str, str]) -> None:
    fm = flutter_messages(terms)
    for loc, updates in fm.items():
        path = ROOT / "lib" / "l10n" / f"app_localizations_{loc}.dart"
        if not path.exists():
            print("skip missing", path)
            continue
        text = path.read_text(encoding="utf-8")
        for key, val in updates.items():
            text, ok = replace_dart_map_value(text, key, val)
            if not ok:
                print(f"WARN dart {loc} key missing or format: {key}")
        path.write_text(text, encoding="utf-8")
        print("patched", path.name)


def patch_pwa(terms: dict[str, str]) -> None:
    pm = pwa_messages(terms)
    lang_dir = ROOT / "public" / "vb" / "lang"
    for loc, updates in pm.items():
        path = lang_dir / f"{loc}.js"
        if not path.exists():
            print("skip missing", path)
            continue
        text = path.read_text(encoding="utf-8")
        for key, val in updates.items():
            text, ok = replace_js_value(text, key, val)
            if not ok:
                print(f"WARN js {loc} key missing: {key}")
        path.write_text(text, encoding="utf-8")
        print("patched", path.relative_to(ROOT))


def main() -> None:
    terms = load_terms()
    need = {"de", "en", "fr", "es", "it", "pt", "ru", "uk", "tr", "zh", "ar"}
    if not need.issubset(set(terms)):
        raise SystemExit(f"translation_glossary.json wishbox_term incomplete: {need - set(terms)}")
    patch_flutter(terms)
    patch_pwa(terms)
    print("Done.")


if __name__ == "__main__":
    main()
