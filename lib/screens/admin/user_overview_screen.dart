import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/trip_service.dart';
import '../../models/user_model.dart';
import '../../models/trip_model.dart';
import '../../theme/clinical_theme.dart';

class UserOverviewScreen extends StatelessWidget {
  const UserOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final tripService = context.watch<TripService>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 650;
    final isTight = screenWidth < 360;

    return Scaffold(
      backgroundColor: ClinicalTheme.background,
      body: FutureBuilder<List<UserModel>>(
        future: authService.getAllUsers(),
        builder: (context, userSnap) {
          final users = userSnap.data ?? AuthService.mockUsers;

          return StreamBuilder<List<IvTripModel>>(
            stream: tripService.streamCompletedTrips(),
            builder: (context, completedSnap) {
              final completedTrips = completedSnap.data ?? [];

              return StreamBuilder<List<ActiveTripModel>>(
                stream: tripService.streamActiveTrips(),
                builder: (context, activeSnap) {
                  final activeTrips = activeSnap.data ?? [];

                  // Count stats per user
                  int getCompletedTripCount(UserModel user) {
                    return completedTrips.where((t) {
                      final by = t.completedBy.toLowerCase();
                      return by.contains(user.name.toLowerCase()) ||
                          by.contains(user.userId.toLowerCase());
                    }).length;
                  }

                  final totalActive = activeTrips.length;

                  return ListView(
                    padding: EdgeInsets.all(isWide ? 20 : 16),
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ClinicalTheme.borderSubtle),
                        ),
                        child: isWide
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Hospital Clinical Staff & Nurse Registry',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: ClinicalTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${users.length} registered healthcare operators',
                                          style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: ClinicalTheme.primaryBlue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$totalActive Infusion(s) Live • ${users.where((u) => u.isNurse).length} Nurses Active',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: ClinicalTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Hospital Clinical Staff & Nurse Registry',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: ClinicalTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${users.length} registered healthcare operators',
                                    style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: ClinicalTheme.primaryBlue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$totalActive Infusion(s) Live • ${users.where((u) => u.isNurse).length} Nurses Active',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: ClinicalTheme.primaryBlue,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      const SizedBox(height: 16),

                      // Users List
                      ...users.map((user) {
                        final completedCount = getCompletedTripCount(user);
                        final isAdmin = user.isAdmin;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ClinicalTheme.borderSubtle),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isWide ? 16 : 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: isAdmin
                                      ? Colors.purple.shade100
                                      : ClinicalTheme.primaryBlue.withOpacity(0.12),
                                  child: Icon(
                                    isAdmin ? Icons.admin_panel_settings : Icons.health_and_safety,
                                    color: isAdmin ? Colors.purple.shade800 : ClinicalTheme.primaryBlue,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              user.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: ClinicalTheme.textPrimary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isAdmin
                                                  ? Colors.purple.shade50
                                                  : Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isAdmin
                                                    ? Colors.purple.shade200
                                                    : Colors.blue.shade200,
                                              ),
                                            ),
                                            child: Text(
                                              user.role.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: isAdmin
                                                    ? Colors.purple.shade800
                                                    : ClinicalTheme.primaryDarkBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildStatPill(
                                      label: isTight ? 'TRIPS' : 'COMPLETED TRIPS',
                                      value: completedCount.toString(),
                                      color: ClinicalTheme.statusRunning,
                                    ),
                                    if (isWide) ...[
                                      const SizedBox(width: 8),
                                      _buildStatPill(
                                        label: 'CURRENT ROLE',
                                        value: isAdmin ? 'Admin' : 'Bedside RN',
                                        color: ClinicalTheme.deepNavy,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: ClinicalTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ClinicalTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: ClinicalTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
