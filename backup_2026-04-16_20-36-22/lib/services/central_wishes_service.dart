import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/song_request.dart';
import 'active_party_service.dart';
import '../utils/debug_log.dart';

/// Zentrale Service-Klasse für die Verwaltung aller Wünsche
/// Bietet einen einzigen Stream für alle wishes-Dokumente einer DJ-ID
/// Reduziert Traffic und verbessert Performance durch zentrale Datenquelle
class CentralWishesService {
  static final CentralWishesService _instance = CentralWishesService._internal();
  factory CentralWishesService() => _instance;
  CentralWishesService._internal();

  StreamSubscription<QuerySnapshot>? _wishesSubscription;
  StreamController<List<SongRequest>>? _wishesController;
  Stream<List<SongRequest>>? _wishesStream;
  String? _currentDjId;
  String? _currentPartyId;
  String? _currentPartyCode;

  /// Initialisiert den zentralen Stream für Wünsche
  /// Filtert AUSSCHLIESSLICH nach party_id (lange Dokument-ID)
  Future<void> initialize(String? viewRole) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await dispose();
      return;
    }

    // Hole aktive Party-Info (mit partyId)
    final partyInfo = await ActivePartyService.getActivePartyInfo(user.uid);
    if (partyInfo == null || partyInfo.partyId == null || partyInfo.partyId!.isEmpty) {
      debugLog('⚠️ CentralWishesService: Keine aktive Party gefunden (partyId fehlt)');
      await dispose();
      return;
    }

    final partyId = partyInfo.partyId!;
    
    // Wenn sich Party-ID nicht geändert hat, Stream nicht neu initialisieren
    if (_currentPartyId == partyId && _wishesStream != null) {
      return;
    }

    await dispose(); // Alte Subscriptions beenden

    _currentPartyId = partyId;
    _currentPartyCode = partyInfo.partyCode;

    // Erstelle Stream-Controller
    _wishesController = StreamController<List<SongRequest>>.broadcast();

    // Erstelle Firebase-Query: NUR nach party_id (lange Dokument-ID) filtern
    Query query = FirebaseFirestore.instance
        .collection('wishes')
        .where('party_id', isEqualTo: partyId);

    debugLog('🔍 CentralWishesService: Initialisiere Stream mit Filter: party_id == $partyId');

    // Abonniere Stream für Wünsche
    _wishesSubscription = query.snapshots().listen((snapshot) {
      final docs = snapshot.docs;
      
      // Konvertiere QueryDocumentSnapshot zu SongRequest-Objekten (mit Fehlertoleranz)
      final allRequests = <SongRequest>[];
      for (final doc in docs) {
        try {
          final songRequest = SongRequest.fromDocument(doc);
          allRequests.add(songRequest);
        } catch (e, stackTrace) {
          debugLog('❌ CentralWishesService: Fehler beim Konvertieren von Dokument ${doc.id}: $e');
          debugLog('   Stack: $stackTrace');
          debugLog('   Document Data: ${doc.data()}');
          // Überspringe dieses Dokument, damit die App weiterläuft
          continue;
        }
      }
      
      debugLog('✅ CentralWishesService: ${allRequests.length} Wünsche empfangen (gefiltert nach party_id: $partyId)');
      _wishesController?.add(allRequests);
    }, onError: (error) {
      debugLog('❌ CentralWishesService: Fehler beim Stream: $error');
      debugLog('   Party-ID: $partyId');
      _wishesController?.addError(error);
    });

    // Erstelle öffentlichen Stream
    _wishesStream = _wishesController!.stream;

    debugLog('✅ CentralWishesService: Stream initialisiert für Party-ID: $partyId');
  }

  /// Gibt den Stream aller Wünsche zurück
  Stream<List<SongRequest>>? get wishesStream => _wishesStream;

  /// Gibt die aktuelle DJ-ID zurück
  String? get currentDjId => _currentDjId;

  /// Gibt die aktuelle Party-ID zurück
  String? get currentPartyId => _currentPartyId;
  
  /// Gibt den aktuellen Party-Code zurück
  String? get currentPartyCode => _currentPartyCode;

  /// Beendet alle Subscriptions und Controller
  Future<void> dispose() async {
    await _wishesSubscription?.cancel();
    _wishesSubscription = null;
    await _wishesController?.close();
    _wishesController = null;
    _wishesStream = null;
    _currentDjId = null;
    _currentPartyId = null;
    _currentPartyCode = null;
  }
}
