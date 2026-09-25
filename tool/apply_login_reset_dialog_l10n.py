#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Passwort-vergessen-Dialog: neue l10n-Keys in allen Sprachen."""

import json
from pathlib import Path
from typing import Dict

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

KEYS = [
    "login_reset_dialog_title",
    "login_reset_dialog_intro",
    "login_reset_dialog_send",
    "login_reset_sent_dialog_title",
    "login_reset_sent_dialog_body",
]

TRANSLATIONS: Dict[str, Dict[str, str]] = {
    "de": {
        "login_reset_dialog_title": "Passwort zurücksetzen",
        "login_reset_dialog_intro": "Gib die E-Mail-Adresse deines Kontos ein. Wir senden dir einen Link zum Zurücksetzen deines Passworts.",
        "login_reset_dialog_send": "Link senden",
        "login_reset_sent_dialog_title": "E-Mail gesendet",
        "login_reset_sent_dialog_body": "Wir haben dir eine E-Mail zum Zurücksetzen deines Passworts gesendet an:\n\n{email}",
    },
    "en": {
        "login_reset_dialog_title": "Reset password",
        "login_reset_dialog_intro": "Enter the email address for your account. We'll send you a link to reset your password.",
        "login_reset_dialog_send": "Send link",
        "login_reset_sent_dialog_title": "Email sent",
        "login_reset_sent_dialog_body": "We sent you a password reset email to:\n\n{email}",
    },
    "fr": {
        "login_reset_dialog_title": "Réinitialiser le mot de passe",
        "login_reset_dialog_intro": "Saisis l'adresse e-mail de ton compte. Nous t'enverrons un lien pour réinitialiser ton mot de passe.",
        "login_reset_dialog_send": "Envoyer le lien",
        "login_reset_sent_dialog_title": "E-mail envoyé",
        "login_reset_sent_dialog_body": "Nous t'avons envoyé un e-mail de réinitialisation du mot de passe à :\n\n{email}",
    },
    "es": {
        "login_reset_dialog_title": "Restablecer contraseña",
        "login_reset_dialog_intro": "Introduce el correo electrónico de tu cuenta. Te enviaremos un enlace para restablecer tu contraseña.",
        "login_reset_dialog_send": "Enviar enlace",
        "login_reset_sent_dialog_title": "Correo enviado",
        "login_reset_sent_dialog_body": "Te hemos enviado un correo para restablecer tu contraseña a:\n\n{email}",
    },
    "it": {
        "login_reset_dialog_title": "Reimposta password",
        "login_reset_dialog_intro": "Inserisci l'indirizzo e-mail del tuo account. Ti invieremo un link per reimpostare la password.",
        "login_reset_dialog_send": "Invia link",
        "login_reset_sent_dialog_title": "E-mail inviata",
        "login_reset_sent_dialog_body": "Ti abbiamo inviato un'e-mail per reimpostare la password a:\n\n{email}",
    },
    "pt": {
        "login_reset_dialog_title": "Redefinir palavra-passe",
        "login_reset_dialog_intro": "Introduz o endereço de e-mail da tua conta. Enviaremos um link para redefinir a tua palavra-passe.",
        "login_reset_dialog_send": "Enviar link",
        "login_reset_sent_dialog_title": "E-mail enviado",
        "login_reset_sent_dialog_body": "Enviámos-te um e-mail para redefinir a tua palavra-passe para:\n\n{email}",
    },
    "nl": {
        "login_reset_dialog_title": "Wachtwoord resetten",
        "login_reset_dialog_intro": "Voer het e-mailadres van je account in. We sturen je een link om je wachtwoord te resetten.",
        "login_reset_dialog_send": "Link versturen",
        "login_reset_sent_dialog_title": "E-mail verzonden",
        "login_reset_sent_dialog_body": "We hebben je een e-mail gestuurd om je wachtwoord te resetten naar:\n\n{email}",
    },
    "pl": {
        "login_reset_dialog_title": "Reset hasła",
        "login_reset_dialog_intro": "Podaj adres e-mail swojego konta. Wyślemy Ci link do zresetowania hasła.",
        "login_reset_dialog_send": "Wyślij link",
        "login_reset_sent_dialog_title": "E-mail wysłany",
        "login_reset_sent_dialog_body": "Wysłaliśmy Ci e-mail do resetu hasła na adres:\n\n{email}",
    },
    "cs": {
        "login_reset_dialog_title": "Obnovit heslo",
        "login_reset_dialog_intro": "Zadej e-mailovou adresu svého účtu. Pošleme ti odkaz pro obnovení hesla.",
        "login_reset_dialog_send": "Odeslat odkaz",
        "login_reset_sent_dialog_title": "E-mail odeslán",
        "login_reset_sent_dialog_body": "Poslali jsme ti e-mail pro obnovení hesla na:\n\n{email}",
    },
    "tr": {
        "login_reset_dialog_title": "Şifreyi sıfırla",
        "login_reset_dialog_intro": "Hesabının e-posta adresini gir. Şifreni sıfırlaman için bir bağlantı göndereceğiz.",
        "login_reset_dialog_send": "Bağlantı gönder",
        "login_reset_sent_dialog_title": "E-posta gönderildi",
        "login_reset_sent_dialog_body": "Şifre sıfırlama e-postasını şu adrese gönderdik:\n\n{email}",
    },
    "ru": {
        "login_reset_dialog_title": "Сброс пароля",
        "login_reset_dialog_intro": "Введи адрес электронной почты своего аккаунта. Мы отправим ссылку для сброса пароля.",
        "login_reset_dialog_send": "Отправить ссылку",
        "login_reset_sent_dialog_title": "Письмо отправлено",
        "login_reset_sent_dialog_body": "Мы отправили письмо для сброса пароля на:\n\n{email}",
    },
    "uk": {
        "login_reset_dialog_title": "Скинути пароль",
        "login_reset_dialog_intro": "Введи адресу електронної пошти свого облікового запису. Ми надішлемо посилання для скидання пароля.",
        "login_reset_dialog_send": "Надіслати посилання",
        "login_reset_sent_dialog_title": "Лист надіслано",
        "login_reset_sent_dialog_body": "Ми надіслали лист для скидання пароля на:\n\n{email}",
    },
    "ar": {
        "login_reset_dialog_title": "إعادة تعيين كلمة المرور",
        "login_reset_dialog_intro": "أدخل عنوان البريد الإلكتروني لحسابك. سنرسل لك رابطًا لإعادة تعيين كلمة المرور.",
        "login_reset_dialog_send": "إرسال الرابط",
        "login_reset_sent_dialog_title": "تم إرسال البريد",
        "login_reset_sent_dialog_body": "أرسلنا بريدًا لإعادة تعيين كلمة المرور إلى:\n\n{email}",
    },
    "hi": {
        "login_reset_dialog_title": "पासवर्ड रीसेट करें",
        "login_reset_dialog_intro": "अपने खाते का ईमेल पता दर्ज करें। हम आपको पासवर्ड रीसेट करने का लिंक भेजेंगे।",
        "login_reset_dialog_send": "लिंक भेजें",
        "login_reset_sent_dialog_title": "ईमेल भेजा गया",
        "login_reset_sent_dialog_body": "हमने पासवर्ड रीसेट ईमेल यहाँ भेजा है:\n\n{email}",
    },
    "ja": {
        "login_reset_dialog_title": "パスワードをリセット",
        "login_reset_dialog_intro": "アカウントのメールアドレスを入力してください。パスワード再設定用のリンクをお送りします。",
        "login_reset_dialog_send": "リンクを送信",
        "login_reset_sent_dialog_title": "メールを送信しました",
        "login_reset_sent_dialog_body": "パスワード再設定用のメールを次のアドレスに送信しました:\n\n{email}",
    },
    "zh": {
        "login_reset_dialog_title": "重置密码",
        "login_reset_dialog_intro": "请输入你账户的电子邮件地址。我们会向你发送重置密码的链接。",
        "login_reset_dialog_send": "发送链接",
        "login_reset_sent_dialog_title": "邮件已发送",
        "login_reset_sent_dialog_body": "我们已向以下地址发送了密码重置邮件:\n\n{email}",
    },
    "vi": {
        "login_reset_dialog_title": "Đặt lại mật khẩu",
        "login_reset_dialog_intro": "Nhập địa chỉ email của tài khoản. Chúng tôi sẽ gửi cho bạn liên kết để đặt lại mật khẩu.",
        "login_reset_dialog_send": "Gửi liên kết",
        "login_reset_sent_dialog_title": "Đã gửi email",
        "login_reset_sent_dialog_body": "Chúng tôi đã gửi email đặt lại mật khẩu tới:\n\n{email}",
    },
    "el": {
        "login_reset_dialog_title": "Επαναφορά κωδικού",
        "login_reset_dialog_intro": "Εισήγαγε τη διεύθυνση email του λογαριασμού σου. Θα σου στείλουμε σύνδεσμο για επαναφορά του κωδικού.",
        "login_reset_dialog_send": "Αποστολή συνδέσμου",
        "login_reset_sent_dialog_title": "Το email στάλθηκε",
        "login_reset_sent_dialog_body": "Σου στείλαμε email επαναφοράς κωδικού στη διεύθυνση:\n\n{email}",
    },
    "sq": {
        "login_reset_dialog_title": "Rivendos fjalëkalimin",
        "login_reset_dialog_intro": "Shkruaj adresën e emailit të llogarisë tënde. Do të të dërgojmë një lidhje për të rivendosur fjalëkalimin.",
        "login_reset_dialog_send": "Dërgo lidhjen",
        "login_reset_sent_dialog_title": "Emaili u dërgua",
        "login_reset_sent_dialog_body": "Të kemi dërguar një email për rivendosjen e fjalëkalimit te:\n\n{email}",
    },
}


def main() -> None:
    for arb_path in sorted(L10N.glob("app_*.arb")):
        locale = arb_path.stem.replace("app_", "")
        if locale not in TRANSLATIONS:
            print(f"Überspringe {locale} (keine Übersetzungen)")
            continue
        data = json.loads(arb_path.read_text(encoding="utf-8"))
        for key in KEYS:
            data[key] = TRANSLATIONS[locale][key]
        arb_path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"OK {arb_path.name}")


if __name__ == "__main__":
    main()
