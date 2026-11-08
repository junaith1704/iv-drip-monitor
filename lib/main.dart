import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';
import 'services/device_service.dart';
import 'services/trip_service.dart';
import 'services/service_request_service.dart';
import 'services/notification_service.dart';
import 'services/hardware_bridge_service.dart';
import 'services/global_alarm_service.dart';
import 'theme/clinical_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/nurse/nurse_main_screen.dart';
import 'screens/nurse/alarm_screen.dart';
import 'screens/admin/admin_main_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseService.initialize();

  if (FirebaseService.isInitialized && !FirebaseService.isMockFallback) {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(const IvDripMonitorApp());
}

class IvDripMonitorApp extends StatefulWidget {
  const IvDripMonitorApp({super.key});

  @override
  State<IvDripMonitorApp> createState() => _IvDripMonitorAppState();
}

class _IvDripMonitorAppState extends State<IvDripMonitorApp> with WidgetsBindingObserver {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetInactivityTimer();
    _listenToNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      if (FirebaseService.isInitialized && !FirebaseService.isMockFallback) {
        try {
          FirebaseAuth.instance.signOut();
        } catch (_) {}
      }
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 15), _handleInactivityTimeout);
  }

  void _handleInactivityTimeout() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        final bridge = context.read<HardwareBridgeService>();
        final tripService = context.read<TripService>();
        if (bridge.isRunning || tripService.hasActiveTrip) {
          _resetInactivityTimer();
          return;
        }

        final authService = context.read<AuthService>();
        if (authService.isAuthenticated) {
          GlobalAlarmService.instance.stopListening();
          authService.signOut();
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      } catch (_) {}
    }
  }

  void _listenToNotifications() {
    NotificationService().onNotificationTapped.listen((payload) {
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
        ChangeNotifierProxyProvider<TripService, HardwareBridgeService>(
          create: (context) => HardwareBridgeService(
            tripService: context.read<TripService>(),
          ),
          update: (context, tripService, previous) =>
              previous ?? HardwareBridgeService(tripService: tripService),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'IV Drip Monitor',
        debugShowCheckedModeBanner: false,
        theme: ClinicalTheme.lightTheme,
        builder: (context, child) {
          final content = child ?? const SizedBox.shrink();
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _resetInactivityTimer(),
            onPointerMove: (_) => _resetInactivityTimer(),
            onPointerUp: (_) => _resetInactivityTimer(),
            child: FirebaseService.isMockFallback
                ? Column(
                    children: [
                      Material(
                        color: ClinicalTheme.statusAlarm,
                        child: SafeArea(
                          bottom: false,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Cannot connect to the database',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: content),
                    ],
                  )
                : content,
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final deviceService = context.read<DeviceService>();
    final tripService = context.read<TripService>();

    if (authService.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GlobalAlarmService.instance.stopListening();
      });
      return const Scaffold(
        backgroundColor: ClinicalTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: ClinicalTheme.primaryBlue),
        ),
      );
    }

    if (!authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GlobalAlarmService.instance.stopListening();
      });
      return const LoginScreen();
    }

    final user = authService.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        GlobalAlarmService.instance.startListening(
          deviceService: deviceService,
          tripService: tripService,
          navigatorKey: navigatorKey,
          isBridgeRunning: () => context.read<HardwareBridgeService>().isRunning,
        );
      });

      if (user.role == 'admin') {
        return const AdminMainScreen();
      } else if (user.role == 'nurse') {
        return const NurseMainScreen();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalAlarmService.instance.stopListening();
    });
    return const LoginScreen();
  }
}
