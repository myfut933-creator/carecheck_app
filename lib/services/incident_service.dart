import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../models/incident.dart';
import '../utils/app_exception.dart';

class IncidentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String dataUriForPhotoBytes(
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) {
    return 'data:$contentType;base64,${base64Encode(bytes)}';
  }

  /// Stores the photo as a base64 Data URL in Firestore so the app works without
  /// a paid Firebase Storage plan.
  Future<String> uploadPhoto(
    String uid,
    XFile photo, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final bytes = await photo.readAsBytes();
      onProgress?.call(1.0);
      return dataUriForPhotoBytes(bytes);
    } on FileSystemException {
      throw AppException('The photo could not be read from this device.');
    } catch (_) {
      throw AppException(
          'The photo could not be uploaded. Check your connection and try again.');
    }
  }

  /// Saves the incident. Returns false if the write is queued (offline).
  Future<bool> submit({
    required String uid,
    required String visitId,
    required String clientAlias,
    required String category,
    required String severity,
    required String description,
    required bool aiAssisted,
    String? photoUrl,
  }) async {
    final write = _db.collection('incidents').add({
      'workerId': uid,
      'visitId': visitId,
      'clientAlias': clientAlias,
      'category': category,
      'severity': severity,
      'description': description.trim(),
      'aiAssisted': aiAssisted,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await write.timeout(const Duration(seconds: 10));
      return true;
    } on TimeoutException {
      return false; // queued locally, will sync when online
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AppException('You do not have permission to submit this report.');
      }
      throw AppException(
          'Could not save the report (${e.code}). Please try again.');
    }
  }

  Stream<List<Incident>> watchIncidents(String uid) {
    return _db
        .collection('incidents')
        .where('workerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Incident.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
