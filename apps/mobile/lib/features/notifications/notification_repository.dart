import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/features/notifications/notification_model.dart';

class NotificationRepository {
  Future<List<AppNotification>> listNotifications() async {
    final data = await SupabaseClientProvider.client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).map((row) => AppNotification.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> markRead(String id) async {
    await SupabaseClientProvider.client.rpc('mark_notification_read', params: {'p_notification_id': id});
  }

  RealtimeChannel subscribe(String userId, void Function() onChange) {
    return SupabaseClientProvider.client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_user_id',
            value: userId,
          ),
          callback: (payload) => onChange(),
        )
        .subscribe();
  }
}
