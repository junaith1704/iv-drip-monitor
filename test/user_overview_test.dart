import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:iv_drip_monitor/screens/admin/user_overview_screen.dart';
import 'package:iv_drip_monitor/services/auth_service.dart';
import 'package:iv_drip_monitor/services/device_service.dart';
import 'package:iv_drip_monitor/services/trip_service.dart';
import 'package:iv_drip_monitor/services/firebase_service.dart';

void main() {
  setUp(() {
    FirebaseService.setMockFallback(true);
  });

  const screenWidths = [
    320.0,
    360.0,
    375.0,
    390.0,
    400.0,
    412.0,
    600.0,
    700.0,
    800.0,
    1024.0,
  ];

  for (final width in screenWidths) {
    testWidgets('UserOverviewScreen renders with zero overflow on ${width}dp width', (WidgetTester tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deviceService = DeviceService();
      final tripService = TripService(deviceService: deviceService);
      final authService = AuthService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<TripService>.value(value: tripService),
          ],
          child: const MaterialApp(
            home: UserOverviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that key elements are rendered properly
      expect(find.text('Hospital Clinical Staff & Nurse Registry'), findsOneWidget);
      expect(find.byType(UserOverviewScreen), findsOneWidget);
      expect(find.text('Nurse Sarah Jenkins, RN'), findsOneWidget);
      expect(find.text('Dr. Robert Vance (Clinical Admin)'), findsOneWidget);
    });
  }
}
