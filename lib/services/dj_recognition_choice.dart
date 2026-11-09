import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Was der DJ als Song-Quelle gewählt hat.
/// `sync` setzt `vibesbox_sync_enabled`, das das Desktop-Tool abfragt.
enum DjRecognitionChoice { microphone, sync, none }

class DjRecognitionChoiceStore {
  /// Aktuelle Wahl. Der Footer hört darauf und blendet sich bei [DjRecognitionChoice.none] aus.
  static final ValueNotifier<DjRecognitionChoice> current =
      ValueNotifier(DjRecognitionChoice.microphone);

  static String _key(String uid) => 'dj_recognition_choice_$uid';

  /// null, wenn der DJ noch nichts gewählt hat.
  static Future<DjRecognitionChoice?> read(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key(uid))) {
      'sync' => DjRecognitionChoice.sync,
      'none' => DjRecognitionChoice.none,
      'microphone' => DjRecognitionChoice.microphone,
      _ => null,
    };
  }

  static Future<DjRecognitionChoice> load(String uid) async {
    return await read(uid) ?? DjRecognitionChoice.microphone;
  }

  static Future<void> save(String uid, DjRecognitionChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (choice) {
      DjRecognitionChoice.microphone => 'microphone',
      DjRecognitionChoice.sync => 'sync',
      DjRecognitionChoice.none => 'none',
    };
    await prefs.setString(_key(uid), raw);
    current.value = choice;
  }
}
