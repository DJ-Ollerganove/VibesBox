import 'package:flutter/material.dart';
import 'locale_helper.dart';

class AppLocalizations {
  final Locale locale;
  late final Map<String, String> _translations;

  AppLocalizations(this.locale) {
    _translations = LocaleHelper.getTranslations(locale);
  }

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  String translate(String key) {
    return _translations[key] ?? key;
  }

  // Getter für häufig verwendete Übersetzungen
  String get appName => translate('app_name');
  String get language => translate('language');
  String get selectLanguage => translate('select_language');
  String get german => translate('german');
  String get english => translate('english');
  String get french => translate('french');
  String get russian => translate('russian');
  String get chinese => translate('chinese');
  String get spanish => translate('spanish');
  String get turkish => translate('turkish');
  String get arabic => translate('arabic');
  String get portuguese => translate('portuguese');
  String get addManualWish => translate('add_manual_wish');
  String get manualByDj => translate('manual_by_dj');
  String get pleaseEnterTitleOrArtist => translate('please_enter_title_or_artist');
  String get wishAdded => translate('wish_added');
  String get home => translate('home');
  String get navStartseite => translate('nav_startseite');
  
  // Greetings
  String get greeting_morning => translate('greeting_morning');
  String get greeting_day => translate('greeting_day');
  String get greeting_evening => translate('greeting_evening');
  String get greeting_night => translate('greeting_night');
  
  // DJ Greetings (without "bei")
  String get greeting_morning_dj => translate('greeting_morning_dj');
  String get greeting_day_dj => translate('greeting_day_dj');
  String get greeting_evening_dj => translate('greeting_evening_dj');
  String get greeting_night_dj => translate('greeting_night_dj');
  // Gast-Startseite: Begrüßung inkl. "bei VibesBox" (alle Sprachen)
  String get greeting_morning_vibesbox => translate('greeting_morning_vibesbox');
  String get greeting_day_vibesbox => translate('greeting_day_vibesbox');
  String get greeting_evening_vibesbox => translate('greeting_evening_vibesbox');
  String get greeting_night_vibesbox => translate('greeting_night_vibesbox');
  /// Personalisierte Gast-Begrüßung (Platzhalter {name}) — je Tageszeit.
  String greetingPersonalMorning(String name) =>
      translate('greeting_personal_morning').replaceAll('{name}', name);
  String greetingPersonalDay(String name) =>
      translate('greeting_personal_day').replaceAll('{name}', name);
  String greetingPersonalEvening(String name) =>
      translate('greeting_personal_evening').replaceAll('{name}', name);
  String greetingPersonalNight(String name) =>
      translate('greeting_personal_night').replaceAll('{name}', name);
  String get party_open => translate('party_open');
  
  // DJ Dashboard Header
  String get dj_dashboard_title => translate('dj_dashboard_title');
  String get dj_dashboard_subtitle => translate('dj_dashboard_subtitle');
  
  // Time
  String get never => translate('never');
  String get party_running_still => translate('party_running_still');
  String get party_starts_in => translate('party_starts_in');
  String get status_notification_title => translate('status_notification_title');
  String get status_notification_listening => translate('status_notification_listening');
  String get recognition_running => translate('recognition_running');
  String get recognition_success => translate('recognition_success');
  String get last_login_was => translate('last_login_was');
  String get partyManagement => translate('party_management');
  String get open => translate('open');
  String get played => translate('played');
  /// Musikerkennung hat den Wunsch als gespielt markiert (Tooltip/Semantics).
  String get automatically_recognized => translate('automatically_recognized');
  String get rejected => translate('rejected');
  String get blocked => translate('blocked');
  String get profile => translate('profile');
  String get socialMedia => translate('social_media');
  String get about => translate('about');
  String get history => translate('history');
  String get wishbox => translate('wishbox');
  /// DJ-Wunschbox: Party ohne Namen in Firestore / Session.
  String get wishbox_dj_party_unnamed => translate('wishbox_dj_party_unnamed');
  /// DJ-Wunschbox: Kopfzeile, wenn keine Party aktiv ist.
  String get wishbox_dj_no_party_selected =>
      translate('wishbox_dj_no_party_selected');
  /// DJ-Wunschbox: Label vor Startzeit (Doppelpunkt in der UI angehängt).
  String get wishbox_dj_party_start => translate('wishbox_dj_party_start');
  /// DJ-Wunschbox: Label vor Endzeit.
  String get wishbox_dj_party_end => translate('wishbox_dj_party_end');
  /// DJ-Wunschbox: Platzhalter, wenn eine Zeit fehlt.
  String get wishbox_dj_party_time_not_set =>
      translate('wishbox_dj_party_time_not_set');
  String get yourWishes => translate('your_wishes');
  /// Hinweis auf „Deine Wünsche“, wenn kein Nutzer eingeloggt ist.
  String get your_wishes_login_required_body =>
      translate('your_wishes_login_required_body');
  String get guestWishesPermissionHint =>
      translate('guest_wishes_permission_hint');
  String get totalVisitors => translate('total_visitors');

  // VibesBox Free / Pro (Gast-PWA & DJ-Limits)
  String get guest_pwa_pro_only_hint => translate('guest_pwa_pro_only_hint');
  String get free_dj_wish_limit_2h => translate('free_dj_wish_limit_2h');
  String get free_limit_info => translate('free_limit_info');
  String get free_dj_party_limit_reached => translate('free_dj_party_limit_reached');
  String get free_party_quota_used_this_period => translate('free_party_quota_used_this_period');
  String socialConnectWith(String djName) => translate('social_connect_with').replaceAll('{djName}', djName);
  String get social_no_pro => translate('social_no_pro');
  String get social_no_links => translate('social_no_links');
  String get social_media_guest_free_hint => translate('social_media_guest_free_hint');
  String get free_dj_limit_reached => translate('free_dj_limit_reached');
  String get current_billing_period => translate('current_billing_period');
  String get billing_period_to => translate('billing_period_to');
  String get free_feature_locked_title => translate('free_feature_locked_title');
  String get free_feature_locked_description => translate('free_feature_locked_description');
  String get free_feature_favorites_title => translate('free_feature_favorites_title');
  String get free_feature_favorites_description => translate('free_feature_favorites_description');
  String get favorites_page_title => translate('favorites_page_title');
  String get free_feature_guest_block_title => translate('free_feature_guest_block_title');
  String get free_feature_guest_block_description => translate('free_feature_guest_block_description');

  // History (Music)
  String get music_history_title => translate('music_history_title');
  String get history_guest_hint => translate('history_guest_hint');
  String get historyDesc => translate('history_desc');
  String get history_subtitle_empty => translate('history_subtitle_empty');
  String get history_subtitle_active => translate('history_subtitle_active');
  String get historyEmptyTitle => translate('history_empty_title');
  String get historyEmptySubtitle => translate('history_empty_subtitle');
  String get history_no_party_info => translate('history_no_party_info');
  String get history_empty_party_active_hint =>
      translate('history_empty_party_active_hint');
  String get history_archived_playlists => translate('history_archived_playlists');
  String get history_archived_playlists_empty =>
      translate('history_archived_playlists_empty');
  String get history_relative_today => translate('history_relative_today');
  String get history_relative_yesterday => translate('history_relative_yesterday');
  String history_relative_days_ago(int count) =>
      translate('history_relative_days_ago').replaceAll('{count}', count.toString());
  String history_session_duration_h_min(int hours, int minutes) =>
      translate('history_session_duration_h_min')
          .replaceAll('{hours}', hours.toString())
          .replaceAll('{minutes}', minutes.toString());
  String get history_playlist_detail_no_tracks =>
      translate('history_playlist_detail_no_tracks');
  String get history_playlist_delete_tooltip => translate('history_playlist_delete_tooltip');
  String get history_active_party => translate('history_active_party');
  String get history_recording_running => translate('history_recording_running');
  String get history_party_active_showing_songs => translate('history_party_active_showing_songs');
  String get history_error_loading_title => translate('history_error_loading_title');
  String get history_error_prefix => translate('history_error_prefix');
  String get history_connection_slow_title => translate('history_connection_slow_title');
  String get history_connection_slow_body => translate('history_connection_slow_body');
  String get history_no_music_recognition_history => translate('history_no_music_recognition_history');
  String get history_songs_appear_when_party_active => translate('history_songs_appear_when_party_active');
  String get history_delete_song_title => translate('history_delete_song_title');
  String get history_label_title => translate('history_label_title');
  String get history_label_artist => translate('history_label_artist');
  String get history_delete_song_confirm => translate('history_delete_song_confirm');
  String get history_yes_delete => translate('history_yes_delete');
  String get history_song_deleted => translate('history_song_deleted');
  String get history_track_delete_not_signed_in => translate('history_track_delete_not_signed_in');
  String get history_track_delete_session_missing => translate('history_track_delete_session_missing');
  String get history_track_delete_no_active_party => translate('history_track_delete_no_active_party');
  String get history_track_delete_session_wrong_party =>
      translate('history_track_delete_session_wrong_party');
  String get history_song_delete_error => translate('history_song_delete_error');
  String get history_rec_label => translate('history_rec_label');
  String get history_time_just_now => translate('history_time_just_now');
  String history_time_minutes_ago(int minutes) =>
      translate('history_time_minutes_ago').replaceAll('{minutes}', minutes.toString());
  String history_time_hours_ago(int hours) =>
      translate('history_time_hours_ago').replaceAll('{hours}', hours.toString());
  String get history_page => translate('history_page');
  String get history_page_previous => translate('history_page_previous');
  String get history_page_next => translate('history_page_next');
  
  // Wishbox / Deine Wünsche / Kontakt (UI)
  String wish_limit_remaining(int remaining, int limit) => translate('wish_limit_remaining')
      .replaceAll('{remaining}', remaining.toString())
      .replaceAll('{limit}', limit.toString());
  String get wish_limit_reset_next_hour => translate('wish_limit_reset_next_hour');
  String get wishbox_inactive_description => translate('wishbox_inactive_description');
  String get wishbox_scan_qr_first => translate('wishbox_scan_qr_first');
  String get party_code_input_hint => translate('party_code_input_hint');
  String get qr_scan_title => translate('qr_scan_title');
  String get qr_scan_hint => translate('qr_scan_hint');
  String get qr_scan_button => translate('qr_scan_button');
  String get qr_scan_permission_denied => translate('qr_scan_permission_denied');
  String get party_code_input_required => translate('party_code_input_required');
  String get party_code_input_invalid => translate('party_code_input_invalid');
  String get party_code_invalid_or_inactive => translate('party_code_invalid_or_inactive');
  String get party_code_invalid => translate('party_code_invalid');
  String get party_code_ended => translate('party_code_ended');
  String get party_code_not_started => translate('party_code_not_started');
  String get party_code_unknown => translate('party_code_unknown');
  String get party_start_at => translate('party_start_at');
  String get wish_title_label => translate('wish_title_label');
  String get wish_artist_label => translate('wish_artist_label');
  String get wish_title_or_artist_required => translate('wish_title_or_artist_required');
  /// DJ manueller Wunsch: Duplikat-Hinweise
  String get manualWishDuplicateHistoryAndOpen =>
      translate('manual_wish_duplicate_history_and_open');
  String get manualWishDuplicateHistoryOnly =>
      translate('manual_wish_duplicate_history_only');
  String get manualWishDuplicateOpenOnly =>
      translate('manual_wish_duplicate_open_only');
  String manualWishSavedSnack(String line) =>
      translate('manual_wish_saved_snack').replaceAll('{line}', line);
  String get wish_tap_for_suggestions => translate('wish_tap_for_suggestions');
  String get suggestionsAutoAppear => translate('suggestions_auto_appear');
  String catalogTopSongs(String artist) =>
      translate('catalog_top_songs').replaceAll('{artist}', artist);
  String get wish_greeting_label => translate('wish_greeting_label');
  String get wish_greeting_max_chars => translate('wish_greeting_max_chars');
  String get wish_greeting_max_chars_error => translate('wish_greeting_max_chars_error');
  String get wish_send_button => translate('wish_send_button');
  String get submitWish => translate('submit_wish');
  String get wish_success_thanks => translate('wish_success_thanks');
  String get wish_success_send_another => translate('wish_success_send_another');
  String get wish_send_another => translate('wish_send_another');
  String get wish_blocked_title => translate('wish_blocked_title');
  String get wish_blocked_body => translate('wish_blocked_body');
  /// Identisch zur Gast-PWA (`data-i18n` wishbox_blocked_*).
  String get wishbox_blocked_title => translate('wishbox_blocked_title');
  String get wishbox_blocked_message => translate('wishbox_blocked_message');
  String get guest_banned_notice => translate('guest_banned_notice');

