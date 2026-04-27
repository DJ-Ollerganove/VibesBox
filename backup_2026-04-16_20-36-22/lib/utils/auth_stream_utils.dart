import 'package:firebase_auth/firebase_auth.dart';

/// [FirebaseAuth.authStateChanges] feuert oft mehrfach für dieselbe UID (Token-Refresh etc.).
/// Liefert nur Events, wenn sich die UID ändert oder Login/Logout (null ↔ User).
Stream<User?> authStateChangesDistinctByUid() =>
    FirebaseAuth.instance.authStateChanges().distinct((User? a, User? b) => a?.uid == b?.uid);
