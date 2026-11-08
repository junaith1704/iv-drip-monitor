import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/device_model.dart';
import '../models/trip_model.dart';
import '../theme/clinical_theme.dart';

class GlobalAlarmDialog extends StatelessWidget {
  final DeviceModel device;
  final ActiveTripModel? trip;
  final int totalStuckCount;
  final bool isNurse;
  final VoidCallback onOpenAlarmScreen;
  final VoidCallback onSilence60s;
  final VoidCallback? onFlowResumed;
  final VoidCallback? onInfusionCompleted;

  const GlobalAlarmDialog({
    super.key,
    required this.device,
    required this.trip,
    required this.totalStuckCount,
    this.isNurse = false,
    required this.onOpenAlarmScreen,
    required this.onSilence60s,
    this.onFlowResumed,
    this.onInfusionCompleted,
  });

  String _extractLocation(String name) {
    if (name.contains('-')) {
      return name.split('-').first.trim();
    }
    if (name.contains(',')) {
      return name.split(',').first.trim();
    }
    return name.trim();
  }

  String _formatStoppedTime() {
    DateTime stopped;
    if (trip != null && trip!.stoppedEvents.isNotEmpty) {
      stopped = trip!.stoppedEvents.last.time;
    } else if (device.lastUpdated != null) {
      stopped = device.lastUpdated!;
    } else {
      stopped = DateTime.now();
    }
    return DateFormat('h:mm:ss a').format(stopped);
  }

  String _formatStartTime() {
    if (trip == null) return 'N/A';
    return DateFormat('h:mm a, MMM d').format(trip!.startTime);
  }

  String? _getReasonText(String? alarmReason) {
    switch (alarmReason) {
      case 'flow_stopped':
        return 'Drip flow stopped';
      case 'board_offline':
        return 'Board disconnected';
      case 'gateway_lost':
        return 'Gateway phone lost contact';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _extractLocation(device.currentName);
    final patientName = trip?.patientName.isNotEmpty == true ? trip!.patientName : 'Unassigned Patient';
    final issueFluid = trip?.issue.isNotEmpty == true ? trip!.issue : 'Unspecified Fluid';
    final startTimeStr = _formatStartTime();
    final stoppedTimeStr = _formatStoppedTime();
    final reasonText = _getReasonText(device.alarmReason);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onSilence60s();
        }
      },
      child: Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xFFFFF5F5),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: ClinicalTheme.statusAlarm.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: ClinicalTheme.statusAlarm, width: 2),
                              ),
                              child: const Icon(
                                Icons.warning_rounded,
                                color: ClinicalTheme.statusAlarm,
                                size: 44,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Center(
                            child: Text(
                              'CRITICAL: INFUSION STOPPED',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: ClinicalTheme.statusAlarm,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (reasonText != null) ...[
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                reasonText,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: ClinicalTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              totalStuckCount > 1
                                  ? '$totalStuckCount devices need attention'
                                  : '1 device needs attention',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: totalStuckCount > 1 ? ClinicalTheme.statusAlarm : ClinicalTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: ClinicalTheme.statusAlarm.withOpacity(0.5), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: ClinicalTheme.statusAlarm.withOpacity(0.08),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow(
                                  icon: Icons.meeting_room_outlined,
                                  label: 'Floor / Location',
                                  value: location,
                                  isHighlighted: true,
                                ),
                                const Divider(height: 18),
                                _buildDetailRow(
                                  icon: Icons.devices_other_rounded,
                                  label: 'Device Name',
                                  value: device.currentName,
                                ),
                                const Divider(height: 18),
                                _buildDetailRow(
                                  icon: Icons.qr_code_2_rounded,
                                  label: 'Device ID',
                                  value: device.deviceId,
                                ),
                                const Divider(height: 18),
                                _buildDetailRow(
                                  icon: Icons.person_outline_rounded,
                                  label: 'Patient Name',
                                  value: patientName,
                                  isHighlighted: true,
                                ),
                                const Divider(height: 18),
                                _buildDetailRow(
                                  icon: Icons.water_drop_outlined,
                                  label: 'Issue / Fluid',
                                  value: issueFluid,
                                ),
                                const Divider(height: 18),
                                _buildDetailRow(
                                  icon: Icons.play_arrow_outlined,
                                  label: 'Trip Start Time',
                                  value: startTimeStr,
                                ),
                                const Divider(height: 18),
                                _buildDetailRow(
                                  icon: Icons.timer_off_outlined,
                                  label: 'Drip Stopped At',
                                  value: stoppedTimeStr,
                                  isCritical: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (device.alarmReason == 'gateway_lost') ...[
                              OutlinedButton.icon(
                                onPressed: onSilence60s,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ClinicalTheme.deepNavy,
                                  side: const BorderSide(color: ClinicalTheme.borderSubtle, width: 1.5),
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.volume_off_rounded, size: 20),
                                label: const Text(
                                  'Silence 60 s',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ] else if (isNurse) ...[
                              ElevatedButton.icon(
                                onPressed: onFlowResumed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ClinicalTheme.statusRunning,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                label: const Text(
                                  'Flow Resumed',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final patientDisplayName = trip?.patientName.isNotEmpty == true ? trip!.patientName : device.currentName;
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Confirm Infusion Completion'),
                                      content: Text(
                                        'This will conclude the infusion session for $patientDisplayName, snapshot telemetry data, and archive the permanent record to ivTrips. The device will become IDLE.',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('CANCEL'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: ClinicalTheme.primaryBlue,
                                          ),
                                          child: const Text('CONFIRM & FINALIZE'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && context.mounted) {
                                    onInfusionCompleted?.call();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ClinicalTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                                label: const Text(
                                  'Infusion Completed',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: onOpenAlarmScreen,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ClinicalTheme.statusAlarm,
                                  side: const BorderSide(color: ClinicalTheme.statusAlarm, width: 1.5),
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                                label: const Text(
                                  'Open alarm screen',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ] else ...[
                              ElevatedButton.icon(
                                onPressed: onOpenAlarmScreen,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ClinicalTheme.statusAlarm,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                                icon: const Icon(Icons.open_in_new_rounded, size: 22),
                                label: const Text(
                                  'Open alarm screen',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            OutlinedButton.icon(
                              onPressed: onSilence60s,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ClinicalTheme.deepNavy,
                                side: const BorderSide(color: ClinicalTheme.borderSubtle, width: 1.5),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.volume_off_rounded, size: 20),
                              label: const Text(
                                'Silence 60 s',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
    bool isCritical = false,
  }) {
    Color valueColor = ClinicalTheme.textPrimary;
    FontWeight fontWeight = FontWeight.w600;
    if (isCritical) {
      valueColor = ClinicalTheme.statusAlarm;
      fontWeight = FontWeight.w800;
    } else if (isHighlighted) {
      valueColor = ClinicalTheme.deepNavy;
      fontWeight = FontWeight.w700;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isCritical ? ClinicalTheme.statusAlarm : ClinicalTheme.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ClinicalTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: fontWeight,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
