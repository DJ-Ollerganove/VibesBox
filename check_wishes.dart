import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vibesbox/utils/debug_log.dart';

void main() async {
  await Firebase.initializeApp();

  debugLog('Prüfe Collection "wishes"...\n');

  final wishesSnapshot = await FirebaseFirestore.instance
      .collection('wishes')
      .limit(10)
      .get();

  debugLog('Gefundene Dokumente: ${wishesSnapshot.docs.length}\n');

  for (int i = 0; i < wishesSnapshot.docs.length; i++) {
    final doc = wishesSnapshot.docs[i];
    final data = doc.data();

    debugLog('--- Dokument ${i + 1} (ID: ${doc.id}) ---');
    debugLog('party_id: ${data['party_id']}');
    debugLog('party_code: ${data['party_code']}');
    debugLog('status: ${data['status']}');
    debugLog('title: ${data['title']}');
    debugLog('artist: ${data['artist']}');
    debugLog('djId: ${data['djId']}');
    debugLog('created_at: ${data['created_at']}');
    debugLog('createdAt: ${data['createdAt']}');
    debugLog('');
  }
}