  String get contact_info_vibesbox => translate('contact_info_vibesbox');
  String get contact_free_mode_info => translate('contact_free_mode_info');
  String get contact_success_title => translate('contact_success_title');
  String get contact_success_body => translate('contact_success_body');
  String get contact_support_success_title => translate('contact_support_success_title');
  String get contact_support_success_body => translate('contact_support_success_body');
  String get contact_success_ok => translate('contact_success_ok');
  String get contact_name_label_required => translate('contact_name_label_required');
  String get contact_name_label => translate('contact_name_label');
  String get contact_email_label => translate('contact_email_label');
  String get contact_phone_label => translate('contact_phone_label');
  String get contact_subject_label => translate('contact_subject_label');
  String get contact_message_label => translate('contact_message_label');
  String get contact_email_or_phone_helper => translate('contact_email_or_phone_helper');
  String get contact_email_or_phone_required => translate('contact_email_or_phone_required');
  String get contact_send_button => translate('contact_send_button');
  String get contact_validation_enter_name => translate('contact_validation_enter_name');
  String get contact_validation_email_or_phone => translate('contact_validation_email_or_phone');
  String get contact_validation_invalid_email => translate('contact_validation_invalid_email');
  String get contact_validation_enter_message => translate('contact_validation_enter_message');
  String get contact_phone_logged_in_helper => translate('contact_phone_logged_in_helper');
  String get contact_message_max_chars => translate('contact_message_max_chars');
  String get contact_sending => translate('contact_sending');
  String contact_error_sending(String error) =>
      translate('contact_error_sending').replaceAll('{error}', error);
  String get contact_error_title => translate('contact_error_title');
  String get contact_error_name_too_long => translate('contact_error_name_too_long');
  String get contact_error_subject_too_long => translate('contact_error_subject_too_long');
  String get contact_error_message_too_long => translate('contact_error_message_too_long');
  String get todoList => translate('todo_list');
  String get userManagement => translate('user_management');
  String get signIn => translate('sign_in');
  String get signOut => translate('sign_out');
  String get leaveParty => translate('leave_party');
  String get leavePartySession => translate('leave_party_session');
  String get wishSentDisclaimer => translate('wish_sent_disclaimer');
  String get pwaRequestHeaderText => translate('pwa_request_header_text');
  String get byDjPrefix => translate('by_dj_prefix');
  String get partyLabel => translate('party_label');
  String get wishSentReceived => translate('wish_sent_received');
  String get close => translate('close');
  
  // Home Page
  String get nice_to_see_you => translate('nice_to_see_you');
  String get welcome_to_music_wishes => translate('welcome_to_music_wishes');
  String get welcomeSubtitle => translate('welcome_subtitle');
  String get welcomeSubtitleTop => translate('welcome_subtitle_top');
  String get welcomeSubtitleBottom => translate('welcome_subtitle_bottom');
  String get welcomeFullText => translate('welcome_full_text');
  String get welcomeLine1 => translate('welcome_line_1');
  String get welcomeLine2 => translate('welcome_line_2');
  String get welcomeBodyText => translate('welcome_body_text');
  String get your_statistics => translate('your_statistics');
  String get djDashboardHeader => translate('dj_dashboard_header');
  String get djDashboardEmptyState => translate('dj_dashboard_empty_state');
  String get premiumFeatureInfoText => translate('premium_feature_info_text');
  String get getVibesboxPro => translate('get_vibesbox_pro');
  String get edit_greetings => translate('edit_greetings');
  String get additional_features_note => translate('additional_features_note');
  String get register_now => translate('register_now');
  String get or_login => translate('or_login');
  String get guest_login_hint => translate('guest_login_hint');
  String login_count_message(int count) => translate('login_count_message').replaceAll('{count}', count.toString());
  String wishes_sent_message(int count) => translate('wishes_sent_message').replaceAll('{count}', count.toString());
  String wishes_sent_message_plural(int count) => translate('wishes_sent_message_plural').replaceAll('{count}', count.toString());
  String songs_played_message(int count) => translate('songs_played_message').replaceAll('{count}', count.toString());
  String songs_played_message_plural(int count) => translate('songs_played_message_plural').replaceAll('{count}', count.toString());
  
  // Home Page - Party Info
  String get your_current_running_party => translate('your_current_running_party');
  String get your_next_planned_party => translate('your_next_planned_party');
  
  // Home Page - Admin Statistics
  String admin_total_wishes_singular(int count) => translate('admin_total_wishes_singular').replaceAll('{count}', count.toString());
  String admin_total_wishes_plural(int count) => translate('admin_total_wishes_plural').replaceAll('{count}', count.toString());
  String admin_pending_wishes_singular(int count) => translate('admin_pending_wishes_singular').replaceAll('{count}', count.toString());
  String admin_pending_wishes_plural(int count) => translate('admin_pending_wishes_plural').replaceAll('{count}', count.toString());
  String admin_played_wishes_singular(int count) => translate('admin_played_wishes_singular').replaceAll('{count}', count.toString());
  String admin_played_wishes_plural(int count) => translate('admin_played_wishes_plural').replaceAll('{count}', count.toString());
  String admin_rejected_wishes_singular(int count) => translate('admin_rejected_wishes_singular').replaceAll('{count}', count.toString());
  String admin_rejected_wishes_plural(int count) => translate('admin_rejected_wishes_plural').replaceAll('{count}', count.toString());
  String admin_not_played_wishes_singular(int count) => translate('admin_not_played_wishes_singular').replaceAll('{count}', count.toString());
  String admin_not_played_wishes_plural(int count) => translate('admin_not_played_wishes_plural').replaceAll('{count}', count.toString());
  String admin_deleted_wishes_singular(int count) => translate('admin_deleted_wishes_singular').replaceAll('{count}', count.toString());
  String admin_deleted_wishes_plural(int count) => translate('admin_deleted_wishes_plural').replaceAll('{count}', count.toString());
  String get distribution_processed_wishes => translate('distribution_processed_wishes');
  String get dj_statistics_description => translate('dj_statistics_description');
  String get no_data_available => translate('no_data_available');
  
  // Home Page - VibesBox
  String get vibesbox_disable_in_party => translate('vibesbox_disable_in_party');
  String get vibesbox_enable_in_party => translate('vibesbox_enable_in_party');
  String get vibesbox_manual_enable => translate('vibesbox_manual_enable');
  String get vibesbox_enabled_during_party => translate('vibesbox_enabled_during_party');
  String get vibesbox_disabled_during_party => translate('vibesbox_disabled_during_party');
  String get vibesbox_manual_enabled => translate('vibesbox_manual_enabled');
  String get vibesbox_only_during_party => translate('vibesbox_only_during_party');
  
  // Home Page - User Info
  String get logged_in_user_more_features => translate('logged_in_user_more_features');
  String get view_your_wishes_anytime => translate('view_your_wishes_anytime');
  String get manage_edit_profile => translate('manage_edit_profile');
  String get view_wish_statistics => translate('view_wish_statistics');
  String get available_as_guest => translate('available_as_guest');
  String get send_music_wishes => translate('send_music_wishes');
  String get use_contact_form => translate('use_contact_form');
  String get open_social_media_links => translate('open_social_media_links');
  String get contact_form_party_required_hint => translate('contact_form_party_required_hint');
  String get navigation_menu_can_do => translate('navigation_menu_can_do');
  String get see_vibesbox => translate('see_vibesbox');
  String get view_edit_profile => translate('view_edit_profile');
  String get see_your_submitted_wishes => translate('see_your_submitted_wishes');
  String get guest_home_nav_logged_hint_title =>
      translate('guest_home_nav_logged_hint_title');
  String get guest_home_nav_logged_hint_1 =>
      translate('guest_home_nav_logged_hint_1');
  String get guest_home_nav_logged_hint_2 =>
      translate('guest_home_nav_logged_hint_2');
  String get guest_home_nav_logged_hint_3 =>
      translate('guest_home_nav_logged_hint_3');
  String guest_home_stats_logins_line(int count) =>
      translate('guest_home_stats_logins_line')
          .replaceAll('{count}', count.toString());
  String guest_home_stats_wishes_line(int count) =>
      translate('guest_home_stats_wishes_line')
          .replaceAll('{count}', count.toString());
  
  // Home Page - Threshold
  String get duplicate_threshold_label => translate('duplicate_threshold_label');
  String get only_main_admin_can_change_threshold => translate('only_main_admin_can_change_threshold');
  String get threshold_validation_invalid => translate('threshold_validation_invalid');
  String threshold_saved(String percent) => translate('threshold_saved').replaceAll('{percent}', percent);
  String get error_saving_threshold => translate('error_saving_threshold');
  
  // Home Page - QR Code Dialog
  String get no_party_code_available => translate('no_party_code_available');
  
  // Common
  String get save => translate('save');
  String get saving_in_progress => translate('saving_in_progress');
  String get link => translate('link');
  String get pdf => translate('pdf');
  String get location_on_map => translate('location_on_map');
  String get changePosition => translate('change_position');
  String get show_location_label => translate('show_location_label');
  String get pdf_display_options => translate('pdf_display_options');
  String get pdf_checkbox_location => translate('pdf_checkbox_location');
  String get pdf_checkbox_phone => translate('pdf_checkbox_phone');
  String get pdf_checkbox_email => translate('pdf_checkbox_email');
  String get pdf_checkbox_alternative_email => translate('pdf_checkbox_alternative_email');
  String get cancel => translate('cancel');
  String get delete => translate('delete');
  String get deleted => translate('deleted');
  String get edit => translate('edit');
  String get ok => translate('ok');
  String get yes => translate('yes');
  String get no => translate('no');
  String get loading => translate('loading');
  String get error => translate('error');
  String get login_error_invalid_credentials => translate('login_error_invalid_credentials');
  String get login_error_inactive => translate('login_error_inactive');
  String get login_error_banned => translate('login_error_banned');
  /// Fehlende/ungültige Rollen-ID nach Login — erneut anmelden.
  String get login_error_role_data_invalid =>
      translate('login_error_role_data_invalid');
  String get login_title => translate('login_title');
  String get register_title => translate('register_title');
  String get login_email_label => translate('login_email_label');
  String get login_email_required => translate('login_email_required');
  String get login_email_invalid => translate('login_email_invalid');
  String get login_name_label => translate('login_name_label');
  String get login_name_required => translate('login_name_required');
  String get login_password_label => translate('login_password_label');
  String get login_password_required => translate('login_password_required');
  String get login_password_requirements_tooltip => translate('login_password_requirements_tooltip');
  String get login_password_requirements_content => translate('login_password_requirements_content');
  String get login_confirm_password_required => translate('login_confirm_password_required');
  String get login_save_password => translate('login_save_password');
  String get login_forgot_password => translate('login_forgot_password');
  String get login_switch_to_register => translate('login_switch_to_register');
  String get login_switch_to_login => translate('login_switch_to_login');
  String get login_profile_load_error_title => translate('login_profile_load_error_title');
  String get login_profile_load_error_body => translate('login_profile_load_error_body');
  /// Nach Login/Kaltstart: Reload der E-Mail-Verifizierung (Overlay, kein Flackern zur Verify-Seite).
  String get profile_loading_verification => translate('profile_loading_verification');
  String get login_contact_support => translate('login_contact_support');
  String get login_email_registration_blocked => translate('login_email_registration_blocked');
  String get login_name_blocked => translate('login_name_blocked');
  String get login_registration_success => translate('login_registration_success');
  String get login_reset_email_required => translate('login_reset_email_required');
  String get login_reset_email_sent => translate('login_reset_email_sent');
  String get login_email_already_registered => translate('login_email_already_registered');
  String get login_password_weak_firebase => translate('login_password_weak_firebase');
  String get login_invalid_email => translate('login_invalid_email');
  String get login_operation_not_allowed => translate('login_operation_not_allowed');
  String get verify_email_title => translate('verify_email_title');
  String get verify_email_message => translate('verify_email_message');
  /// Platzhalter `{email}` in [verify_email_message].
  String verify_email_message_for(String email) =>
      translate('verify_email_message').replaceAll('{email}', email);
  String get verify_email_resend => translate('verify_email_resend');
  String get verify_email_refresh => translate('verify_email_refresh');
  String get verify_email_check => translate('verify_email_check');
  String get verify_email_still_pending =>
      translate('verify_email_still_pending');
  String get verify_email_logout => translate('verify_email_logout');
  String get registration_in_progress => translate('registration_in_progress');
  String get role_guest => translate('role_guest');
  String get date_uhr => translate('date_uhr');
  String get verify_success_title => translate('verify_success_title');
  String get verify_success => translate('verify_success');
  String get verify_error => translate('verify_error');
  String get verify_success_instruction => translate('verify_success_instruction');
  String get verify_error_title => translate('verify_error_title');
  String get verify_error_instruction_login =>
      translate('verify_error_instruction_login');
  String get manual_code_hint => translate('manual_code_hint');
  String get verify_manual_submit => translate('verify_manual_submit');
  String get verify_manual_check => translate('verify_manual_check');
  String get error_too_many_requests => translate('error_too_many_requests');
  String get login_registration_profile_failed =>
      translate('login_registration_profile_failed');
  /// Profil-Write fehlgeschlagen, Verifizierungs-Mail wurde (laut Ablauf) vermutlich gesendet.
  String get login_registration_profile_failed_after_email_ok =>
      translate('login_registration_profile_failed_after_email_ok');
  /// Registrierung ok, aber Callable/Netzwerk hat keine Verifizierungs-Mail gesendet.
  String get login_verification_email_send_failed =>
      translate('login_verification_email_send_failed');
  /// E-Mail: Verifizierung — HTML; Platzhalter {userName}, {link}, {confirm_email_button} (Button-Text in App durch [confirm_email_button] ersetzt).
  String get auth_email_verification_subject =>
      translate('auth_email_verification_subject');
  String get auth_email_verification_body =>
      translate('auth_email_verification_body');
  String get confirm_email_button => translate('confirm_email_button');
  /// E-Mail: Passwort zurücksetzen — Platzhalter {userName}, {link}
  String get auth_password_reset_subject =>
      translate('auth_password_reset_subject');
  String get auth_password_reset_body => translate('auth_password_reset_body');
  String get role_selection_title => translate('role_selection_title');
  String get i_am_guest => translate('i_am_guest');
  String get i_am_dj => translate('i_am_dj');
  String get dj_confirm_title => translate('dj_confirm_title');
  String get dj_confirm_message => translate('dj_confirm_message');
  String get dj_confirm_yes => translate('dj_confirm_yes');
  String get dj_confirm_no => translate('dj_confirm_no');
  String get role_selection_required => translate('role_selection_required');
  String get success => translate('success');

