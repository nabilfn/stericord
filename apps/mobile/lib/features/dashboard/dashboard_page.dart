import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/auth/profile_page.dart';
import 'package:stericord_mobile/features/cycles/cycles_list_page.dart';
import 'package:stericord_mobile/features/dashboard/dashboard_home.dart';
import 'package:stericord_mobile/features/equipment/equipment_list_page.dart';
import 'package:stericord_mobile/features/ot/qr_scan_page.dart';

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final bool emphasized;
  const _Destination(this.label, this.icon, this.selectedIcon, this.page, {this.emphasized = false});
}

/// Bottom-nav shell (redesign prompt section 10). Which tabs appear is
/// unchanged from before this redesign -- role-gating logic (canScan,
/// canSeeCycles, canSeeEquipment) is preserved exactly, only the visual
/// treatment changed, including giving Scan (when present) a visually
/// emphasized raised-pill treatment per section 10's "center Scan action
/// can be visually emphasized."
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
      const _Destination('Home', Icons.home_outlined, Icons.home_rounded, DashboardHome()),
      if (canSeeCycles) const _Destination('Cycles', Icons.layers_outlined, Icons.layers_rounded, CyclesListPage()),
      if (canScan)
        const _Destination('Scan', Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded, QrScanPage(), emphasized: true),
      if (canSeeEquipment)
        const _Destination('Equipment', Icons.build_outlined, Icons.build_rounded, EquipmentListPage()),
      const _Destination('Profile', Icons.person_outline, Icons.person_rounded, ProfilePage()),
    ];

    final index = _index < destinations.length ? _index : 0;

    return Scaffold(
      // Deliberately not an IndexedStack: QrScanPage starts the camera in
      // initState, so keeping every tab mounted simultaneously would start
      // the camera the moment the dashboard loads, not when Scan is
      // actually opened. Matches the original behavior -- only the active
      // tab's page is ever in the tree.
      body: destinations[index].page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations.map((d) {
          final selected = destinations.indexOf(d) == index;
          if (d.emphasized) {
            return NavigationDestination(
              icon: _EmphasizedScanIcon(selected: selected, icon: d.icon),
              label: d.label,
            );
          }
          return NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          );
        }).toList(),
      ),
    );
  }
}

class _EmphasizedScanIcon extends StatelessWidget {
  final bool selected;
  final IconData icon;

  const _EmphasizedScanIcon({required this.selected, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: selected ? AppColors.tealDark : AppColors.teal,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.teal.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}
