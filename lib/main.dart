import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/visits_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'services/incident_service.dart';
import 'services/location_service.dart';
import 'services/visit_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CareCheckApp());
}

class CareCheckApp extends StatelessWidget {
  const CareCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Service layer
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<LocationService>(create: (_) => LocationService()),
        ProxyProvider<LocationService, VisitService>(
          update: (_, location, previous) => previous ?? VisitService(location),
        ),
        Provider<IncidentService>(create: (_) => IncidentService()),
        Provider<AiService>(create: (_) => AiService()),
        // State layer
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<AuthService>()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, VisitsProvider>(
          create: (ctx) => VisitsProvider(ctx.read<VisitService>()),
          update: (ctx, auth, visits) {
            final provider = visits ?? VisitsProvider(ctx.read<VisitService>());
            provider.bind(auth.user?.uid);
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'CareCheck',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Shows Login or Home depending on Firebase Auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.initialised) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.user == null ? const LoginScreen() : const HomeScreen();
  }
}
