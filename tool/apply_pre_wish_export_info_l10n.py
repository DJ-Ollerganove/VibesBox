#!/usr/bin/env python3
"""Info-Texte für Vorab-Export-Format-Dialog in alle Sprachen."""

import json
import re
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

KEYS = [
    "pre_wish_export_format_info_title",
    "pre_wish_export_format_info_body",
]

TRANSLATIONS: dict[str, dict[str, str]] = {
    "en": {
        "pre_wish_export_format_info_title": "What's in the export file?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV and M3U are compact lists: each line contains only title and artist — "
            "ideal for DJ software or a quick overview.\n\n"
            "The PDF adds your party name and the start date and time at the top, followed by "
            "all advance requests with names and greetings — great for printing or sharing with your team."
        ),
    },
    "fr": {
        "pre_wish_export_format_info_title": "Que contient le fichier d'export ?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV et M3U sont des listes compactes : chaque ligne ne contient que le titre et "
            "l'artiste — idéal pour ton logiciel DJ ou un aperçu rapide.\n\n"
            "Le PDF ajoute le nom de la soirée ainsi que la date et l'heure de début en tête, "
            "suivis de toutes les demandes préalables avec noms et messages — parfait pour imprimer "
            "ou partager avec ton équipe."
        ),
    },
    "es": {
        "pre_wish_export_format_info_title": "¿Qué contiene el archivo de exportación?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV y M3U son listas compactas: cada línea contiene solo título e intérprete — "
            "ideal para tu software de DJ o una vista rápida.\n\n"
            "El PDF añade el nombre de la fiesta y la fecha y hora de inicio arriba, seguido de "
            "todas las solicitudes anticipadas con nombres y dedicatorias — perfecto para imprimir "
            "o compartir con tu equipo."
        ),
    },
    "it": {
        "pre_wish_export_format_info_title": "Cosa contiene il file di esportazione?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV e M3U sono elenchi compatti: ogni riga contiene solo titolo e artista — "
            "ideale per il software DJ o una panoramica veloce.\n\n"
            "Il PDF aggiunge in cima il nome della festa e data e ora di inizio, seguiti da tutte "
            "le richieste anticipate con nomi e dediche — perfetto per stampare o condividere con il team."
        ),
    },
    "nl": {
        "pre_wish_export_format_info_title": "Wat staat er in het exportbestand?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV en M3U zijn compacte lijsten: elke regel bevat alleen titel en artiest — "
            "ideaal voor DJ-software of een snel overzicht.\n\n"
            "De PDF voegt bovenaan de feestnaam en startdatum en -tijd toe, gevolgd door alle "
            "verzoeken vooraf met namen en groeten — handig om af te drukken of te delen met je team."
        ),
    },
    "pt": {
        "pre_wish_export_format_info_title": "O que contém o ficheiro de exportação?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV e M3U são listas compactas: cada linha contém apenas título e artista — "
            "ideal para software de DJ ou uma visão rápida.\n\n"
            "O PDF acrescenta no topo o nome da festa e a data e hora de início, seguidos de todos "
            "os pedidos antecipados com nomes e dedicatórias — perfeito para imprimir ou partilhar com a equipa."
        ),
    },
    "pl": {
        "pre_wish_export_format_info_title": "Co zawiera plik eksportu?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV i M3U to zwarte listy: każda linia zawiera tylko tytuł i wykonawcę — "
            "idealne do oprogramowania DJ lub szybkiego przeglądu.\n\n"
            "PDF dodaje na górze nazwę imprezy oraz datę i godzinę rozpoczęcia, a poniżej wszystkie "
            "zgłoszenia z wyprzedzeniem z imionami i życzeniami — świetne do druku lub udostępnienia zespołowi."
        ),
    },
    "cs": {
        "pre_wish_export_format_info_title": "Co obsahuje exportovaný soubor?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV a M3U jsou přehledné seznamy: každý řádek obsahuje pouze název a interpreta — "
            "ideální pro DJ software nebo rychlý přehled.\n\n"
            "PDF navíc nahoře uvádí název večírku a datum a čas začátku, pod ním všechna předběžná "
            "přání se jmény a vzkazy — vhodné k tisku nebo sdílení s týmem."
        ),
    },
    "ru": {
        "pre_wish_export_format_info_title": "Что содержится в файле экспорта?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV и M3U — компактные списки: в каждой строке только название и исполнитель — "
            "удобно для DJ-софта или быстрого просмотра.\n\n"
            "В PDF дополнительно вверху указаны название вечеринки, дата и время начала, а ниже — "
            "все предварительные заявки с именами и поздравлениями — отлично для печати или команды."
        ),
    },
    "uk": {
        "pre_wish_export_format_info_title": "Що містить файл експорту?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV і M3U — компактні списки: у кожному рядку лише назва та виконавець — "
            "зручно для DJ-софту або швидкого огляду.\n\n"
            "У PDF додатково зверху вказані назва вечірки, дата та час початку, а нижче — "
            "усі попередні заявки з іменами та привітаннями — чудово для друку або команди."
        ),
    },
    "ar": {
        "pre_wish_export_format_info_title": "ماذا يحتوي ملف التصدير؟",
        "pre_wish_export_format_info_body": (
            "ملفات TXT وCSV وM3U قوائم مدمجة: كل سطر يحتوي على العنوان والفنان فقط — "
            "مثالية لبرامج الدي جي أو نظرة سريعة.\n\n"
            "يضيف PDF اسم الحفلة وتاريخ ووقت البداية في الأعلى، يليه جميع الطلبات المسبقة "
            "مع الأسماء والتحيات — رائع للطباعة أو المشاركة مع الفريق."
        ),
    },
    "zh": {
        "pre_wish_export_format_info_title": "导出文件包含什么？",
        "pre_wish_export_format_info_body": (
            "TXT、CSV 和 M3U 是精简列表：每行仅包含曲名和艺人——适合 DJ 软件或快速浏览。\n\n"
            "PDF 在顶部额外显示派对名称以及开始日期和时间，下方列出所有提前申请及姓名和祝福语——"
            "适合打印或与团队分享。"
        ),
    },
    "ja": {
        "pre_wish_export_format_info_title": "エクスポートファイルの内容",
        "pre_wish_export_format_info_body": (
            "TXT、CSV、M3U はコンパクトなリストです。各行にはタイトルとアーティストのみ — "
            "DJ ソフトや素早い確認に最適です。\n\n"
            "PDF には上部にパーティー名と開始日時が加わり、その下に名前とメッセージ付きの"
            "事前リクエストがすべて記載されます — 印刷やチーム共有に便利です。"
        ),
    },
    "hi": {
        "pre_wish_export_format_info_title": "निर्यात फ़ाइल में क्या है?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV और M3U संक्षिप्त सूचियाँ हैं: प्रत्येक पंक्ति में केवल शीर्षक और कलाकार — "
            "DJ सॉफ़्टवेयर या त्वरित अवलोकन के लिए आदर्श।\n\n"
            "PDF में ऊपर पार्टी का नाम और शुरुआत की तारीख व समय होता है, उसके नीचे सभी पूर्व अनुरोध "
            "नाम और शुभकामनाओं सहित — प्रिंट या टीम के साथ साझा करने के लिए बढ़िया।"
        ),
    },
    "tr": {
        "pre_wish_export_format_info_title": "Dışa aktarma dosyasında ne var?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV ve M3U kompakt listelerdir: her satırda yalnızca başlık ve sanatçı — "
            "DJ yazılımı veya hızlı bakış için ideal.\n\n"
            "PDF üstte parti adı ile başlangıç tarihi ve saatini ekler, altında isimler ve "
            "tebriklerle tüm ön talepler yer alır — yazdırmak veya ekiple paylaşmak için harika."
        ),
    },
    "vi": {
        "pre_wish_export_format_info_title": "Tệp xuất chứa gì?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV và M3U là danh sách gọn: mỗi dòng chỉ có tiêu đề và nghệ sĩ — "
            "lý tưởng cho phần mềm DJ hoặc xem nhanh.\n\n"
            "PDF thêm tên bữa tiệc và ngày giờ bắt đầu ở trên, kèm tất cả yêu cầu trước "
            "với tên và lời chúc — phù hợp để in hoặc chia sẻ với đội ngũ."
        ),
    },
    "el": {
        "pre_wish_export_format_info_title": "Τι περιέχει το αρχείο εξαγωγής;",
        "pre_wish_export_format_info_body": (
            "TXT, CSV και M3U είναι συμπαγείς λίστες: κάθε γραμμή περιέχει μόνο τίτλο και καλλιτέχνη — "
            "ιδανικό για λογισμικό DJ ή γρήγορη επισκόπηση.\n\n"
            "Το PDF προσθέτει στην κορυφή το όνομα του πάρτι και την ημερομηνία και ώρα έναρξης, "
            "ακολουθούμενο από όλα τα προκαταβολικά αιτήματα με ονόματα και ευχές — ιδανικό για εκτύπωση ή ομάδα."
        ),
    },
    "sq": {
        "pre_wish_export_format_info_title": "Çfarë përmban skedari i eksportit?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV dhe M3U janë lista kompakte: çdo rresht përmban vetëm titullin dhe artistin — "
            "ideale për softuerin DJ ose një pasqyrë të shpejtë.\n\n"
            "PDF shton në krye emrin e festës dhe datën dhe orën e fillimit, pasuar nga të gjitha "
            "kërkesat paraprake me emra dhe urime — e shkëlqyer për printim ose ndarje me ekipin."
        ),
    },
    "th": {
        "pre_wish_export_format_info_title": "ไฟล์ส่งออกมีอะไรบ้าง?",
        "pre_wish_export_format_info_body": (
            "TXT, CSV และ M3U เป็นรายการกระชับ: แต่ละบรรทัดมีเพียงชื่อเพลงและศิลปิน — "
            "เหมาะสำหรับซอฟต์แวร์ DJ หรือดูอย่างรวดเร็ว\n\n"
            "PDF เพิ่มชื่อปาร์ตี้และวันที่เวลาเริ่มด้านบน ตามด้วยคำขอล่วงหน้าทั้งหมดพร้อมชื่อและคำอวยพร — "
            "เหมาะสำหรับพิมพ์หรือแชร์กับทีม"
        ),
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
        if lang is None or lang == "de":
            continue
        if apply_to_file(arb_path, lang):
            print(f"updated {arb_path.name}")


if __name__ == "__main__":
    main()
