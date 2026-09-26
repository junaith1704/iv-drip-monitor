import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/service_request_service.dart';
import '../../services/device_service.dart';
import '../../services/auth_service.dart';
import '../../models/service_request_model.dart';
import '../../models/device_model.dart';
import '../../theme/clinical_theme.dart';

class NurseServiceScreen extends StatefulWidget {
  const NurseServiceScreen({super.key});

  @override
  State<NurseServiceScreen> createState() => _NurseServiceScreenState();
}

class _NurseServiceScreenState extends State<NurseServiceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _issueController = TextEditingController();
  String? _selectedDeviceId;
  String? _selectedDeviceName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final authService = context.read<AuthService>();
    final requestService = context.read<ServiceRequestService>();
    final currentUser = authService.currentUser;

    try {
      await requestService.submitRequest(
        raisedBy: currentUser?.userId ?? 'nurse_user',
        raisedByName: currentUser?.name ?? 'Nurse',
        deviceId: _selectedDeviceId,
        deviceName: _selectedDeviceName,
        issueText: _issueController.text.trim(),
      );

      _issueController.clear();
      setState(() {
        _selectedDeviceId = null;
        _selectedDeviceName = null;
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service request submitted to biomedical engineering / admin.'),
            backgroundColor: ClinicalTheme.statusRunning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _tabController.animateTo(1); // Switch to my requests tab
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: ClinicalTheme.statusAlarm,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final requestService = context.watch<ServiceRequestService>();
    final deviceService = context.watch<DeviceService>();
    final nurseId = authService.currentUser?.userId ?? 'nurse_sarah_01';

    return Scaffold(
      backgroundColor: ClinicalTheme.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: ClinicalTheme.primaryBlue,
              unselectedLabelColor: ClinicalTheme.textSecondary,
              indicatorColor: ClinicalTheme.primaryBlue,
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  icon: Icon(Icons.add_comment_outlined, size: 20),
                  text: 'SUBMIT ISSUE',
                ),
                Tab(
                  icon: Icon(Icons.list_alt_rounded, size: 20),
                  text: 'MY SUBMITTED REQUESTS',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ClinicalTheme.borderSubtle),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Submit Form
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Report Hardware or Sensor Issue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ClinicalTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Issues reported here are routed directly to the clinical admin and biomed engineering queue.',
                            style: TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                          ),
                          const SizedBox(height: 20),

                          // Optional Device Selector
                          const Text(
                            'Associated Hardware Device (Optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ClinicalTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          StreamBuilder<List<DeviceModel>>(
                            stream: deviceService.streamDevices(),
                            builder: (context, snap) {
                              final devices = snap.data ?? [];
                              return DropdownButtonFormField<String>(
                                value: _selectedDeviceId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.devices_other, color: ClinicalTheme.textMuted),
                                  hintText: 'None / General Ward Hardware',
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('General Ward / Unspecified Device'),
                                  ),
                                  ...devices.map(
                                    (d) => DropdownMenuItem<String>(
                                      value: d.deviceId,
                                      child: Text('${d.currentName} (${d.deviceId})'),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedDeviceId = val;
                                    if (val != null) {
                                      _selectedDeviceName = devices
                                          .firstWhere((d) => d.deviceId == val)
                                          .currentName;
                                    } else {
                                      _selectedDeviceName = null;
                                    }
                                  });
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 18),

                          // Free Text Issue Field
                          const Text(
                            'Issue Description / Symptoms',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ClinicalTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _issueController,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Describe sensor anomaly, mechanical latch issue, false drop stoppage alarm, battery drain, etc...',
                              alignLabelWithHint: true,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please describe the issue in detail';
                              }
                              if (val.trim().length < 8) {
                                return 'Please provide more clinical/hardware detail';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Submit Action
                          ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitRequest,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('SUBMIT SERVICE TICKET'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClinicalTheme.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Tab 2: Nurse's Submitted Requests List
                StreamBuilder<List<ServiceRequestModel>>(
                  stream: requestService.streamNurseRequests(nurseId),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final requests = snap.data ?? [];
                    if (requests.isEmpty) {
                      return const Center(
                        child: Text(
                          'You have not submitted any service tickets yet.',
                          style: TextStyle(color: ClinicalTheme.textSecondary),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        final isResolved = req.isResolved;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isResolved
                                  ? ClinicalTheme.borderSubtle
                                  : ClinicalTheme.statusStuckBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isResolved
                                              ? ClinicalTheme.statusRunningBg
                                              : ClinicalTheme.statusStuckBg,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isResolved
                                                ? ClinicalTheme.statusRunningBorder
                                                : ClinicalTheme.statusStuckBorder,
                                          ),
                                        ),
                                        child: Text(
                                          req.status.toUpperCase(),
                                          style: TextStyle(
                                            color: isResolved
                                                ? ClinicalTheme.statusRunning
                                                : ClinicalTheme.statusStuck,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (req.deviceName != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          req.deviceName!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: ClinicalTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    DateFormat('MMM d, HH:mm').format(req.raisedAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ClinicalTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                req.issueText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: ClinicalTheme.deepNavy,
                                  height: 1.4,
                                ),
                              ),
                              if (isResolved) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: ClinicalTheme.background,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle, size: 14, color: ClinicalTheme.statusRunning),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Resolved by ${req.resolvedBy ?? "Admin"} on ${req.resolvedAt != null ? DateFormat('MMM d, HH:mm').format(req.resolvedAt!) : ""}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: ClinicalTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