  // App-Update-Dialog
  String get updateRequiredTitle => translate('update_required_title');
  String get updateAvailableTitle => translate('update_available_title');
  String get updateButton => translate('update_button');
  String get updateCancelButton => translate('update_cancel_button');
  String get updateMandatoryExitButton => translate('update_mandatory_exit_button');
  String get laterButton => translate('later_button');
  String get updateDescriptionMandatory => translate('update_description_mandatory');
  String get updateDescriptionOptional => translate('update_description_optional');
  String get updateVersionAvailable => translate('update_version_available');
  String get updateStoreLabel => translate('update_store_label');
  String get updateLocalLabel => translate('update_local_label');
  String get updateMatrixTitle => translate('update_matrix_title');
  String get updateMatrixSubtitle => translate('update_matrix_subtitle');
  String get updateMilestoneHint => translate('update_milestone_hint');
  String get updateCurrentVersionLabel => translate('update_current_version_label');
  String get updateTargetVersionLabel => translate('update_target_version_label');
  String get updateTargetVersionHint => translate('update_target_version_hint');
  String get updateVersionMajor => translate('update_version_major');
  String get updateVersionMinor => translate('update_version_minor');
  String get updateVersionPatch => translate('update_version_patch');
  String get updateNewTargetVersionPreview => translate('update_new_target_version_preview');
  String get updateCheckboxQuestion => translate('update_checkbox_question');
  String get updateMinVersionDjAndroid => translate('update_min_version_dj_android');
  String get updateMinVersionDjIos => translate('update_min_version_dj_ios');
  String get updateMinVersionGuestAndroid => translate('update_min_version_guest_android');
  String get updateMinVersionGuestIos => translate('update_min_version_guest_ios');
  String get updateSaveButton => translate('update_save_button');
  String get updateSavedMessage => translate('update_saved_message');
  String updateSaveErrorMessage(String error) => translate('update_save_error').replaceAll('{error}', error);

  // Offen Page
  String get open_wishes => translate('open_wishes');
  String get no_active_party => translate('no_active_party');
  String get no_active_party_description => translate('no_active_party_description');
  String get no_active_party_message => translate('no_active_party_message');
  String get no_wishes_yet => translate('no_wishes_yet');
  String get no_open_wishes => translate('no_open_wishes');
  String get new_label => translate('new_label');
  String get block => translate('block');
  String get delete_or_reject_wish => translate('delete_or_reject_wish');
  String get reject_or_delete_question => translate('reject_or_delete_question');
  String get back => translate('back');
  String get what_to_do_with_wish => translate('what_to_do_with_wish');
  String get nothing => translate('nothing');
  String get reject => translate('reject');
  String get wish_deleted => translate('wish_deleted');
  String get error_deleting => translate('error_deleting');
  String get confirm_wish_action => translate('confirm_wish_action');
  String get status_updated => translate('status_updated');
  String get error_updating => translate('error_updating');
  String get no_user_info_found => translate('no_user_info_found');
  String get block_user => translate('block_user');
  String get block_for => translate('block_for');
  String get how_to_block => translate('how_to_block');
  String get block_for_party_only => translate('block_for_party_only');
  String get block_permanently => translate('block_permanently');
  String get not_authorized => translate('not_authorized');
  String get error_blocking => translate('error_blocking');
  String get wish_details => translate('wish_details');
  String get wish => translate('wish');
  String get genre => translate('genre');
  String get requested_by => translate('requested_by');
  String get requested_versions => translate('requested_versions');
  String get greeting => translate('greeting');
  String get requested_at => translate('requested_at');
  String get duplicates => translate('duplicates');
  String get is_duplicate => translate('is_duplicate');
  String get original_wish_id => translate('original_wish_id');
  String get played_at => translate('played_at');
  String get played_at_um => translate('played_at_um');
  String get rejected_at_um => translate('rejected_at_um');
  String wishPlayedAt(String time) => translate('wish_played_at').replaceAll('{time}', time);
  String wishRejectedAt(String time) => translate('wish_rejected_at').replaceAll('{time}', time);
  String get status_changed => translate('status_changed');
  String get status_reason => translate('status_reason');
  String get mark_as_played => translate('mark_as_played');
  String get blocked_permanently => translate('blocked_permanently');
  String get blocked_for_party => translate('blocked_for_party');
  String get was_blocked => translate('was_blocked');
  String get blocked_action => translate('blocked_action');
  
  // Gespielt Page
  String get played_wishes => translate('played_wishes');
  String get no_played_wishes => translate('no_played_wishes');
  String get played_at_label => translate('played_at');
  String get back_to_open => translate('back_to_open');
  String get confirm_reopen_title => translate('confirm_reopen_title');
  String get confirm_reopen_message => translate('confirm_reopen_message');
  String get confirm_reopen_yes => translate('confirm_reopen_yes');
  String get confirm_reopen_no => translate('confirm_reopen_no');
  String wish_group_count(int count) =>
      translate('wish_group_count').replaceAll('{count}', count.toString());
  String wish_timeline_submitted(String date, String time) =>
      translate('wish_timeline_submitted')
          .replaceAll('{date}', date)
          .replaceAll('{time}', time);
  String wish_timeline_rejected(String date, String time) =>
      translate('wish_timeline_rejected')
          .replaceAll('{date}', date)
          .replaceAll('{time}', time);
  String get error_no_party_id_found => translate('error_no_party_id_found');
  String error_with_message(String message) =>
      translate('error_with_message').replaceAll('{message}', message);
  String get guest_blocked_badge => translate('guest_blocked_badge');
  String guest_blocked_badge_with_occurrence(int count) =>
      translate('guest_blocked_badge_with_occurrence')
          .replaceAll('{count}', count.toString());
  String get delete_permanently => translate('delete_permanently');
  String get confirm_delete_permanently => translate('confirm_delete_permanently');
  
  // Abgelehnt Page
  String wish_restored_count(int count) => translate('wish_restored_count').replaceAll('{count}', count.toString());
  String get rejected_wishes => translate('rejected_wishes');
  String get no_rejected_wishes => translate('no_rejected_wishes');
  String get rejected_at => translate('rejected_at');
  
  // Gesperrt Page
  String get blocked_guests => translate('blocked_guests');
  String get no_blocked_guests => translate('no_blocked_guests');
  /// Leerer Zustand: aktive Party, aber noch keine Sperre in dieser Party.
  String get gesperrt_page_empty_active_party =>
      translate('gesperrt_page_empty_active_party');
  /// Badge z. B. „3. Sperre“ / History-Zähler.
  String gesperrt_block_history_badge(int count) =>
      translate('gesperrt_block_history_badge').replaceAll('{count}', '$count');
  String get all_guests_can_send => translate('all_guests_can_send');
  String get unknown => translate('unknown');
  String get vibesbox_pro_life => translate('vibesbox_pro_life');
  String get vibesbox_free => translate('vibesbox_free');
  String get vibesbox_pro => translate('vibesbox_pro');
  String get pro_activated_success => translate('pro_activated_success');
  String get click_for_pro_hint => translate('click_for_pro_hint');
  String get pro_runs_until => translate('pro_runs_until');
  String get trial_period_until_prefix => translate('trial_period_until_prefix');
  /// Free-Musikerkennung: Snackbar, [minutes] = volle Minuten (aufgerundet).
  String free_scan_cooldown_snackbar(int minutes) => translate(
        'free_scan_cooldown_snackbar',
      ).replaceAll('{minutes}', '$minutes');
  String get music_recognition_free_mode_interval_hint =>
      translate('music_recognition_free_mode_interval_hint');
  String get trial_activated_snackbar => translate('trial_activated_snackbar');
  String get trial_expired_dialog_message =>
      translate('trial_expired_dialog_message');
  String get trial_expired_dialog_ok => translate('trial_expired_dialog_ok');
  String get paywall_start_trial_button => translate('paywall_start_trial_button');
  /// Klartext unter dem 2-Tage-Pro-Button (kein Store-Abo / kein „Trial“-Marketing).
  String get paywall_promo_access_hint => translate('paywall_promo_access_hint');
  String get pro_life_revoked => translate('pro_life_revoked');
  String get payment_source_store => translate('payment_source_store');
  String get payment_amount_credit => translate('payment_amount_credit');
  String get payment_amount_gifted => translate('payment_amount_gifted');
  String get time_suffix => translate('time_suffix');
  String get permanently_blocked => translate('permanently_blocked');
  String get temporarily_blocked => translate('temporarily_blocked');
  String get blocked_at_label => translate('blocked_at');
  String get show_details => translate('show_details');
  String get unblock => translate('unblock');
  String get no_active_party_retry => translate('no_active_party_retry');
  String get profile_load_timeout_message => translate('profile_load_timeout_message');
  String get retry_button => translate('retry_button');
  String get error_loading_info => translate('error_loading_info');
  String get block_information => translate('block_information');
  String get block_status => translate('block_status');
  String get status => translate('status');
  String get blocked_on => translate('blocked_on');
  String get blocked_by => translate('blocked_by');
  String get greetings => translate('greetings');
  String get requested_songs => translate('requested_songs');
  String get no_title => translate('no_title');
  String get no_artist => translate('no_artist');
  String get no_greetings_or_songs => translate('no_greetings_or_songs');
  String get unblock_guest => translate('unblock_guest');
  String get confirm_unblock => translate('confirm_unblock');
  String get really_unblock => translate('really_unblock');
  String get was_unblocked => translate('was_unblocked');
  String get error_unblocking => translate('error_unblocking');
  
  // About Page
  String get aboutTextDj => translate('about_text_dj');
  String get aboutTextGuest => translate('about_text_guest');
  String get version => translate('version');
  String get deepStateTitle => translate('deepStateTitle');
  String get latencyLabel => translate('latencyLabel');
  String get connectionStable => translate('connectionStable');
  String get connectionLag => translate('connectionLag');
  String get labelConnection => translate('labelConnection');
  String get labelPartyId => translate('labelPartyId');
  String get labelDjId => translate('labelDjId');
  String get refreshStreams => translate('refreshStreams');
  String get newsPaperTitle => translate('newsPaperTitle');
  String get newsPaperLatency => translate('newsPaperLatency');
  String get newsPaperSync => translate('newsPaperSync');
  String get signalLabel => translate('signalLabel');
  String get frankenStateHeader => translate('frankenStateHeader');
  String get guestsTodayLabel => translate('guestsTodayLabel');
  String get guestsOnlineLabel => translate('guestsOnlineLabel');
  String get wishesOpenLabel => translate('wishesOpenLabel');
  String get reSyncStreams => translate('reSyncStreams');
  String get hardwareLabel => translate('hardwareLabel');
  String get networkLabel => translate('networkLabel');
  String get firebaseStateLabel => translate('firebaseStateLabel');
  String get connectionTestTitle => translate('connectionTestTitle');
  String get databaseLabel => translate('databaseLabel');
  String get remeasureLabel => translate('remeasureLabel');
  String get imprint => translate('imprint');
  String get privacyPolicy => translate('privacy_policy');
  
  // Impressum Page
  String get tmg_info => translate('tmg_info');
  String get address => translate('address');
  String get contact => translate('contact');
  String get phone => translate('phone');
  String get email => translate('email');
  
