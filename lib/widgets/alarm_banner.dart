import 'package:flutter/material.dart';
import '../theme/clinical_theme.dart';
import '../models/device_model.dart';

class AlarmBanner extends StatelessWidget {
  final List<DeviceModel> stuckDevices;
  final Function(DeviceModel) onTapDevice;

  const AlarmBanner({
    super.key,
    required this.stuckDevices,
    required this.onTapDevice,
  });

  @override
  Widget build(BuildContext context) {
    if (stuckDevices.isEmpty) return const SizedBox.shrink();

    final device = stuckDevices.first;
    final totalStuck = stuckDevices.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ClinicalTheme.statusAlarmBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ClinicalTheme.statusAlarm, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ClinicalTheme.statusAlarm.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ClinicalTheme.statusAlarm.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: ClinicalTheme.statusAlarm,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'FLOW STOPPAGE DETECTED',
                      style: TextStyle(
                        color: ClinicalTheme.statusAlarm,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (totalStuck > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ClinicalTheme.statusAlarm,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalStuck DEVICES',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.currentName} (${device.deviceId}) drop sensor interrupted.',
                  style: const TextStyle(
                    color: ClinicalTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => onTapDevice(device),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClinicalTheme.statusAlarm,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text(
              'VIEW ALARM',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
