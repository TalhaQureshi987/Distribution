// lib/main.dart
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'config/config.dart';

// Screens
import 'screens/common/home_screen.dart';
import 'screens/requester/request_screen.dart';
import 'screens/donor/donate_screen.dart';
import 'screens/admin/confirm_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/account/personal_info_screen.dart';
import 'screens/account/address_screen.dart';
import 'screens/account/phone_number_screen.dart';
import 'screens/account/change_password_screen.dart';
import 'screens/activity/donation_history_screen.dart';
import 'screens/activity/request_history_screen.dart';
import 'screens/activity/my_reviews_screen.dart';
import 'screens/activity/notifications_screen.dart';
import 'screens/support/help_support_screen.dart';
import 'screens/support/about_app_screen.dart';
import 'screens/support/privacy_policy_screen.dart';
import 'screens/support/terms_of_service_screen.dart';
import 'screens/delivery/delivery_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Setup API base ---
  // Option 1: USB reverse for Android device
  // adb reverse tcp:3001 tcp:3001
  // ApiService.setBase('http://127.0.0.1:3001');

  // Option 2: Direct Wi-Fi connection using PC LAN IP
ApiService.setBase('http://localhost:3001');
  print('ApiService.base => ${ApiService.base}');

  // Check login state before building the app
  await AuthService.checkLogin();

  final initialRoute = AuthService.isLoggedIn ? '/' : '/login';

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String? initialRoute;
  const MyApp({Key? key, this.initialRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final start = initialRoute ?? '/login';

    return MaterialApp(
      title: 'Zero Food Waste',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        scaffoldBackgroundColor: Colors.grey[100],
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: start,
      routes: {
        '/': (context) => HomeScreen(),
        '/donate': (context) => DonateScreen(),
        '/request': (context) => RequestScreen(),
        '/confirm': (context) => ConfirmScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/edit_profile': (context) => PersonalInfoScreen(),
        '/address': (context) => AddressScreen(),
        '/phone_number': (context) => PhoneNumberScreen(),
        '/change_password': (context) => ChangePasswordScreen(),
        '/donation_history': (context) => DonationHistoryScreen(),
        '/request_history': (context) => RequestHistoryScreen(),
        '/my_reviews': (context) => MyReviewsScreen(),
        '/notifications': (context) => NotificationsScreen(),
        '/help_support': (context) => HelpSupportScreen(),
        '/about_app': (context) => AboutAppScreen(),
        '/privacy_policy': (context) => PrivacyPolicyScreen(),
        '/terms_of_service': (context) => TermsOfServiceScreen(),
        '/delivery': (context) => DeliveryScreen(),
      },
    );
  }
}
