import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/trip_service.dart';
import '../../services/device_service.dart';
import '../../models/trip_model.dart';
import '../../models/device_model.dart';
import '../../theme/clinical_theme.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final _searchController = TextEditingController();
  String _patientQuery = '';
  String? _selectedDeviceId;
  DateTimeRange? _selectedDateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTripDetails(BuildContext context, IvTripModel trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: ClinicalTheme.primaryBlue),
            const SizedBox(width: 8),
            const Text('Completed Infusion Audit Record'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAuditField('Trip Identifier', trip.tripId, isMonospace: true),
                const Divider(height: 16),
                _buildAuditField('Patient Name', trip.patientName, isBold: true),
                _buildAuditField('Condition / Fluid', trip.issue),
                _buildAuditField('Hardware Snapshot', '${trip.deviceName} (${trip.deviceId})'),
                const Divider(height: 16),
                _buildAuditField(
                  'Infusion Started',
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(trip.startTime),
                ),
                _buildAuditField(
                  'Infusion Concluded',
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(trip.endTime),
                ),
                _buildAuditField(
                  'Total Duration',
                  '${trip.totalDuration.inHours}h ${trip.totalDuration.inMinutes % 60}m',
                ),
                _buildAuditField('Verified Completed By', trip.completedBy, isBold: true),
                _buildAuditField(
                  'Archived At',
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(trip.completedAt),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Stoppage Incidents During Session:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ClinicalTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                if (trip.stoppedEvents.isEmpty)
                  const Text('Zero flow interruptions recorded.', style: TextStyle(fontSize: 12, color: ClinicalTheme.statusRunning))
                else
                  ...trip.stoppedEvents.map((ev) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ClinicalTheme.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ClinicalTheme.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.alarm_off, size: 16, color: ClinicalTheme.statusStuck),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Stopped: ${DateFormat('HH:mm:ss').format(ev.time)} → '
                                'Resolved: ${ev.resolvedTime != null ? DateFormat('HH:mm:ss').format(ev.resolvedTime!) : "N/A"}'
                                '${ev.resolvedBy != null ? " by ${ev.resolvedBy}" : ""}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditField(String label, String value, {bool isBold = false, bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontFamily: isMonospace ? 'monospace' : null,
                color: ClinicalTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripService = context.watch<TripService>();
    final deviceService = context.watch<DeviceService>();

    return Scaffold(
      backgroundColor: ClinicalTheme.background,
      body: StreamBuilder<List<IvTripModel>>(
        stream: tripService.streamCompletedTrips(),
        builder: (context, tripSnap) {
          final allTrips = tripSnap.data ?? [];

          // Apply filters
          final filtered = allTrips.where((trip) {
            // Patient search filter
            if (_patientQuery.isNotEmpty) {
              final query = _patientQuery.toLowerCase();
              final matchesPatient = trip.patientName.toLowerCase().contains(query);
              final matchesIssue = trip.issue.toLowerCase().contains(query);
              if (!matchesPatient && !matchesIssue) return false;
            }

            // Device filter
            if (_selectedDeviceId != null && trip.deviceId != _selectedDeviceId) {
              return false;
            }

            // Date Range filter
            if (_selectedDateRange != null) {
              if (trip.completedAt.isBefore(_selectedDateRange!.start) ||
                  trip.completedAt.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)))) {
                return false;
              }
            }

            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Filter Panel
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
                    const Text(
                      'Search & Filter Infusion Records (ivTrips)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ClinicalTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Patient Search
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search patient name, fluid, condition...',
                              prefixIcon: const Icon(Icons.search, size: 20, color: ClinicalTheme.textMuted),
                              suffixIcon: _patientQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _patientQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (val) => setState(() => _patientQuery = val.trim()),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Device Filter
                        Expanded(
                          flex: 2,
                          child: StreamBuilder<List<DeviceModel>>(
                            stream: deviceService.streamDevices(),
                            builder: (context, devSnap) {
                              final devices = devSnap.data ?? [];
                              return DropdownButtonFormField<String?>(
                                value: _selectedDeviceId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.filter_alt_outlined, color: ClinicalTheme.textMuted),
                                  hintText: 'All Devices',
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All Devices'),
                                  ),
                                  ...devices.map(
                                    (d) => DropdownMenuItem<String?>(
                                      value: d.deviceId,
                                      child: Text(d.currentName),
                                    ),
                                  ),
                                ],
                                onChanged: (val) => setState(() => _selectedDeviceId = val),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Date Picker Button
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2025, 1, 1),
                              lastDate: DateTime.now().add(const Duration(days: 1)),
                              initialDateRange: _selectedDateRange,
                            );
                            if (picked != null) {
                              setState(() => _selectedDateRange = picked);
                            }
                          },
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            _selectedDateRange == null
                                ? 'Date Range'
                                : '${DateFormat('MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('MM/dd').format(_selectedDateRange!.end)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),

                        if (_selectedDateRange != null || _selectedDeviceId != null || _patientQuery.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.restart_alt, color: ClinicalTheme.statusAlarm),
                            tooltip: 'Reset Filters',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _patientQuery = '';
                                _selectedDeviceId = null;
                                _selectedDateRange = null;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Records Table Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Archived Infusion Records (${filtered.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ClinicalTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Records List
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ClinicalTheme.borderSubtle),
                  ),
                  child: const Text('No finalized infusion records matching current filters.'),
                )
              else
                ...filtered.map((trip) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ClinicalTheme.borderSubtle),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ClinicalTheme.statusRunningBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ClinicalTheme.statusRunningBorder),
                            ),
                            child: const Icon(
                              Icons.task_alt_rounded,
                              color: ClinicalTheme.statusRunning,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip.patientName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: ClinicalTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  trip.issue,
                                  style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Station: ${trip.deviceName} (${trip.deviceId})',
                                  style: const TextStyle(fontSize: 11, color: ClinicalTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Completed: ${DateFormat('MMM d, HH:mm').format(trip.completedAt)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Duration: ${trip.totalDuration.inMinutes} mins',
                                  style: const TextStyle(fontSize: 11, color: ClinicalTheme.textSecondary),
                                ),
                                Text(
                                  'By: ${trip.completedBy}',
                                  style: const TextStyle(fontSize: 11, color: ClinicalTheme.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _showTripDetails(context, trip),
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: const Text('AUDIT LOG'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ClinicalTheme.primaryBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
