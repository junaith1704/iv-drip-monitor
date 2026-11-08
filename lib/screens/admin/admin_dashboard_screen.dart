import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/device_service.dart';
import '../../services/firebase_service.dart';
import '../../services/service_request_service.dart';
import '../../models/device_model.dart';
import '../../theme/clinical_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/connection_badge.dart';

class AdminDashboardScreen extends StatelessWidget {
  final Function(int) onNavigateTab;

  const AdminDashboardScreen({
    super.key,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final deviceService = context.watch<DeviceService>();
    final requestService = context.watch<ServiceRequestService>();

    return StreamBuilder<List<DeviceModel>>(
      stream: deviceService.streamDevices(),
      builder: (context, devSnap) {
        final devices = devSnap.data ?? [];
        final totalDevices = devices.length;
        final runningDevices = devices.where((d) => d.isRunning).length;
        final stuckDevices = devices.where((d) => d.isStuck || d.isAlarm).length;
        final idleDevices = devices.where((d) => d.isIdle).length;

        return StreamBuilder(
          stream: requestService.streamOpenRequests(),
          builder: (context, reqSnap) {
            final openRequests = reqSnap.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Metric Cards Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      return GridView.count(
                        crossAxisCount: isWide ? 4 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isWide ? 1.6 : 1.4,
                        children: [
                          _buildKpiCard(
                            title: 'TOTAL HARDWARE',
                            value: totalDevices.toString(),
                            subtitle: '$idleDevices idle / available',
                            icon: Icons.developer_board_rounded,
                            color: ClinicalTheme.deepNavy,
                            onTap: () => onNavigateTab(1), // Device Management
                          ),
                          _buildKpiCard(
                            title: 'ACTIVE INFUSIONS',
                            value: runningDevices.toString(),
                            subtitle: 'In progress across ward',
                            icon: Icons.water_drop_rounded,
                            color: ClinicalTheme.statusRunning,
                            onTap: () => onNavigateTab(2), // Trip History
                          ),
                          _buildKpiCard(
                            title: 'CRITICAL / STUCK',
                            value: stuckDevices.toString(),
                            subtitle: stuckDevices > 0 ? 'Requires attention' : 'All flows normal',
                            icon: Icons.warning_amber_rounded,
                            color: stuckDevices > 0 ? ClinicalTheme.statusAlarm : ClinicalTheme.statusIdle,
                            onTap: () => onNavigateTab(1),
                          ),
                          _buildKpiCard(
                            title: 'OPEN SERVICE TICKETS',
                            value: openRequests.length.toString(),
                            subtitle: 'Pending admin resolution',
                            icon: Icons.build_circle_outlined,
                            color: openRequests.isNotEmpty ? ClinicalTheme.statusStuck : ClinicalTheme.statusRunning,
                            onTap: () => onNavigateTab(4), // Service requests tab
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Quick Administrative Action Hub
                  const Text(
                    'Administrative Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ClinicalTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tiles = [
                        _buildActionTile(
                          icon: Icons.edit_location_alt_outlined,
                          title: 'Device Reassignment',
                          subtitle: 'Rename devices & update ward floors',
                          color: ClinicalTheme.primaryBlue,
                          onTap: () => onNavigateTab(1),
                        ),
                        _buildActionTile(
                          icon: Icons.history_edu_rounded,
                          title: 'Completed ivTrips',
                          subtitle: 'Search & audit infusion history',
                          color: ClinicalTheme.tealAccent,
                          onTap: () => onNavigateTab(2),
                        ),
                        _buildActionTile(
                          icon: Icons.people_alt_outlined,
                          title: 'Nurse & Staff Registry',
                          subtitle: 'Overview staff members & stats',
                          color: Colors.purple.shade700,
                          onTap: () => onNavigateTab(3),
                        ),
                      ];
                      if (constraints.maxWidth > 700) {
                        return Row(
                          children: [
                            for (int i = 0; i < tiles.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(child: tiles[i]),
                            ],
                          ],
                        );
                      }
                      return Column(
                        children: [
                          for (int i = 0; i < tiles.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            tiles[i],
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Real-time Device Inventory & Telemetry Table
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ClinicalTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Live Hardware Telemetry Inventory',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: ClinicalTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'ESP32-C3 Drop Sensors connected to Firestore',
                                      style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () => onNavigateTab(1),
                                icon: const Icon(Icons.tune_rounded, size: 16),
                                label: const Text('MANAGE ALL'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: ClinicalTheme.borderSubtle),
                        if (devices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                FirebaseService.isMockFallback
                                    ? 'Cannot connect to the database'
                                    : 'No registered hardware units in telemetry inventory.',
                                style: const TextStyle(fontSize: 13, color: ClinicalTheme.textSecondary),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: devices.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: ClinicalTheme.borderSubtle),
                          itemBuilder: (context, index) {
                            final device = devices[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: ClinicalTheme.getStatusConfig(device.status).color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          device.currentName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: ClinicalTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'ID: ${device.deviceId}',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: ClinicalTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      device.nameHistory.isNotEmpty
                                          ? '${device.nameHistory.length} previous location(s)'
                                          : 'Initial location',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: ClinicalTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      StatusBadge(status: device.status),
                                      ConnectionBadge(device: device),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ClinicalTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ClinicalTheme.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ClinicalTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ClinicalTheme.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ClinicalTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: ClinicalTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
