import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/auth/profile_page.dart';
import 'package:stericord_mobile/features/cycles/cycles_list_page.dart';
import 'package:stericord_mobile/features/equipment/equipment_list_page.dart';
import 'package:stericord_mobile/features/incidents/incidents_list_page.dart';
import 'package:stericord_mobile/features/notifications/notifications_page.dart';
import 'package:stericord_mobile/features/ot/qr_scan_page.dart';

class _Destination {
  final String label;
  final IconData icon;
  final Widget page;
  const _Destination(this.label, this.icon, this.page);
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canScan = auth.hasRole([UserRole.otNurse, UserRole.cssdSupervisor, UserRole.hospitalAdmin]);
    final canSeeCycles = auth.hasRole([UserRole.cssdTechnician, UserRole.cssdSupervisor, UserRole.hospitalAdmin]);
    final canSeeEquipment = auth.hasRole([
      UserRole.cssdTechnician,
      UserRole.cssdSupervisor,
      UserRole.hospitalAdmin,
      UserRole.biomedicalEngineer,
    ]);

    final destinations = <_Destination>[
      const _Destination('Dashboard', Icons.dashboard_outlined, _DashboardHome()),
      if (canScan) const _Destination('Scan', Icons.qr_code_scanner, QrScanPage()),
      if (canSeeCycles) const _Destination('Cycles', Icons.layers_outlined, CyclesListPage()),
      if (canSeeEquipment) const _Destination('Equipment', Icons.build_outlined, EquipmentListPage()),
      const _Destination('Profile', Icons.person_outline, ProfilePage()),
    ];

    final index = _index < destinations.length ? _index : 0;

    return Scaffold(
      body: destinations[index].page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations
            .map((d) => NavigationDestination(icon: Icon(d.icon), label: d.label))
            .toList(),
      ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canManageIncidents = auth.hasRole([UserRole.hospitalAdmin, UserRole.cssdSupervisor]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SteriCord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Welcome, ${auth.profile?.fullName ?? '…'}', style: Theme.of(context).textTheme.titleLarge),
          Text(auth.roles.map((r) => r.dbValue).join(', '), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          if (canManageIncidents)
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: AppColors.fail),
                title: const Text('Incidents'),
                subtitle: const Text('Review and manage open safety events'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const IncidentsListPage()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
