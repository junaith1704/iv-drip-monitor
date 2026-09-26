import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/device_service.dart';
import '../../services/trip_service.dart';
import '../../models/device_model.dart';
import '../../theme/clinical_theme.dart';

class NewTripScreen extends StatefulWidget {
  final String? preselectedDeviceId;
  final bool isEmbedded;
  final VoidCallback? onTripStarted;

  const NewTripScreen({
    super.key,
    this.preselectedDeviceId,
    this.isEmbedded = false,
    this.onTripStarted,
  });

  @override
  State<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends State<NewTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _issueController = TextEditingController();

  String? _selectedDeviceId;
  String? _selectedDeviceName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDeviceId = widget.preselectedDeviceId;
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _startInfusion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDeviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an IV drip monitoring device'),
          backgroundColor: ClinicalTheme.statusAlarm,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final tripService = context.read<TripService>();
      await tripService.startTrip(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? _selectedDeviceId!,
        patientName: _patientNameController.text.trim(),
        issue: _issueController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Infusion initiated successfully for ${_patientNameController.text.trim()}',
            ),
            backgroundColor: ClinicalTheme.statusRunning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (widget.isEmbedded || !Navigator.canPop(context)) {
          _patientNameController.clear();
          _issueController.clear();
          setState(() {
            _selectedDeviceId = null;
            _selectedDeviceName = null;
            _isSubmitting = false;
          });
          widget.onTripStarted?.call();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start infusion: $e'),
            backgroundColor: ClinicalTheme.statusAlarm,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceService = context.watch<DeviceService>();

    return Scaffold(
      backgroundColor: ClinicalTheme.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('New IV Infusion Session'),
              elevation: 0,
            ),
      body: StreamBuilder<List<DeviceModel>>(
        stream: deviceService.streamDevices(),
        builder: (context, snapshot) {
          final devices = snapshot.data ?? [];
          // Prioritize idle devices, but also allow selecting current device if preselected
          final availableDevices = devices.where((d) {
            if (d.deviceId == widget.preselectedDeviceId) return true;
            return d.isIdle;
          }).toList();

          if (_selectedDeviceId != null && _selectedDeviceName == null) {
            try {
              final d = devices.firstWhere((element) => element.deviceId == _selectedDeviceId);
              _selectedDeviceName = d.currentName;
            } catch (_) {}
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clinical Guideline Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ClinicalTheme.primaryBlue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ClinicalTheme.primaryBlue.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: ClinicalTheme.primaryBlue, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Verify the drop sensor clamp is firmly seated on the drip chamber before starting telemetry tracking.',
                              style: TextStyle(
                                fontSize: 13,
                                color: ClinicalTheme.deepNavy,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 1: Device Selection
                    const Text(
                      '1. ASSIGN MONITORING HARDWARE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ClinicalTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (availableDevices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ClinicalTheme.statusStuckBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ClinicalTheme.statusStuckBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: ClinicalTheme.statusStuck),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No idle devices available right now. All units are currently running infusions.',
                                style: TextStyle(
                                  color: ClinicalTheme.statusStuck,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: availableDevices.any((d) => d.deviceId == _selectedDeviceId)
                            ? _selectedDeviceId
                            : null,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.router_outlined, color: ClinicalTheme.textMuted),
                          hintText: 'Select an available IV drip sensor unit',
                        ),
                        items: availableDevices.map((device) {
                          return DropdownMenuItem<String>(
                            value: device.deviceId,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    device.currentName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${device.deviceId})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: ClinicalTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedDeviceId = val;
                            if (val != null) {
                              _selectedDeviceName = availableDevices
                                  .firstWhere((d) => d.deviceId == val)
                                  .currentName;
                            }
                          });
                        },
                        validator: (val) => val == null ? 'Device selection is mandatory' : null,
                      ),

                    const SizedBox(height: 24),

                    // Section 2: Patient Clinical Details
                    const Text(
                      '2. PATIENT ADMISSION & INFUSION DETAILS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ClinicalTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Patient Name Field
                    const Text(
                      'Patient Full Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ClinicalTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _patientNameController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline, color: ClinicalTheme.textMuted),
                        hintText: 'e.g. Johnathan Doe (Bed 12)',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Patient name is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Condition / Prescription / Issue Field
                    const Text(
                      'Condition & Infusion Fluid / Drug',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ClinicalTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _issueController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Post-operative rehydration: 0.9% Normal Saline 1000ml @ 100ml/hr with Potassium Chloride',
                        alignLabelWithHint: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Infusion details or medical condition is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      onPressed: (_isSubmitting || availableDevices.isEmpty) ? null : _startInfusion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ClinicalTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow_rounded, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'START INFUSION TRACKING',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
