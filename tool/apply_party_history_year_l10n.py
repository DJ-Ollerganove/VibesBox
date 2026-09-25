#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Party-Historie: einsehbar + Jahresnavigation l10n."""

import json
from pathlib import Path
from typing import Dict

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

TRANSLATIONS: Dict[str, Dict[str, str]] = {
    "de": {
        "finished_parties_pro_notice": "Im Free-Account sind alle beendeten Partys sichtbar, aber nur die letzte ist einsehbar. Mit VibesBox Pro kannst du alle vergangenen Partys einsehen.",
        "party_history_prior_years_title": "Frühere Jahre",
        "party_history_year_title": "Party-Historie {year}",
        "party_history_no_parties_in_year": "Keine beendeten Partys in {year}.",
        "party_history_back_to_current_year": "Zurück zum aktuellen Jahr",
    },
    "en": {
        "finished_parties_pro_notice": "In the free account all finished parties are visible, but only the last one can be viewed. With VibesBox Pro you can view all past parties.",
        "party_history_prior_years_title": "Earlier years",
        "party_history_year_title": "Party history {year}",
        "party_history_no_parties_in_year": "No finished parties in {year}.",
        "party_history_back_to_current_year": "Back to current year",
    },
    "fr": {
        "finished_parties_pro_notice": "En compte gratuit, toutes les fêtes terminées sont visibles, mais seule la dernière est consultable. Avec VibesBox Pro, consulte toutes les fêtes passées.",
        "party_history_prior_years_title": "Années précédentes",
        "party_history_year_title": "Historique {year}",
        "party_history_no_parties_in_year": "Aucune fête terminée en {year}.",
        "party_history_back_to_current_year": "Retour à l'année en cours",
    },
    "es": {
        "finished_parties_pro_notice": "En la cuenta gratuita se ven todas las fiestas finalizadas, pero solo la última se puede consultar. Con VibesBox Pro puedes ver todas las fiestas pasadas.",
        "party_history_prior_years_title": "Años anteriores",
        "party_history_year_title": "Historial {year}",
        "party_history_no_parties_in_year": "No hay fiestas finalizadas en {year}.",
        "party_history_back_to_current_year": "Volver al año actual",
    },
    "it": {
        "finished_parties_pro_notice": "Nell'account gratuito tutte le feste terminate sono visibili, ma solo l'ultima è consultabile. Con VibesBox Pro puoi vedere tutte le feste passate.",
        "party_history_prior_years_title": "Anni precedenti",
        "party_history_year_title": "Cronologia {year}",
        "party_history_no_parties_in_year": "Nessuna festa terminata nel {year}.",
        "party_history_back_to_current_year": "Torna all'anno corrente",
    },
    "pt": {
        "finished_parties_pro_notice": "Na conta gratuita todas as festas encerradas são visíveis, mas só a última pode ser consultada. Com VibesBox Pro podes ver todas as festas passadas.",
        "party_history_prior_years_title": "Anos anteriores",
        "party_history_year_title": "Histórico {year}",
        "party_history_no_parties_in_year": "Nenhuma festa encerrada em {year}.",
        "party_history_back_to_current_year": "Voltar ao ano atual",
    },
    "nl": {
        "finished_parties_pro_notice": "In het gratis account zijn alle voltooide partijen zichtbaar, maar alleen de laatste is in te zien. Met VibesBox Pro kun je alle eerdere partijen bekijken.",
        "party_history_prior_years_title": "Eerdere jaren",
        "party_history_year_title": "Geschiedenis {year}",
        "party_history_no_parties_in_year": "Geen voltooide partijen in {year}.",
        "party_history_back_to_current_year": "Terug naar huidig jaar",
    },
    "pl": {
        "finished_parties_pro_notice": "Na koncie Free widać wszystkie zakończone imprezy, ale tylko ostatnia jest dostępna do podglądu. Z VibesBox Pro możesz przeglądać wszystkie minione imprezy.",
        "party_history_prior_years_title": "Wcześniejsze lata",
        "party_history_year_title": "Historia {year}",
        "party_history_no_parties_in_year": "Brak zakończonych imprez w {year}.",
        "party_history_back_to_current_year": "Powrót do bieżącego roku",
    },
    "cs": {
        "finished_parties_pro_notice": "Na bezplatném účtu jsou vidět všechny dokončené párty, ale prohlédnout lze jen poslední. S VibesBox Pro si můžeš prohlédnout všechny minulé párty.",
        "party_history_prior_years_title": "Dřívější roky",
        "party_history_year_title": "Historie {year}",
        "party_history_no_parties_in_year": "Žádné dokončené párty v roce {year}.",
        "party_history_back_to_current_year": "Zpět na aktuální rok",
    },
    "tr": {
        "finished_parties_pro_notice": "Ücretsiz hesapta biten tüm partiler görünür, ancak yalnızca sonuncusu görüntülenebilir. VibesBox Pro ile tüm geçmiş partileri görüntüleyebilirsin.",
        "party_history_prior_years_title": "Önceki yıllar",
        "party_history_year_title": "Geçmiş {year}",
        "party_history_no_parties_in_year": "{year} yılında biten parti yok.",
        "party_history_back_to_current_year": "Cari yıla dön",
    },
    "ru": {
        "finished_parties_pro_notice": "В бесплатной учётной записи видны все завершённые вечеринки, но просмотреть можно только последнюю. С VibesBox Pro доступны все прошлые вечеринки.",
        "party_history_prior_years_title": "Предыдущие годы",
        "party_history_year_title": "История {year}",
        "party_history_no_parties_in_year": "Нет завершённых вечеринок в {year} г.",
        "party_history_back_to_current_year": "К текущему году",
    },
    "uk": {
        "finished_parties_pro_notice": "У безкоштовному обліковому записі видно всі завершені вечірки, але переглянути можна лише останню. З VibesBox Pro доступні всі минулі вечірки.",
        "party_history_prior_years_title": "Попередні роки",
        "party_history_year_title": "Історія {year}",
        "party_history_no_parties_in_year": "Немає завершених вечірок у {year} р.",
        "party_history_back_to_current_year": "До поточного року",
    },
    "ar": {
        "finished_parties_pro_notice": "في الحساب المجاني تظهر جميع الحفلات المنتهية، لكن يمكن عرض آخر حفلة فقط. مع VibesBox Pro يمكنك عرض جميع الحفلات السابقة.",
        "party_history_prior_years_title": "سنوات سابقة",
        "party_history_year_title": "سجل {year}",
        "party_history_no_parties_in_year": "لا توجد حفلات منتهية في {year}.",
        "party_history_back_to_current_year": "العودة إلى السنة الحالية",
    },
    "hi": {
        "finished_parties_pro_notice": "फ्री अकाउंट में सभी समाप्त पार्टियाँ दिखती हैं, लेकिन केवल आखिरी वाली देखी जा सकती है। VibesBox Pro से आप सभी पिछली पार्टियाँ देख सकते हैं।",
        "party_history_prior_years_title": "पिछले वर्ष",
        "party_history_year_title": "इतिहास {year}",
        "party_history_no_parties_in_year": "{year} में कोई समाप्त पार्टी नहीं।",
        "party_history_back_to_current_year": "वर्तमान वर्ष पर वापस",
    },
    "ja": {
        "finished_parties_pro_notice": "無料アカウントでは終了したパーティーがすべて表示されますが、閲覧できるのは最後の1件だけです。VibesBox Proで過去のパーティーをすべて閲覧できます。",
        "party_history_prior_years_title": "過去の年",
        "party_history_year_title": "履歴 {year}",
        "party_history_no_parties_in_year": "{year}年に終了したパーティーはありません。",
        "party_history_back_to_current_year": "今年に戻る",
    },
    "zh": {
        "finished_parties_pro_notice": "免费账户会显示所有已结束的派对，但只能查看最近一场。使用 VibesBox Pro 可查看所有过往派对。",
        "party_history_prior_years_title": "往年",
        "party_history_year_title": "历史 {year}",
        "party_history_no_parties_in_year": "{year} 年没有已结束的派对。",
        "party_history_back_to_current_year": "返回今年",
    },
    "vi": {
        "finished_parties_pro_notice": "Trong tài khoản miễn phí, tất cả bữa tiệc đã kết thúc đều hiển thị, nhưng chỉ bữa tiệc gần nhất có thể xem. Với VibesBox Pro bạn có thể xem tất cả bữa tiệc trước đây.",
        "party_history_prior_years_title": "Các năm trước",
        "party_history_year_title": "Lịch sử {year}",
        "party_history_no_parties_in_year": "Không có bữa tiệc đã kết thúc trong {year}.",
        "party_history_back_to_current_year": "Về năm hiện tại",
    },
    "el": {
        "finished_parties_pro_notice": "Στον λογαριασμό Free φαίνονται όλα τα ολοκληρωμένα πάρτι, αλλά μόνο το τελευταίο μπορεί να προβληθεί. Με VibesBox Pro μπορείς να δεις όλα τα παλαιότερα πάρτι.",
        "party_history_prior_years_title": "Προηγούμενα έτη",
        "party_history_year_title": "Ιστορικό {year}",
        "party_history_no_parties_in_year": "Δεν υπάρχουν ολοκληρωμένα πάρτι το {year}.",
        "party_history_back_to_current_year": "Επιστροφή στο τρέχον έτος",
    },
    "sq": {
        "finished_parties_pro_notice": "Në llogarinë Falas shihen të gjitha festat e përfunduara, por vetëm e fundit mund të shihet. Me VibesBox Pro mund të shohësh të gjitha festat e kaluara.",
        "party_history_prior_years_title": "Vite të mëparshme",
        "party_history_year_title": "Historiku {year}",
        "party_history_no_parties_in_year": "Nuk ka festa të përfunduara në {year}.",
        "party_history_back_to_current_year": "Kthehu te viti aktual",
    },
}


def main() -> None:
    for arb_path in sorted(L10N.glob("app_*.arb")):
        locale = arb_path.stem.replace("app_", "")
        if locale not in TRANSLATIONS:
            print(f"Überspringe {locale}")
            continue
        data = json.loads(arb_path.read_text(encoding="utf-8"))
        for key, value in TRANSLATIONS[locale].items():
            data[key] = value
        arb_path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"OK {arb_path.name}")


if __name__ == "__main__":
    main()
