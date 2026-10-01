import 'package:cloud_firestore/cloud_firestore.dart';

enum VisitStatus { scheduled, inProgress, completed }

VisitStatus visitStatusFromString(String? s) {
  switch (s) {
    case 'in_progress':
      return VisitStatus.inProgress;
    case 'completed':
      return VisitStatus.completed;
    default:
      return VisitStatus.scheduled;
  }
}

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;
double? _num(dynamic v) => v is num ? v.toDouble() : null;

/// A scheduled visit to a client. Client details are a denormalised snapshot
/// (alias only, no full name) to keep personal information to a minimum.
class Visit {
  const Visit({
    required this.id,
    required this.workerId,
    required this.clientAlias,
    required this.clientAddress,
    required this.clientLat,
    required this.clientLng,
    required this.scheduledStart,
    required this.status,
    this.checkInAt,
    this.checkOutAt,
    this.distanceM,
    this.accuracyM,
    this.lowAccuracy = false,
    this.note,
  });

  final String id;
  final String workerId;
  final String clientAlias;
  final String clientAddress;
  final double clientLat;
  final double clientLng;
  final DateTime scheduledStart;
  final VisitStatus status;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final double? distanceM;
  final double? accuracyM;
  final bool lowAccuracy;
  final String? note;

  Duration? get duration => (checkInAt != null && checkOutAt != null)
      ? checkOutAt!.difference(checkInAt!)
      : null;

  factory Visit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Visit(
      id: doc.id,
      workerId: (d['workerId'] ?? '') as String,
      clientAlias: (d['clientAlias'] ?? 'Client') as String,
      clientAddress: (d['clientAddress'] ?? '') as String,
      clientLat: _num(d['clientLat']) ?? 0,
      clientLng: _num(d['clientLng']) ?? 0,
      scheduledStart: _ts(d['scheduledStart']) ?? DateTime.now(),
      status: visitStatusFromString(d['status'] as String?),
      checkInAt: _ts(d['checkInAt']),
      checkOutAt: _ts(d['checkOutAt']),
      distanceM: _num(d['distanceM']),
      accuracyM: _num(d['accuracyM']),
      lowAccuracy: (d['lowAccuracy'] ?? false) as bool,
      note: d['note'] as String?,
    );
  }
}
