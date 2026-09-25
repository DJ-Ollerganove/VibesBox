#!/usr/bin/env python3
"""Erzeugt fehlende InfoPlist.strings, setzt EN-Defaults in Info.plist, bindet Strings ins Xcode-Projekt ein."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "ios" / "Runner"
PBX = ROOT / "ios" / "Runner.xcodeproj" / "project.pbxproj"
INFO = RUNNER / "Info.plist"

EN_STRINGS = {
    "NSLocalNetworkUsageDescription": (
        "VibesBox may use the local network so development tools can connect during testing, "
        "and for optional device features on the same Wi‑Fi."
    ),
    "NSMicrophoneUsageDescription": (
        "VibesBox needs microphone access to analyze playing music for recognition."
    ),
    "NSAppleMusicUsageDescription": (
        "VibesBox may access your media library to link music recognition with Apple Music features."
    ),
    "NSCameraUsageDescription": (
        "VibesBox needs camera access to scan QR codes and take photos."
    ),
    "NSPhotoLibraryUsageDescription": (
        "VibesBox needs photo library access so you can choose a profile picture."
    ),
    "NSPhotoLibraryAddUsageDescription": (
        "VibesBox saves images such as QR codes to your library when you choose to."
    ),
    "NSLocationWhenInUseUsageDescription": (
        "VibesBox uses your location to centre the map on your party location."
    ),
    "NSLocationAlwaysAndWhenInUseUsageDescription": (
        "VibesBox uses your location to centre the map on your party location."
    ),
    "NSCalendarsUsageDescription": (
        "Needed to export party dates to your calendar."
    ),
    "NSFaceIDUsageDescription": (
        "Face ID protects admin settings so only you can access sensitive options."
    ),
}

# Locale folder → translated overrides (fallback EN for missing keys)
LOCALES: dict[str, dict[str, str]] = {
    "en": {},
    "de": {
        "NSLocalNetworkUsageDescription": (
            "VibesBox nutzt das lokale Netzwerk für Entwicklungsverbindungen (z. B. Hot Reload) "
            "und optional für Gerätedienste im gleichen WLAN."
        ),
        "NSMicrophoneUsageDescription": (
            "VibesBox benötigt Zugriff auf das Mikrofon, um laufende Musik für die Musikerkennung zu analysieren."
        ),
        "NSAppleMusicUsageDescription": (
            "VibesBox kann auf deine Mediathek zugreifen, um Musikerkennung mit Apple Music zu verknüpfen."
        ),
        "NSCameraUsageDescription": (
            "VibesBox benötigt Zugriff auf die Kamera, um QR-Codes zu scannen und Fotos aufzunehmen."
        ),
        "NSPhotoLibraryUsageDescription": (
            "VibesBox benötigt Zugriff auf deine Mediathek, um ein Profilbild auszuwählen."
        ),
        "NSPhotoLibraryAddUsageDescription": (
            "VibesBox speichert Bilder (z. B. QR-Codes) in deiner Mediathek, wenn du es wählst."
        ),
        "NSLocationWhenInUseUsageDescription": (
            "VibesBox nutzt deinen Standort, um die Karte auf die Party-Location zu zentrieren."
        ),
        "NSLocationAlwaysAndWhenInUseUsageDescription": (
            "VibesBox nutzt deinen Standort, um die Karte auf die Party-Location zu zentrieren."
        ),
        "NSCalendarsUsageDescription": (
            "Wird benötigt, um Party-Termine in deinen Kalender zu exportieren."
        ),
        "NSFaceIDUsageDescription": (
            "Face ID schützt Admin-Einstellungen, damit nur du darauf zugreifen kannst."
        ),
    },
    "es": {
        "NSMicrophoneUsageDescription": "VibesBox necesita acceso al micrófono para analizar la música que suena y reconocerla.",
        "NSCameraUsageDescription": "VibesBox necesita la cámara para escanear códigos QR y hacer fotos.",
        "NSLocationWhenInUseUsageDescription": "Usamos tu ubicación para centrar el mapa en la ubicación de la fiesta.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Usamos tu ubicación para centrar el mapa en la ubicación de la fiesta.",
    },
    "fr": {
        "NSMicrophoneUsageDescription": "VibesBox a besoin du micro pour analyser la musique en cours et la reconnaître.",
        "NSCameraUsageDescription": "VibesBox a besoin de la caméra pour scanner les codes QR et prendre des photos.",
        "NSLocationWhenInUseUsageDescription": "Nous utilisons votre position pour centrer la carte sur le lieu de la soirée.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Nous utilisons votre position pour centrer la carte sur le lieu de la soirée.",
    },
    "it": {
        "NSMicrophoneUsageDescription": "VibesBox usa il microfono per analizzare la musica in riproduzione e riconoscerla.",
        "NSCameraUsageDescription": "VibesBox usa la fotocamera per scansionare codici QR e scattare foto.",
        "NSLocationWhenInUseUsageDescription": "Usiamo la tua posizione per centrare la mappa sulla location della festa.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Usiamo la tua posizione per centrare la mappa sulla location della festa.",
    },
    "pt": {
        "NSMicrophoneUsageDescription": "O VibesBox precisa do microfone para analisar a música em reprodução e reconhecê-la.",
        "NSCameraUsageDescription": "O VibesBox precisa da câmara para ler códigos QR e tirar fotografias.",
        "NSLocationWhenInUseUsageDescription": "Usamos a sua localização para centrar o mapa no local da festa.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Usamos a sua localização para centrar o mapa no local da festa.",
    },
    "ru": {
        "NSMicrophoneUsageDescription": "VibesBox использует микрофон, чтобы анализировать воспроизводимую музыку и распознавать её.",
        "NSCameraUsageDescription": "VibesBox использует камеру для сканирования QR-кодов и съёмки фото.",
        "NSLocationWhenInUseUsageDescription": "Мы используем ваше местоположение, чтобы центрировать карту на локации вечеринки.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Мы используем ваше местоположение, чтобы центрировать карту на локации вечеринки.",
    },
    "tr": {
        "NSMicrophoneUsageDescription": "VibesBox, çalan müziği analiz etmek ve tanımak için mikrofona ihtiyaç duyar.",
        "NSCameraUsageDescription": "VibesBox QR kodları taramak ve fotoğraf çekmek için kameraya ihtiyaç duyar.",
        "NSLocationWhenInUseUsageDescription": "Parti konumunu haritada ortalamak için konumunuz kullanılır.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Parti konumunu haritada ortalamak için konumunuz kullanılır.",
    },
    "uk": {
        "NSMicrophoneUsageDescription": "VibesBox використовує мікрофон, щоб аналізувати музику, що відтворюється, і розпізнавати її.",
        "NSCameraUsageDescription": "VibesBox використовує камеру для сканування QR-кодів і зйомки фото.",
        "NSLocationWhenInUseUsageDescription": "Ми використовуємо ваше місцезнаходження, щоб центрувати карту на локації вечірки.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Ми використовуємо ваше місцезнаходження, щоб центрувати карту на локації вечірки.",
    },
    "hi": {
        "NSMicrophoneUsageDescription": "VibesBox को चल रहे संगीत का विश्लेषण और पहचान करने के लिए माइक्रोफ़ोन एक्सेस चाहिए।",
        "NSCameraUsageDescription": "VibesBox को QR कोड स्कैन करने और फ़ोटो लेने के लिए कैमरा चाहिए।",
        "NSLocationWhenInUseUsageDescription": "पार्टी स्थान पर मानचित्र केंद्रित करने के लिए आपकी लोकेशन का उपयोग होता है।",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "पार्टी स्थान पर मानचित्र केंद्रित करने के लिए आपकी लोकेशन का उपयोग होता है।",
    },
    "zh-Hans": {
        "NSMicrophoneUsageDescription": "VibesBox 需要访问麦克风以分析正在播放的音乐并进行识别。",
        "NSCameraUsageDescription": "VibesBox 需要使用相机扫描二维码和拍摄照片。",
        "NSLocationWhenInUseUsageDescription": "我们使用你的位置将地图居中到派对地点。",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "我们使用你的位置将地图居中到派对地点。",
    },
    # Zusätzliche App-Sprachen (Fallback EN wo nicht übersetzt)
    "ar": {
        "NSMicrophoneUsageDescription": "تحتاج VibesBox إلى الميكروفون لتحليل الموسيقى قيد التشغيل والتعرف عليها.",
        "NSCameraUsageDescription": "تحتاج VibesBox إلى الكاميرا لمسح رموز QR والتقاط الصور.",
        "NSLocationWhenInUseUsageDescription": "نستخدم موقعك لتوسيط الخريطة على موقع الحفلة.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "نستخدم موقعك لتوسيط الخريطة على موقع الحفلة.",
        "NSPhotoLibraryUsageDescription": "تحتاج VibesBox إلى مكتبة الصور لاختيار صورة الملف الشخصي.",
        "NSPhotoLibraryAddUsageDescription": "تحفظ VibesBox الصور مثل رموز QR في مكتبتك عند اختيارك ذلك.",
        "NSCalendarsUsageDescription": "مطلوب لتصدير مواعيد الحفلات إلى تقويمك.",
        "NSFaceIDUsageDescription": "Face ID يحمي إعدادات المسؤول حتى لا يصل إليها سواك.",
        "NSAppleMusicUsageDescription": "قد تصل VibesBox إلى مكتبتك الإعلامية لربط التعرف على الموسيقى بميزات Apple Music.",
        "NSLocalNetworkUsageDescription": "قد تستخدم VibesBox الشبكة المحلية لأدوات التطوير ولاختياريًا لميزات الجهاز على نفس الشبكة.",
    },
    "ja": {
        "NSMicrophoneUsageDescription": "VibesBox は再生中の音楽を解析・認識するためにマイクへのアクセスが必要です。",
        "NSCameraUsageDescription": "VibesBox は QR コードの読み取りや写真の撮影にカメラを使用します。",
        "NSLocationWhenInUseUsageDescription": "パーティー会場を地図の中心に合わせるために位置情報を使用します。",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "パーティー会場を地図の中心に合わせるために位置情報を使用します。",
    },
    "nl": {
        "NSMicrophoneUsageDescription": "VibesBox heeft microfoontoegang nodig om afgespeelde muziek te analyseren en te herkennen.",
        "NSCameraUsageDescription": "VibesBox gebruikt de camera om QR-codes te scannen en foto’s te maken.",
        "NSLocationWhenInUseUsageDescription": "We gebruiken je locatie om de kaart op de party-locatie te centreren.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "We gebruiken je locatie om de kaart op de party-locatie te centreren.",
    },
    "pl": {
        "NSMicrophoneUsageDescription": "VibesBox potrzebuje dostępu do mikrofonu, aby analizować i rozpoznawać odtwarzaną muzykę.",
        "NSCameraUsageDescription": "VibesBox używa aparatu do skanowania kodów QR i robienia zdjęć.",
        "NSLocationWhenInUseUsageDescription": "Używamy Twojej lokalizacji, aby wyśrodkować mapę na lokalizacji imprezy.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Używamy Twojej lokalizacji, aby wyśrodkować mapę na lokalizacji imprezy.",
    },
    "cs": {
        "NSMicrophoneUsageDescription": "VibesBox potřebuje přístup k mikrofonu, aby analyzoval a rozpoznal přehrávanou hudbu.",
        "NSCameraUsageDescription": "VibesBox používá fotoaparát ke skenování QR kódů a pořizování fotek.",
        "NSLocationWhenInUseUsageDescription": "Používáme vaši polohu k vycentrování mapy na místo party.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Používáme vaši polohu k vycentrování mapy na místo party.",
    },
    "el": {
        "NSMicrophoneUsageDescription": "Το VibesBox χρειάζεται πρόσβαση στο μικρόφωνο για ανάλυση και αναγνώριση της μουσικής που παίζει.",
        "NSCameraUsageDescription": "Το VibesBox χρησιμοποιεί την κάμερα για σάρωση QR και φωτογραφίες.",
        "NSLocationWhenInUseUsageDescription": "Χρησιμοποιούμε την τοποθεσία σας για να κεντράρουμε τον χάρτη στη θέση του πάρτι.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Χρησιμοποιούμε την τοποθεσία σας για να κεντράρουμε τον χάρτη στη θέση του πάρτι.",
    },
    "sq": {
        "NSMicrophoneUsageDescription": "VibesBox ka nevojë për mikrofonin për të analizuar dhe njohur muzikën që po luhet.",
        "NSCameraUsageDescription": "VibesBox përdor kamerën për të skanuar kode QR dhe për të bërë foto.",
        "NSLocationWhenInUseUsageDescription": "Përdorim vendndodhjen tënde për të qendërzuar hartën te lokacioni i partisë.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Përdorim vendndodhjen tënde për të qendërzuar hartën te lokacioni i partisë.",
    },
    "vi": {
        "NSMicrophoneUsageDescription": "VibesBox cần quyền micro để phân tích và nhận diện nhạc đang phát.",
        "NSCameraUsageDescription": "VibesBox dùng camera để quét mã QR và chụp ảnh.",
        "NSLocationWhenInUseUsageDescription": "Chúng tôi dùng vị trí của bạn để căn giữa bản đồ tại địa điểm tiệc.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Chúng tôi dùng vị trí của bạn để căn giữa bản đồ tại địa điểm tiệc.",
    },
    "th": {
        "NSMicrophoneUsageDescription": "VibesBox ต้องการใช้ไมโครโฟนเพื่อวิเคราะห์และจดจำเพลงที่กำลังเล่น",
        "NSCameraUsageDescription": "VibesBox ใช้กล้องเพื่อสแกนคิวอาร์โค้ดและถ่ายรูป",
        "NSLocationWhenInUseUsageDescription": "เราใช้ตำแหน่งของคุณเพื่อจัดกึ่งกลางแผนที่ที่สถานที่ปาร์ตี้",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "เราใช้ตำแหน่งของคุณเพื่อจัดกึ่งกลางแผนที่ที่สถานที่ปาร์ตี้",
    },
}


def write_strings(locale: str, overrides: dict[str, str]) -> None:
    folder = RUNNER / f"{locale}.lproj"
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / "InfoPlist.strings"
    merged = dict(EN_STRINGS)
    merged.update(overrides)
    lines = ['/* Info.plist localization – VibesBox */']
    for key in EN_STRINGS:
        val = merged[key].replace('\\', '\\\\').replace('"', '\\"')
        lines.append(f'"{key}" = "{val}";')
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def patch_info_plist_defaults() -> None:
    text = INFO.read_text(encoding="utf-8")
    for key, val in EN_STRINGS.items():
        # Replace <key>KEY</key>\n\t\t<string>...</string>
        pat = rf"(<key>{re.escape(key)}</key>\s*<string>)(.*?)(</string>)"
        if re.search(pat, text, flags=re.S):
            text = re.sub(pat, rf"\1{val}\3", text, count=1, flags=re.S)
        else:
            # insert before UIApplicationSupportsIndirectInputEvents if missing
            insert = f"\t\t<key>{key}</key>\n\t\t<string>{val}</string>\n"
            text = text.replace(
                "\t\t<key>UIApplicationSupportsIndirectInputEvents</key>",
                insert + "\t\t<key>UIApplicationSupportsIndirectInputEvents</key>",
                1,
            )
    INFO.write_text(text, encoding="utf-8")


def patch_pbxproj(locales: list[str]) -> None:
    pbx = PBX.read_text(encoding="utf-8")
    if "InfoPlist.strings in Resources" in pbx:
        print("pbxproj already has InfoPlist.strings — updating knownRegions only")
    else:
        # IDs (unique-ish, fixed for reproducibility)
        VARIANT = "A1B2C3D42CF9000F007C11IP"
        BUILD = "A1B2C3D52CF9000F007C11IP"
        # locale file refs
        loc_ids = {}
        for i, loc in enumerate(locales):
            loc_ids[loc] = f"A1B2C3{i:02X}2CF9000F007C11IP"

        # PBXBuildFile
        pbx = pbx.replace(
            "/* End PBXBuildFile section */",
            f"\t\t{BUILD} /* InfoPlist.strings in Resources */ = {{isa = PBXBuildFile; fileRef = {VARIANT} /* InfoPlist.strings */; }};\n/* End PBXBuildFile section */",
            1,
        )

        # PBXFileReference for each locale
        refs = []
        for loc, lid in loc_ids.items():
            refs.append(
                f'\t\t{lid} /* {loc} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = {loc}; path = {loc}.lproj/InfoPlist.strings; sourceTree = "<group>"; }};'
            )
        pbx = pbx.replace(
            "/* End PBXFileReference section */",
            "\n".join(refs) + "\n/* End PBXFileReference section */",
            1,
        )

        # Variant group
        children = ",\n".join(f"\t\t\t\t{loc_ids[loc]} /* {loc} */" for loc in locales)
        variant = f"""/* Begin PBXVariantGroup section */
		{VARIANT} /* InfoPlist.strings */ = {{
			isa = PBXVariantGroup;
			children = (
{children},
			);
			name = InfoPlist.strings;
			sourceTree = "<group>";
		}};
