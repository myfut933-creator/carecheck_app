import 'dart:typed_data';

import 'package:carecheck/services/incident_service.dart';
import 'package:carecheck/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('worker@example.com'), isNull);
    });

    test('password', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('incident description needs 10+ characters', () {
      expect(Validators.incident('short'), isNotNull);
      expect(Validators.incident('Client slipped near the bathroom door.'),
          isNull);
    });

    test('incident photo data uri stays in free Firebase-safe format', () {
      final dataUri = IncidentService.dataUriForPhotoBytes(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(dataUri, startsWith('data:image/jpeg;base64,'));
      expect(dataUri, endsWith('AQID'));
    });
  });
}
