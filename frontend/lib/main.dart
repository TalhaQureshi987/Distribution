// lib/main.dart
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'config/config.dart';
import 'config/theme.dart';

// Screens
import 'screens/common/splash_screen.dart';
import 'screens/common/app_intro_screen.dart';
import 'screens/requester/request_screen.dart';
import 'screens/donor/donate_screen.dart';
import 'screens/admin/confirm_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/account/personal_info_screen.dart';
import 'screens/account/address_screen.dart';
import 'screens/account/phone_number_screen.dart';
import 'screens/account/change_password_screen.dart';
import 'screens/activity/donation_history_screen.dart';
import 'screens/activity/request_history_screen.dart';
import 'screens/activity/notifications_screen.dart';
import 'screens/support/about_app_screen.dart';
import 'screens/support/privacy_policy_screen.dart';
import 'screens/support/terms_of_service_screen.dart';
import 'screens/delivery/delivery_screen.dart';
import 'screens/common/volunteer_screen_new.dart' show VolunteerScreen;
import 'screens/activity/activity_screen.dart';
import 'screens/payment/payment_confirmation_screen.dart';
import 'screens/auth/stripe_payment_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/email_otp_verification_screen.dart';
import 'screens/auth/identity_verification_screen.dart';
import 'services/dashboard_router.dart';
import 'screens/donor/donor_dashboard.dart';
import 'screens/requester/requester_dashboard.dart';
import 'screens/volunteer/volunteer_dashboard.dart';
import 'screens/delivery/delivery_dashboard.dart';
import 'screens/verification/document_upload_screen.dart';
import 'screens/verification/verification_pending_screen.dart';
import 'screens/common/volunteer_details_screen.dart';
import 'screens/donor/accepted_offers_screen.dart';
import 'screens/volunteer/accepted_volunteer_offers_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Setup API base ---
  // Using new AppConfig structure for better configuration management

  // === DEBUGGING MODE SELECTION ===
  // Choose ONE of these options:

  // Option 1: Android Emulator
  // ApiService.setBase(AppConfig.getDevUrl('android'));

  // Option 2: Physical Device with ngrok (Wireless)
  ApiService.setBase(AppConfig.getDevUrl('physical_device'));

  // Option 3: Physical Device with USB Cable (localhost)
  // ApiService.setBase(AppConfig.getDevUrl('web'));

  // Option 4: Use environment-based URL (recommended for production)
  // ApiService.setBase(AppConfig.baseUrl);

  print('ApiService base set to ${ApiService.base}');
  print('ApiService.base => ${ApiService.base}');

  // Check login state before building the app
  await AuthService.checkLogin();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zero Food Waste',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => AppLauncher(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/forgot-password': (context) => ForgotPasswordScreen(),
        '/reset-password': (context) => ResetPasswordScreen(),
        '/donate': (context) => DonateScreen(),
        '/request': (context) => RequestScreen(),
        '/confirm': (context) => ConfirmScreen(),
        '/personal-info': (context) => PersonalInfoScreen(),
        '/address': (context) => AddressScreen(),
        '/phone-number': (context) => PhoneNumberScreen(),
        '/change-password': (context) => ChangePasswordScreen(),
        '/donation-history': (context) => DonationHistoryScreen(),
        '/request-history': (context) => RequestHistoryScreen(),
        '/notifications': (context) => NotificationsScreen(),
        '/about-app': (context) => AboutAppScreen(),
        '/privacy-policy': (context) => PrivacyPolicyScreen(),
        '/terms-of-service': (context) => TermsOfServiceScreen(),
        '/delivery': (context) => DeliveryScreen(),
        '/volunteer': (context) => VolunteerScreen(),
        '/activity': (context) => ActivityScreen(),
        '/payment-integration': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return StripePaymentScreen(
            userId: args?['userId'] ?? '',
            amount: args?['amount'] ?? 500,
            userEmail: args?['email'] ?? '',
            userName: args?['userData']?['name'] ?? 'User',
            paymentType: 'registration',
            requestData: null,
          );
        },
        '/payment-confirmation': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return PaymentConfirmationScreen(
            type: args?['type'] ?? 'request',
            itemData: args,
            userId: args?['userId'],
            registrationAmount: args?['registrationAmount']?.toDouble(),
            amount: args?['amount']?.toDouble(),
          );
        },
        '/email-verification': (context) {
          final rawArgs =
              ModalRoute.of(context)!.settings.arguments as Map? ?? {};
          final Map<String, dynamic> args = Map<String, dynamic>.from(rawArgs);
          return EmailVerificationScreen(
            email: args['email'],
            userId: args['userId'],
            userData: args['userData'],
          );
        },
        '/stripe-payment': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return StripePaymentScreen(
            userId: args?['userId'] ?? '',
            amount: args?['amount'] ?? 100,
            userEmail: args?['userEmail'] ?? '',
            userName: args?['userName'] ?? '',
            paymentType: args?['type'] ?? 'registration',
            requestData: args?['requestData'],
          );
        },
        '/donor-dashboard': (context) => DonorDashboard(),
        '/requester-dashboard': (context) => RequesterDashboard(),
        '/volunteer-dashboard': (context) => VolunteerDashboard(),
        '/delivery-dashboard': (context) => DeliveryDashboard(),
        '/document-upload': (context) => DocumentUploadScreen(),
        '/verification-pending': (context) => VerificationPendingScreen(),
        '/email-otp-verification': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return EmailOTPVerificationScreen(
            email: args?['email'] ?? '',
            userId: args?['userId'] ?? '',
            userData: args?['userData'] ?? {},
          );
        },
        '/identity-verification': (context) => IdentityVerificationScreen(),
        '/volunteer-details': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return VolunteerDetailsScreen(
            volunteerData: args?['volunteerData'] ?? {},
            itemData: args?['itemData'] ?? {},
            itemType: args?['itemType'] ?? 'donation',
          );
        },
        '/accepted-offers': (context) => AcceptedOffersScreen(),
        '/accepted-volunteer-offers': (context) =>
            AcceptedVolunteerOffersScreen(),
      },
    );
  }
}

class AppLauncher extends StatefulWidget {
  @override
  _AppLauncherState createState() => _AppLauncherState();
}

class _AppLauncherState extends State<AppLauncher> {
  bool _showSplash = true;
  bool _showOnboarding = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Show splash screen for 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    // Check if user has seen onboarding
    final hasSeenOnboarding = await _checkOnboardingStatus();

    // Check login status
    await AuthService.checkLogin();

    setState(() {
      _showSplash = false;
      _showOnboarding = !hasSeenOnboarding;
      _isLoggedIn = AuthService.isLoggedIn;
    });

    // If logged in, redirect directly to dashboard (skip home screen)
    if (_isLoggedIn && hasSeenOnboarding) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardRouter.getHomeDashboard(),
        ),
      );
    }
  }

  Future<bool> _checkOnboardingStatus() async {
    // Check if user has completed onboarding
    // For now, return false to always show onboarding
    // In production, this should check SharedPreferences or similar
    return false;
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onComplete: () {
          // This will be called after splash animation completes
        },
      );
    }

    if (_showOnboarding) {
      return AppIntroScreen(onGetStarted: _onOnboardingComplete);
    }

    if (_isLoggedIn) {
      return DashboardRouter.getHomeDashboard(); // Role-based dashboard
    } else {
      return LoginScreen();
    }
  }
}
