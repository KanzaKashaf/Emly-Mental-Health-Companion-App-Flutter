import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';

// API FOUNDATION
import 'core/data/api/token_store.dart';
import 'core/data/api/api_client.dart';
import 'core/data/repositories/auth_repository.dart';
import 'core/data/repositories/user_repository.dart';
import 'core/data/repositories/subscription_repository.dart';
import 'core/data/repositories/chat_session_repository.dart';
import 'core/data/repositories/therapy_repository.dart';
import 'core/data/repositories/report_repository.dart';
import 'core/data/repositories/doctor_repository.dart';
import 'core/data/repositories/appointment_repository.dart';
import 'core/data/repositories/emergency_contact_repository.dart';
import 'core/data/repositories/knowledge_repository.dart';

import 'core/services/cbt_notification_service.dart';


final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

/// Simple global container
class AppServices {
  static late final TokenStore tokenStore;
  static late final ApiClient apiClient;
  static late final AuthRepository authRepository;
  static late final UserRepository userRepository;
  static late final SubscriptionRepository subscriptionRepository;
  static late final ChatSessionRepository chatSessionRepository;
  static late final TherapyRepository therapyRepository;
  static late final ReportRepository reportRepository;
  static late final DoctorRepository doctorRepository;
  static late final AppointmentRepository appointmentRepository;
  static late final EmergencyContactRepository emergencyContactRepository;
  static late final KnowledgeRepository knowledgeRepository;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Theme setup
  final prefs = await SharedPreferences.getInstance();
  final storedTheme = prefs.getString('themeMode');

  /// API setup
  AppServices.tokenStore = TokenStore();
  AppServices.apiClient = ApiClient(
    tokenStore: AppServices.tokenStore,
  );
  AppServices.authRepository =
      AuthRepository(AppServices.apiClient);
  AppServices.userRepository =
      UserRepository(AppServices.apiClient);
  AppServices.subscriptionRepository =
    SubscriptionRepository(AppServices.apiClient);
  AppServices.chatSessionRepository =
    ChatSessionRepository(AppServices.apiClient);
  AppServices.therapyRepository =
    TherapyRepository(AppServices.apiClient);
  AppServices.reportRepository =
    ReportRepository(AppServices.apiClient);
  AppServices.doctorRepository =
    DoctorRepository(AppServices.apiClient);
  AppServices.appointmentRepository =
    AppointmentRepository(AppServices.apiClient);
  AppServices.emergencyContactRepository =
    EmergencyContactRepository(AppServices.apiClient);
  AppServices.knowledgeRepository =
    KnowledgeRepository(AppServices.apiClient);

  await CbtNotificationService.instance.init(
    navigatorKey: appNavigatorKey,
  );

  runApp(MyApp(
    initialThemeMode:
        storedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light,
  ));
}

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const MyApp({
    super.key,
    required this.initialThemeMode,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CbtNotificationService.instance.handlePendingPayload();
    });
  }

  Future<void> _changeTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _themeMode = mode;
    });

    await prefs.setString(
      'themeMode',
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      navigatorKey: appNavigatorKey,

      /// Routing unchanged
      routes: AppRoutes.routes(
        currentTheme: _themeMode,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}
