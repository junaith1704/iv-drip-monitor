import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/clinical_theme.dart';
import '../models/device_model.dart';
import '../models/trip_model.dart';
import 'status_badge.dart';

class DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final ActiveTripModel? activeTrip;
  final VoidCallback onStartTrip;
  final VoidCallback onOpenAlarm;
  final VoidCallback? onSimulateDropStop;
  final VoidCallback? onDeviceDetails;

  const DeviceCard({
    super.key,
    required this.device,
    this.activeTrip,
    required this.onStartTrip,
    required this.onOpenAlarm,
    this.onSimulateDropStop,
    this.onDeviceDetails,
  });

  @override
  Widget build(BuildContext context) {
    final statusConfig = ClinicalTheme.getStatusConfig(device.status);
    final isStuck = device.isStuck || device.isAlarm;

    return Container(
      decoration: BoxDecoration(
        color: ClinicalTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isStuck ? ClinicalTheme.statusAlarm : ClinicalTheme.borderSubtle,
          width: isStuck ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isStuck
                ? ClinicalTheme.statusAlarm.withOpacity(0.08)
                : Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isStuck
                  ? ClinicalTheme.statusAlarmBg
                  : ClinicalTheme.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
              border: Border(
                bottom: BorderSide(
                  color: isStuck ? ClinicalTheme.statusAlarmBorder : ClinicalTheme.borderSubtle,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        statusConfig.icon,
                        size: 18,
                        color: statusConfig.color,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          device.currentName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ClinicalTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ClinicalTheme.borderSubtle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          device.deviceId,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: ClinicalTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: device.status),
              ],
            ),
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeTrip != null) ...[
                  // Patient Info
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: ClinicalTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        activeTrip!.patientName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ClinicalTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.medical_services_outlined, size: 16, color: ClinicalTheme.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          activeTrip!.issue,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ClinicalTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Elapsed Time & Stopped Events
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 15, color: ClinicalTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Started ${DateFormat('HH:mm').format(activeTrip!.startTime)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ClinicalTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (activeTrip!.stoppedEvents.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ClinicalTheme.statusStuckBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: ClinicalTheme.statusStuckBorder),
                          ),
                          child: Text(
                            '${activeTrip!.stoppedEvents.length} stop event(s)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ClinicalTheme.statusStuck,
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  // Idle State
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: ClinicalTheme.statusIdle),
                      SizedBox(width: 6),
                      Text(
                        'Device Ready for Next Infusion',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: ClinicalTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: ClinicalTheme.borderSubtle),
                const SizedBox(height: 12),

                // Action Row
                Row(
                  children: [
                    if (isStuck) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onOpenAlarm,
                          icon: const Icon(Icons.alarm_on, size: 18),
                          label: const Text('RESPOND TO ALARM'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClinicalTheme.statusAlarm,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else if (device.isIdle) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onStartTrip,
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('START INFUSION'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClinicalTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Running state
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onOpenAlarm,
                          icon: const Icon(Icons.medical_information_outlined, size: 18),
                          label: const Text('MANAGE INFUSION'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ClinicalTheme.primaryDarkBlue,
                            side: const BorderSide(color: ClinicalTheme.primaryBlue),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      if (onSimulateDropStop != null) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Simulate hardware drop sensor stop (ESP32-C3 event)',
                          child: InkWell(
                            onTap: onSimulateDropStop,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: ClinicalTheme.statusStuckBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: ClinicalTheme.statusStuckBorder),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.sensors_off_rounded, size: 16, color: ClinicalTheme.statusStuck),
                                  SizedBox(width: 4),
                                  Text(
                                    'Test Sensor Stop',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: ClinicalTheme.statusStuck,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