  // Mail / Kontakt-Template
  String mailSubject(String userName) =>
      translate('mail_subject').replaceAll('{{user_name}}', userName);
  String get mail_contact_header => translate('mail_contact_header');
  String get mail_contact_subject_line => translate('mail_contact_subject_line');
  String get mail_contact_intro_text => translate('mail_contact_intro_text');
  String get label_message => translate('label_message');
  String get label_sender => translate('label_sender');
  String get label_role => translate('label_role');
  String get label_party => translate('label_party');
  String get label_date => translate('label_date');
  String get label_reply_button => translate('label_reply_button');
  String get mail_footer_automated => translate('mail_footer_automated');
  String get responsible_content => translate('responsible_content');
  String get edit_imprint => translate('edit_imprint');
  String get imprint_saved => translate('imprint_saved');
  String get error_saving_imprint => translate('error_saving_imprint');
  String get imprintLegalNoteNonDe => translate('imprint_legal_note_non_de');
  String get imprintHtmlContent => translate('imprint_html_content');
  String get name => translate('name');
  String get street => translate('street');
  String get house_number => translate('house_number');
  String get postal_code => translate('postal_code');
  String get city => translate('city');
  String get phone_number => translate('phone_number');
  String get email_address => translate('email_address');
  
  // Impressum Content
  String get imprint_name => translate('imprint_name');
  String get imprint_address => translate('imprint_address');
  String get imprint_city => translate('imprint_city');
  String get imprint_phone => translate('imprint_phone');
  String get imprint_email => translate('imprint_email');
  String get imprint_legal_notices => translate('imprint_legal_notices');
  String get imprint_section1_title => translate('imprint_section1_title');
  String get imprint_section1_text => translate('imprint_section1_text');
  String get imprint_section2_title => translate('imprint_section2_title');
  String get imprint_section2_text => translate('imprint_section2_text');
  String get imprint_section3_title => translate('imprint_section3_title');
  String get imprint_section3_text => translate('imprint_section3_text');
  String get imprint_section4_title => translate('imprint_section4_title');
  String get imprint_section4_text => translate('imprint_section4_text');
  
  // Privacy Policy / DSGVO Content
  String get privacy_title => translate('privacy_title');
  String get privacy_section1_title => translate('privacy_section1_title');
  String get privacy_section1_text => translate('privacy_section1_text');
  String get privacy_section2_title => translate('privacy_section2_title');
  String get privacy_section2_text => translate('privacy_section2_text');
  String get privacy_section3_title => translate('privacy_section3_title');
  String get privacy_section3_text => translate('privacy_section3_text');
  String get privacy_section4_title => translate('privacy_section4_title');
  String get privacy_section4_text => translate('privacy_section4_text');
  String get privacy_section5_title => translate('privacy_section5_title');
  String get privacy_section5_text => translate('privacy_section5_text');
  
  // AGB / Terms and Conditions Content
  String get agb => translate('agb');
  String get agb_title => translate('agb_title');
  String get agb_intro => translate('agb_intro');
  String get agb_section1_title => translate('agb_section1_title');
  String get agb_section1_text => translate('agb_section1_text');
  String get agb_section2_title => translate('agb_section2_title');
  String get agb_section2_text => translate('agb_section2_text');
  String get agb_section3_title => translate('agb_section3_title');
  String get agb_section3_text => translate('agb_section3_text');
  String get agb_section4_title => translate('agb_section4_title');
  String get agb_section4_text => translate('agb_section4_text');
  String get agb_section5_title => translate('agb_section5_title');
  String get agb_section5_text => translate('agb_section5_text');
  String get termsOfServiceContent => translate('terms_of_service_content');

  // Profile Page
  String get please_log_in => translate('please_log_in');
  String get must_be_logged_in => translate('must_be_logged_in');
  String get change_image => translate('change_image');
  String get delete_image => translate('delete_image');
  String get name_label => translate('name_label');
  String get no_name => translate('no_name');
  String get email_label => translate('email_label');
  String get no_email => translate('no_email');
  String get registered_since => translate('registered_since');
  String get account_type => translate('account_type');
  String get guest => translate('guest');
  String get admin => translate('admin');
  String get free_account => translate('free_account');
  String get premium_member => translate('premium_member');
  String get change_password => translate('change_password');
  String get change_password_short => translate('change_password_short');
  String get switch_theme => translate('switch_theme');
  String get delete_account => translate('delete_account');
  String get delete_account_short => translate('delete_account_short');
  String get delete_account_question => translate('delete_account_question');
  String get delete_account_warning => translate('delete_account_warning');
  String get delete_account_permanently => translate('delete_account_permanently');
  String get delete_account_password_prompt => translate('delete_account_password_prompt');
  String get delete_account_requires_email => translate('delete_account_requires_email');
  String get confirm_delete_account => translate('confirm_delete_account');
  String get yes_delete => translate('yes_delete');
  String get account_deleted => translate('account_deleted');
  String get error_deleting_account => translate('error_deleting_account');
  String get delete_profile_picture => translate('delete_profile_picture');
  String get confirm_delete_profile_picture => translate('confirm_delete_profile_picture');
  String get profile_picture_deleted => translate('profile_picture_deleted');
  String get error_deleting_picture => translate('error_deleting_picture');
  String get error_processing_image => translate('error_processing_image');
  String get image_too_large => translate('image_too_large');
  String get profile_picture_uploaded => translate('profile_picture_uploaded');
  String get error_uploading => translate('error_uploading');
  String get new_password => translate('new_password');
  String get password_requirements => translate('password_requirements');
  String get password_must => translate('password_must');
  String get password_min_length => translate('password_min_length');
  String get password_uppercase => translate('password_uppercase');
  String get password_special_chars => translate('password_special_chars');
  String get confirm_new_password => translate('confirm_new_password');
  String get password_required => translate('password_required');
  String get password_too_short => translate('password_too_short');
  String get password_no_uppercase => translate('password_no_uppercase');
  String get password_no_special => translate('password_no_special');
  String get password_strength_weak => translate('password_strength_weak');
  String get password_strength_medium => translate('password_strength_medium');
  String get password_strength_strong => translate('password_strength_strong');
  String get password_strength_very_strong => translate('password_strength_very_strong');
  String get password_strength_tip => translate('password_strength_tip');
  String get password_info_hint => translate('password_info_hint');
  String get password_confirm_required => translate('password_confirm_required');
  String get passwords_dont_match => translate('passwords_dont_match');
  String get password_changed => translate('password_changed');
  String get error_changing_password => translate('error_changing_password');
  String get password_too_weak => translate('password_too_weak');
  String get recent_login_required => translate('recent_login_required');
  String get login_security_snackbar => translate('login_security_snackbar');
  String get edit_profile => translate('edit_profile');
  String get change_name => translate('change_name');
  String get change_email => translate('change_email');
  String get new_name => translate('new_name');
  String get name_cannot_be_empty => translate('name_cannot_be_empty');
  String get name_too_short => translate('name_too_short');
  String get name_not_allowed => translate('name_not_allowed');
  String get name_changed => translate('name_changed');
  String get error_changing_name => translate('error_changing_name');
  String get new_email_address => translate('new_email_address');
  String get confirmation_email_sent => translate('confirmation_email_sent');
  String get email_cannot_be_empty => translate('email_cannot_be_empty');
  String get invalid_email => translate('invalid_email');
  String get email_already_current => translate('email_already_current');
  String get send_confirmation_email => translate('send_confirmation_email');
  String get email_change_send_link => translate('email_change_send_link');
  String get confirmation_email_sent_to => translate('confirmation_email_sent_to');
  String get email_change_reauth_hint => translate('email_change_reauth_hint');
  String get email_change_check_inbox => translate('email_change_check_inbox');
  String get email_change_success_confirmed =>
      translate('email_change_success_confirmed');
  String get confirm_password => translate('confirm_password');
  String get your_password => translate('your_password');
  String get enter_password_to_confirm => translate('enter_password_to_confirm');
  String get password_cannot_be_empty => translate('password_cannot_be_empty');
  String get confirm => translate('confirm');
  String get error_sending_confirmation => translate('error_sending_confirmation');
  String get email_already_in_use => translate('email_already_in_use');
  String get invalid_email_address => translate('invalid_email_address');
  String get wrong_password => translate('wrong_password');
  String get email_changed => translate('email_changed');
  
  // Social Media Page
  String get social_media_title => translate('social_media_title');
  String get vibesbox_social_media_follow_hint => translate('vibesbox_social_media_follow_hint');
  String get vibesbox_social_intro => translate('vibesbox_social_intro');
  String get vibesbox_follow_updates_intro =>
      translate('vibesbox_follow_updates_intro');
  String get vibesbox_social_instagram_label =>
      translate('vibesbox_social_instagram_label');
  String get vibesbox_social_facebook_label =>
      translate('vibesbox_social_facebook_label');
  String get vibesbox_social_website_label =>
      translate('vibesbox_social_website_label');
  String get facebook => translate('facebook');
  String get instagram => translate('instagram');
  String get tiktok => translate('tiktok');
  String get spotify => translate('spotify');
  String get soundcloud => translate('soundcloud');
  String get youtube => translate('youtube');
  String get whatsapp => translate('whatsapp');
  String get website => translate('website');
  String get error_opening_link => translate('error_opening_link');
  String get error_opening => translate('error_opening');
  String get firebase_index_required_title =>
      translate('firebase_index_required_title');
  String get firebase_index_instruction =>
      translate('firebase_index_instruction');
  String get url_copied_to_clipboard_snackbar =>
      translate('url_copied_to_clipboard_snackbar');
  String get url_copy => translate('url_copy');
  String get open_in_browser => translate('open_in_browser');
  String get url_launch_failed_snackbar =>
      translate('url_launch_failed_snackbar');
  String url_open_error_with_detail_snackbar(String error) =>
      translate('url_open_error_with_detail_snackbar')
          .replaceAll('{error}', error);
  String get firebase_index_browser_tip =>
      translate('firebase_index_browser_tip');
  String get error_occurred_generic => translate('error_occurred_generic');
  String get no_social_media_links => translate('no_social_media_links');
  String get edit_social_media => translate('edit_social_media');
  String get add_social_media_link => translate('add_social_media_link');
  String get select_platform => translate('select_platform');
  String get enter_url => translate('enter_url');
  String get url_required => translate('url_required');
  String get invalid_url => translate('invalid_url');
  String get social_media_saved => translate('social_media_saved');
  String get error_saving_social_media => translate('error_saving_social_media');
  String get remove_link => translate('remove_link');
  String get drag_to_reorder_hint => translate('drag_to_reorder_hint');
  
