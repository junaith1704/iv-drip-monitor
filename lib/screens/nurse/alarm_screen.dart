import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/device_service.dart';
import '../../services/trip_service.dart';
import '../../services/auth_service.dart';
import '../../models/device_model.dart';
import '../../models/trip_model.dart';
import '../../theme/clinical_theme.dart';
import '../../widgets/status_badge.dart';

class AlarmScreen extends StatefulWidget {
  final String? deviceId;
  final String? tripId;
  final bool isEmbedded;

  const AlarmScreen({
    super.key,
    this.deviceId,
    this.tripId,
    this.isEmbedded = false,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  bool _isProcessing = false;

  Future<void> _handleFlowResumed(ActiveTripModel trip) async {
    setState(() => _isProcessing = true);
    final tripService = context.read<TripService>();
    final authService = context.read<AuthService>();
    final nurseName = authService.currentUser?.name ?? 'Nurse on Duty';

    if (widget.deviceId == null) return;
    try {
      await tripService.resumeFlow(
        tripId: trip.tripId,
        deviceId: widget.deviceId!,
        nurseIdentifier: nurseName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flow resumption verified and logged. Device returned to RUNNING.'),
            backgroundColor: ClinicalTheme.statusRunning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resolving flow: $e'),
            backgroundColor: ClinicalTheme.statusAlarm,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleInfusionCompleted(ActiveTripModel trip) async {
    if (widget.deviceId == null) return;
    final tripService = context.read<TripService>();
    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final nurseName = authService.currentUser?.name ?? 'Nurse on Duty';

    // Show confirmation dialog before closing the trip
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Infusion Completion'),
        content: Text(
          'This will conclude the infusion session for ${trip.patientName}, snapshot telemetry data, and archive the permanent record to ivTrips. The device will become IDLE.',
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

    if (confirm != true || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      await tripService.completeInfusion(
        tripId: trip.tripId,
        deviceId: widget.deviceId!,
        nurseIdentifier: nurseName,
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Infusion finalized for ${trip.patientName} and saved to ivTrips.'),
            backgroundColor: ClinicalTheme.primaryDarkBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finalizing infusion: $e'),
            backgroundColor: ClinicalTheme.statusAlarm,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceService = context.watch<DeviceService>();
    final tripService = context.watch<TripService>();

    return Scaffold(
      backgroundColor: ClinicalTheme.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Clinical Infusion Alert & Control'),
              elevation: 0,
            ),
      body: widget.deviceId == null
          ? _buildWardAlarmsOverview(context, deviceService, tripService)
          : FutureBuilder<DeviceModel?>(
              future: deviceService.getDevice(widget.deviceId!),
              builder: (context, devSnap) {
                final device = devSnap.data;
                final isStuck = device?.isStuck ?? false || (device?.isAlarm ?? false);

                return FutureBuilder<ActiveTripModel?>(
                  future: tripService.getActiveTripForDevice(widget.deviceId!),
                  builder: (context, tripSnap) {
                    final trip = tripSnap.data;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // High-Contrast Safety Alarm Banner
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isStuck ? ClinicalTheme.statusAlarmBg : ClinicalTheme.statusRunningBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isStuck ? ClinicalTheme.statusAlarm : ClinicalTheme.statusRunning,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isStuck ? ClinicalTheme.statusAlarm : ClinicalTheme.statusRunning).withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              isStuck ? Icons.warning_rounded : Icons.check_circle_rounded,
                              size: 48,
                              color: isStuck ? ClinicalTheme.statusAlarm : ClinicalTheme.statusRunning,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isStuck
                                  ? 'CRITICAL ALERT: DROP FLOW STOPPED'
                                  : 'INFUSION CURRENTLY ACTIVE',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: isStuck ? ClinicalTheme.statusAlarm : ClinicalTheme.statusRunning,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isStuck
                                  ? 'Hardware optical sensor detected no drops for extended duration. Bedside inspection required immediately.'
                                  : 'Optical sensor is continuously registering regular drop intervals.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: ClinicalTheme.deepNavy,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Device & Infusion Telemetry Data Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ClinicalTheme.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device?.currentName ?? 'Device ${widget.deviceId}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: ClinicalTheme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Hardware Identifier: ${widget.deviceId}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: ClinicalTheme.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  status: device?.status ?? 'idle',
                                  isLarge: true,
                                ),
                              ],
                            ),
                            const Divider(height: 28, color: ClinicalTheme.borderSubtle),

                            if (trip != null) ...[
                              _buildInfoRow('Patient Name', trip.patientName, isBold: true),
                              const SizedBox(height: 10),
                              _buildInfoRow('Diagnosis / Drug', trip.issue),
                              const SizedBox(height: 10),
                              _buildInfoRow(
                                'Infusion Started',
                                DateFormat('MMM d, yyyy • HH:mm:ss').format(trip.startTime),
                              ),
                              const SizedBox(height: 10),
                              _buildInfoRow(
                                'Elapsed Infusion Time',
                                '${DateTime.now().difference(trip.startTime).inMinutes} minutes',
                              ),
                              const SizedBox(height: 10),
                              _buildInfoRow(
                                'Total Stoppage Incidents',
                                '${trip.stoppedEvents.length} event(s)',
                              ),
                            ] else ...[
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'No active infusion associated with this device.',
                                    style: TextStyle(color: ClinicalTheme.textSecondary),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (trip != null && trip.stoppedEvents.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        // Stoppage Events Log
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ClinicalTheme.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.history_toggle_off_rounded, size: 18, color: ClinicalTheme.textSecondary),
                                  SizedBox(width: 8),
                                  Text(
                                    'Session Stoppage Incident Log',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: ClinicalTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...trip.stoppedEvents.reversed.map((ev) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: ev.isResolved
                                        ? ClinicalTheme.background
                                        : ClinicalTheme.statusAlarmBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: ev.isResolved
                                          ? ClinicalTheme.borderSubtle
                                          : ClinicalTheme.statusAlarmBorder,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Stopped: ${DateFormat('HH:mm:ss').format(ev.time)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: ev.isResolved
                                                  ? ClinicalTheme.textPrimary
                                                  : ClinicalTheme.statusAlarm,
                                            ),
                                          ),
                                          if (ev.isResolved)
                                            Text(
                                              'Resolved by: ${ev.resolvedBy ?? "Staff"} at ${DateFormat('HH:mm:ss').format(ev.resolvedTime!)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: ClinicalTheme.textSecondary,
                                              ),
                                            )
                                          else
                                            const Text(
                                              'Pending bedside intervention',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: ClinicalTheme.statusAlarm,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                      Icon(
                                        ev.isResolved ? Icons.check_circle : Icons.warning,
                                        size: 18,
                                        color: ev.isResolved
                                            ? ClinicalTheme.statusRunning
                                            : ClinicalTheme.statusAlarm,
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Safety Response Actions
                      if (trip != null) ...[
                        const Text(
                          'CLINICAL INTERVENTION RESPONSES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ClinicalTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Button 1: "Flow Resumed"
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _handleFlowResumed(trip),
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text('FLOW RESUMED (DROP RE-ESTABLISHED)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClinicalTheme.statusRunning,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Button 2: "Infusion Completed"
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _handleInfusionCompleted(trip),
                          icon: const Icon(Icons.done_all_rounded, size: 20),
                          label: const Text('INFUSION COMPLETED (WRITE TO IVTRIPS)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClinicalTheme.deepNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: ClinicalTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: ClinicalTheme.textPrimary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
