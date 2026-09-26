import 'package:flutter/material.dart';
import '../../widgets/clinical_app_bar.dart';
import '../../theme/clinical_theme.dart';
import 'admin_dashboard_screen.dart';
import 'device_management_screen.dart';
import 'trip_history_screen.dart';
import 'user_overview_screen.dart';
import 'admin_service_requests_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  final List<String> _titles = [
    'Hospital Telemetry Dashboard',
    'IV Hardware & Device Management',
    'Completed Infusion History (ivTrips)',
    'Clinical Staff & Nurse Overview',
    'Biomedical Engineering Service Requests',
  ];

  final List<String> _subtitles = [
    'Central Ward Telemetry & Hardware Status',
    'Hardware Unit Registry & Location History',
    'Finalized Infusion Records & Audit Trail',
    'Registered Nurses & Activity Metrics',
    'Open Issues & Maintenance Queue',
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
          AdminDashboardScreen(
            onNavigateTab: (index) => setState(() => _currentIndex = index),
          ),
          const DeviceManagementScreen(),
          const TripHistoryScreen(),
          const UserOverviewScreen(),
          const AdminServiceRequestsScreen(),
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
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: ClinicalTheme.primaryBlue),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.devices_other_outlined),
              selectedIcon: Icon(Icons.devices_other, color: ClinicalTheme.primaryBlue),
              label: 'Devices',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history, color: ClinicalTheme.primaryBlue),
              label: 'ivTrips',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people, color: ClinicalTheme.primaryBlue),
              label: 'Staff',
            ),
            NavigationDestination(
              icon: Icon(Icons.build_circle_outlined),
              selectedIcon: Icon(Icons.build_circle, color: ClinicalTheme.primaryBlue),
              label: 'Service',
            ),
          ],
        ),
      ),
    );
  }
}