  // Party Management Page
  String get party_status_upcoming => translate('party_status_upcoming');
  String get party_status_running => translate('party_status_running');
  String get party_status_ended => translate('party_status_ended');
  String get party_status_started => translate('party_status_started');
  String get party_status_starts_now => translate('party_status_starts_now');
  String get party_status_less_than_minute => translate('party_status_less_than_minute');
  String get party_status_ended_label => translate('party_status_ended_label');
  String get party_countdown_in => translate('party_countdown_in');
  String get party_countdown_still => translate('party_countdown_still');
  String get party_day => translate('party_day');
  String get party_days => translate('party_days');
  String get party_minute => translate('party_minute');
  String get party_minutes => translate('party_minutes');
  String get party_hour => translate('party_hour');
  String get party_hours => translate('party_hours');
  String get party_management_title => translate('party_management_title');
  String get no_active_parties => translate('no_active_parties');
  String get unnamed_party => translate('unnamed_party');
  String get show_qr_code => translate('show_qr_code');
  String get party_start => translate('party_start');
  String get party_end => translate('party_end');
  String get party_begin => translate('party_begin');
  String get party_edit => translate('party_edit');
  String get party_delete => translate('party_delete');
  String get party_ended => translate('party_ended');
  String get party_pause => translate('party_pause');
  String get party_resume => translate('party_resume');
  String get new_party => translate('new_party');
  String get edit_party => translate('edit_party');
  String get party_name_label => translate('party_name_label');
  String get party_name_display => translate('party_name_display');
  String get party_type_label => translate('party_type_label');
  String get party_type_private => translate('party_type_private');
  String get party_type_public => translate('party_type_public');
  String get party_type_display => translate('party_type_display');
  String get party_start_label => translate('party_start_label');
  String get party_end_label => translate('party_end_label');
  String get party_date_label => translate('party_date_label');
  String get party_time_label => translate('party_time_label');
  String get party_location_label => translate('party_location_label');
  String get party_not_selected => translate('party_not_selected');
  String get change_location => translate('change_location');
  String get clear_party_location => translate('clear_party_location');
  String get status_changes => translate('status_changes');
  String get wishbox_paused => translate('wishbox_paused');
  String get wishbox_resumed => translate('wishbox_resumed');
  String get party_wish_limits => translate('party_wish_limits');
  String get party_guest_limit => translate('party_guest_limit');
  String get party_user_limit => translate('party_user_limit');
  String get party_cancel => translate('party_cancel');
  String get party_save => translate('party_save');
  String get party_delete_title => translate('party_delete_title');
  String party_delete_confirm(String partyName) => translate('party_delete_confirm').replaceAll('{partyName}', partyName);
  String get party_delete_only_own => translate('party_delete_only_own');
  String get party_delete_not_started => translate('party_delete_not_started');
  String get party_delete_permission_denied => translate('party_delete_permission_denied');
  String get party_delete_error_start_time => translate('party_delete_error_start_time');
  String get party_delete_error => translate('party_delete_error');
  String get party_updated_success => translate('party_updated_success');
  String get party_deleted_success => translate('party_deleted_success');
  String get party_error_updating => translate('party_error_updating');
  String get party_error_deleting => translate('party_error_deleting');
  String get party_error_loading_limits => translate('party_error_loading_limits');
  String get party_error_generating_pdf => translate('party_error_generating_pdf');
  String get party_error_saving_qr => translate('party_error_saving_qr');
  String get party_qr_saved => translate('party_qr_saved');
  String get party_qr_save_error => translate('party_qr_save_error');
  String get party_pdf_3part => translate('party_pdf_3part');
  String get party_pdf_single => translate('party_pdf_single');
  String get party_pdf_save => translate('party_pdf_save');
  String get party_pdf_text => translate('party_pdf_text');
  String get party_pdf_font_downloading => translate('party_pdf_font_downloading');
  String get party_pdf_generating => translate('party_pdf_generating');
  String get party_pdf_export => translate('party_pdf_export');
  String get party_pdf_poster_a4 => translate('party_pdf_poster_a4');
  String get party_pdf_table_stand => translate('party_pdf_table_stand');
  String get party_pdf_flyer_4xa6 => translate('party_pdf_flyer_4xa6');
  String get party_pdf_a4_landscape_2xa5 =>
      translate('party_pdf_a4_landscape_2xa5');
  String get tooltip_copy_link => translate('tooltip_copy_link');
  String get wish_device_id_unavailable =>
      translate('wish_device_id_unavailable');
  String get party_validation_start_required => translate('party_validation_start_required');
  String get party_validation_end_required => translate('party_validation_end_required');
  String get party_validation_end_before_start => translate('party_validation_end_before_start');
  String get party_validation_end_in_past => translate('party_validation_end_in_past');
  String get party_validation_start_in_past => translate('party_validation_start_in_past');
  String get party_validation_guest_limit_required => translate('party_validation_guest_limit_required');
  String get party_validation_user_limit_required => translate('party_validation_user_limit_required');
  String get party_validation_duration_too_short => translate('party_validation_duration_too_short');
  String get party_validation_duration_too_long => translate('party_validation_duration_too_long');
  String get party_validation_overlap => translate('party_validation_overlap');
  String get party_validation_gap_too_short => translate('party_validation_gap_too_short');
  String get party_validation_too_far_future => translate('party_validation_too_far_future');
  String get party_error => translate('party_error');
  String get party_time_at => translate('party_time_at');
  String get party_time_clock => translate('party_time_clock');
  String get time_am => translate('time_am');
  String get time_pm => translate('time_pm');
  
  // DJ Dashboard Statistics
  String get stats_title => translate('stats_title');
  String get no_party_data_available => translate('no_party_data_available');
  String get start_your_first_party => translate('start_your_first_party');
  String get no_further_parties_planned => translate('no_further_parties_planned');
  String get status_running => translate('status_running');
  String get status_upcoming => translate('status_upcoming');
  String get status_no_party_planned => translate('status_no_party_planned');
  String get stats_live => translate('stats_live');
  String get stats_last_party => translate('stats_last_party');
  String get stats_no_party_completed => translate('stats_no_party_completed');
  /// Platzhalter unter der Statistik-Überschrift, wenn noch keine Party beendet wurde.
  String get stats_no_party_completed_hint =>
      translate('stats_no_party_completed_hint');
  String get live_party => translate('live_party');
  String get last_party => translate('last_party');
  String total_wishes_count(int count) => translate('total_wishes_count').replaceAll('{count}', count.toString());
  String total_logins_count(int count) => translate('total_logins_count').replaceAll('{count}', count.toString());
  String get last_login_on => translate('last_login_on');
  String get overall_balance => translate('overall_balance');
  String total_wishes_overall_count(int count) => translate('total_wishes_overall_count').replaceAll('{count}', count.toString());
  String get average_wait_time_label => translate('average_wait_time_label');
  String get played_songs_label => translate('played_songs_label');
  String get rejected_songs_label => translate('rejected_songs_label');
  String get open_songs_label => translate('open_songs_label');
  String get not_played_songs_label => translate('not_played_songs_label');
  String get deleted_songs_label => translate('deleted_songs_label');
  String get no_wishes_yet_hint => translate('no_wishes_yet_hint');
  String get logins_title => translate('logins_title');
  String get active_upcoming_party_title => translate('active_upcoming_party_title');
  
  // Audio Settings
  String get audio_settings_title => translate('audio_settings_title');
  String get audio_settings_info_tooltip => translate('audio_settings_info_tooltip');
  String get music_recognition_pro_only_notice => translate('music_recognition_pro_only_notice');
  String get scan_interval_label => translate('scan_interval_label');
  String get mic_sensitivity_label => translate('mic_sensitivity_label');
  String get recognition_threshold_label => translate('recognition_threshold_label');
  String get microphone_level_label => translate('microphone_level_label');
  String get smart_threshold_label => translate('smart_threshold_label');
  String get smart_threshold_description => translate('smart_threshold_description');
  String get smart_threshold_enabled_saved => translate('smart_threshold_enabled_saved');
  String get smart_threshold_disabled_saved => translate('smart_threshold_disabled_saved');
  String get auto_start_recognition_label => translate('auto_start_recognition_label');
  String get auto_start_recognition_description => translate('auto_start_recognition_description');
  String get status_notification_enabled => translate('status_notification_enabled');
  String get notification_permission_required => translate('notification_permission_required');
  String get interval_seconds_short => translate('interval_seconds_short');
  String get interval_minutes_short => translate('interval_minutes_short');
  /// Kompakte Anzeige für Scan-Intervall-Slider/Snackbar (z. B. „30 Sek.“).
  String audio_format_seconds_only(int seconds) =>
      translate('audio_format_seconds_only')
          .replaceAll('{seconds}', seconds.toString());
  String audio_format_minutes_only(int minutes) =>
      translate('audio_format_minutes_only')
          .replaceAll('{minutes}', minutes.toString());
  String audio_format_minutes_seconds(int minutes, int seconds) =>
      translate('audio_format_minutes_seconds')
          .replaceAll('{minutes}', minutes.toString())
          .replaceAll('{seconds}', seconds.toString());
  String get sensitivity_low => translate('sensitivity_low');
  String get sensitivity_high => translate('sensitivity_high');
  String get threshold_low => translate('threshold_low');
  String get threshold_high => translate('threshold_high');
  String get music_recognition => translate('music_recognition');
  String get shazamBackgroundHint => translate('shazam_background_hint');
  String get music_recognition_preparing =>
      translate('music_recognition_preparing');
  /// Klammer-Zusatz mit MM:SS, z. B. „(nächster Scan in 04:32)“.
  String music_recognition_next_scan_in(String time) => translate(
        'music_recognition_next_scan_in',
      ).replaceAll('{time}', time);
  String get music_recognition_none_found => translate('music_recognition_none_found');
  String get recognition_lock_dialog_title =>
      translate('recognition_lock_dialog_title');
  String get recognition_lock_dialog_body =>
      translate('recognition_lock_dialog_body');
  String get recognition_lock_acquire_failed =>
      translate('recognition_lock_acquire_failed');
  /// Musikerkennung: kein Party-Kontext (Footer-Switch).
  String get scan_not_possible_start_party_first =>
      translate('scan_not_possible_start_party_first');
  /// Musikerkennung ohne laufende Party: nur Anzeige, kein Speichern in music_history.
  String get music_recognition_test_mode_no_save_hint =>
      translate('music_recognition_test_mode_no_save_hint');
  String get info_music_recognition_title => translate('info_music_recognition_title');
  String get info_music_recognition_intro => translate('info_music_recognition_intro');
  String get info_scan_process => translate('info_scan_process');
  String get info_scan_process_description => translate('info_scan_process_description');
  String get info_scan_interval => translate('info_scan_interval');
  String get info_scan_interval_description => translate('info_scan_interval_description');
  String get info_mic_sensitivity => translate('info_mic_sensitivity');
  String get info_mic_sensitivity_description => translate('info_mic_sensitivity_description');
  String get info_recognition_threshold => translate('info_recognition_threshold');
  String get info_recognition_threshold_description => translate('info_recognition_threshold_description');
  String get info_smart_threshold => translate('info_smart_threshold');
  String get info_smart_threshold_description => translate('info_smart_threshold_description');
  String get info_auto_start_recognition_info => translate('info_auto_start_recognition_info');
  String get info_auto_start_recognition_info_description => translate('info_auto_start_recognition_info_description');
  String get understood => translate('understood');
  String scan_interval_set(String interval) => translate('scan_interval_set').replaceAll('{interval}', interval);
  String mic_sensitivity_set(String sensitivity) => translate('mic_sensitivity_set').replaceAll('{sensitivity}', sensitivity);
  String threshold_set(String percent) => translate('threshold_set').replaceAll('{percent}', percent);
  String get autostart_enabled_message => translate('autostart_enabled_message');
  String get autostart_disabled_message => translate('autostart_disabled_message');
  String get error_saving => translate('error_saving');
  String get live_update_failed_fallback => translate('live_update_failed_fallback');
  String get auto_resume_check_active => translate('auto_resume_check_active');
  String get auto_resume_check_error => translate('auto_resume_check_error');
  
  // Pro Comparison Table (Free vs Pro)
  String get pro_comparison_vibesbox_free => translate('pro_comparison_vibesbox_free');
  String get pro_comparison_vibesbox_pro => translate('pro_comparison_vibesbox_pro');
  String get pro_comparison_party_anlegen => translate('pro_comparison_party_anlegen');
  String get pro_comparison_one_per_month => translate('pro_comparison_one_per_month');
  String get pro_comparison_unlimited => translate('pro_comparison_unlimited');
  String get pro_comparison_mic_settings => translate('pro_comparison_mic_settings');
  String get pro_comparison_smart_adjustment => translate('pro_comparison_smart_adjustment');
  String get pro_comparison_auto_music_recognition => translate('pro_comparison_auto_music_recognition');
  String get pro_comparison_live_translation => translate('pro_comparison_live_translation');
  String get pro_comparison_dj_logo_visible => translate('pro_comparison_dj_logo_visible');
  String get pro_comparison_social_media_links => translate('pro_comparison_social_media_links');
  String get pro_comparison_favorites => translate('pro_comparison_favorites');
  String get pro_comparison_guest_block => translate('pro_comparison_guest_block');
  String get pro_comparison_music_recognition => translate('pro_comparison_music_recognition');
  String get pro_comparison_live_party_stats => translate('pro_comparison_live_party_stats');
  String get pro_comparison_stats_after_party => translate('pro_comparison_stats_after_party');
  String get pro_comparison_stats_last_finished_only => translate('pro_comparison_stats_last_finished_only');
  String get pro_comparison_contact_form => translate('pro_comparison_contact_form');
  String get pro_comparison_cta_button => translate('pro_comparison_cta_button');
  String get pro_comparison_show_all => translate('pro_comparison_show_all');

  // Feature-Vergleich (Login: Gast | User | DJ)
  String get feature_comparison_guest => translate('feature_comparison_guest');
  String get feature_comparison_user => translate('feature_comparison_user');

  // DJ Feature-Übersicht (Landing/Info)
  String get feature_dj_title => translate('feature_dj_title');
  String get feature_dj_control => translate('feature_dj_control');
  String get feature_dj_management => translate('feature_dj_management');
  String get feature_dj_recognition => translate('feature_dj_recognition');
  String get feature_dj_wishbox => translate('feature_dj_wishbox');
  String get feature_dj_branding => translate('feature_dj_branding');

