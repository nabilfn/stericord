import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/notifications/notification_model.dart';
import 'package:stericord_mobile/features/notifications/notification_repository.dart';

Color colorForPriority(String priority) {
  switch (priority) {
    case 'CRITICAL':
      return AppColors.fail;
    case 'HIGH':
      return AppColors.warning;
    case 'MEDIUM':
      return AppColors.scBlue;
    default:
      return Colors.grey;
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
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _future;
        },
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snapshot) {
            final notifications = snapshot.data ?? [];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (notifications.isEmpty) {
              return ListView(
                children: const [Padding(padding: EdgeInsets.all(24), child: Text('No notifications yet.'))],
              );
            }
            return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return ListTile(
                  tileColor: n.isRead ? null : AppColors.scBlueLight,
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: n.body != null ? Text(n.body!) : null,
                  trailing: Chip(
                    label: Text(n.priority, style: const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: colorForPriority(n.priority),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  onTap: () => _markRead(n),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
