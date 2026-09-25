import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Technische Firebase-/Functions-Fehler für Snackbars (Code + Message).
String formatFirebaseErrorDetail(Object error) {
  if (error is FirebaseException) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return '${error.code}: $message';
    }
    return error.code;
  }
  if (error is FirebaseFunctionsException) {
    final message = error.message?.trim();
    final prefix = 'firebase_functions/${error.code}';
    if (message != null && message.isNotEmpty) {
      return '$prefix: $message';
    }
    return prefix;
  }
  final text = error.toString();
  const exceptionPrefix = 'Exception: ';
  if (text.startsWith(exceptionPrefix)) {
    return text.substring(exceptionPrefix.length);
  }
  return text;
}
