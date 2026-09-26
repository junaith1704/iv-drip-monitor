import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/device_service.dart';
import '../../models/device_model.dart';
import '../../theme/clinical_theme.dart';
import '../../widgets/status_badge.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddDeviceDialog(BuildContext context) {
    final idController = TextEditingController();
    final nameController = TextEditingController();
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
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('REGISTER DEVICE'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, DeviceModel device) {
    final nameController = TextEditingController(text: device.currentName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reassign / Rename ${device.deviceId}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current location: "${device.currentName}". Renaming this unit will archive this name into the permanent nameHistory audit trail with timestamps.',
                style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text('New Floor / Bed Location Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'e.g. Floor 4 - ICU Bed 08'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Name cannot be empty';
                  if (val.trim() == device.currentName) return 'Must be different from current name';
                  return null;
                },
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
              await deviceService.renameDevice(device.deviceId, nameController.text.trim());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${device.deviceId} reassigned to ${nameController.text.trim()}'),
                    backgroundColor: ClinicalTheme.primaryBlue,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('SAVE & UPDATE HISTORY'),
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

              // Current Active Assignment Card
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
                        // Show most recent previous name first
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
              // Search & Add Bar
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

              // Devices List
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ClinicalTheme.borderSubtle),
                  ),
                  child: const Text('No devices match your search criteria.'),
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
                                    Text(
                                      device.currentName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: ClinicalTheme.textPrimary,
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
                                          fontWeight: FontWeight.w600,
                                          color: ClinicalTheme.textSecondary,
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
                                  style: const TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: device.status),
                          const SizedBox(width: 12),

                          // View Name History Button
                          IconButton(
                            icon: const Icon(Icons.history_edu_rounded, size: 20, color: ClinicalTheme.textSecondary),
                            tooltip: 'View Name & Floor History',
                            onPressed: () => _showHistoryDialog(context, device),
                          ),

                          // Rename / Floor Reassignment Button
                          ElevatedButton.icon(
                            onPressed: () => _showRenameDialog(context, device),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('RENAME'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClinicalTheme.background,
                              foregroundColor: ClinicalTheme.deepNavy,
                              elevation: 0,
                              side: const BorderSide(color: ClinicalTheme.borderMedium),
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
