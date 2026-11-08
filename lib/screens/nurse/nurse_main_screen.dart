import 'package:flutter/material.dart';
import '../../widgets/clinical_app_bar.dart';
import '../../theme/clinical_theme.dart';
import 'nurse_home_screen.dart';
import 'nurse_service_screen.dart';
import 'new_trip_screen.dart';
import 'alarm_screen.dart';

class NurseMainScreen extends StatefulWidget {
  const NurseMainScreen({super.key});

  @override
  State<NurseMainScreen> createState() => _NurseMainScreenState();
}

class _NurseMainScreenState extends State<NurseMainScreen> {
  int _currentIndex = 0;

  static const List<String> _titles = [
    'Nurse Telemetry Workstation',
    'New Infusion',
    'Ward Alarms',
    'Biomedical Service Requests',
  ];

  static const List<String> _subtitles = [
    'Hospital Ward Monitoring',
    'Patient & Trip Entry',
    'Active Alerts',
    'Hardware Support & Ticketing',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClinicalTheme.background,
      appBar: ClinicalAppBar(
        title: _titles[_currentIndex],
        subtitle: _subtitles[_currentIndex],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          NurseHomeScreen(
            onNavigateTab: (index) => setState(() => _currentIndex = index),
          ),
          const NewTripScreen(),
          const AlarmScreen(),
          const NurseServiceScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ClinicalTheme.borderSubtle)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: Colors.white,
          indicatorColor: ClinicalTheme.primaryBlue.withOpacity(0.12),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined),
              selectedIcon: Icon(Icons.monitor_heart, color: ClinicalTheme.primaryBlue),
              label: 'Live Devices',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle, color: ClinicalTheme.primaryBlue),
              label: 'New Trip',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications, color: ClinicalTheme.primaryBlue),
              label: 'Alarms',
            ),
            NavigationDestination(
              icon: Icon(Icons.handyman_outlined),
              selectedIcon: Icon(Icons.handyman, color: ClinicalTheme.primaryBlue),
              label: 'Service Tickets',
            ),
          ],
        ),
      ),
    );
  }
}
