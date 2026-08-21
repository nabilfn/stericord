import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/core/offline/sync_status_badge.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';
import 'package:stericord_mobile/features/cycles/cycle_repository.dart';
import 'package:stericord_mobile/features/cycles/cycle_status_chip.dart';
import 'package:stericord_mobile/features/cycles/cycles_list_page.dart';
import 'package:stericord_mobile/features/equipment/equipment_list_page.dart';
import 'package:stericord_mobile/features/equipment/equipment_model.dart';
import 'package:stericord_mobile/features/equipment/equipment_repository.dart';
import 'package:stericord_mobile/features/incidents/incidents_list_page.dart';
import 'package:stericord_mobile/features/notifications/notification_model.dart';
import 'package:stericord_mobile/features/notifications/notification_repository.dart';
import 'package:stericord_mobile/features/notifications/notifications_page.dart';
import 'package:stericord_mobile/features/ot/qr_scan_page.dart';

/// Home tab content. Every number here comes from a real query against
/// equipment/cycles/notifications (already-existing repositories) -- no
/// fabricated placeholder data, per the redesign brief's explicit
/// instruction not to invent numbers when real application state exists.
class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  final _equipmentRepository = EquipmentRepository();
  final _cycleRepository = CycleRepository();
  final _notificationRepository = NotificationRepository();

  List<Equipment>? _equipment;
  List<SterilizationCycle>? _cycles;
  List<AppNotification>? _notifications;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        _equipmentRepository.listEquipment(),
        _cycleRepository.listCycles(),
        _notificationRepository.listNotifications(),
      ]);
      if (!mounted) return;
      setState(() {
        _equipment = results[0] as List<Equipment>;
        _cycles = results[1] as List<SterilizationCycle>;
        _notifications = results[2] as List<AppNotification>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canManageIncidents = auth.hasRole([UserRole.hospitalAdmin, UserRole.cssdSupervisor]);
    final canScan = auth.hasRole([UserRole.otNurse, UserRole.cssdSupervisor, UserRole.hospitalAdmin]);
    final canSeeCycles = auth.hasRole([UserRole.cssdTechnician, UserRole.cssdSupervisor, UserRole.hospitalAdmin]);
    final canSeeEquipment = auth.hasRole([
      UserRole.cssdTechnician,
      UserRole.cssdSupervisor,
      UserRole.hospitalAdmin,
      UserRole.biomedicalEngineer,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SteriCord'),
        actions: [
          const SyncStatusBadge(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: _error != null
            ? SteriErrorState(onRetry: _load)
            : (_equipment == null || _cycles == null || _notifications == null)
                ? const SteriLoadingState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.lg,
                      AppSpacing.screenPadding,
                      AppSpacing.xxxl,
                    ),
                    children: [
                      _Greeting(name: auth.profile?.fullName, roles: auth.roles),
                      const SizedBox(height: AppSpacing.xl),
                      if (_criticalAlerts.isNotEmpty) ...[
                        _CriticalAlertsBanner(alerts: _criticalAlerts),
                        const SizedBox(height: AppSpacing.sectionGap),
                      ],
                      const SteriSectionHeader(title: "Today's overview"),
                      const SizedBox(height: AppSpacing.md),
                      _OverviewGrid(
                        cyclesToday: _cyclesToday,
                        pendingVerification: _pendingVerification,
                        activeEquipment: _activeEquipment,
                        unreadAlerts: _unreadCount,
                      ),
                      const SizedBox(height: AppSpacing.sectionGap),
                      const SteriSectionHeader(title: 'Quick actions'),
                      const SizedBox(height: AppSpacing.md),
                      _QuickActions(
                        canScan: canScan,
                        canSeeCycles: canSeeCycles,
                        canSeeEquipment: canSeeEquipment,
                        canManageIncidents: canManageIncidents,
                      ),
                      if (canSeeEquipment) ...[
                        const SizedBox(height: AppSpacing.sectionGap),
                        SteriSectionHeader(
                          title: 'Equipment',
                          actionLabel: _equipment!.length > 3 ? 'View all' : null,
                          onAction: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const EquipmentListPage()),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _EquipmentPreview(equipment: _equipment!.take(3).toList()),
                      ],
                      if (canSeeCycles) ...[
                        const SizedBox(height: AppSpacing.sectionGap),
                        SteriSectionHeader(
                          title: 'Recent activity',
                          actionLabel: _cycles!.isNotEmpty ? 'View all' : null,
                          onAction: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CyclesListPage()),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RecentActivity(cycles: _cycles!.take(5).toList()),
                      ],
                    ],
                  ),
      ),
    );
  }

  List<AppNotification> get _criticalAlerts =>
      (_notifications ?? []).where((n) => !n.isRead && n.priority == 'CRITICAL').toList();

  int get _unreadCount => (_notifications ?? []).where((n) => !n.isRead).length;

  int get _cyclesToday {
    final now = DateTime.now();
    return (_cycles ?? [])
        .where((c) =>
            c.createdAt.year == now.year && c.createdAt.month == now.month && c.createdAt.day == now.day)
        .length;
  }

  int get _pendingVerification =>
      (_cycles ?? []).where((c) => c.cycleStatus == CycleStatus.pendingVerification).length;

  int get _activeEquipment => (_equipment ?? []).where((e) => e.operatingStatus == EquipmentStatus.active).length;
}

