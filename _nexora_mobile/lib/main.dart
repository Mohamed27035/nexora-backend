import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/localization/app_language.dart';
import 'core/theme/app_theme.dart';
import 'screens/admin/kyc_review_screen.dart';
import 'screens/about_screen.dart';
import 'screens/admin/user_details_screen.dart';
import 'screens/admin/users_management_screen.dart';
import 'screens/audit/audit_logs_screen.dart';
import 'screens/contact_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/kyc_screen.dart';
import 'screens/login_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/reset_password_otp_screen.dart';
import 'screens/security/security_center_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/api_service.dart';
import 'services/secure_storage_service.dart';
import 'utils/navigation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.init();
  await AppLanguage.init();

  final prefs = await SharedPreferences.getInstance();
  final hasSeenWelcome = prefs.getBool("has_seen_welcome") ?? false;
  final token = await SecureStorageService.getToken();

  runApp(
    MyApp(
      hasSeenWelcome: hasSeenWelcome,
      isLoggedIn: token != null,
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool hasSeenWelcome;
  final bool isLoggedIn;

  const MyApp({
    super.key,
    required this.hasSeenWelcome,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.notifier,
      builder: (context, language, _) {
        return MaterialApp(
          navigatorKey: NavigationService.navigatorKey,
          debugShowCheckedModeBanner: false,
          title: "Nexora",
          theme: AppTheme.light,
          locale: AppLanguage.locale,
          supportedLocales: const [
            Locale("fr"),
            Locale("ar"),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: language == "ar" ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          routes: {
            "/": (context) {
              return hasSeenWelcome ? const LoginScreen() : const WelcomeScreen();
            },
            "/register": (context) => const RegisterScreen(),
            "/forgot-password": (context) => const ForgotPasswordScreen(),
            "/reset-password-otp": (context) => const ResetPasswordOtpScreen(),
            "/otp": (context) => const OtpScreen(),
            "/login": (context) => const LoginScreen(),
            "/dashboard": (context) => const DashboardScreen(),
            "/transactions": (context) => const TransactionsScreen(),
            "/messages": (context) => const MessagesScreen(),
            "/notifications": (context) => const NotificationsScreen(),
            "/profile": (context) => const ProfileScreen(),
            "/about": (context) => const AboutScreen(),
            "/contact": (context) => const ContactScreen(),
            "/kyc": (context) => const KycScreen(),
            "/admin/users": (context) => const UsersManagementScreen(),
            "/admin/user-details": (context) => const UserDetailsScreen(),
            "/admin/kyc-review": (context) => const KycReviewScreen(),
            "/audit": (context) => const AuditLogsScreen(),
            "/reports": (context) => const ReportsScreen(),
            "/security": (context) => const SecurityCenterScreen(),
          },
        );
      },
    );
  }
}
