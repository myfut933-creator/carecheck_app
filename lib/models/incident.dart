import 'package:cloud_firestore/cloud_firestore.dart';

class Incident {
  const Incident({
    required this.id,
    required this.visitId,
    required this.category,
    required this.severity,
    required this.description,
    required this.aiAssisted,
    required this.createdAt,
    this.photoUrl,
    this.clientAlias,
  });

  final String id;
  final String visitId;
  final String category;
  final String severity;
  final String description;
  final bool aiAssisted;
  final DateTime createdAt;
  final String? photoUrl;
  final String? clientAlias;

  factory Incident.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Incident(
      id: doc.id,
      visitId: (d['visitId'] ?? '') as String,
      category: (d['category'] ?? 'Other') as String,
      severity: (d['severity'] ?? 'Low') as String,
      description: (d['description'] ?? '') as String,
      aiAssisted: (d['aiAssisted'] ?? false) as bool,
      // A just-written document may not have its server timestamp yet.
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: d['photoUrl'] as String?,
      clientAlias: d['clientAlias'] as String?,
    );
  }
}
