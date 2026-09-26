import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/clinical_theme.dart';

class ClinicalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showUserBadge;

  const ClinicalAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showUserBadge = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final isNarrow = MediaQuery.sizeOf(context).width < 450;

    return AppBar(
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ClinicalTheme.primaryBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  size: 16,
                  color: ClinicalTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ClinicalTheme.deepNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: ClinicalTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      actions: [
        if (showUserBadge && user != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: PopupMenuButton<String>(
              tooltip: 'User Profile & Switcher',
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: ClinicalTheme.borderSubtle),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ClinicalTheme.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ClinicalTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: user.isAdmin
                          ? ClinicalTheme.deepNavy
                          : ClinicalTheme.primaryBlue,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0] : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!isNarrow) ...[
                      const SizedBox(width: 6),
                      Text(
                        user.name.split(' ').first,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ClinicalTheme.textPrimary,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: user.isAdmin
                            ? Colors.purple.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: user.isAdmin
                              ? Colors.purple.shade200
                              : Colors.blue.shade200,
                        ),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: user.isAdmin ? Colors.purple.shade800 : ClinicalTheme.primaryDarkBlue,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16, color: ClinicalTheme.textMuted),
                  ],
                ),
              ),
              onSelected: (value) async {
                if (value == 'logout') {
                  await authService.signOut();
                } else if (value.startsWith('switch_')) {
                  final targetEmail = value.replaceFirst('switch_', '');
                  final targetUser = AuthService.mockUsers.firstWhere((u) => u.email == targetEmail);
                  await authService.switchDemoUser(targetUser);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: ClinicalTheme.textPrimary),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'SWITCH ROLE (DEMO TESTING):',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ClinicalTheme.textMuted),
                  ),
                ),
                ...AuthService.mockUsers.map(
                  (u) => PopupMenuItem(
                    value: 'switch_${u.email}',
                    child: Row(
                      children: [
                        Icon(
                          u.isAdmin ? Icons.admin_panel_settings : Icons.health_and_safety,
                          size: 16,
                          color: u.isAdmin ? Colors.purple : ClinicalTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${u.name.split(',').first} (${u.role.toUpperCase()})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: u.userId == user.userId ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 16, color: ClinicalTheme.statusAlarm),
                      SizedBox(width: 8),
                      Text('Sign Out', style: TextStyle(color: ClinicalTheme.statusAlarm, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        ...?actions,
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: ClinicalTheme.borderSubtle),
      ),
    );
  }
}
