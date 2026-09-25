#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Füllt leere ARB-Einträge, wo DE Text hat (Einzel-Lücken pro Locale)."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

# locale -> key -> value
FILL: dict[str, dict[str, str]] = {
    "cs": {
        "imprint_html_content": (
            "<h1>Impressum</h1> <p>Údaje podle § 5 DDG</p> "
            "<p>VibesBox by Swen Steller<br> Neefestr. 9<br> 09119 Chemnitz<br> Německo</p> "
            "<p>E-mail: info@vibesbox.app</p>"
        ),
        "admin_lifetime_body_grant": "Chceš {name} navždy aktivovat Pro účet?",
    },
    "el": {
        "admin_pending_wishes_plural": "{count} ευχές είναι ακόμα ανοιχτές.",
        "snackbar_wishes_updated_many": "Ενημερώθηκαν {count} ευχές.",
        "wish_restored_count": "Επαναφέρθηκαν {count} ευχές",
        "admin_lifetime_body_grant": "Θέλεις να ενεργοποιήσεις μόνιμα τον Pro λογαριασμό για {name};",
    },
    "nl": {
        "admin_pending_wishes_plural": "{count} wensen zijn nog open.",
        "snackbar_wishes_updated_many": "{count} wensen zijn bijgewerkt.",
        "admin_lifetime_body_grant": "Wil je {name} levenslang Pro geven?",
        "history_time_hours_ago": "{hours} uur geleden",
        "pre_wish_count_plural": "{count} wensen",
        "audio_format_minutes_only": "{minutes} min.",
        "audio_format_minutes_seconds": "{minutes} min. {seconds} sek.",
        "paywall_free_phase_label": "{duration} gratis",
    },
    "pl": {
        "admin_lifetime_body_grant": "Czy chcesz na stałe aktywować Pro dla {name}?",
        "history_relative_days_ago": "{count} dni temu",
    },
    "ja": {
        "guest_home_stats_wishes_line": "リクエスト数: {count}",
        "history_time_minutes_ago": "{minutes}分前",
        "catalog_top_songs": "{artist}の人気曲",
        "modal_history_message": "「{title}」（{artist}）は今日すでに再生されています。それでもリクエストしますか？",
        "modal_pending_message": "「{title}」（{artist}）はすでにリクエストリストにあります。それでも送信しますか？",
        "verify_email_message": "{email} にリンクを送信しました。アカウントを確認してください。",
        "wish_played_at": "再生 {time}",
        "wish_rejected_at": "拒否 {time}",
        "wish_group_count": "リクエスト数: {count}",
        "wish_timeline_submitted": "送信: {date} · {time}",
        "wish_timeline_rejected": "拒否: {date} · {time}",
        "mail_subject": "{{user_name}} からの新しいお問い合わせ",
        "save_location_dialog_content": "ロケーション「{locationName}」を永久に保存しますか？",
        "party_code_retry_exhausted": "{count} 回試行しましたが有効なパーティコードを生成できませんでした。もう一度お試しください。",
        "wish_since_minutes": "{min}分前",
        "wish_since_hours_minutes": "{hours}時間{min}分前",
        "total_wishes_overall_count": "リクエスト総数: {count}",
        "dj_notification_line": "VibesBox: 新しいリクエスト - {title} - {artist}",
        "social_connect_with": "{djName} とつながる",
        "dialog_admin_change_role_title": "{name} のロールを変更",
        "snackbar_lifetime_revoked": "{name} の Lifetime ステータスを取り消しました。",
        "dialog_admin_change_password_title": "{name} のパスワードを変更",
        "announcement_progress_translating_to": "{label} に翻訳中…",
        "announcement_progress_translating_subject": "{label} に翻訳中…（件名）",
        "announcement_translate_failed": "{code} への翻訳に失敗:",
        "admin_lifetime_body_grant": "{name} に Lifetime Pro を付与しますか？",
        "admin_lifetime_body_revoke": "{name} の Lifetime ステータスを取り消しますか？",
        "admin_password_changed_success": "{name} のパスワードを変更しました。",
        "stats_error_permission_denied": "データベースへのアクセスが拒否されました（ロール: {role}）",
        "admin_pending_wishes_plural": "未処理のリクエストが {count} 件あります。",
        "snackbar_wishes_updated_many": "{count} 件のリクエストを更新しました。",
        "imprint_html_content": (
            "<h1>Impressum</h1> <p>ドイツ法 §5 DDG に基づく情報</p> "
            "<p>VibesBox by Swen Steller<br> Neefestr. 9<br> 09119 Chemnitz<br> ドイツ</p> "
            "<p>メール: info@vibesbox.app</p>"
        ),
    },
}


def main() -> None:
    total = 0
    for locale, keys in FILL.items():
        path = L10N / f"app_{locale}.arb"
        if not path.exists():
            print(f"SKIP {path.name}")
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        changed = 0
        for key, value in keys.items():
            if not str(data.get(key, "")).strip():
                data[key] = value
                changed += 1
        if changed:
            path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
            print(f"filled {path.name}: {changed} keys")
            total += changed
    print(f"Done: {total} fills")


if __name__ == "__main__":
    main()
