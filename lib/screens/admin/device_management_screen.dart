import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/device_service.dart';
import '../../services/firebase_service.dart';
import '../../services/hardware_bridge_service.dart';
import '../../models/device_model.dart';
import '../../theme/clinical_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/connection_badge.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isScanning = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _findBoards(
    HardwareBridgeService bridge,
    List<DeviceModel> devices,
  ) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    final wasRunning = bridge.isRunning;
    final foundBoards = <Map<String, dynamic>>[];

    try {
      if (wasRunning) {
        await bridge.stop();
      }

      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final subnets = <String>{};

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        final isAllowed = name.startsWith('wlan') ||
            name.startsWith('ap') ||
            name.startsWith('swlan') ||
            name.startsWith('eth');
        final isMobile = name.startsWith('rmnet') ||
            name.startsWith('ccmni') ||
            name.startsWith('pdp') ||
            name.startsWith('v4-');
        if (!isAllowed || isMobile) continue;

        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            final parts = address.address.split('.');
            if (parts.length == 4) {
              final o1 = int.tryParse(parts[0]);
              final o2 = int.tryParse(parts[1]);
              final o3 = int.tryParse(parts[2]);
              final o4 = int.tryParse(parts[3]);
              if (o1 != null && o2 != null && o3 != null && o4 != null) {
                final isPrivate = o1 == 10 ||
                    (o1 == 192 && o2 == 168) ||
                    (o1 == 172 && o2 >= 16 && o2 <= 31);
                if (isPrivate) {
                  subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
                }
              }
            }
          }
        }
      }

      final ips = <String>[];
      for (final subnet in subnets) {
        for (var host = 1; host <= 254; host++) {
          ips.add('$subnet.$host');
        }
      }

      if (ips.isNotEmpty) {
        final client = http.Client();
        try {
          var index = 0;
          Future<void> worker() async {
            while (index < ips.length) {
              final targetIp = ips[index++];
              try {
                final uri = Uri.parse('http://$targetIp/api');
                final res = await client.get(uri).timeout(const Duration(seconds: 1));
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  if (data is Map<String, dynamic> &&
                      data.containsKey('drops') &&
                      data.containsKey('speed')) {
                    foundBoards.add({
                      'ip': targetIp,
                      'speed': data['speed']?.toString() ?? '',
                      'runtime': data['runtime']?.toString() ?? '',
                    });
                  }
                }
              } catch (_) {}
            }
          }

          final workers = List.generate(20, (_) => worker());
          await Future.wait(workers);
        } finally {
          client.close();
        }
      }
    } catch (e) {
      debugPrint('[DeviceManagementScreen] Scan error: $e');
    } finally {
      if (wasRunning) {
        await bridge.start();
      }
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }

    if (!mounted) return;
    _showFoundBoardsBottomSheet(foundBoards, devices);
  }

  void _showFoundBoardsBottomSheet(
    List<Map<String, dynamic>> foundBoards,
    List<DeviceModel> devices,
  ) {
    if (foundBoards.isEmpty) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: ClinicalTheme.statusAlarm),
              const SizedBox(height: 16),
              const Text(
                'No Boards Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'No boards found. Check the board is powered and on the same WiFi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: ClinicalTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final assignments = <String, String?>{};
    for (final board in foundBoards) {
      final ip = board['ip'] as String;
      final matchedDevice = devices.cast<DeviceModel?>().firstWhere(
        (d) => d?.boardIp == ip,
        orElse: () => null,
      );
      assignments[ip] = matchedDevice?.deviceId;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final assignedList = assignments.values.where((id) => id != null && id.isNotEmpty).toList();
            final hasDuplicates = assignedList.length != assignedList.toSet().length;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Found Hardware Boards',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Found ${foundBoards.length} board(s) on the local network.',
                    style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (hasDuplicates)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ClinicalTheme.statusAlarm.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ClinicalTheme.statusAlarm),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.error_outline, color: ClinicalTheme.statusAlarm, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Multiple boards assigned to the same device. Please ensure each device has at most one board assigned.',
                              style: TextStyle(fontSize: 12, color: ClinicalTheme.statusAlarm, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: foundBoards.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final board = foundBoards[index];
                        final ip = board['ip'] as String;
                        final speed = board['speed'] as String;
                        final runtime = board['runtime'] as String;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ClinicalTheme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClinicalTheme.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.developer_board, size: 20, color: ClinicalTheme.primaryBlue),
                                  const SizedBox(width: 8),
                                  Text(
                                    ip,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ClinicalTheme.borderSubtle,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Speed: $speed',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Runtime: $runtime',
                                style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String?>(
                                value: assignments[ip],
                                decoration: const InputDecoration(
                                  labelText: 'Assign to Device',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Unassigned'),
                                  ),
                                  ...devices.map((d) {
                                    return DropdownMenuItem<String?>(
                                      value: d.deviceId,
                                      child: Text('${d.currentName} (${d.deviceId})'),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setModalState(() {
                                    assignments[ip] = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: hasDuplicates
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final deviceService = context.read<DeviceService>();
                              for (final board in foundBoards) {
                                final ip = board['ip'] as String;
                                final assignedDeviceId = assignments[ip];
                                if (assignedDeviceId != null && assignedDeviceId.isNotEmpty) {
                                  final target = devices.firstWhere((d) => d.deviceId == assignedDeviceId);
                                  await deviceService.updateDeviceSettings(
                                    deviceId: target.deviceId,
                                    newName: target.currentName,
                                    boardIp: ip,
                                  );
                                }
                              }
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Board assignments saved successfully.'),
                                    backgroundColor: ClinicalTheme.statusRunning,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      child: const Text('SAVE ASSIGNMENTS'),
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

  void _showAddDeviceDialog(BuildContext context) {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final ipController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register New Hardware Unit'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Device Hardware ID (ESP32-C3)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: idController,
                decoration: const InputDecoration(hintText: 'e.g. ESP32_05'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Hardware ID required' : null,
              ),
              const SizedBox(height: 14),
              const Text('Assigned Ward Location / Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'e.g. Floor 3 - Room 302'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Device name required' : null,
              ),
              const SizedBox(height: 14),
              const Text('Board IP (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: ipController,
                decoration: const InputDecoration(hintText: 'e.g. 192.168.1.50'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final deviceService = context.read<DeviceService>();
              await deviceService.addDevice(
                deviceId: idController.text.trim(),
                currentName: nameController.text.trim(),
                boardIp: ipController.text.trim().isEmpty ? null : ipController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('REGISTER DEVICE'),
          ),
        ],
      ),
    );
  }

  void _showEditDeviceDialog(BuildContext context, DeviceModel device) {
    final nameController = TextEditingController(text: device.currentName);
    final ipController = TextEditingController(text: device.boardIp ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${device.deviceId}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current location: "${device.currentName}". Changing location will archive the previous name into nameHistory.',
                style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text('Floor / Bed Location Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'e.g. Floor 4 - ICU Bed 08'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Name cannot be empty';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const Text('Board IP (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: ipController,
                decoration: const InputDecoration(hintText: 'e.g. 192.168.1.50'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final deviceService = context.read<DeviceService>();
              await deviceService.updateDeviceSettings(
                deviceId: device.deviceId,
                newName: nameController.text.trim(),
                boardIp: ipController.text.trim().isEmpty ? null : ipController.text.trim(),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${device.deviceId} updated successfully.'),
                    backgroundColor: ClinicalTheme.primaryBlue,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('SAVE CHANGES'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDeviceDialog(BuildContext context, DeviceModel device) {
    final hasActiveTrip = (device.activeTripId != null && device.activeTripId!.isNotEmpty) ||
        device.status.toLowerCase() == 'running' ||
        device.status.toLowerCase() == 'stuck';

    if (hasActiveTrip) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete Device'),
          content: Text(
            'Device "${device.currentName}" (${device.deviceId}) currently has an active infusion trip (${device.status.toUpperCase()}).\n\nPlease complete or finalize the infusion before deleting this device.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete Device'),
        content: Text(
          'Are you sure you want to permanently delete device "${device.currentName}" (ID: ${device.deviceId})?\n\nThis removes only the device record and will never touch infusion records in ivTrips.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final deviceService = context.read<DeviceService>();
              await deviceService.deleteDevice(device.deviceId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Device ${device.currentName} (${device.deviceId}) deleted.'),
                    backgroundColor: ClinicalTheme.statusAlarm,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ClinicalTheme.statusAlarm,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog(BuildContext context, DeviceModel device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ClinicalTheme.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location & Name History',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ClinicalTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Hardware: ${device.deviceId} • Currently: ${device.currentName}',
                        style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                      ),
                    ],
                  ),
                  StatusBadge(status: device.status),
                ],
              ),
              const Divider(height: 24, color: ClinicalTheme.borderSubtle),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ClinicalTheme.primaryBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ClinicalTheme.primaryBlue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_drop, color: ClinicalTheme.primaryBlue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CURRENT ACTIVE ASSIGNMENT',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ClinicalTheme.primaryDarkBlue),
                          ),
                          Text(
                            device.currentName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            device.lastUpdated != null
                                ? 'Active since ${DateFormat('MMM d, yyyy • HH:mm').format(device.lastUpdated!)}'
                                : 'Active',
                            style: const TextStyle(fontSize: 11, color: ClinicalTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'PREVIOUS REASSIGNMENTS (nameHistory):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ClinicalTheme.textMuted, letterSpacing: 0.4),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: device.nameHistory.isEmpty
                  ? const Center(
                      child: Text(
                        'No previous renames or floor reassignments recorded for this unit.',
                        style: TextStyle(color: ClinicalTheme.textSecondary, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: device.nameHistory.length,
                      itemBuilder: (context, index) {
                        final historyEntry = device.nameHistory.reversed.toList()[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ClinicalTheme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClinicalTheme.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.history, color: ClinicalTheme.textMuted, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      historyEntry.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'From: ${DateFormat('MMM d, yyyy HH:mm').format(historyEntry.from)} → '
                                      'To: ${historyEntry.to != null ? DateFormat('MMM d, yyyy HH:mm').format(historyEntry.to!) : "Reassigned"}',
                                      style: const TextStyle(fontSize: 11, color: ClinicalTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceService = context.watch<DeviceService>();

    return Scaffold(
      backgroundColor: ClinicalTheme.background,
      body: StreamBuilder<List<DeviceModel>>(
        stream: deviceService.streamDevices(),
        builder: (context, snap) {
          final devices = snap.data ?? [];
          final filtered = devices.where((d) {
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            return d.currentName.toLowerCase().contains(query) ||
                d.deviceId.toLowerCase().contains(query);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
                Consumer<HardwareBridgeService>(
                  builder: (context, bridge, _) {
                    final linkedDevices = devices
                        .where((d) => d.boardIp != null && d.boardIp!.trim().isNotEmpty)
                        .toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ClinicalTheme.borderSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.settings_input_antenna, color: ClinicalTheme.primaryBlue, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Hardware Gateway',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: ClinicalTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (linkedDevices.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ClinicalTheme.background,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: ClinicalTheme.borderSubtle),
                              ),
                              child: const Text(
                                'No hardware units currently configured with a Board IP.',
                                style: TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                              ),
                            )
                          else
                            ...linkedDevices.map((d) {
                              final isConnected = bridge.isRunning && bridge.isDeviceOnline(d.deviceId);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: ClinicalTheme.background,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: ClinicalTheme.borderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        d.currentName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: ClinicalTheme.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isConnected
                                            ? ClinicalTheme.statusRunning.withOpacity(0.12)
                                            : ClinicalTheme.statusAlarm.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isConnected
                                              ? ClinicalTheme.statusRunning.withOpacity(0.4)
                                              : ClinicalTheme.statusAlarm.withOpacity(0.4),
                                        ),
                                      ),
                                      child: Text(
                                        isConnected ? 'Connected' : 'Offline',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isConnected ? ClinicalTheme.statusRunning : ClinicalTheme.statusAlarm,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (bridge.isRunning) {
                                      bridge.stop();
                                    } else {
                                      bridge.start();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: bridge.isRunning ? ClinicalTheme.statusAlarm : ClinicalTheme.statusRunning,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  child: Text(bridge.isRunning ? 'STOP BRIDGE' : 'START BRIDGE'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isScanning ? null : () => _findBoards(bridge, devices),
                                  icon: _isScanning
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.search, size: 18),
                                  label: Text(_isScanning ? 'SCANNING...' : 'FIND BOARDS'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isScanning) ...[
                            const SizedBox(height: 10),
                            const LinearProgressIndicator(),
                          ],
                          const SizedBox(height: 10),
                          const Text(
                            'Alarms on a locked phone are not guaranteed on the free plan. The device buzzer is the primary safety alarm.',
                            style: TextStyle(
                              fontSize: 11,
                              color: ClinicalTheme.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search hardware ID, ward room, or floor...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: ClinicalTheme.textMuted),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDeviceDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('ADD DEVICE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClinicalTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ClinicalTheme.borderSubtle),
                  ),
                  child: Text(
                    FirebaseService.isMockFallback
                        ? 'Cannot connect to the database'
                        : 'No devices match your search criteria.',
                  ),
                )
              else
                ...filtered.map((device) {
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
                              color: ClinicalTheme.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ClinicalTheme.borderSubtle),
                            ),
                            child: const Icon(
                              Icons.router_outlined,
                              color: ClinicalTheme.deepNavy,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        device.currentName,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: ClinicalTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ClinicalTheme.borderSubtle,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          device.deviceId,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: ClinicalTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  device.nameHistory.isNotEmpty
                                      ? '${device.nameHistory.length} previous reassignment(s) logged'
                                      : 'Initial floor assignment',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                   style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    StatusBadge(status: device.status),
                                    ConnectionBadge(device: device),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),

                          IconButton(
                            icon: const Icon(Icons.history_edu_rounded, size: 20, color: ClinicalTheme.textSecondary),
                            tooltip: 'View Name & Floor History',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: () => _showHistoryDialog(context, device),
                          ),

                          Tooltip(
                            message: 'Edit Device Settings',
                            child: IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: ClinicalTheme.deepNavy),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              onPressed: () => _showEditDeviceDialog(context, device),
                            ),
                          ),

                          Tooltip(
                            message: 'Delete Device',
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: ClinicalTheme.statusAlarm),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              onPressed: () => _showDeleteDeviceDialog(context, device),
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