  // New Party Page
  String get new_party_title => translate('new_party_title');
  String get event_type_label => translate('event_type_label');
  String get party_name_label_new => translate('party_name_label_new');
  String get party_name_hint => translate('party_name_hint');
  String get party_name_required => translate('party_name_required');
  String get select_hour => translate('select_hour');
  String get select_minute => translate('select_minute');
  String get party_new => translate('party_new');
  String get party_private => translate('party_private');
  String get party_public => translate('party_public');
  String get party_location_timezone_title =>
      translate('party_location_timezone_title');
  String get party_from_saved_locations =>
      translate('party_from_saved_locations');
  String get party_use_current_timezone_radio =>
      translate('party_use_current_timezone_radio');
  String get party_timezone_prefix => translate('party_timezone_prefix');
  String get party_timezone_pending => translate('party_timezone_pending');
  String get party_timezone_loading_short =>
      translate('party_timezone_loading_short');
  String get party_search_place => translate('party_search_place');
  String get party_search_other_place =>
      translate('party_search_other_place');
  String get party_pick_start_hour_title =>
      translate('party_pick_start_hour_title');
  String get party_pick_start_minute_title =>
      translate('party_pick_start_minute_title');
  String get party_pick_end_hour_title =>
      translate('party_pick_end_hour_title');
  String get party_pick_end_minute_title =>
      translate('party_pick_end_minute_title');
  String get party_saving_progress => translate('party_saving_progress');
  String get error_no_network_retry => translate('error_no_network_retry');
  String get party_validation_start_date_first =>
      translate('party_validation_start_date_first');
  String get party_validation_end_hour_first =>
      translate('party_validation_end_hour_first');
  String get party_validation_end_date_first =>
      translate('party_validation_end_date_first');
  String get party_validation_start_min_future =>
      translate('party_validation_start_min_future');
  String get party_pick_on_map_tooltip =>
      translate('party_pick_on_map_tooltip');
  String get party_save_location_future =>
      translate('party_save_location_future');
  String get party_fixed_code_same_venue =>
      translate('party_fixed_code_same_venue');
  String get party_code_on_save => translate('party_code_on_save');
  String party_fixed_code_display(String code) =>
      translate('party_fixed_code_display').replaceAll('{code}', code);
  String get party_one_time_event_code =>
      translate('party_one_time_event_code');
  String get party_one_time_code_range_hint =>
      translate('party_one_time_code_range_hint');
  String party_fixed_code_in_use_hint(String code) =>
      translate('party_fixed_code_in_use_hint').replaceAll('{code}', code);
  String get party_timezone_auto_explanation =>
      translate('party_timezone_auto_explanation');
  String party_code_retry_exhausted(int count) =>
      translate('party_code_retry_exhausted')
          .replaceAll('{count}', count.toString());
  String get party_code_generate_failed_retry =>
      translate('party_code_generate_failed_retry');
  String party_created_location_save_failed(String error) =>
      translate('party_created_location_save_failed')
          .replaceAll('{error}', error);
  String get party_save_permission_denied =>
      translate('party_save_permission_denied');
  String get unnamed_location => translate('unnamed_location');
  String get location_label => translate('location_label');
  String get select_location => translate('select_location');
  String get select_existing_location => translate('select_existing_location');
  String get location_name_label => translate('location_name_label');
  String get location_name_hint => translate('location_name_hint');
  String get location_not_specified => translate('location_not_specified');
  String get location_required => translate('location_required');
  String get reset_selection => translate('reset_selection');
  String get start_label_new => translate('start_label_new');
  String get end_label_new => translate('end_label_new');
  String get not_selected => translate('not_selected');
  String get save_party_data => translate('save_party_data');
  String get validation_all_datetimes_required => translate('validation_all_datetimes_required');
  String get validation_end_before_start_new => translate('validation_end_before_start_new');
  String get validation_guest_limit_required_new => translate('validation_guest_limit_required_new');
  String get validation_user_limit_required_new => translate('validation_user_limit_required_new');
  String get validation_location_required => translate('validation_location_required');
  String get save_location_dialog_title => translate('save_location_dialog_title');
  String save_location_dialog_content(String locationName) => translate('save_location_dialog_content').replaceAll('{locationName}', locationName);
  String get save_location_no => translate('save_location_no');
  String get save_location_yes => translate('save_location_yes');
  String get party_created_success => translate('party_created_success');
  String get party_saved_standby_free_limit => translate('party_saved_standby_free_limit');
  String get party_status_standby_label => translate('party_status_standby_label');
  String get standby_limit_reached => translate('standby_limit_reached');
  String get party_standby_info_title => translate('party_standby_info_title');
  String get party_standby_info_text => translate('party_standby_info_text');
  String get error_saving_party => translate('error_saving_party');
  String get validation_limit_required => translate('validation_limit_required');
  String get error_generating_party_code => translate('error_generating_party_code');
  String get error_creating_location => translate('error_creating_location');
  
  // Ended Parties Page
  String get ended_parties_title => translate('ended_parties_title');
  String get no_ended_parties => translate('no_ended_parties');
  String get no_finished_parties_found => translate('no_finished_parties_found');
  String get finished_parties_pro_notice => translate('finished_parties_pro_notice');
  String get ended_parties_display_label => translate('ended_parties_display_label');
  String ended_parties_of_total_finished(int count) =>
      translate('ended_parties_of_total_finished').replaceAll('{count}', '$count');
  String ended_parties_list_count_shown(int count) =>
      translate('ended_parties_list_count_shown').replaceAll('{count}', '$count');
  String ended_parties_error_loading(String error) =>
      translate('ended_parties_error_loading').replaceAll('{error}', error);
  String get ended_party_delete_tooltip => translate('ended_party_delete_tooltip');
  String get statistics => translate('statistics');
  
  // Party Statistics Page
  String get party_statistics_title => translate('party_statistics_title');
  String get party_code_label => translate('party_code_label');
  String get contact_label => translate('contact_label');
  String get dj_name_label => translate('dj_name_label');
  String get no_dj_name => translate('no_dj_name');
  
  // Profil-Seite
  String get profile_dj_name => translate('profile_dj_name');
  String get profile_real_name => translate('profile_real_name');
  String get profile_edit_data_title => translate('profile_edit_data_title');
  String get profile_personal_data => translate('profile_personal_data');
  String get profile_guest_name_title => translate('profile_guest_name_title');
  String get profile_guest_name_label => translate('profile_guest_name_label');
  String get profile_field_name => translate('profile_field_name');
  String get profile_email => translate('profile_email');
  String get profile_member_since => translate('profile_member_since');
  String get profile_phone => translate('profile_phone');
  String get real_name_label => translate('real_name_label');
  String get phone_label => translate('phone_label');
  String get profile_birthday => translate('profile_birthday');
  String get profile_birthday_readonly_hint =>
      translate('profile_birthday_readonly_hint');
  String get profile_value_placeholder => translate('profile_value_placeholder');
  String get profile_country => translate('profile_country');
  String get profile_registered_since => translate('profile_registered_since');
  String get profile_alternative_email => translate('profile_alternative_email');
  String get profile_alternative_email_disabled => translate('profile_alternative_email_disabled');
  String get profile_alternative_email_disable => translate('profile_alternative_email_disable');
  String get profile_alternative_email_disable_confirm => translate('profile_alternative_email_disable_confirm');
  String get profile_alternative_email_disable_title => translate('profile_alternative_email_disable_title');
  String get profile_alternative_email_disable_body => translate('profile_alternative_email_disable_body');
  String get profile_alternative_email_dialog_title => translate('profile_alternative_email_dialog_title');
  String get profile_alternative_email_dialog_email => translate('profile_alternative_email_dialog_email');
  String get profile_alternative_email_dialog_confirm => translate('profile_alternative_email_dialog_confirm');
  String get profile_alternative_email_dialog_save => translate('profile_alternative_email_dialog_save');
  String get profile_alternative_email_validation_invalid => translate('profile_alternative_email_validation_invalid');
  String get profile_alternative_email_validation_mismatch => translate('profile_alternative_email_validation_mismatch');
  String get profile_alternative_email_saved => translate('profile_alternative_email_saved');
  String get profile_alternative_email_info_title =>
      translate('profile_alternative_email_info_title');
  String get profile_alternative_email_info_body =>
      translate('profile_alternative_email_info_body');
  String get payment_history_title => translate('payment_history_title');
  String get dj_free_logo_hint => translate('dj_free_logo_hint');
  // DJ Logo/Branding
  String get dj_branding => translate('dj_branding');
  String get dj_logo => translate('dj_logo');
  String get upload_dj_logo => translate('upload_dj_logo');
  String get no_logo_selected => translate('no_logo_selected');
  String get logo_uploaded => translate('logo_uploaded');
  String get logo_deleted => translate('logo_deleted');
  String get delete_logo => translate('delete_logo');
  String get confirm_delete_logo => translate('confirm_delete_logo');
  String get error_uploading_logo => translate('error_uploading_logo');
  String get error_deleting_logo => translate('error_deleting_logo');
  String get file_too_large => translate('file_too_large');
  String get file_too_large_message => translate('file_too_large_message');
  String get wrong_file_format => translate('wrong_file_format');
  String get wrong_file_format_message => translate('wrong_file_format_message');
  String get error_processing_logo => translate('error_processing_logo');
  String get logo_preview => translate('logo_preview');
  String get uploading => translate('uploading');
  String get total_wishes => translate('total_wishes');
  String get played_songs => translate('played_songs');
  String get rejected_songs => translate('rejected_songs');
  String get not_played_songs => translate('not_played_songs');
  String get avg_time_to_play => translate('avg_time_to_play');
  String get minutes_short => translate('minutes_short');
  String get wait_time_label => translate('wait_time_label');
  String get last_request_label => translate('last_request_label');
  String get also_wished_by_label => translate('also_wished_by_label');
  /// Live-Wartezeit in der Wunschbox (Offen): seit X Min. / seit X Std. Y Min.
  String wishSinceMinutes(int min) => translate('wish_since_minutes').replaceAll('{min}', min.toString());
  String wishSinceHoursMinutes(int hours, int min) => translate('wish_since_hours_minutes')
      .replaceAll('{hours}', hours.toString())
      .replaceAll('{min}', min.toString());
  String wishAdditionalRequests(int count) =>
      translate('wish_additional_requests').replaceAll('{count}', count.toString());
  String get distribution => translate('distribution');
  String get no_wishes_available => translate('no_wishes_available');
  String get wishes_per_hour => translate('wishes_per_hour');
  String get small_statistics => translate('small_statistics');
  String get detailed_statistics => translate('detailed_statistics');
  String get pdf_generation_not_implemented => translate('pdf_generation_not_implemented');

