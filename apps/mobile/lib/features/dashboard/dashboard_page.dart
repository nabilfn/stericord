import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/equipment/equipment_list_page.dart';
import 'package:stericord_mobile/features/auth/profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const _DashboardHome(), const EquipmentListPage(), const ProfilePage()];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.build_outlined), label: 'Equipment'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('SteriCord')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Welcome, ${auth.profile?.fullName ?? '…'}', style: Theme.of(context).textTheme.titleLarge),
          Text(auth.roles.map((r) => r.dbValue).join(', '), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Card(
            color: AppColors.scBlueLight,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sterilization cycles, pack tracking, and OT verification arrive in Phase 2 and Phase 3.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
