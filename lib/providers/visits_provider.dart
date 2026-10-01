import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/visit.dart';
import '../services/visit_service.dart';

/// Holds the signed-in worker's visits, kept live by a Firestore stream.
class VisitsProvider extends ChangeNotifier {
  VisitsProvider(this._service);

  final VisitService _service;
  StreamSubscription<List<Visit>>? _sub;
  String? _uid;

  List<Visit> visits = const [];
  bool loading = false;
  String? error;

  /// Called whenever the signed-in user changes. Does not notify directly
  /// because it may run during a build; stream events notify instead.
  void bind(String? uid) {
    if (uid == _uid) return;
    _sub?.cancel();
    _sub = null;
    _uid = uid;
    visits = const [];
    error = null;
    if (uid == null) {
      loading = false;
      return;
    }
    loading = true;
    _sub = _service.watchVisits(uid).listen(
      (list) {
        visits = list;
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object e) {
        loading = false;
        error = 'Could not load visits. Check your connection and try again.';
        notifyListeners();
      },
    );
  }

  List<Visit> get active =>
      visits.where((v) => v.status != VisitStatus.completed).toList();

  List<Visit> get completed {
    final list =
        visits.where((v) => v.status == VisitStatus.completed).toList();
    list.sort((a, b) => (b.checkOutAt ?? b.scheduledStart)
        .compareTo(a.checkOutAt ?? a.scheduledStart));
    return list;
  }

  Visit? byId(String id) {
    for (final v in visits) {
      if (v.id == id) return v;
    }
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
