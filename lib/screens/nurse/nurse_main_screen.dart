import 'package:flutter/material.dart';
import '../../widgets/clinical_app_bar.dart';
import '../../theme/clinical_theme.dart';
import 'nurse_home_screen.dart';
import 'nurse_service_screen.dart';

class NurseMainScreen extends StatefulWidget {
  const NurseMainScreen({super.key});

  @override
  State<NurseMainScreen> createState() => _NurseMainScreenState();
}

class _NurseMainScreenState extends State<NurseMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClinicalTheme.background,
      appBar: ClinicalAppBar(
        title: _currentIndex == 0 ? 'Nurse Telemetry Workstation' : 'Biomedical Service Requests',
        subtitle: _currentIndex == 0 ? 'Hospital Ward Monitoring' : 'Hardware Support & Ticketing',
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          NurseHomeScreen(
            onNavigateTab: (index) => setState(() => _currentIndex = index),
          ),
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
