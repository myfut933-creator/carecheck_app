import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/visit.dart';
import '../utils/app_exception.dart';
import 'location_service.dart';

/// Result of a write that may be queued offline.
typedef CheckInResult = ({double distance, bool synced});

class VisitService {
  VisitService(this._location);

  final LocationService _location;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Geofence radius. A provider could tune this per client.
  static const double geofenceMetres = 150;

  /// Accuracy (metres) above which a check-in is flagged for review.
  static const double lowAccuracyMetres = 50;

  static const Duration _writeTimeout = Duration(seconds: 10);

  /// Real-time stream of this worker's visits (filter matches security rules).
  Stream<List<Visit>> watchVisits(String uid) {
    return _db
        .collection('visits')
        .where('workerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Visit.fromDoc).toList();
      list.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      return list;
    });
  }

  /// Distance from the device to the client, for the "check my distance" button.
  Future<double> distanceToClient(Visit visit) async {
    final pos = await _location.currentPosition();
    return _location.distanceMetres(pos, visit.clientLat, visit.clientLng);
  }

  /// GPS-gated check-in. Throws [AppException] if outside the geofence.
  Future<CheckInResult> checkIn(Visit visit) async {
    final pos = await _location.currentPosition();
    final dist =
        _location.distanceMetres(pos, visit.clientLat, visit.clientLng);

    if (dist > geofenceMetres) {
      throw AppException(
          'You are ${dist.round()} m from the client (limit ${geofenceMetres.round()} m). '
          'Move closer to check in.');
    }

    final write = _db.collection('visits').doc(visit.id).update({
      'status': 'in_progress',
      'checkInAt': FieldValue.serverTimestamp(),
      'checkInLat': pos.latitude,
      'checkInLng': pos.longitude,
      'accuracyM': pos.accuracy,
      'distanceM': dist,
      'lowAccuracy': pos.accuracy > lowAccuracyMetres,
    });
    return (distance: dist, synced: await _settle(write));
  }

  /// Check-out with an optional note. Returns false if the write was queued offline.
  Future<bool> checkOut(Visit visit, String note) {
    final write = _db.collection('visits').doc(visit.id).update({
      'status': 'completed',
      'checkOutAt': FieldValue.serverTimestamp(),
      'note': note.trim(),
    });
    return _settle(write);
  }

  /// Creates 3 synthetic visits around the device's current location so the
  /// geofence can be demonstrated (two in range, one far away).
  Future<void> seedDemoVisits(String uid) async {
    final pos = await _location.currentPosition();
    final now = DateTime.now();
    final demos = <Map<String, dynamic>>[
      {'alias': 'Client A (demo - nearby)', 'addr': '12 Example St', 'dLat': 0.0, 'dLng': 0.0, 'h': 1},
      {'alias': 'Client B (demo - nearby)', 'addr': '34 Sample Ave', 'dLat': 0.0002, 'dLng': 0.0002, 'h': 3},
      {'alias': 'Client C (demo - far away)', 'addr': '56 Faraway Rd', 'dLat': 0.01, 'dLng': 0.01, 'h': 5},
    ];

    final batch = _db.batch();
    for (final d in demos) {
      final ref = _db.collection('visits').doc();
      batch.set(ref, {
        'workerId': uid,
        'clientAlias': d['alias'],
        'clientAddress': d['addr'],
        'clientLat': pos.latitude + (d['dLat'] as double),
        'clientLng': pos.longitude + (d['dLng'] as double),
        'scheduledStart': Timestamp.fromDate(now.add(Duration(hours: d['h'] as int))),
        'status': 'scheduled',
        'demo': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await _settle(batch.commit());
  }

  /// Firestore queues writes while offline and the Future only completes once
  /// the server acknowledges. A timeout therefore means "saved locally, will
  /// sync later" rather than "failed".
  Future<bool> _settle(Future<void> write) async {
    try {
      await write.timeout(_writeTimeout);
      return true;
    } on TimeoutException {
      return false;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AppException('You do not have permission to do that.');
      }
      throw AppException('Could not save (${e.code}). Please try again.');
    }
  }
}