class _Greeting extends StatelessWidget {
  final String? name;
  final List<UserRole> roles;

  const _Greeting({required this.name, required this.roles});

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _roleLabel(UserRole role) {
    final words = role.dbValue.split('_').map((w) => '${w[0]}${w.substring(1).toLowerCase()}');
    return words.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final nameParts = (name ?? '').split(' ');
    final firstName = nameParts.isEmpty ? '' : nameParts.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$_timeGreeting${firstName.isEmpty ? '' : ', $firstName'}', style: AppTypography.heroHeader),
        if (roles.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(roles.map(_roleLabel).join(' · '), style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

class _CriticalAlertsBanner extends StatelessWidget {
  final List<AppNotification> alerts;

  const _CriticalAlertsBanner({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return SteriCard(
      backgroundColor: AppColors.failSoft,
      borderColor: AppColors.fail.withValues(alpha: 0.25),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsPage())),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.fail, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${alerts.length} critical alert${alerts.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.fail, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(alerts.first.title, style: const TextStyle(color: AppColors.fail, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.fail),
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  final int cyclesToday;
  final int pendingVerification;
  final int activeEquipment;
  final int unreadAlerts;

  const _OverviewGrid({
    required this.cyclesToday,
    required this.pendingVerification,
    required this.activeEquipment,
    required this.unreadAlerts,
  });

  @override
  Widget build(BuildContext context) {
    // Two IntrinsicHeight Rows of Expanded cards, not GridView.count: a
    // fixed aspect ratio forces a rigid cell height that doesn't actually
    // track the content's real height (icon + a 30px number + a label wrap
    // differently across devices and text-scale/accessibility settings),
    // which overflowed in practice. IntrinsicHeight + Expanded lets each
    // card take the height its own content needs, and forces its sibling
    // to match -- CrossAxisAlignment.stretch alone isn't enough here since
    // the Row's only non-flexible child would otherwise be a zero-height
    // spacer SizedBox.
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SteriMetricCard(value: '$cyclesToday', label: 'Cycles today', icon: Icons.layers_outlined),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SteriMetricCard(
                  value: '$pendingVerification',
                  label: 'Pending verification',
                  icon: Icons.hourglass_empty_rounded,
                  accentColor: pendingVerification > 0 ? AppColors.warning : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SteriMetricCard(value: '$activeEquipment', label: 'Equipment active', icon: Icons.build_outlined),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SteriMetricCard(
                  value: '$unreadAlerts',
                  label: 'Unread alerts',
                  icon: Icons.notifications_outlined,
                  accentColor: unreadAlerts > 0 ? AppColors.fail : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SteriCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.scBlueLight, borderRadius: BorderRadius.circular(AppRadius.small)),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.navy, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool canScan;
  final bool canSeeCycles;
  final bool canSeeEquipment;
  final bool canManageIncidents;

  const _QuickActions({
    required this.canScan,
    required this.canSeeCycles,
    required this.canSeeEquipment,
    required this.canManageIncidents,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickActionButton>[
      if (canScan)
        _QuickActionButton(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Scan Pack',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScanPage())),
        ),
      if (canSeeCycles)
        _QuickActionButton(
          icon: Icons.layers_outlined,
          label: 'Cycles',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CyclesListPage())),
        ),
      if (canSeeEquipment)
        _QuickActionButton(
          icon: Icons.build_outlined,
          label: 'Equipment',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EquipmentListPage())),
        ),
      if (canManageIncidents)
        _QuickActionButton(
          icon: Icons.warning_amber_rounded,
          label: 'Incidents',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IncidentsListPage())),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    // A Row of Expanded buttons, not GridView.count: same reasoning as
    // _OverviewGrid above -- a fixed aspect ratio doesn't track the actual
    // height a label needs once it wraps to two lines, which overflowed in
    // practice. There are at most 4 possible actions (one per boolean role
    // flag above), so a single Row always fits without needing to wrap.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            Expanded(child: actions[i]),
          ],
        ],
      ),
    );
  }
}

class _EquipmentPreview extends StatelessWidget {
  final List<Equipment> equipment;

  const _EquipmentPreview({required this.equipment});

  @override
  Widget build(BuildContext context) {
    if (equipment.isEmpty) {
      return const SteriEmptyState(
        icon: Icons.build_outlined,
        title: 'No equipment yet',
        message: 'Equipment registered for your organization will appear here.',
      );
    }
    return Column(
      children: equipment
          .map((e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SteriCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EquipmentListPage())),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.equipmentCode, style: AppTypography.cardTitle),
                            if (e.location != null) ...[
                              const SizedBox(height: 2),
                              Text(e.location!, style: AppTypography.metadata),
                            ],
                          ],
                        ),
                      ),
                      _equipmentStatusBadge(e.operatingStatus),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _equipmentStatusBadge(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return const SteriStatusBadge(label: 'ACTIVE', tone: SteriStatusTone.pass, icon: Icons.check_circle_outline, compact: true);
      case EquipmentStatus.lockedOut:
        return const SteriStatusBadge(label: 'LOCKED OUT', tone: SteriStatusTone.fail, icon: Icons.lock_outline, compact: true);
      case EquipmentStatus.maintenance:
        return const SteriStatusBadge(label: 'MAINTENANCE', tone: SteriStatusTone.warning, icon: Icons.build_outlined, compact: true);
      case EquipmentStatus.decommissioned:
        return const SteriStatusBadge(label: 'DECOMMISSIONED', tone: SteriStatusTone.neutral, icon: Icons.block, compact: true);
    }
  }
}

class _RecentActivity extends StatelessWidget {
  final List<SterilizationCycle> cycles;

  const _RecentActivity({required this.cycles});

  @override
  Widget build(BuildContext context) {
    if (cycles.isEmpty) {
      return const SteriEmptyState(
        icon: Icons.layers_outlined,
        title: 'No cycles yet',
        message: 'Sterilization cycles you create will show up here.',
      );
    }
    return Column(
      children: cycles
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SteriCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CyclesListPage())),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cycle ${c.cycleNumber}', style: AppTypography.cardTitle),
                            const SizedBox(height: 2),
                            Text(_relativeTime(c.createdAt), style: AppTypography.metadata),
                          ],
                        ),
                      ),
                      CycleStatusChip(status: c.cycleStatus),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
