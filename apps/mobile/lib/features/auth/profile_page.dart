import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: const Text('Full name'), subtitle: Text(profile?.fullName ?? '—')),
          ListTile(title: const Text('Email'), subtitle: Text(profile?.email ?? '—')),
          ListTile(title: const Text('Roles'), subtitle: Text(auth.roles.map((r) => r.dbValue).join(', '))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<AuthController>().signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
