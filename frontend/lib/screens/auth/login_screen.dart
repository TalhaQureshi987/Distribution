import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_router.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _login() async {
    print('🚀 LOGIN FUNCTION STARTED');
    if (_formKey.currentState!.validate()) {
      print('📝 Form validation passed');
      setState(() => _isLoading = true);
      try {
        print('🌐 Calling AuthService.login...');
        final loginResponse = await AuthService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        print('📨 Login response received: ${loginResponse.toString()}');

        // Check if email verification is required
        if (loginResponse.containsKey('requiresEmailVerification') && loginResponse['requiresEmailVerification'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please verify your email before logging in'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pushReplacementNamed(context, '/email-otp-verification', arguments: {
            'email': loginResponse['email'],
            'userId': loginResponse['userId'],
            'requiresEmailVerification': true,
          });
          return;
        }

        // Check if payment is required
        if (loginResponse.containsKey('requiresPayment') && loginResponse['requiresPayment'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment required to complete registration'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pushReplacementNamed(context, '/payment', arguments: {
            'userId': loginResponse['userId'],
            'paymentAmount': loginResponse['paymentAmount'],
          });
          return;
        }

        // Check login response for verification status
        if (loginResponse['success'] == true) {
          final user = loginResponse['user'];
          
          print('🔍 LOGIN SUCCESS - User data received: ${user != null ? user['name'] : 'null'}');
          print('🔍 LOGIN SUCCESS - User role: ${user?['role']}');
          print('🔍 LOGIN SUCCESS - AuthService.currentUser before navigation: ${AuthService.getCurrentUser()?.name}');
          print('🔍 LOGIN SUCCESS - AuthService.isLoggedIn: ${AuthService.isLoggedIn}');
          
          // MANDATORY: Check email verification FIRST - cannot login without it
          if (user['isEmailVerified'] != true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please verify your email before logging in'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.pushReplacementNamed(context, '/email-otp-verification', arguments: {
              'email': user['email'],
              'userId': user['_id'] ?? user['id'],
              'role': user['role'] ?? user['roles']?[0],
            });
            return;
          }

          // Verify user data is properly stored before navigation
          final currentUser = AuthService.getCurrentUser();
          if (currentUser == null) {
            print('❌ CRITICAL: AuthService.getCurrentUser() is null after successful login!');
            print('❌ Login response user data: $user');
            
            // Force refresh user data
            await AuthService.refreshUserData();
            final refreshedUser = AuthService.getCurrentUser();
            print('🔄 After refresh - AuthService.getCurrentUser(): ${refreshedUser?.name}');
          }

          // DEBUG: Show user role information before navigation
          final userForDebug = AuthService.getCurrentUser();
          print('🔍 PRE-NAVIGATION DEBUG:');
          print('🔍 User name: ${userForDebug?.name}');
          print('🔍 User role: "${userForDebug?.role}"');
          print('🔍 User role type: ${userForDebug?.role.runtimeType}');
          print('🔍 User role length: ${userForDebug?.role?.length}');
          print('🔍 User role isEmpty: ${userForDebug?.role?.isEmpty}');
          print('🔍 User role isNull: ${userForDebug?.role == null}');
          print('🔍 Full user JSON: ${userForDebug?.toJson()}');

          print('🚀 Navigating to dashboard...');
          // All verifications complete - proceed to dashboard (skip home screen)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardRouter.getHomeDashboard(),
            ),
          );
        } else {
          throw Exception(loginResponse['message'] ?? 'Login failed');
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    AuthService.checkLogin().then((_) {
      if (AuthService.isLoggedIn) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            final homeRoute = DashboardRouter.getHomeRoute();
            Navigator.pushReplacementNamed(context, homeRoute);
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F4F4), Color(0xFFE8F5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 80, color: Colors.brown),
                  SizedBox(height: 16),
                  Text(
                    "Welcome Back!",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Login to your account",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.email, color: Colors.brown),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.brown,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter your email";
                            }
                            // Basic email validation
                            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
                              return "Please enter a valid email address";
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: Icon(Icons.lock, color: Colors.brown),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.brown,
                                width: 2,
                              ),
                            ),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter your password";
                            }
                            if (value.length < 6) {
                              return "Password must be at least 6 characters";
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child:
                                _isLoading
                                    ? CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    )
                                    : Text(
                                      "Login",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                    child: Text(
                      "Forgot password?",
                      style: TextStyle(
                        color: Colors.brown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        () => Navigator.pushReplacementNamed(
                          context,
                          '/register',
                        ),
                    child: Text(
                      "Don't have an account? Register",
                      style: TextStyle(
                        color: Colors.brown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
