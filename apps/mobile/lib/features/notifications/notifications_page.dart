import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/notifications/notification_model.dart';
import 'package:stericord_mobile/features/notifications/notification_repository.dart';

SteriStatusTone toneForPriority(String priority) {
  switch (priority) {
    case 'CRITICAL':
      return SteriStatusTone.fail;
    case 'HIGH':
      return SteriStatusTone.warning;
    case 'MEDIUM':
      return SteriStatusTone.info;
    default:
      return SteriStatusTone.neutral;
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _repository = NotificationRepository();
  late Future<List<AppNotification>> _future;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _future = _repository.listNotifications();
    final userId = context.read<AuthController>().profile?.id;
    if (userId != null) {
      _channel = _repository.subscribe(userId, _refresh);
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _future = _repository.listNotifications());
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    await _repository.markRead(n.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _future;
        },
        color: AppColors.teal,
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SteriLoadingState();
            }
            if (snapshot.hasError) {
              return SteriErrorState(title: 'Unable to load alerts', onRetry: _refresh);
            }
            final notifications = snapshot.data ?? [];
            if (notifications.isEmpty) {
              return const SteriEmptyState(
                icon: Icons.notifications_none,
                title: 'No alerts',
                message: "You're all caught up.",
              );
            }

            final now = DateTime.now();
            final critical = <AppNotification>[];
            final today = <AppNotification>[];
            final earlier = <AppNotification>[];
            for (final n in notifications) {
              final isToday = n.createdAt.year == now.year && n.createdAt.month == now.month && n.createdAt.day == now.day;
              if (!n.isRead && n.priority == 'CRITICAL') {
                critical.add(n);
              } else if (isToday) {
                today.add(n);
              } else {
                earlier.add(n);
              }
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                if (critical.isNotEmpty) _Group(title: 'Critical', notifications: critical, onTap: _markRead),
                if (today.isNotEmpty) _Group(title: 'Today', notifications: today, onTap: _markRead),
                if (earlier.isNotEmpty) _Group(title: 'Earlier', notifications: earlier, onTap: _markRead),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<AppNotification> notifications;
  final void Function(AppNotification) onTap;

  const _Group({required this.title, required this.notifications, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SteriSectionHeader(title: title),
          const SizedBox(height: AppSpacing.md),
          ...notifications.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SteriCard(
                  onTap: () => onTap(n),
                  backgroundColor: n.isRead ? AppColors.surface : AppColors.infoSoft,
                  borderColor: n.isRead ? AppColors.border : AppColors.info.withValues(alpha: 0.25),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700, fontSize: 14.5),
                            ),
                            if (n.body != null) ...[
                              const SizedBox(height: 2),
                              Text(n.body!, style: AppTypography.metadata),
                            ],
                            const SizedBox(height: 4),
                            Text(_relativeTime(n.createdAt), style: AppTypography.metadata),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SteriStatusBadge(label: n.priority, tone: toneForPriority(n.priority), compact: true),
                    ],
                  ),
                ),
              )),
        ],
      ),
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
