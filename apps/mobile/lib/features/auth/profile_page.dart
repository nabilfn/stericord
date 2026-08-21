import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profile = auth.profile;
    final initial = (profile?.fullName.trim().isNotEmpty ?? false) ? profile!.fullName.trim()[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(profile?.fullName ?? '—', style: AppTypography.sectionHeader),
                const SizedBox(height: 2),
                Text(profile?.email ?? '—', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const SteriSectionHeader(title: 'Roles'),
          const SizedBox(height: AppSpacing.md),
          if (auth.roles.isEmpty)
            const SteriEmptyState(icon: Icons.badge_outlined, title: 'No roles assigned', message: 'Contact your administrator.')
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: auth.roles
                  .map((r) => SteriStatusBadge(label: r.dbValue.replaceAll('_', ' '), tone: SteriStatusTone.info))
                  .toList(),
            ),
          const SizedBox(height: AppSpacing.sectionGap),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.read<AuthController>().signOut(),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.fail, side: const BorderSide(color: AppColors.fail)),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}
