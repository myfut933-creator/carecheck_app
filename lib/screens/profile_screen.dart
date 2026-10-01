import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/visit_service.dart';
import '../utils/app_exception.dart';

/// Screen 7: Profile, demo-data loader and sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _seeding = false;

  Future<void> _seed() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    final service = context.read<VisitService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _seeding = true);
    try {
      await service.seedDemoVisits(uid);
      messenger.showSnackBar(const SnackBar(
          content: Text('Demo visits created around your current location.')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final auth = context.read<AuthProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = (user?.displayName?.isNotEmpty ?? false) ? user!.displayName! : 'Support worker';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(name, style: Theme.of(context).textTheme.titleLarge)),
          Center(child: Text(user?.email ?? '')),
          const SizedBox(height: 4),
          const Center(child: Text('Role: Support worker')),
          const SizedBox(height: 24),
          const Divider(),
          const Text('Testing tools', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Creates 3 synthetic visits around your current location: two within the '
            '150 m geofence and one far away, so you can demonstrate GPS check-in.',
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _seeding ? null : _seed,
            icon: _seeding
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.science_outlined),
            label: const Text('Load demo visits'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
