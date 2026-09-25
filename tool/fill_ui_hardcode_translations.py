#!/usr/bin/env python3
"""Sinnvolle Übersetzungen für die neuen UI-L10n-Keys in alle ARBs."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / "l10n"

# DE ist Quelle der Wahrheit (bereits in app_de.arb).
# EN bereits gesetzt. Hier: alle anderen Sprachen.

T: dict[str, dict[str, str]] = {
    "fr": {
        "pro_promotion_banner_message": "VibesBox Pro pour un contrôle total",
        "open_wishes_reorder_hint": (
            "Réorganisation : la ligne blanche = position de dépôt — aussi avant le premier et après le dernier titre."
        ),
        "mandatory_profile_title": "Compléter le profil",
        "mandatory_profile_intro": (
            "Pour améliorer VibesBox et à des fins purement statistiques, nous avons encore besoin de quelques informations. "
            "Vos données sont traitées de manière confidentielle et ne sont pas utilisées ailleurs."
        ),
        "mandatory_profile_name_hint": "Prénom et nom",
        "mandatory_profile_name_required": "Veuillez indiquer un nom.",
        "mandatory_profile_country_label": "Pays",
        "mandatory_profile_country_required": "Veuillez choisir un pays.",
        "mandatory_profile_pick_birthdate": "Choisir la date de naissance",
        "mandatory_profile_birthdate_future": "La date ne peut pas être dans le futur.",
        "mandatory_profile_min_age": "Vous devez avoir au moins 10 ans.",
        "mandatory_profile_birthdate_immutable": "La date de naissance ne pourra plus être modifiée plus tard !",
        "history_save_log_title": "Journal d'enregistrement de l'historique",
        "history_save_log_empty": (
            "Aucune entrée pour l'instant. Activez la reconnaissance musicale, détectez un titre, puis rouvrez ici."
        ),
        "history_save_log_empty_session": "Aucun journal d'historique dans cette session.",
        "history_save_log_share_subject": "Journal d'historique VibesBox",
        "log_copied_to_clipboard": "Journal copié dans le presse-papiers",
        "diagnostic_log_title": "Journal de diagnostic",
        "diagnostic_log_description": (
            "Journal sur cet appareil (aussi en version release). Après un plantage ou un gel : "
            "vérifiez ou exportez ici. Aucun envoi automatique vers le cloud."
        ),
        "diagnostic_log_settings_subtitle": "Enregistrer les erreurs et événements sur cet appareil",
        "diagnostic_log_capture_active": "Enregistrement actif",
        "diagnostic_log_capture_on_hint": "Erreurs, snackbars rouges, party, cycle de vie, Shazam",
        "diagnostic_log_capture_off_hint": "En pause — affichage des anciennes entrées uniquement",
        "diagnostic_log_empty": "Aucune entrée pour l'instant.\nUtilisez l'app — les problèmes apparaîtront ici.",
        "diagnostic_log_share_subject": "Journal de diagnostic VibesBox",
        "diagnostic_log_clear_title": "Vider le journal ?",
        "diagnostic_log_clear_body": "Toutes les entrées sur cet appareil seront supprimées.",
        "copy": "Copier",
        "share": "Partager",
        "clear": "Vider",
        "filter_all": "Tous",
        "location_enable_gps_hint": "Veuillez activer le GPS dans les réglages pour trouver votre position.",
        "location_tap_button_hint": "Touchez le bouton de localisation (en haut à droite) pour utiliser votre position.",
        "location_fallback_banner": (
            "Impossible de déterminer votre position ; la carte montre une position par défaut. "
            "Touchez le réticule dans la barre pour réessayer."
        ),
        "location_position_label": "Position",
        "location_resolving_address": "Adresse et fuseau horaire en cours de résolution...",
        "location_search_label": "Rechercher un lieu",
        "location_search_hint": "p. ex. Marsa Alam, Club XYZ, désert, plage",
        "music_recognition_settings_title": "Réglages de reconnaissance musicale",
        "music_recognition_info_tooltip": "Informations sur la reconnaissance musicale",
        "shazam_autostart_label": "Démarrer automatiquement la reconnaissance musicale si une party est active",
        "shazam_autostart_description": (
            "Démarre automatiquement la reconnaissance musicale dès qu'une de vos parties devient active dans le cloud"
        ),
        "vibesbox_status_title": "Statut VibesBox",
        "status_enabled": "Activé",
        "status_disabled": "Désactivé",
        "not_logged_in": "Non connecté",
        "admin_lock_account_title": "Verrouiller le compte (connexion) ?",
        "admin_unlock_account_title": "Déverrouiller le compte ?",
        "admin_lock_account_body": (
            "Verrouiller « {name} » pour la connexion ? Le compte ne pourra plus se connecter."
        ),
        "admin_unlock_account_body": "Autoriser à nouveau « {name} » à se connecter normalement ?",
        "admin_account_locked_snackbar": "Compte verrouillé : {name}",
        "admin_account_unlocked_snackbar": "Compte déverrouillé : {name}",
        "admin_lock_action": "Verrouiller",
        "admin_unlock_action": "Déverrouiller",
        "password_required": "Veuillez saisir un mot de passe.",
        "password_min_length_8": "Au moins 8 caractères requis.",
        "admin_otp_no_secret": "Aucun secret admin configuré.",
        "admin_otp_invalid": "Code invalide. Veuillez réessayer.",
        "admin_otp_check_failed": "Échec de la vérification du code.",
        "admin_otp_required": "Code d'authenticator requis",
        "admin_otp_verifying": "Vérification de l'accès admin...",
        "admin_no_permission": "Pas d'autorisation admin.",
        "notification_channel_new_wishes": "Nouveaux souhaits",
        "notification_channel_new_wishes_desc": "Notifications pour les nouveaux souhaits",
        "error_loading_prefix": "Erreur de chargement",
        "music_recognition_none_found": "Aucun titre reconnu pour l'instant",
        "device_android_label": "Appareil Android",
    },
    "es": {
        "pro_promotion_banner_message": "VibesBox Pro para control total",
        "open_wishes_reorder_hint": (
            "Reordenar: la línea blanca = posición de colocación — también antes del primero y después del último."
        ),
        "mandatory_profile_title": "Completar perfil",
        "mandatory_profile_intro": (
            "Para mejorar VibesBox y con fines puramente estadísticos, aún necesitamos algunos datos. "
            "Tus datos se tratan de forma confidencial y no se usan en otro lugar."
        ),
        "mandatory_profile_name_hint": "Nombre y apellidos",
        "mandatory_profile_name_required": "Introduce tu nombre.",
        "mandatory_profile_country_label": "País",
        "mandatory_profile_country_required": "Selecciona un país.",
        "mandatory_profile_pick_birthdate": "Elegir fecha de nacimiento",
        "mandatory_profile_birthdate_future": "La fecha no puede ser futura.",
        "mandatory_profile_min_age": "Debes tener al menos 10 años.",
        "mandatory_profile_birthdate_immutable": "¡La fecha de nacimiento no se podrá cambiar después!",
        "history_save_log_title": "Registro de guardado del historial",
        "history_save_log_empty": (
            "Aún no hay entradas. Activa el reconocimiento musical, detecta una canción y vuelve a abrir."
        ),
        "history_save_log_empty_session": "No hay registros de historial en esta sesión.",
        "history_save_log_share_subject": "Registro de historial VibesBox",
        "log_copied_to_clipboard": "Registro copiado al portapapeles",
        "diagnostic_log_title": "Registro de diagnóstico",
        "diagnostic_log_description": (
            "Registro en este dispositivo (también en release). Tras un fallo o bloqueo: "
            "revisa o exporta aquí. Sin envío automático a la nube."
        ),
        "diagnostic_log_settings_subtitle": "Registrar errores y eventos en este dispositivo",
        "diagnostic_log_capture_active": "Grabación activa",
        "diagnostic_log_capture_on_hint": "Errores, snackbars rojos, fiesta, ciclo de vida, Shazam",
        "diagnostic_log_capture_off_hint": "En pausa — solo entradas antiguas",
        "diagnostic_log_empty": "Aún no hay entradas.\nUsa la app — aquí aparecerán los problemas.",
        "diagnostic_log_share_subject": "Registro de diagnóstico VibesBox",
        "diagnostic_log_clear_title": "¿Vaciar registro?",
        "diagnostic_log_clear_body": "Se eliminarán todas las entradas de este dispositivo.",
        "copy": "Copiar",
        "share": "Compartir",
        "clear": "Vaciar",
        "filter_all": "Todos",
        "location_enable_gps_hint": "Activa el GPS en ajustes para encontrar tu ubicación.",
        "location_tap_button_hint": "Toca el botón de ubicación (arriba a la derecha) para usar tu posición.",
        "location_fallback_banner": (
            "No se pudo determinar tu ubicación; el mapa muestra una posición predeterminada. "
            "Toca la cruz en la barra para intentarlo de nuevo."
        ),
        "location_position_label": "Posición",
        "location_resolving_address": "Obteniendo dirección y zona horaria...",
        "location_search_label": "Buscar ubicación",
        "location_search_hint": "p. ej. Marsa Alam, Club XYZ, desierto, playa",
        "music_recognition_settings_title": "Ajustes de reconocimiento musical",
        "music_recognition_info_tooltip": "Información sobre el reconocimiento musical",
        "shazam_autostart_label": "Iniciar reconocimiento musical automáticamente si hay fiesta activa",
        "shazam_autostart_description": (
            "Inicia el reconocimiento musical automáticamente cuando una de tus fiestas se active en la nube"
        ),
        "vibesbox_status_title": "Estado de VibesBox",
        "status_enabled": "Activado",
        "status_disabled": "Desactivado",
        "not_logged_in": "No has iniciado sesión",
        "admin_lock_account_title": "¿Bloquear cuenta (inicio de sesión)?",
        "admin_unlock_account_title": "¿Desbloquear cuenta?",
        "admin_lock_account_body": (
            "¿Bloquear a «{name}» para iniciar sesión? La cuenta ya no podrá entrar."
        ),
        "admin_unlock_account_body": "¿Permitir de nuevo que «{name}» inicie sesión con normalidad?",
        "admin_account_locked_snackbar": "Cuenta bloqueada: {name}",
        "admin_account_unlocked_snackbar": "Cuenta desbloqueada: {name}",
        "admin_lock_action": "Bloquear",
        "admin_unlock_action": "Desbloquear",
        "password_required": "Introduce una contraseña.",
        "password_min_length_8": "Se requieren al menos 8 caracteres.",
        "admin_otp_no_secret": "No hay secreto de administrador configurado.",
        "admin_otp_invalid": "Código no válido. Inténtalo de nuevo.",
        "admin_otp_check_failed": "Error al verificar el código.",
        "admin_otp_required": "Se requiere código del autenticador",
        "admin_otp_verifying": "Verificando acceso de administrador...",
        "admin_no_permission": "Sin permiso de administrador.",
        "notification_channel_new_wishes": "Nuevos deseos",
        "notification_channel_new_wishes_desc": "Notificaciones de nuevos deseos",
        "error_loading_prefix": "Error al cargar",
        "music_recognition_none_found": "Aún no se han reconocido canciones",
        "device_android_label": "Dispositivo Android",
    },
}

# Compact packs for remaining langs (full dicts)
def _it() -> dict[str, str]:
    return {
        "pro_promotion_banner_message": "VibesBox Pro per il controllo completo",
        "open_wishes_reorder_hint": (
            "Riordino: la linea bianca = posizione di rilascio — anche prima del primo e dopo l'ultimo."
        ),
        "mandatory_profile_title": "Completa il profilo",
        "mandatory_profile_intro": (
            "Per migliorare VibesBox e per scopi puramente statistici, ci servono ancora alcuni dati. "
            "I tuoi dati sono trattati in modo confidenziale e non vengono usati altrove."
        ),
        "mandatory_profile_name_hint": "Nome e cognome",
        "mandatory_profile_name_required": "Inserisci il nome.",
        "mandatory_profile_country_label": "Paese",
        "mandatory_profile_country_required": "Seleziona un paese.",
        "mandatory_profile_pick_birthdate": "Scegli la data di nascita",
        "mandatory_profile_birthdate_future": "La data non può essere nel futuro.",
        "mandatory_profile_min_age": "Devi avere almeno 10 anni.",
        "mandatory_profile_birthdate_immutable": "La data di nascita non potrà più essere modificata!",
        "history_save_log_title": "Log di salvataggio cronologia",
        "history_save_log_empty": (
            "Nessuna voce. Attiva il riconoscimento musicale, rileva un brano e riapri qui."
        ),
        "history_save_log_empty_session": "Nessun log di cronologia in questa sessione.",
        "history_save_log_share_subject": "Log cronologia VibesBox",
        "log_copied_to_clipboard": "Log copiato negli appunti",
        "diagnostic_log_title": "Log di diagnostica",
        "diagnostic_log_description": (
            "Log su questo dispositivo (anche in release). Dopo un crash o un blocco: "
            "controlla o esporta qui. Nessun invio automatico al cloud."
        ),
        "diagnostic_log_settings_subtitle": "Registra errori ed eventi su questo dispositivo",
        "diagnostic_log_capture_active": "Registrazione attiva",
        "diagnostic_log_capture_on_hint": "Errori, snackbar rossi, party, ciclo di vita, Shazam",
        "diagnostic_log_capture_off_hint": "In pausa — solo voci precedenti",
        "diagnostic_log_empty": "Nessuna voce.\nUsa l'app — i problemi compariranno qui.",
        "diagnostic_log_share_subject": "Log diagnostica VibesBox",
        "diagnostic_log_clear_title": "Svuotare il log?",
        "diagnostic_log_clear_body": "Tutte le voci su questo dispositivo verranno eliminate.",
        "copy": "Copia",
        "share": "Condividi",
        "clear": "Svuota",
        "filter_all": "Tutti",
        "location_enable_gps_hint": "Attiva il GPS nelle impostazioni per trovare la tua posizione.",
        "location_tap_button_hint": "Tocca il pulsante posizione (in alto a destra) per usare la tua posizione.",
        "location_fallback_banner": (
            "Impossibile determinare la posizione; la mappa mostra una posizione predefinita. "
            "Tocca il mirino nella barra per riprovare."
        ),
        "location_position_label": "Posizione",
        "location_resolving_address": "Rilevamento indirizzo e fuso orario...",
        "location_search_label": "Cerca luogo",
        "location_search_hint": "es. Marsa Alam, Club XYZ, deserto, spiaggia",
        "music_recognition_settings_title": "Impostazioni riconoscimento musicale",
        "music_recognition_info_tooltip": "Informazioni sul riconoscimento musicale",
        "shazam_autostart_label": "Avvia automaticamente il riconoscimento musicale se c'è una festa attiva",
        "shazam_autostart_description": (
            "Avvia automaticamente il riconoscimento musicale quando una delle tue feste diventa attiva nel cloud"
        ),
        "vibesbox_status_title": "Stato VibesBox",
        "status_enabled": "Attivato",
        "status_disabled": "Disattivato",
        "not_logged_in": "Non connesso",
        "admin_lock_account_title": "Bloccare account (login)?",
        "admin_unlock_account_title": "Sbloccare account?",
        "admin_lock_account_body": (
            "Bloccare «{name}» per il login? L'account non potrà più accedere."
        ),
        "admin_unlock_account_body": "Consentire di nuovo a «{name}» di accedere normalmente?",
        "admin_account_locked_snackbar": "Account bloccato: {name}",
        "admin_account_unlocked_snackbar": "Account sbloccato: {name}",
        "admin_lock_action": "Blocca",
        "admin_unlock_action": "Sblocca",
        "password_required": "Inserisci una password.",
        "password_min_length_8": "Sono richiesti almeno 8 caratteri.",
        "admin_otp_no_secret": "Nessun secret admin configurato.",
        "admin_otp_invalid": "Codice non valido. Riprova.",
        "admin_otp_check_failed": "Verifica del codice non riuscita.",
        "admin_otp_required": "Codice authenticator richiesto",
        "admin_otp_verifying": "Verifica accesso admin...",
        "admin_no_permission": "Nessun permesso admin.",
        "notification_channel_new_wishes": "Nuovi desideri",
        "notification_channel_new_wishes_desc": "Notifiche per nuovi desideri",
        "error_loading_prefix": "Errore di caricamento",
        "music_recognition_none_found": "Nessun brano riconosciuto ancora",
        "device_android_label": "Dispositivo Android",
    }


T["it"] = _it()

T["nl"] = {
    "pro_promotion_banner_message": "VibesBox Pro voor volledige controle",
    "open_wishes_reorder_hint": (
        "Herordenen: witte lijn = neerzetpositie — ook vóór de eerste en na de laatste titel."
    ),
    "mandatory_profile_title": "Profiel voltooien",
    "mandatory_profile_intro": (
        "Om VibesBox te verbeteren en voor puur statistische doeleinden hebben we nog enkele gegevens nodig. "
        "Je gegevens worden vertrouwelijk behandeld en nergens anders gebruikt."
    ),
    "mandatory_profile_name_hint": "Voor- en achternaam",
    "mandatory_profile_name_required": "Voer een naam in.",
    "mandatory_profile_country_label": "Land",
    "mandatory_profile_country_required": "Kies een land.",
    "mandatory_profile_pick_birthdate": "Geboortedatum kiezen",
    "mandatory_profile_birthdate_future": "Datum mag niet in de toekomst liggen.",
    "mandatory_profile_min_age": "Je moet minstens 10 jaar oud zijn.",
    "mandatory_profile_birthdate_immutable": "De geboortedatum kan later niet meer worden gewijzigd!",
    "history_save_log_title": "Geschiedenis-opslaglog",
    "history_save_log_empty": (
        "Nog geen items. Zet muziekherkenning aan, herken een nummer en open hier opnieuw."
    ),
    "history_save_log_empty_session": "Geen geschiedenislogs in deze sessie.",
    "history_save_log_share_subject": "VibesBox geschiedenislog",
    "log_copied_to_clipboard": "Log naar klembord gekopieerd",
    "diagnostic_log_title": "Diagnose-log",
    "diagnostic_log_description": (
        "Log op dit apparaat (ook in release). Na een crash of freeze: "
        "hier controleren of exporteren. Geen automatische cloud-upload."
    ),
    "diagnostic_log_settings_subtitle": "Fouten en gebeurtenissen op dit apparaat loggen",
    "diagnostic_log_capture_active": "Opname actief",
    "diagnostic_log_capture_on_hint": "Fouten, rode snackbars, party, lifecycle, Shazam",
    "diagnostic_log_capture_off_hint": "Gepauzeerd — alleen oude items",
    "diagnostic_log_empty": "Nog geen items.\nGebruik de app — problemen verschijnen hier.",
    "diagnostic_log_share_subject": "VibesBox diagnose-log",
    "diagnostic_log_clear_title": "Log wissen?",
    "diagnostic_log_clear_body": "Alle items op dit apparaat worden verwijderd.",
    "copy": "Kopiëren",
    "share": "Delen",
    "clear": "Wissen",
    "filter_all": "Alle",
    "location_enable_gps_hint": "Schakel GPS in de instellingen in om je locatie te vinden.",
    "location_tap_button_hint": "Tik op de locatieknop (rechtsboven) om je positie te gebruiken.",
    "location_fallback_banner": (
        "Je locatie kon niet worden bepaald; de kaart toont een standaardpositie. "
        "Tik op het kruisdraad in de balk om opnieuw te proberen."
    ),
    "location_position_label": "Positie",
    "location_resolving_address": "Adres en tijdzone worden opgehaald...",
    "location_search_label": "Locatie zoeken",
    "location_search_hint": "bijv. Marsa Alam, Club XYZ, woestijn, strand",
    "music_recognition_settings_title": "Instellingen muziekherkenning",
    "music_recognition_info_tooltip": "Informatie over muziekherkenning",
    "shazam_autostart_label": "Muziekherkenning automatisch starten bij actieve party",
    "shazam_autostart_description": (
        "Start muziekherkenning automatisch zodra een van je party's in de cloud actief wordt"
    ),
    "vibesbox_status_title": "VibesBox-status",
    "status_enabled": "Ingeschakeld",
    "status_disabled": "Uitgeschakeld",
    "not_logged_in": "Niet ingelogd",
    "admin_lock_account_title": "Account vergrendelen (login)?",
    "admin_unlock_account_title": "Account ontgrendelen?",
    "admin_lock_account_body": (
        "„{name}” voor login vergrendelen? Het account kan dan niet meer inloggen."
    ),
    "admin_unlock_account_body": "Mag „{name}” weer normaal inloggen?",
    "admin_account_locked_snackbar": "Account vergrendeld: {name}",
    "admin_account_unlocked_snackbar": "Account ontgrendeld: {name}",
    "admin_lock_action": "Vergrendelen",
    "admin_unlock_action": "Ontgrendelen",
    "password_required": "Voer een wachtwoord in.",
    "password_min_length_8": "Minimaal 8 tekens vereist.",
    "admin_otp_no_secret": "Geen admin-secret geconfigureerd.",
    "admin_otp_invalid": "Ongeldige code. Probeer opnieuw.",
    "admin_otp_check_failed": "Codecontrole mislukt.",
    "admin_otp_required": "Authenticator-code vereist",
    "admin_otp_verifying": "Admin-toegang verifiëren...",
    "admin_no_permission": "Geen admin-rechten.",
    "notification_channel_new_wishes": "Nieuwe wensen",
    "notification_channel_new_wishes_desc": "Meldingen voor nieuwe wensen",
    "error_loading_prefix": "Fout bij laden",
    "music_recognition_none_found": "Nog geen nummers herkend",
    "device_android_label": "Android-apparaat",
}

# Remaining languages: load from companion JSON next to this script after write
# We'll embed PT, PL, RU, TR, UK, CS, EL, PT, SQ, JA, ZH, AR, HI, VI, TH below via external file for size.

def save_arb(path: Path, data: dict) -> None:
    items = list(data.items())
    lines = ["{"]
    for i, (k, v) in enumerate(items):
        comma = "," if i < len(items) - 1 else ""
        lines.append(
            f"\t{json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}{comma}"
        )
    lines.append("}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    extra = Path(__file__).with_name("ui_hardcode_l10n_translations_extra.json")
    if extra.exists():
        more = json.loads(extra.read_text(encoding="utf-8"))
        for lang, mapping in more.items():
            T.setdefault(lang, {}).update(mapping)

    updated = 0
    for lang, mapping in T.items():
        path = L10N / f"app_{lang}.arb"
        if not path.exists():
            print("skip missing", lang)
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        n = 0
        for k, v in mapping.items():
            if data.get(k) != v:
                data[k] = v
                n += 1
        if n:
            save_arb(path, data)
            updated += n
            print(f"{lang}: updated {n}")
        else:
            print(f"{lang}: unchanged")
    print(f"total field updates: {updated}")


if __name__ == "__main__":
    main()
