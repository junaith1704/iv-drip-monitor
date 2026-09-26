import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/device_service.dart';
import '../../services/trip_service.dart';
import '../../models/device_model.dart';
import '../../models/trip_model.dart';
import '../../theme/clinical_theme.dart';
import '../../widgets/device_card.dart';
import '../../widgets/alarm_banner.dart';
import 'new_trip_screen.dart';
import 'alarm_screen.dart';

class NurseHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const NurseHomeScreen({super.key, this.onNavigateTab});

  @override
  State<NurseHomeScreen> createState() => _NurseHomeScreenState();
}

class _NurseHomeScreenState extends State<NurseHomeScreen> {
  String _statusFilter = 'all'; // 'all', 'running', 'stuck', 'idle'

  @override
  Widget build(BuildContext context) {
    final deviceService = context.watch<DeviceService>();
    final tripService = context.watch<TripService>();

    return StreamBuilder<List<DeviceModel>>(
      stream: deviceService.streamDevices(),
      builder: (context, deviceSnap) {
        if (!deviceSnap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: ClinicalTheme.primaryBlue),
          );
        }

        final devices = deviceSnap.data ?? [];
        final stuckDevices = devices.where((d) => d.isStuck || d.isAlarm).toList();
        final runningCount = devices.where((d) => d.isRunning).length;
        final idleCount = devices.where((d) => d.isIdle).length;

        final filteredDevices = devices.where((d) {
          if (_statusFilter == 'all') return true;
          return d.status.toLowerCase() == _statusFilter;
        }).toList();

        return StreamBuilder<List<ActiveTripModel>>(
          stream: tripService.streamActiveTrips(),
          builder: (context, tripSnap) {
            final activeTrips = tripSnap.data ?? [];

            ActiveTripModel? findTrip(String deviceId) {
              try {
                return activeTrips.firstWhere((t) => t.deviceId == deviceId);
              } catch (_) {
                return null;
              }
            }

            return Scaffold(
              backgroundColor: ClinicalTheme.background,
              body: RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Persistent Alarm Banner if any device is stuck
                    if (stuckDevices.isNotEmpty)
                      AlarmBanner(
                        stuckDevices: stuckDevices,
                        onTapDevice: (device) {
                          final trip = findTrip(device.deviceId);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlarmScreen(
                                deviceId: device.deviceId,
                                tripId: trip?.tripId,
                              ),
                            ),
                          );
                        },
                      ),

                    // Quick Ward Infusion Stats Bar
                    Row(
                      children: [
                        _buildStatChip(
                          label: 'TOTAL',
                          count: devices.length,
                          color: ClinicalTheme.deepNavy,
                          isSelected: _statusFilter == 'all',
                          onTap: () => setState(() => _statusFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          label: 'RUNNING',
                          count: runningCount,
                          color: ClinicalTheme.statusRunning,
                          isSelected: _statusFilter == 'running',
                          onTap: () => setState(() => _statusFilter = 'running'),
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          label: 'STUCK / ALERTS',
                          count: stuckDevices.length,
                          color: ClinicalTheme.statusAlarm,
                          isSelected: _statusFilter == 'stuck',
                          onTap: () => setState(() => _statusFilter = 'stuck'),
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          label: 'IDLE',
                          count: idleCount,
                          color: ClinicalTheme.statusIdle,
                          isSelected: _statusFilter == 'idle',
                          onTap: () => setState(() => _statusFilter = 'idle'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Action Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Live Ward Telemetry',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: ClinicalTheme.textPrimary,
                              ),
                            ),
                            Text(
                              '${filteredDevices.length} monitored drop station(s)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ClinicalTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NewTripScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('NEW INFUSION'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClinicalTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Device Cards List
                    if (filteredDevices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ClinicalTheme.borderSubtle),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.sensors_off, size: 36, color: ClinicalTheme.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              'No devices matching filter "$_statusFilter"',
                              style: const TextStyle(color: ClinicalTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    else
                      ...filteredDevices.map((device) {
                        final trip = findTrip(device.deviceId);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DeviceCard(
                            device: device,
                            activeTrip: trip,
                            onStartTrip: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NewTripScreen(preselectedDeviceId: device.deviceId),
                                ),
                              );
                            },
                            onOpenAlarm: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AlarmScreen(
                                    deviceId: device.deviceId,
                                    tripId: trip?.tripId,
                                  ),
                                ),
                              );
                            },
                            onSimulateDropStop: device.isRunning
                                ? () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    await tripService.simulateDropStop(deviceId: device.deviceId);
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Simulated Drop Sensor Stoppage on ${device.currentName}'),
                                          backgroundColor: ClinicalTheme.statusAlarm,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatChip({
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : ClinicalTheme.borderSubtle,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : ClinicalTheme.textSecondary,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
