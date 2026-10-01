import 'package:carecheck/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell renders without crashing', (tester) async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: '1:1234567890:android:abc123',
        messagingSenderId: '1234567890',
        projectId: 'demo-carecheck',
        storageBucket: 'demo-carecheck.appspot.com',
      ),
    );

    await tester.pumpWidget(const CareCheckApp());

    expect(find.byType(CareCheckApp), findsOneWidget);
  });
}