/* End PBXVariantGroup section */
"""
        if "/* Begin PBXVariantGroup section */" in pbx:
            # append children into existing? for Flutter there usually is one for storyboards
            pbx = pbx.replace(
                "/* End PBXVariantGroup section */",
                f"\t\t{VARIANT} /* InfoPlist.strings */ = {{\n\t\t\tisa = PBXVariantGroup;\n\t\t\tchildren = (\n{children},\n\t\t\t);\n\t\t\tname = InfoPlist.strings;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n/* End PBXVariantGroup section */",
                1,
            )
        else:
            pbx = pbx.replace(
                "/* End PBXResourcesBuildPhase section */",
                "/* End PBXResourcesBuildPhase section */\n\n" + variant,
                1,
            )

        # Add to Runner Resources
        pbx = pbx.replace(
            "\t\t\t\tD73BE9222F112233004455AA /* notification.caf in Resources */,\n",
            "\t\t\t\tD73BE9222F112233004455AA /* notification.caf in Resources */,\n"
            f"\t\t\t\t{BUILD} /* InfoPlist.strings in Resources */,\n",
            1,
        )

        # Add to Runner group children (near Info.plist)
        pbx = pbx.replace(
            "\t\t\t\t97C147021CF9000F007C117D /* Info.plist */,\n",
            "\t\t\t\t97C147021CF9000F007C117D /* Info.plist */,\n"
            f"\t\t\t\t{VARIANT} /* InfoPlist.strings */,\n",
            1,
        )

    # knownRegions
    regions = ["en", "Base"] + [l for l in locales if l not in ("en", "Base")]
    # unique preserve order
    seen = set()
    ordered = []
    for r in regions:
        if r not in seen:
            seen.add(r)
            ordered.append(r)
    block = "\n".join(f"\t\t\t\t{r}," for r in ordered)
    pbx = re.sub(
        r"knownRegions = \(\s*[^)]*?\);",
        f"knownRegions = (\n{block}\n\t\t\t);",
        pbx,
        count=1,
        flags=re.S,
    )
    PBX.write_text(pbx, encoding="utf-8")


def main() -> None:
    for locale, overrides in LOCALES.items():
        write_strings(locale, overrides)
        print(f"wrote {locale}.lproj/InfoPlist.strings")
    patch_info_plist_defaults()
    print("patched Info.plist defaults → English")
    patch_pbxproj(sorted(LOCALES.keys(), key=lambda x: (x != "en", x)))
    print("patched project.pbxproj")


if __name__ == "__main__":
    main()
