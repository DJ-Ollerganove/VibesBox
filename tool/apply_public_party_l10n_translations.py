#!/usr/bin/env python3
"""Übersetzt öffentliche-Party-l10n-Keys in alle Sprachen (kein EN-Fallback)."""

import json
import re
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

KEYS = [
    "party_venue_overlap_info_body",
    "party_venue_overlap_dialog_title",
    "party_venue_overlap_dialog_intro",
    "party_venue_overlap_party_line",
    "party_venue_overlap_join_floor_question",
    "party_venue_overlap_decline_hint",
    "party_public_location_matched_title",
    "party_public_location_matched_own_title",
    "party_public_location_matched_body",
    "party_public_location_badge",
    "party_dj_fallback",
    "party_pre_wishes_public_unavailable",
    "party_save_permission_denied",
]

TRANSLATIONS: dict[str, dict[str, str]] = {
    "ar": {
        "party_venue_overlap_info_body": "يوجد DJ آخر يقيم حفلة في هذا المكان خلال فترتك الزمنية. اختر طابقًا شاغرًا أو أضف طابقًا جديدًا.",
        "party_venue_overlap_dialog_title": "تداخل في هذا المكان",
        "party_venue_overlap_dialog_intro": "خلال الفترة الزمنية التي اخترتها يوجد بالفعل:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "هل تريد الانضمام في طابق منفصل؟",
        "party_venue_overlap_decline_hint": "يُرجى تغيير وقت البدء/الانتهاء أو اختيار مكان آخر.",
        "party_public_location_matched_title": "مكان عام معروف",
        "party_public_location_matched_own_title": "مكانك المحفوظ",
        "party_public_location_matched_body": "يُستخدم رمز الحفلة الثابت المحفوظ لهذا المكان.",
        "party_public_location_badge": "عام",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "الأمنيات المسبقة غير متاحة للحفلات العامة.",
        "party_save_permission_denied": "فشل الحفظ: تم رفض الإذن. يُرجى المحاولة مرة أخرى أو إعادة تشغيل التطبيق.",
    },
    "cs": {
        "party_venue_overlap_info_body": "V tomto místě už v tvém časovém okně probíhá party jiného DJe. Vyber volný floor nebo přidej nový.",
        "party_venue_overlap_dialog_title": "Překrytí na tomto místě",
        "party_venue_overlap_dialog_intro": "Ve zvoleném časovém okně už probíhá:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Chceš se připojit na samostatný floor?",
        "party_venue_overlap_decline_hint": "Změň prosím začátek/konec nebo zvol jiné místo.",
        "party_public_location_matched_title": "Známé veřejné místo",
        "party_public_location_matched_own_title": "Tvé uložené místo",
        "party_public_location_matched_body": "Pro toto místo platí uložený fixní party kód.",
        "party_public_location_badge": "veřejné",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "U veřejných akcí nejsou předběžná přání k dispozici.",
        "party_save_permission_denied": "Uložení se nezdařilo: oprávnění odepřeno. Zkus to znovu nebo restartuj aplikaci.",
    },
    "el": {
        "party_venue_overlap_info_body": "Σε αυτόν τον χώρο, ένας άλλος DJ έχει ήδη πάρτι στο χρονικό σου διάστημα. Διάλεξε ένα ελεύθερο floor ή πρόσθεσε νέο.",
        "party_venue_overlap_dialog_title": "Επικάλυψη σε αυτόν τον χώρο",
        "party_venue_overlap_dialog_intro": "Στο επιλεγμένο χρονικό διάστημα υπάρχει ήδη:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Θέλεις να συνδεθείς σε ξεχωριστό floor;",
        "party_venue_overlap_decline_hint": "Άλλαξε την ώρα έναρξης/λήξης ή διάλεξε άλλο χώρο.",
        "party_public_location_matched_title": "Γνωστός δημόσιος χώρος",
        "party_public_location_matched_own_title": "Ο αποθηκευμένος χώρος σου",
        "party_public_location_matched_body": "Για αυτόν τον χώρο ισχύει ο αποθηκευμένος σταθερός κωδικός πάρτι.",
        "party_public_location_badge": "δημόσιος",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "Οι προκαταβολικές ευχές δεν είναι διαθέσιμες για δημόσιες εκδηλώσεις.",
        "party_save_permission_denied": "Αποτυχία αποθήκευσης: άρνηση άδειας. Δοκίμασε ξανά ή επανεκκίνησε την εφαρμογή.",
    },
    "es": {
        "party_venue_overlap_info_body": "En este lugar ya hay una fiesta de otro DJ en tu franja horaria. Elige un piso libre o añade uno nuevo.",
        "party_venue_overlap_dialog_title": "Solapamiento en este lugar",
        "party_venue_overlap_dialog_intro": "En la franja horaria seleccionada ya hay:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "¿Quieres unirte en un piso separado?",
        "party_venue_overlap_decline_hint": "Cambia la hora de inicio/fin o elige otro lugar.",
        "party_public_location_matched_title": "Lugar público conocido",
        "party_public_location_matched_own_title": "Tu lugar guardado",
        "party_public_location_matched_body": "Para este lugar se usa el código de fiesta fijo guardado.",
        "party_public_location_badge": "público",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "Los deseos anticipados no están disponibles para fiestas públicas.",
        "party_save_permission_denied": "Error al guardar: permiso denegado. Inténtalo de nuevo o reinicia la app.",
    },
    "fr": {
        "party_venue_overlap_info_body": "Un autre DJ a déjà une fête à cet endroit pendant ton créneau horaire. Choisis un étage libre ou ajoute-en un nouveau.",
        "party_venue_overlap_dialog_title": "Chevauchement à cet endroit",
        "party_venue_overlap_dialog_intro": "Pendant le créneau horaire sélectionné, il y a déjà :",
        "party_venue_overlap_party_line": "{partyName} ({djName}) : {start} – {end}",
        "party_venue_overlap_join_floor_question": "Veux-tu te joindre sur un étage séparé ?",
        "party_venue_overlap_decline_hint": "Modifie l'heure de début/fin ou choisis un autre endroit.",
        "party_public_location_matched_title": "Lieu public connu",
        "party_public_location_matched_own_title": "Ton lieu enregistré",
        "party_public_location_matched_body": "Ce lieu utilise le code de fête fixe enregistré.",
        "party_public_location_badge": "public",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "Les souhaits à l'avance ne sont pas disponibles pour les fêtes publiques.",
        "party_save_permission_denied": "Échec de l'enregistrement : autorisation refusée. Réessaie ou redémarre l'application.",
    },
    "hi": {
        "party_venue_overlap_info_body": "इस स्थान पर आपके समय स्लॉट में पहले से ही किसी अन्य DJ की पार्टी चल रही है। एक खाली फ़्लोर चुनें या नया जोड़ें।",
        "party_venue_overlap_dialog_title": "इस स्थान पर ओवरलैप",
        "party_venue_overlap_dialog_intro": "आपके चुने हुए समय स्लॉट में पहले से मौजूद है:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "क्या आप अलग फ़्लोर पर जुड़ना चाहते हैं?",
        "party_venue_overlap_decline_hint": "कृपया शुरू/समाप्ति समय बदलें या दूसरा स्थान चुनें।",
        "party_public_location_matched_title": "ज्ञात सार्वजनिक स्थान",
        "party_public_location_matched_own_title": "आपका सहेजा हुआ स्थान",
        "party_public_location_matched_body": "इस स्थान के लिए सहेजा गया निश्चित पार्टी कोड लागू होता है।",
        "party_public_location_badge": "सार्वजनिक",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "सार्वजनिक कार्यक्रमों के लिए पूर्व-इच्छाएँ उपलब्ध नहीं हैं।",
        "party_save_permission_denied": "सहेजना विफल: अनुमति अस्वीकृत। कृपया पुनः प्रयास करें या ऐप पुनः प्रारंभ करें।",
    },
    "it": {
        "party_venue_overlap_info_body": "In questo locale c'è già una festa di un altro DJ nella tua fascia oraria. Scegli un piano libero o aggiungine uno nuovo.",
        "party_venue_overlap_dialog_title": "Sovrapposizione in questo locale",
        "party_venue_overlap_dialog_intro": "Nella fascia oraria selezionata c'è già:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Vuoi unirti su un piano separato?",
        "party_venue_overlap_decline_hint": "Modifica l'orario di inizio/fine o scegli un altro locale.",
        "party_public_location_matched_title": "Locale pubblico noto",
        "party_public_location_matched_own_title": "Il tuo locale salvato",
        "party_public_location_matched_body": "Per questo locale vale il codice festa fisso salvato.",
        "party_public_location_badge": "pubblico",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "I desideri anticipati non sono disponibili per feste pubbliche.",
        "party_save_permission_denied": "Salvataggio non riuscito: permesso negato. Riprova o riavvia l'app.",
    },
    "ja": {
        "party_venue_overlap_info_body": "この会場では、選択した時間帯にすでに別のDJのパーティーが開催されています。空いているフロアを選ぶか、新しいフロアを追加してください。",
        "party_venue_overlap_dialog_title": "この会場での重複",
        "party_venue_overlap_dialog_intro": "選択した時間帯にはすでに以下があります：",
        "party_venue_overlap_party_line": "{partyName}（{djName}）：{start} – {end}",
        "party_venue_overlap_join_floor_question": "別のフロアで参加しますか？",
        "party_venue_overlap_decline_hint": "開始/終了時刻を変更するか、別の会場を選んでください。",
        "party_public_location_matched_title": "既知の公開会場",
        "party_public_location_matched_own_title": "保存した会場",
        "party_public_location_matched_body": "この会場には保存済みの固定パーティーコードが適用されます。",
        "party_public_location_badge": "公開",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "公開イベントでは事前リクエストは利用できません。",
        "party_save_permission_denied": "保存に失敗しました：権限が拒否されました。もう一度お試しいただくか、アプリを再起動してください。",
    },
    "nl": {
        "party_venue_overlap_info_body": "Op deze locatie is in jouw tijdslot al een party van een andere DJ. Kies een vrije floor of voeg een nieuwe toe.",
        "party_venue_overlap_dialog_title": "Overlap op deze locatie",
        "party_venue_overlap_dialog_intro": "In het gekozen tijdslot is er al:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Wil je aansluiten op een aparte floor?",
        "party_venue_overlap_decline_hint": "Wijzig de start-/eindtijd of kies een andere locatie.",
        "party_public_location_matched_title": "Bekende openbare locatie",
        "party_public_location_matched_own_title": "Jouw opgeslagen locatie",
        "party_public_location_matched_body": "Voor deze locatie geldt de opgeslagen vaste partycode.",
        "party_public_location_badge": "openbaar",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "Voorafgaande wensen zijn niet beschikbaar bij openbare feesten.",
        "party_save_permission_denied": "Opslaan mislukt: toestemming geweigerd. Probeer het opnieuw of start de app opnieuw.",
    },
    "pl": {
        "party_venue_overlap_info_body": "W tym miejscu w Twoim przedziale czasowym odbywa się już impreza innego DJ-a. Wybierz wolny floor lub dodaj nowy.",
        "party_venue_overlap_dialog_title": "Nakładanie się w tym miejscu",
        "party_venue_overlap_dialog_intro": "W wybranym przedziale czasowym odbywa się już:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Czy chcesz dołączyć na osobnym floorze?",
        "party_venue_overlap_decline_hint": "Zmień godzinę rozpoczęcia/zakończenia lub wybierz inne miejsce.",
        "party_public_location_matched_title": "Znane miejsce publiczne",
        "party_public_location_matched_own_title": "Twoje zapisane miejsce",
        "party_public_location_matched_body": "Dla tego miejsca obowiązuje zapisany stały kod imprezy.",
        "party_public_location_badge": "publiczne",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "Życzenia z wyprzedzeniem nie są dostępne przy imprezach publicznych.",
        "party_save_permission_denied": "Zapis nie powiódł się: odmowa uprawnień. Spróbuj ponownie lub uruchom aplikację ponownie.",
    },
    "pt": {
        "party_venue_overlap_info_body": "Neste local já há uma festa de outro DJ no teu horário. Escolhe um piso livre ou adiciona um novo.",
        "party_venue_overlap_dialog_title": "Sobreposição neste local",
        "party_venue_overlap_dialog_intro": "No horário selecionado já existe:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Queres juntar-te num piso separado?",
        "party_venue_overlap_decline_hint": "Altera a hora de início/fim ou escolhe outro local.",
        "party_public_location_matched_title": "Local público conhecido",
        "party_public_location_matched_own_title": "O teu local guardado",
        "party_public_location_matched_body": "Para este local aplica-se o código de festa fixo guardado.",
        "party_public_location_badge": "público",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "Pedidos antecipados não estão disponíveis para festas públicas.",
        "party_save_permission_denied": "Falha ao guardar: permissão negada. Tenta novamente ou reinicia a app.",
    },
    "ru": {
        "party_venue_overlap_info_body": "В этом месте в вашем временном окне уже идёт вечеринка другого DJ. Выберите свободный этаж или добавьте новый.",
        "party_venue_overlap_dialog_title": "Пересечение в этом месте",
        "party_venue_overlap_dialog_intro": "В выбранном временном окне уже есть:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Хотите присоединиться на отдельном этаже?",
        "party_venue_overlap_decline_hint": "Измените время начала/окончания или выберите другое место.",
        "party_public_location_matched_title": "Известное публичное место",
        "party_public_location_matched_own_title": "Ваше сохранённое место",
        "party_public_location_matched_body": "Для этого места действует сохранённый фиксированный код вечеринки.",
        "party_public_location_badge": "публичное",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "Предварительные пожелания недоступны для публичных мероприятий.",
        "party_save_permission_denied": "Не удалось сохранить: доступ запрещён. Повторите попытку или перезапустите приложение.",
    },
    "sq": {
        "party_venue_overlap_info_body": "Në këtë vend ka tashmë një festë të një DJ-i tjetër gjatë intervalit tënd kohor. Zgjidh një kat të lirë ose shto një të ri.",
        "party_venue_overlap_dialog_title": "Mbivendosje në këtë vend",
        "party_venue_overlap_dialog_intro": "Gjatë intervalit kohor të zgjedhur ekziston tashmë:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Dëshiron të bashkohesh në një kat të veçantë?",
        "party_venue_overlap_decline_hint": "Ndrysho orën e fillimit/mbarimit ose zgjidh një vend tjetër.",
        "party_public_location_matched_title": "Vend publik i njohur",
        "party_public_location_matched_own_title": "Vendi yt i ruajtur",
        "party_public_location_matched_body": "Për këtë vend vlen kodi fiks i festës i ruajtur.",
        "party_public_location_badge": "publik",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "Dëshirat paraprake nuk janë të disponueshme për festa publike.",
        "party_save_permission_denied": "Ruajtja dështoi: leja u refuzua. Provo përsëri ose rinis aplikacionin.",
    },
    "tr": {
        "party_venue_overlap_info_body": "Bu mekânda zaman aralığınızda başka bir DJ'in partisi zaten devam ediyor. Boş bir kat seçin veya yeni bir kat ekleyin.",
        "party_venue_overlap_dialog_title": "Bu mekânda çakışma",
        "party_venue_overlap_dialog_intro": "Seçtiğiniz zaman aralığında zaten şunlar var:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Ayrı bir katta katılmak ister misiniz?",
        "party_venue_overlap_decline_hint": "Lütfen başlangıç/bitiş saatini değiştirin veya başka bir mekân seçin.",
        "party_public_location_matched_title": "Bilinen herkese açık mekân",
        "party_public_location_matched_own_title": "Kayıtlı mekânınız",
        "party_public_location_matched_body": "Bu mekân için kayıtlı sabit parti kodu geçerlidir.",
        "party_public_location_badge": "herkese açık",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "Herkese açık etkinliklerde ön istekler kullanılamaz.",
        "party_save_permission_denied": "Kaydetme başarısız: izin reddedildi. Lütfen tekrar deneyin veya uygulamayı yeniden başlatın.",
    },
    "uk": {
        "party_venue_overlap_info_body": "У цьому місці у вашому часовому вікні вже проходить вечірка іншого DJ. Оберіть вільний поверх або додайте новий.",
        "party_venue_overlap_dialog_title": "Перетин у цьому місці",
        "party_venue_overlap_dialog_intro": "У вибраному часовому вікні вже є:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Бажаєте приєднатися на окремому поверсі?",
        "party_venue_overlap_decline_hint": "Змініть час початку/закінчення або оберіть інше місце.",
        "party_public_location_matched_title": "Відоме публічне місце",
        "party_public_location_matched_own_title": "Ваше збережене місце",
        "party_public_location_matched_body": "Для цього місця діє збережений фіксований код вечірки.",
        "party_public_location_badge": "публічне",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "Попередні побажання недоступні для публічних заходів.",
        "party_save_permission_denied": "Не вдалося зберегти: доступ заборонено. Спробуйте ще раз або перезапустіть застосунок.",
    },
    "vi": {
        "party_venue_overlap_info_body": "Tại địa điểm này đã có tiệc của DJ khác trong khung giờ của bạn. Chọn một tầng trống hoặc thêm tầng mới.",
        "party_venue_overlap_dialog_title": "Trùng lịch tại địa điểm này",
        "party_venue_overlap_dialog_intro": "Trong khung giờ đã chọn đã có:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Bạn có muốn tham gia ở một tầng riêng không?",
        "party_venue_overlap_decline_hint": "Vui lòng đổi giờ bắt đầu/kết thúc hoặc chọn địa điểm khác.",
        "party_public_location_matched_title": "Địa điểm công khai đã biết",
        "party_public_location_matched_own_title": "Địa điểm đã lưu của bạn",
        "party_public_location_matched_body": "Địa điểm này dùng mã tiệc cố định đã lưu.",
        "party_public_location_badge": "công khai",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "Yêu cầu trước không khả dụng cho sự kiện công khai.",
        "party_save_permission_denied": "Lưu thất bại: quyền bị từ chối. Vui lòng thử lại hoặc khởi động lại ứng dụng.",
    },
    "zh": {
        "party_venue_overlap_info_body": "该场所在您选择的时间段内已有其他 DJ 的派对。请选择一个空闲楼层或添加新楼层。",
        "party_venue_overlap_dialog_title": "该场所时间冲突",
        "party_venue_overlap_dialog_intro": "在您选择的时间段内已有：",
        "party_venue_overlap_party_line": "{partyName}（{djName}）：{start} – {end}",
        "party_venue_overlap_join_floor_question": "您是否要在独立楼层加入？",
        "party_venue_overlap_decline_hint": "请更改开始/结束时间或选择其他场所。",
        "party_public_location_matched_title": "已知公开场所",
        "party_public_location_matched_own_title": "您保存的场所",
        "party_public_location_matched_body": "该场所使用已保存的固定派对码。",
        "party_public_location_badge": "公开",
        "party_dj_fallback": "DJ",
        "party_pre_wishes_public_unavailable": "公开活动不支持预先点歌。",
        "party_save_permission_denied": "保存失败：权限被拒绝。请重试或重新启动应用。",
    },
}




def lang_from_filename(name: str) -> Optional[str]:
    m = re.match(r"app_([a-z]{2})\.arb$", name)
    return m.group(1) if m else None


def apply_to_file(arb_path: Path, lang: str) -> bool:
    if lang not in TRANSLATIONS:
        return False
    data = json.loads(arb_path.read_text(encoding="utf-8"))
    tr = TRANSLATIONS[lang]
    changed = False
    for key in KEYS:
        if key in tr and data.get(key) != tr[key]:
            data[key] = tr[key]
            changed = True
    if changed:
        arb_path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
    return changed


def main() -> None:
    for arb_path in sorted(L10N.glob("app_*.arb")):
        lang = lang_from_filename(arb_path.name)
        if lang is None or lang in ("de", "en"):
            continue
        if apply_to_file(arb_path, lang):
            print(f"translated {arb_path.name}")


if __name__ == "__main__":
    main()
