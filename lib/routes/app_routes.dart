import 'package:flutter/material.dart';

import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/onboarding/onboarding_screen.dart';
import '../presentation/screens/welcome/welcome_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/signup_screen.dart';
import '../presentation/screens/auth/forget_password_screen.dart';
import '../presentation/screens/auth/forget_password_otp_screen.dart';
import '../presentation/screens/auth/set_new_password_screen.dart';
import '../presentation/screens/auth/account_creation_otp_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/chat/chat_screen.dart';
import '../presentation/screens/cbt/cbt_plan_screen.dart';
import '../presentation/screens/cbt/progress_evaluation_screen.dart';
import '../presentation/screens/cbt/thought_record_screen.dart';
import '../presentation/screens/cbt/thinking_traps_screen.dart';
import '../presentation/screens/cbt/sleep_habits_screen.dart';
import '../presentation/screens/cbt/gratitude_log_screen.dart';
import '../presentation/screens/cbt/self_compassion_screen.dart';
import '../presentation/screens/cbt/weekly_review_screen.dart';
import '../presentation/screens/cbt/mood_check_in_screen.dart';
import '../presentation/screens/cbt/pleasant_activities_screen.dart';
import '../presentation/screens/history/history_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/settings/my_profile_screen.dart';
import '../presentation/screens/settings/personal_info_screen.dart';
import '../presentation/screens/settings/reports_screen.dart';
import '../presentation/screens/settings/individual_report_screen.dart';
import '../presentation/screens/settings/my_appointments_screen.dart';
import '../presentation/screens/settings/find_doctor_screen.dart';
import '../presentation/screens/settings/book_appointment_screen.dart';
import '../presentation/screens/settings/emergency_contacts_screen.dart';
import '../presentation/screens/settings/data_controls_screen.dart';
import '../presentation/screens/settings/subscription_screen.dart';
import '../presentation/screens/settings/help_center_screen.dart';
import '../presentation/screens/settings/terms_conditions_screen.dart';
import '../presentation/screens/settings/cbt_notification_settings_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgetPassword = '/forget-password';
  static const String forgetPasswordOtp = '/forget-password-otp';
  static const String setNewPassword = '/set-new-password';
  static const String accountCreationOtp = '/account-creation-otp';
  static const String profileCompletion = '/complete-profile';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String cbt = '/cbt';
  static const String progressEvaluation = '/progress-evaluation';
  static const String thoughtRecord = '/thought-record';
  static const String thinkingTraps = '/thinking-traps';
  static const String sleepHabits = '/sleep-habits';
  static const String gratitudeLog = '/gratitude-log';
  static const String selfCompassion = '/self-compassion';
  static const String weeklyReview = '/weekly-review';
  static const String moodCheckIn = '/mood-check-in';
  static const String pleasantActivities = '/pleasant-activities';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String myProfile = '/my-profile';
  static const String personalInfo = '/personal-info';
  static const String reports = '/reports';
  static const String individualReport = '/individual-report';
  static const String myAppointments = '/my-appointments';
  static const String findDoctor = '/find-doctor';
  static const String bookAppointment = '/book-appointment';
  static const String emergencyContacts = '/emergency-contacts';
  static const String dataControls = '/data-controls';
  static const String subscription = '/subscription';
  static const String helpCenter = '/help-center';
  static const String termsConditions = '/terms-conditions';
  static const String cbtNotificationSettings = '/cbt-notification-settings';

  static Map<String, WidgetBuilder> routes({
    required ThemeMode currentTheme,
    required void Function(ThemeMode) onThemeChanged,
  }) {
    return {
      splash: (_) => const SplashScreen(),
      onboarding: (_) => const OnboardingScreen(),
      welcome: (_) => const WelcomeScreen(),
      login: (_) => const LoginScreen(),
      signup: (_) => const SignUpScreen(),
      forgetPassword: (_) => const ForgetPasswordScreen(),
      forgetPasswordOtp: (_) => const ForgetPasswordOtpScreen(),
      setNewPassword: (_) => const SetNewPasswordScreen(),
      accountCreationOtp: (_) => const AccountCreationOtpScreen(),
      profileCompletion: (_) =>
          const PersonalInfoScreen(isProfileCompletion: true),
      home: (_) => const HomeScreen(),
      chat: (_) => const ChatScreen(),
      cbt: (_) => const CbtPlanScreen(),
      progressEvaluation: (_) => const ProgressEvaluationScreen(),
      thoughtRecord: (_) => const ThoughtRecordScreen(),
      thinkingTraps: (_) => const ThinkingTrapsScreen(),
      sleepHabits: (_) => const SleepHabitsScreen(),
      gratitudeLog: (_) => const GratitudeLogScreen(),
      selfCompassion: (_) => const SelfCompassionScreen(),
      weeklyReview: (_) => const WeeklyReviewScreen(),
      moodCheckIn: (_) => const MoodCheckInScreen(),
      pleasantActivities: (_) => const PleasantActivitiesScreen(),
      history: (_) => const HistoryScreen(),
      settings: (_) => SettingsScreen(
        currentTheme: currentTheme,
        onThemeChanged: onThemeChanged,
      ),
      myProfile: (_) => const MyProfileScreen(),
      personalInfo: (_) => const PersonalInfoScreen(),
      reports: (_) => const ReportsScreen(),
      individualReport: (_) => const IndividualReportScreen(),
      myAppointments: (_) => const MyAppointmentsScreen(),
      findDoctor: (_) => const FindDoctorScreen(),
      bookAppointment: (_) => const BookAppointmentScreen(),
      emergencyContacts: (_) => const EmergencyContactsScreen(),
      dataControls: (_) => const DataControlsScreen(),
      subscription: (_) => const SubscriptionScreen(),
      helpCenter: (_) => const HelpCenterScreen(),
      termsConditions: (_) => const TermsConditionsScreen(),
      cbtNotificationSettings: (_) => const CbtNotificationSettingsScreen(),
    };
  }
}