  // Overlays: SnackBars & Dialoge (zentrale Übersetzungen)
  String get snackbar_error_adding_todo => translate('snackbar_error_adding_todo');
  String get snackbar_error_updating_todo => translate('snackbar_error_updating_todo');
  String get snackbar_error_deleting_todo => translate('snackbar_error_deleting_todo');
  String dialog_admin_change_role_title(String name) =>
      translate('dialog_admin_change_role_title').replaceAll('{name}', name);
  String get snackbar_must_sign_in_for_roles => translate('snackbar_must_sign_in_for_roles');
  String get snackbar_role_updated_success => translate('snackbar_role_updated_success');
  String snackbar_user_now_lifetime(String name) =>
      translate('snackbar_user_now_lifetime').replaceAll('{name}', name);
  String snackbar_lifetime_revoked(String name) =>
      translate('snackbar_lifetime_revoked').replaceAll('{name}', name);
  String dialog_admin_change_password_title(String name) =>
      translate('dialog_admin_change_password_title').replaceAll('{name}', name);
  String get snackbar_no_roles_available => translate('snackbar_no_roles_available');
  String get snackbar_admin_password_change_forbidden =>
      translate('snackbar_admin_password_change_forbidden');
  String get snackbar_party_not_logged_in_long => translate('snackbar_party_not_logged_in_long');
  String get snackbar_party_not_found => translate('snackbar_party_not_found');
  String get error_party_start_time_unknown => translate('error_party_start_time_unknown');
  String get snackbar_not_logged_in_short => translate('snackbar_not_logged_in_short');
  String get snackbar_party_started => translate('snackbar_party_started');
  String get snackbar_error_starting_party => translate('snackbar_error_starting_party');
  String get snackbar_error_pausing_wishbox => translate('snackbar_error_pausing_wishbox');
  String get snackbar_party_ended_success => translate('snackbar_party_ended_success');
  String get snackbar_error_ending_party => translate('snackbar_error_ending_party');
  String get dialog_wishbox_confirm_pause => translate('dialog_wishbox_confirm_pause');
  String get dialog_wishbox_confirm_resume => translate('dialog_wishbox_confirm_resume');
  String unblock_user_songs_reactivated(String name, int count) => count == 1
      ? translate('unblock_user_songs_reactivated_one').replaceAll('{name}', name)
      : translate('unblock_user_songs_reactivated_many')
          .replaceAll('{name}', name)
          .replaceAll('{count}', count.toString());
  String unblock_user_wishes_restored(String name) =>
      translate('unblock_user_wishes_restored').replaceAll('{name}', name);
  String get paywall_purchase_sync_failed => translate('paywall_purchase_sync_failed');
  String get paywall_pro_active => translate('paywall_pro_active');
  String get paywall_purchase_verifying => translate('paywall_purchase_verifying');
  String get paywall_purchase_failed => translate('paywall_purchase_failed');
  String get paywall_trial_failed => translate('paywall_trial_failed');
  String get paywall_restore_failed => translate('paywall_restore_failed');
  String get delete_party_only_own => translate('delete_party_only_own');
  String party_deleted_with_related(String partyName, int count) =>
      translate('party_deleted_with_related')
          .replaceAll('{partyName}', partyName)
          .replaceAll('{count}', count.toString());
  String get party_delete_radical_title => translate('party_delete_radical_title');
  String party_delete_named_line(String name) =>
      translate('party_delete_named_line').replaceAll('{name}', name);
  String get party_delete_radical_intro => translate('party_delete_radical_intro');
  String get party_delete_bullet_wishes => translate('party_delete_bullet_wishes');
  String get party_delete_bullet_music_history =>
      translate('party_delete_bullet_music_history');
  String get party_delete_bullet_shazam => translate('party_delete_bullet_shazam');
  String get party_delete_bullet_blocked_guests =>
      translate('party_delete_bullet_blocked_guests');
  String get party_delete_bullet_block_history =>
      translate('party_delete_bullet_block_history');
  String get party_delete_bullet_party_status =>
      translate('party_delete_bullet_party_status');
  String get party_delete_bullet_party_sessions =>
      translate('party_delete_bullet_party_sessions');
  String get party_delete_stats_will_decrease =>
      translate('party_delete_stats_will_decrease');
  String get party_delete_confirm_anyway => translate('party_delete_confirm_anyway');
  String get map_pick_location_first => translate('map_pick_location_first');
  String get admin_check_failed_login => translate('admin_check_failed_login');
  String get email_migration_title => translate('email_migration_title');
  String get email_migration_run => translate('email_migration_run');
  String get email_migration_running => translate('email_migration_running');
  String get email_migration_failed => translate('email_migration_failed');
  String get back_press_again_to_exit => translate('back_press_again_to_exit');
  String get permission_allow => translate('permission_allow');
  String get permission_open_settings => translate('permission_open_settings');
  String get spotify_filter_saved => translate('spotify_filter_saved');
  String get spotify_save_cloud_and_local =>
      translate('spotify_save_cloud_and_local');
  String get spotify_admin_excluded_terms_intro =>
      translate('spotify_admin_excluded_terms_intro');
  String get spotify_admin_add_term_hint => translate('spotify_admin_add_term_hint');
  String get spotify_admin_add_button => translate('spotify_admin_add_button');
  String spotify_admin_max_duration_label(int minutes) =>
      translate('spotify_admin_max_duration_label').replaceAll('{minutes}', minutes.toString());
  String spotify_admin_slider_minutes(int minutes) =>
      translate('spotify_admin_slider_minutes').replaceAll('{minutes}', minutes.toString());
  String get referral_code_length => translate('referral_code_length');
  String get referral_code_saved => translate('referral_code_saved');
  String get referral_code_invalid => translate('referral_code_invalid');
  String get referral_redeem_title => translate('referral_redeem_title');
  String get referral_redeem_body => translate('referral_redeem_body');
  String get referral_code_hint => translate('referral_code_hint');
  String get referral_redeem_action => translate('referral_redeem_action');
  String get pdf_generation_error => translate('pdf_generation_error');
  String get pwa_link_copied => translate('pwa_link_copied');
  String get favorite_status_update_error => translate('favorite_status_update_error');
  String get admin_check_failed_snackbar => translate('admin_check_failed_snackbar');
  String get exit_press_back_again_snackbar => translate('exit_press_back_again_snackbar');
  String played_group_delete_message(int count, String title) =>
      translate('played_group_delete_message')
          .replaceAll('{count}', count.toString())
          .replaceAll('{title}', title);
  String snackbar_wishes_updated(int count) => count == 1
      ? translate('snackbar_wishes_updated_one')
      : translate('snackbar_wishes_updated_many').replaceAll('{count}', count.toString());
  String snackbar_wishes_marked_played(int count) => count == 1
      ? translate('snackbar_wishes_marked_played_one')
      : translate('snackbar_wishes_marked_played_many').replaceAll('{count}', count.toString());
  String get terms_of_service_loading => translate('terms_of_service_loading');
  String payment_history_error_loading(Object error) =>
      translate('payment_history_error_loading').replaceAll('{error}', '$error');
  String get history_playlist_delete_title => translate('history_playlist_delete_title');
  String get history_playlist_label_prefix => translate('history_playlist_label_prefix');
  String get history_playlist_delete_body => translate('history_playlist_delete_body');
  String get history_playlist_deleted => translate('history_playlist_deleted');
  String get history_playlist_delete_failed => translate('history_playlist_delete_failed');
  String get history_track_delete_body => translate('history_track_delete_body');
  String get location_permission_dialog_title => translate('location_permission_dialog_title');
  String get location_permission_dialog_body => translate('location_permission_dialog_body');
  String get button_select => translate('button_select');
  String shazam_scan_interval_set(String interval) =>
      translate('shazam_scan_interval_set').replaceAll('{interval}', interval);
  String shazam_mic_sensitivity_set(String value) =>
      translate('shazam_mic_sensitivity_set').replaceAll('{value}', value);
  String shazam_threshold_percent_set(String percent) =>
      translate('shazam_threshold_percent_set').replaceAll('{percent}', percent);
  String get shazam_autostart_enabled_snackbar =>
      translate('shazam_autostart_enabled_snackbar');
  String get shazam_autostart_disabled_snackbar =>
      translate('shazam_autostart_disabled_snackbar');
  String get shazam_app_check_invalid_snackbar =>
      translate('shazam_app_check_invalid_snackbar');
  String get qr_gallery_save_failed => translate('qr_gallery_save_failed');
  String get maps_app_unavailable => translate('maps_app_unavailable');
  String get maps_no_location_data => translate('maps_no_location_data');
  String get maps_open_error => translate('maps_open_error');
  String get admin_start_view_saved => translate('admin_start_view_saved');
  String get announcement_card_title_global =>
      translate('announcement_card_title_global');
  String get announcement_card_title_edit =>
      translate('announcement_card_title_edit');
  String get announcement_field_subject_label =>
      translate('announcement_field_subject_label');
  String get announcement_field_subject_hint_de_source =>
      translate('announcement_field_subject_hint_de_source');
  String get announcement_field_message_label =>
      translate('announcement_field_message_label');
  String get announcement_field_message_hint_de_source =>
      translate('announcement_field_message_hint_de_source');
  String get announcement_loading_languages =>
      translate('announcement_loading_languages');
  String announcement_progress_translating_to(String label) =>
      translate('announcement_progress_translating_to')
          .replaceAll('{label}', label);
  String announcement_progress_original(String label) =>
      translate('announcement_progress_original').replaceAll('{label}', label);
  String announcement_progress_translating_subject(String label) =>
      translate('announcement_progress_translating_subject')
          .replaceAll('{label}', label);
  String get announcement_saving_progress =>
      translate('announcement_saving_progress');
  String get announcement_saved_success =>
      translate('announcement_saved_success');
  String get announcement_updated_success =>
      translate('announcement_updated_success');
  String get announcement_button_sending =>
      translate('announcement_button_sending');
  String get announcement_button_send => translate('announcement_button_send');
  String get announcement_button_update =>
      translate('announcement_button_update');
  String get admin_stats_current_party => translate('admin_stats_current_party');
  String admin_stats_party_code_line(String code) =>
      translate('admin_stats_party_code_line').replaceAll('{code}', code);
  String get admin_stats_qr_tooltip => translate('admin_stats_qr_tooltip');
  String get admin_stats_vibesbox_status_title =>
      translate('admin_stats_vibesbox_status_title');
  String get admin_stats_duplicate_limit_percent =>
      translate('admin_stats_duplicate_limit_percent');
  String get admin_duplicate_threshold_hint =>
      translate('admin_duplicate_threshold_hint');
  String get role_switch_admin_area => translate('role_switch_admin_area');
  String get role_switch_dj_view => translate('role_switch_dj_view');
  String get role_switch_guest_view => translate('role_switch_guest_view');
  String get role_switch_location_view => translate('role_switch_location_view');
  String get admin_language_fill_code_and_english_name =>
      translate('admin_language_fill_code_and_english_name');
  String get admin_language_saved_snackbar =>
      translate('admin_language_saved_snackbar');
  String get admin_language_new_entry_title =>
      translate('admin_language_new_entry_title');
  String get admin_start_view_label => translate('admin_start_view_label');
  String get admin_start_view_option_admin_dashboard =>
      translate('admin_start_view_option_admin_dashboard');
  String get admin_start_view_option_dj_area =>
      translate('admin_start_view_option_dj_area');
  String get admin_start_view_option_guest_area =>
      translate('admin_start_view_option_guest_area');
  String get admin_set_default_start_view_title =>
      translate('admin_set_default_start_view_title');
  String get admin_dialog_last_announcement_empty_title =>
      translate('admin_dialog_last_announcement_empty_title');
  String get admin_announcement_no_subject_preview =>
      translate('admin_announcement_no_subject_preview');
  String get admin_last_announcement_manage_title =>
      translate('admin_last_announcement_manage_title');
  String get admin_announcement_delete_title =>
      translate('admin_announcement_delete_title');
  String get admin_announcement_delete_confirm_body =>
      translate('admin_announcement_delete_confirm_body');
  String get admin_role_switcher_label => translate('admin_role_switcher_label');
  String get admin_no_announcement_yet => translate('admin_no_announcement_yet');
  String get admin_show_last_announcement_button =>
      translate('admin_show_last_announcement_button');
  String get admin_language_save => translate('admin_language_save');
  String get admin_language_saving => translate('admin_language_saving');
  String get announcement_need_subject_or_message =>
      translate('announcement_need_subject_or_message');
  String get announcement_no_active_languages => translate('announcement_no_active_languages');
  String announcement_translate_failed(String code, Object e) =>
      '${translate('announcement_translate_failed').replaceAll('{code}', code)} $e';
  String shazamSongMoved(String title, String artist) =>
      translate('shazam_song_moved').replaceAll('{title}', title).replaceAll('{artist}', artist);
  String get offen_no_active_party => translate('offen_no_active_party');
  String dj_wish_added(String trackName) =>
      translate('dj_wish_added').replaceAll('{name}', trackName);
  String get dj_spotify_search_title => translate('dj_spotify_search_title');
  String snackbar_wishes_deleted(int count) => count == 1
      ? translate('snackbar_wish_deleted_one')
      : translate('snackbar_wishes_deleted_many').replaceAll('{count}', count.toString());
  String snackbar_wishes_rejected(int count) => count == 1
      ? translate('snackbar_wish_rejected_one')
      : translate('snackbar_wishes_rejected_many').replaceAll('{count}', count.toString());
  String get exception_no_party_id => translate('exception_no_party_id');
  String get playlist_song_deleted => translate('playlist_song_deleted');
  String get playlist_song_delete_error => translate('playlist_song_delete_error');
  String get global_announcement_read_ok => translate('global_announcement_read_ok');
  String get global_announcement_default_title =>
      translate('global_announcement_default_title');
  String get shazam_dialog_microphone_title =>
      translate('shazam_dialog_microphone_title');
  String get shazam_dialog_microphone_body => translate('shazam_dialog_microphone_body');
  String get user_block_invalid_party_id => translate('user_block_invalid_party_id');
  String get calendar_error_end_time_unknown => translate('calendar_error_end_time_unknown');
  String get calendar_error_start_time_unknown => translate('calendar_error_start_time_unknown');
  String get calendar_export_error => translate('calendar_export_error');
  String get party_calendar_export => translate('party_calendar_export');
  String get calendar_party_ics_untitled => translate('calendar_party_ics_untitled');
  String calendar_party_ics_title(String name, String time, String tz) =>
      translate('calendar_party_ics_title')
          .replaceAll('{name}', name)
          .replaceAll('{time}', time)
          .replaceAll('{tz}', tz);
  String calendar_party_ics_body_time(String time, String tz) =>
      translate('calendar_party_ics_body_time')
          .replaceAll('{time}', time)
          .replaceAll('{tz}', tz);
  String calendar_party_ics_body_maps(String url) =>
      translate('calendar_party_ics_body_maps').replaceAll('{url}', url);
  String get todo_delete_dialog_title => translate('todo_delete_dialog_title');
  String get todo_delete_dialog_body => translate('todo_delete_dialog_body');
  String get todo_field_new_label => translate('todo_field_new_label');
  String get todo_field_new_hint => translate('todo_field_new_hint');
  String get todo_add_tooltip => translate('todo_add_tooltip');
  String get todo_empty_title => translate('todo_empty_title');
  String get todo_empty_subtitle => translate('todo_empty_subtitle');
  String get todo_label_created => translate('todo_label_created');
  String get todo_label_completed => translate('todo_label_completed');
  String todo_stream_error(Object error) =>
      translate('todo_stream_error').replaceAll('{error}', '$error');
  String todo_completed_section_title(int count) =>
      translate('todo_completed_section_title').replaceAll('{count}', count.toString());
  String get todo_default_first_item => translate('todo_default_first_item');
  String get admin_users_empty => translate('admin_users_empty');
  String get admin_users_empty_for_role_filter =>
      translate('admin_users_empty_for_role_filter');
  String get admin_user_section_user => translate('admin_user_section_user');
  String get admin_user_section_devices => translate('admin_user_section_devices');
  String get admin_user_section_tech => translate('admin_user_section_tech');
  String get admin_user_section_data => translate('admin_user_section_data');
  String get admin_user_realname => translate('admin_user_realname');
  String get admin_user_origin_country => translate('admin_user_origin_country');
  String get admin_user_no_devices => translate('admin_user_no_devices');
  String get admin_user_registered_prefix => translate('admin_user_registered_prefix');
  String get admin_user_no_device_registered =>
      translate('admin_user_no_device_registered');
  String get admin_user_app_prefix => translate('admin_user_app_prefix');
  String get admin_device_map_key => translate('admin_device_map_key');
  String get admin_device_platform => translate('admin_device_platform');
  String get admin_device_model => translate('admin_device_model');
  String get admin_device_os_version => translate('admin_device_os_version');
  String get admin_device_app_version => translate('admin_device_app_version');
  String get admin_device_last_seen => translate('admin_device_last_seen');
  String get admin_lifetime_tooltip_active => translate('admin_lifetime_tooltip_active');
  String get admin_lifetime_tooltip_grant => translate('admin_lifetime_tooltip_grant');
  String get admin_pro_tooltip_life => translate('admin_pro_tooltip_life');
  String get admin_pro_tooltip_pro => translate('admin_pro_tooltip_pro');
  String get admin_pro_tooltip_free => translate('admin_pro_tooltip_free');
  String get admin_user_threshold_pegel => translate('admin_user_threshold_pegel');
  String get admin_user_shazam_interval_s => translate('admin_user_shazam_interval_s');
  String get admin_user_login_count => translate('admin_user_login_count');
  String get admin_user_last_login => translate('admin_user_last_login');
  String get admin_smart_adapt_tooltip_on => translate('admin_smart_adapt_tooltip_on');
  String get admin_smart_adapt_tooltip_off => translate('admin_smart_adapt_tooltip_off');
  String get admin_auto_recognition_tooltip_on =>
      translate('admin_auto_recognition_tooltip_on');
  String get admin_auto_recognition_tooltip_off =>
      translate('admin_auto_recognition_tooltip_off');
  String get admin_user_auto_recognition_short =>
      translate('admin_user_auto_recognition_short');
  String get admin_switch_on => translate('admin_switch_on');
  String get admin_switch_off => translate('admin_switch_off');
  String get admin_user_pro_label => translate('admin_user_pro_label');
  String get admin_select_role_prompt => translate('admin_select_role_prompt');
  String get admin_role_label => translate('admin_role_label');
  String get admin_role_not_set => translate('admin_role_not_set');
  String get admin_lifetime_title_revoke => translate('admin_lifetime_title_revoke');
  String get admin_lifetime_title_grant => translate('admin_lifetime_title_grant');
  String admin_lifetime_body_revoke(String name) =>
      translate('admin_lifetime_body_revoke').replaceAll('{name}', name);
  String admin_lifetime_body_grant(String name) =>
      translate('admin_lifetime_body_grant').replaceAll('{name}', name);
  String get admin_lifetime_action_revoke => translate('admin_lifetime_action_revoke');
  String get admin_lifetime_action_grant => translate('admin_lifetime_action_grant');
  String get admin_new_password_label => translate('admin_new_password_label');
  String get admin_password_required => translate('admin_password_required');
  String get admin_password_min_length => translate('admin_password_min_length');
  String admin_password_changed_success(String name) =>
      translate('admin_password_changed_success').replaceAll('{name}', name);
  String get admin_password_change_functions_error =>
      translate('admin_password_change_functions_error');
  String get party_confirm_end_title => translate('party_confirm_end_title');
  String party_confirm_end_body(String partyName) =>
      translate('party_confirm_end_body').replaceAll('{partyName}', partyName);
  String get party_confirm_end_action => translate('party_confirm_end_action');
  String wishbox_pause_confirm_resume(String partyName) =>
      translate('wishbox_pause_confirm_resume').replaceAll('{partyName}', partyName);
  String wishbox_pause_confirm_pause(String partyName) =>
      translate('wishbox_pause_confirm_pause').replaceAll('{partyName}', partyName);

