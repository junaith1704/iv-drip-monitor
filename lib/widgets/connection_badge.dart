import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../theme/clinical_theme.dart';

class ConnectionBadge extends StatelessWidget {
  final DeviceModel device;

  const ConnectionBadge({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final hasBoardIp = device.boardIp != null && device.boardIp!.trim().isNotEmpty;
    if (!hasBoardIp) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ClinicalTheme.borderSubtle,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: ClinicalTheme.borderMedium),
        ),
        child: const Text(
          'NOT LINKED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: ClinicalTheme.textSecondary,
          ),
        ),
      );
    }

    final isOnline = device.boardOnline &&
        device.lastSeen != null &&
        DateTime.now().difference(device.lastSeen!).inMinutes < 3;

    if (isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ClinicalTheme.statusRunning.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: ClinicalTheme.statusRunning.withOpacity(0.4)),
        ),
        child: const Text(
          'ONLINE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: ClinicalTheme.statusRunning,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ClinicalTheme.statusAlarm.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: ClinicalTheme.statusAlarm.withOpacity(0.4)),
        ),
        child: const Text(
          'OFFLINE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: ClinicalTheme.statusAlarm,
          ),
        ),
      );
    }
  }
}
