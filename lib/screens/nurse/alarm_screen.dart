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
          : StreamBuilder<DeviceModel?>(
              stream: deviceService.streamDevices().map((list) {
                try {
                  return list.firstWhere((d) => d.deviceId == widget.deviceId!);
                } catch (_) {
                  return null;
                }
              }),
              builder: (context, devSnap) {
                final device = devSnap.data;
                final isStuck = device?.isStuck ?? false || (device?.isAlarm ?? false);

                return StreamBuilder<ActiveTripModel?>(
                  stream: tripService.streamActiveTrips().map((list) {
                    try {
                      return list.firstWhere((t) => t.deviceId == widget.deviceId!);
                    } catch (_) {
                      return null;
                    }
                  }),
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (device != null && !device.boardOnline)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: ClinicalTheme.statusAlarm.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: ClinicalTheme.statusAlarm.withOpacity(0.4)),
                                        ),
                                        child: const Text(
                                          'Offline',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: ClinicalTheme.statusAlarm,
                                          ),
                                        ),
                                      ),
                                    if (device != null && device.isLowBattery)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: ClinicalTheme.statusAlarm.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: ClinicalTheme.statusAlarm.withOpacity(0.4)),
                                        ),
                                        child: Text(
                                          'Low Battery (${device.battery}%)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: ClinicalTheme.statusAlarm,
                                          ),
                                        ),
                                      ),
                                    StatusBadge(
                                      status: device?.status ?? 'idle',
                                      isLarge: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 28, color: ClinicalTheme.borderSubtle),

                            _buildInfoRow('Optical Speed', device?.speed ?? '--'),
                            const SizedBox(height: 10),
                            _buildInfoRow('Flow Rate (DPM)', device?.dpm != null ? device!.dpm!.toStringAsFixed(1) : '--'),
                            const SizedBox(height: 10),
                            _buildInfoRow('Hardware Battery', (device?.battery != null && device!.battery! > 0) ? '${device.battery}%' : 'No sensor'),
                            const SizedBox(height: 10),

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

  Widget _buildWardAlarmsOverview(
    BuildContext context,
    DeviceService deviceService,
    TripService tripService,
  ) {
    return StreamBuilder<List<DeviceModel>>(
      stream: deviceService.streamDevices(),
      builder: (context, devSnap) {
        if (devSnap.connectionState == ConnectionState.waiting && !devSnap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: ClinicalTheme.primaryBlue),
          );
        }

        final devices = devSnap.data ?? [];
        final stuckDevices = devices.where((d) => d.isStuck || d.isAlarm).toList();

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

            final hasAlarms = stuckDevices.isNotEmpty;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // High-Contrast Safety Overview Banner
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: hasAlarms ? ClinicalTheme.statusAlarmBg : ClinicalTheme.statusRunningBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasAlarms ? ClinicalTheme.statusAlarm : ClinicalTheme.statusRunning,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (hasAlarms ? ClinicalTheme.statusAlarm : ClinicalTheme.statusRunning).withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              hasAlarms ? Icons.warning_rounded : Icons.check_circle_rounded,
                              size: 48,
                              color: hasAlarms ? ClinicalTheme.statusAlarm : ClinicalTheme.statusRunning,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hasAlarms
                                  ? 'CRITICAL ALERT: ${stuckDevices.length} WARD ALARM(S) ACTIVE'
                                  : 'ALL WARD INFUSIONS OPERATING NORMALLY',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: hasAlarms ? ClinicalTheme.statusAlarm : ClinicalTheme.statusRunning,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hasAlarms
                                  ? 'Immediate bedside verification required. One or more devices report optical sensor flow stoppage.'
                                  : 'No optical sensor stoppages or hardware alerts detected across monitored stations.',
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

                      const SizedBox(height: 24),

                      // Active Alarms Section
                      _buildActiveAlarmsSection(context, stuckDevices, activeTrips),

                      if (devices.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'ALL MONITORED WARD STATIONS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ClinicalTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...devices.map((device) {
                          final trip = findTrip(device.deviceId);
                          final isDeviceStuck = device.isStuck || device.isAlarm;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDeviceStuck ? ClinicalTheme.statusAlarmBorder : ClinicalTheme.borderSubtle,
                                width: isDeviceStuck ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isDeviceStuck ? ClinicalTheme.statusAlarm : ClinicalTheme.primaryBlue).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isDeviceStuck ? Icons.warning_rounded : Icons.sensors,
                                    color: isDeviceStuck ? ClinicalTheme.statusAlarm : ClinicalTheme.primaryBlue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device.currentName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: ClinicalTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        trip != null ? 'Patient: ${trip.patientName}' : 'Hardware ID: ${device.deviceId}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: ClinicalTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(status: device.status),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () {
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
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: isDeviceStuck ? ClinicalTheme.statusAlarm : ClinicalTheme.borderSubtle,
                                    ),
                                    foregroundColor: isDeviceStuck ? ClinicalTheme.statusAlarm : ClinicalTheme.primaryBlue,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: Text(
                                    isDeviceStuck ? 'RESPOND' : 'VIEW',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveAlarmsSection(
    BuildContext context,
    List<DeviceModel> stuckDevices,
    List<ActiveTripModel> activeTrips,
  ) {
    if (stuckDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ClinicalTheme.borderSubtle),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: ClinicalTheme.statusRunning, size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Active Critical Alarms',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ClinicalTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'All ongoing infusions are delivering drops within normal safety parameters.',
                    style: TextStyle(
                      fontSize: 12,
                      color: ClinicalTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    ActiveTripModel? findTrip(String deviceId) {
      try {
        return activeTrips.firstWhere((t) => t.deviceId == deviceId);
      } catch (_) {
        return null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACTIVE CRITICAL ALERTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: ClinicalTheme.statusAlarm,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...stuckDevices.map((device) {
          final trip = findTrip(device.deviceId);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ClinicalTheme.statusAlarmBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: ClinicalTheme.statusAlarm.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
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
                            device.currentName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ClinicalTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hardware ID: ${device.deviceId}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: ClinicalTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: device.status, isLarge: true),
                  ],
                ),
                const Divider(height: 20, color: ClinicalTheme.borderSubtle),
                if (trip != null) ...[
                  _buildInfoRow('Patient Name', trip.patientName, isBold: true),
                  const SizedBox(height: 8),
                  _buildInfoRow('Diagnosis / Drug', trip.issue),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Infusion Started',
                    DateFormat('MMM d, yyyy • HH:mm').format(trip.startTime),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Incident Count',
                    '${trip.stoppedEvents.length} recorded stoppage(s)',
                  ),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No active infusion associated with this device.',
                      style: TextStyle(color: ClinicalTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
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
                    icon: const Icon(Icons.emergency, size: 18),
                    label: const Text('MANAGE BEDSIDE ALARM'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClinicalTheme.statusAlarm,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