  String get paywall_restore_success_pro => translate('paywall_restore_success_pro');
  String get paywall_restore_success_no_pro => translate('paywall_restore_success_no_pro');
  String get paywall_offering_load_error => translate('paywall_offering_load_error');
  String get paywall_choose_plan_title => translate('paywall_choose_plan_title');
  String get paywall_status_active => translate('paywall_status_active');
  String get paywall_pay_one_moment => translate('paywall_pay_one_moment');
  String get paywall_pay_button => translate('paywall_pay_button');
  String get paywall_restore_purchases => translate('paywall_restore_purchases');
  String get paywall_load_error_title => translate('paywall_load_error_title');
  String get paywall_plan_month => translate('paywall_plan_month');
  String get paywall_plan_quarter => translate('paywall_plan_quarter');
  String get paywall_plan_halfyear => translate('paywall_plan_halfyear');
  String get paywall_plan_year => translate('paywall_plan_year');
  String get paywall_tip_badge => translate('paywall_tip_badge');
  String get paywall_free_phase_label => translate('paywall_free_phase_label');
  String get dj_home_trial_banner_title => translate('dj_home_trial_banner_title');
  String get dj_home_display_name_fallback => translate('dj_home_display_name_fallback');
  String get dj_home_total_balance_note_excluding_active =>
      translate('dj_home_total_balance_note_excluding_active');
  String get dj_home_stats_row_total => translate('dj_home_stats_row_total');
  String get dj_home_stats_row_played => translate('dj_home_stats_row_played');
  String get dj_home_stats_row_party_count => translate('dj_home_stats_row_party_count');
  String get stats_piechart_waiting_for_data => translate('stats_piechart_waiting_for_data');
  String get stats_piechart_no_global_data => translate('stats_piechart_no_global_data');
  String get stats_error_unknown => translate('stats_error_unknown');
  String stats_error_permission_denied(String role) =>
      translate('stats_error_permission_denied').replaceAll('{role}', role);
  String get stats_role_unknown => translate('stats_role_unknown');
  String get unlock_now_button => translate('unlock_now_button');
  String get dialog_notice_title => translate('dialog_notice_title');
  String get spotify_track_search_title => translate('spotify_track_search_title');
  String get spotify_search_field_hint => translate('spotify_search_field_hint');
  String get spotify_search_press_enter => translate('spotify_search_press_enter');
  String get button_search => translate('button_search');
  String get dialog_send_anyway => translate('dialog_send_anyway');
  String get offen_wish_save_error => translate('offen_wish_save_error');
  String get party_dj_id_missing => translate('party_dj_id_missing');
  String get wish_count_label => translate('wish_count_label');
  String offen_favorites_hidden(int count) => count == 1
      ? translate('offen_favorites_hidden_one')
      : translate('offen_favorites_hidden_many').replaceAll('{count}', count.toString());
  String snackbar_error_details(Object error) =>
      translate('snackbar_error_details').replaceAll('{error}', '$error');

  String get period_day_singular => translate('period_day_singular');
  String period_days(int n) => translate('period_days').replaceAll('{n}', n.toString());
  String get period_week_singular => translate('period_week_singular');
  String period_weeks(int n) => translate('period_weeks').replaceAll('{n}', n.toString());
  String get period_month_singular => translate('period_month_singular');
  String period_months(int n) => translate('period_months').replaceAll('{n}', n.toString());
  String get period_year_singular => translate('period_year_singular');
  String period_years(int n) => translate('period_years').replaceAll('{n}', n.toString());

  String get mass_verify_dialog_title => translate('mass_verify_dialog_title');
  String get mass_verify_dialog_body => translate('mass_verify_dialog_body');
  String mass_verify_snackbar_result(int verified, int scanned, int errors) =>
      translate('mass_verify_snackbar_result')
          .replaceAll('{verified}', verified.toString())
          .replaceAll('{scanned}', scanned.toString())
          .replaceAll('{errors}', errors.toString());

  String get logout_profile_verify_failed => translate('logout_profile_verify_failed');
  String get battery_opt_dialog_title => translate('battery_opt_dialog_title');
  String get battery_opt_dialog_body => translate('battery_opt_dialog_body');
  String get battery_settings_open_failed => translate('battery_settings_open_failed');
  String get notification_permission_title => translate('notification_permission_title');
  String get notification_permission_body => translate('notification_permission_body');
  
  // Settings Page
  String get settings_title => translate('settings_title');
  String get translation_settings_title => translate('translation_settings_title');
  String get translation_settings_description => translate('translation_settings_description');
  String get settings_text_scale_title => translate('settings_text_scale_title');
  String get settings_text_scale_subtitle => translate('settings_text_scale_subtitle');
  String get settings_text_scale_smallest => translate('settings_text_scale_smallest');
  String get settings_text_scale_small => translate('settings_text_scale_small');
  String get settings_text_scale_normal => translate('settings_text_scale_normal');
  String get settings_text_scale_large => translate('settings_text_scale_large');
  String get settings_text_scale_largest =>
      translate('settings_text_scale_largest');

  String get settings_section_notifications =>
      translate('settings_section_notifications');
  String get settings_notify_new_wishes =>
      translate('settings_notify_new_wishes');
  String get settings_enable_notification_sound =>
      translate('settings_enable_notification_sound');

  /// Zeile für lokale DJ-Benachrichtigung: **VibesBox** bleibt in allen Sprachen gleich.
  String dj_notification_line(String title, String artist) => translate(
        'dj_notification_line',
      ).replaceAll('{title}', title).replaceAll('{artist}', artist);
  /// Kurze erste Zeile (Android/iOS Titel), ohne Song — verhindert mitten im Wort umgebrochene Kandidaten.
  String get dj_notification_short_title => translate('dj_notification_short_title');
  /// Nur Song: Titel + Interpret (Body unter [dj_notification_short_title]).
  String dj_notification_song_line(String title, String artist) => translate(
        'dj_notification_song_line',
      ).replaceAll('{title}', title).replaceAll('{artist}', artist);
  String get settings_saved => translate('settings_saved');
  String get about_word => translate('about_word');

  // DJ Quickstart-Guide
  String get dj_quickstart_nav => translate('dj_quickstart_nav');
  String get dj_quickstart_title => translate('dj_quickstart_title');
  String get dj_quickstart_h1_music => translate('dj_quickstart_h1_music');
  String get dj_quickstart_p_music => translate('dj_quickstart_p_music');
  String get dj_quickstart_h1_checkin => translate('dj_quickstart_h1_checkin');
  String get dj_quickstart_p_checkin => translate('dj_quickstart_p_checkin');
  String get dj_quickstart_h1_qr => translate('dj_quickstart_h1_qr');
  String get dj_quickstart_p_qr => translate('dj_quickstart_p_qr');
  String get dj_quickstart_h1_recognition =>
      translate('dj_quickstart_h1_recognition');
  String get dj_quickstart_p_recognition =>
      translate('dj_quickstart_p_recognition');
  String get dj_quickstart_h1_i18n => translate('dj_quickstart_h1_i18n');
  String get dj_quickstart_p_i18n => translate('dj_quickstart_p_i18n');
  String get dj_quickstart_h1_notifications =>
      translate('dj_quickstart_h1_notifications');
  String get dj_quickstart_p_notifications =>
      translate('dj_quickstart_p_notifications');
  String get dj_quickstart_h1_multidevice =>
      translate('dj_quickstart_h1_multidevice');
  String get dj_quickstart_p_multidevice =>
      translate('dj_quickstart_p_multidevice');
  String get dj_quickstart_h1_stability =>
      translate('dj_quickstart_h1_stability');
  String get dj_quickstart_p_stability =>
      translate('dj_quickstart_p_stability');
  /// Einmaliges DJ-Onboarding: Begrüßungstext (je nach App-Sprache; neue Sprachen: gleicher Key in `app_localizations_<code>.dart`).
  String get dj_quickstart_onboarding_body =>
      translate('dj_quickstart_onboarding_body');
  /// CTA zum Quickstart-Tab (Benennung wie Navigation).
  String get dj_quickstart_onboarding_button =>
      translate('dj_quickstart_onboarding_button');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return LocaleHelper.supportedLanguageCodes.contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

