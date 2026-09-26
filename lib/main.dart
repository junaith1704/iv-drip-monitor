import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';
import 'services/device_service.dart';
import 'services/trip_service.dart';
import 'services/service_request_service.dart';
import 'services/notification_service.dart';
import 'theme/clinical_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/nurse/nurse_main_screen.dart';
import 'screens/nurse/alarm_screen.dart';
import 'screens/admin/admin_main_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (or clinical mock fallback if offline/pending keys)
  await FirebaseService.initialize();

  // Initialize Notification Service (FCM & Topic subscription)
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(const IvDripMonitorApp());
}

class IvDripMonitorApp extends StatefulWidget {
  const IvDripMonitorApp({super.key});

  @override
  State<IvDripMonitorApp> createState() => _IvDripMonitorAppState();
}

class _IvDripMonitorAppState extends State<IvDripMonitorApp> {
  @override
  void initState() {
    super.initState();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    NotificationService().onNotificationTapped.listen((payload) {
      debugPrint('[App] Notification tapped: device=${payload.deviceId}');
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AlarmScreen(
            deviceId: payload.deviceId,
            tripId: payload.tripId,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DeviceService()),
        ChangeNotifierProxyProvider<DeviceService, TripService>(
          create: (context) => TripService(
            deviceService: context.read<DeviceService>(),
          ),
          update: (context, deviceService, previous) =>
              previous ?? TripService(deviceService: deviceService),
        ),
        ChangeNotifierProvider(create: (_) => ServiceRequestService()),
        ChangeNotifierProvider.value(value: NotificationService()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'IV Drip Monitor',
        debugShowCheckedModeBanner: false,
        theme: ClinicalTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

/// Role-based routing gate based on Firebase Auth + Firestore users collection
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (authService.isLoading) {
      return const Scaffold(
        backgroundColor: ClinicalTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: ClinicalTheme.primaryBlue),
        ),
      );
    }

    if (!authService.isAuthenticated) {
      return const LoginScreen();
    }

    final user = authService.currentUser;
    if (user != null && user.isAdmin) {
      return const AdminMainScreen();
    }

    return const NurseMainScreen();
  }
}
