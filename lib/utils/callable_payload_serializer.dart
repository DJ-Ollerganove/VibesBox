import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore-Typen für [HttpsCallable] serialisieren (nur String, num, bool, List, Map).
Map<String, dynamic> serializeForCallable(Map<String, dynamic> data) {
  final out = <String, dynamic>{};
  data.forEach((key, value) {
    out[key] = _serializeCallableValue(value);
  });
  return out;
}

dynamic _serializeCallableValue(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) {
    return <String, int>{
      'seconds': value.seconds,
      'nanoseconds': value.nanoseconds,
    };
  }
  if (value is String || value is num || value is bool) return value;
  if (value is List) {
    return value.map(_serializeCallableValue).toList();
  }
  if (value is Map) {
    final map = <String, dynamic>{};
    value.forEach((key, dynamic entry) {
      map[key.toString()] = _serializeCallableValue(entry);
    });
    return map;
  }
  return value.toString();
}
