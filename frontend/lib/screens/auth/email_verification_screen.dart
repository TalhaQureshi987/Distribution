import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../payment/payment_integration_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String userId;
  final Map<String, dynamic> userData;

  const EmailVerificationScreen({
    Key? key,
    required this.email,
    required this.userId,
    required this.userData,
  }) : super(key: key);

  @override
  _EmailVerificationScreenState createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _startResendCountdown();
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _countdownTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _setupAnimation() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  void _startResendCountdown() {
    setState(() => _resendCountdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _onCodeChanged(String value, int index) {
    if (value.length == 1) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyCode();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _getCode() => _controllers.map((controller) => controller.text).join();

  void _clearCode() {
    for (var c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _shakeError() {
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  Future<void> _verifyCode() async {
    final code = _getCode();
    if (code.length != 6) {
      _showError('Please enter the complete 6-digit code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AuthService.verifyEmail(
        email: widget.email,
        code: code,
      );

      if (response['success'] == true) {
        _showSuccess('Email verified successfully!');

        Future.delayed(const Duration(seconds: 1), () {
          // Check if user role requires payment
          final userRole = widget.userData['role'] ?? '';
          final paymentRequiredRoles = ['requester', 'delivery'];
          final requiresPayment = paymentRequiredRoles.contains(
            userRole.toLowerCase(),
          );

          if (requiresPayment) {
            // Go to Stripe payment screen for requester/delivery
            Navigator.pushReplacementNamed(
              context,
              '/stripe-payment',
              arguments: {
                'userId': widget.userId,
                'amount': 500,
                'userEmail': widget.email,
                'userName': widget.userData?['name'] ?? 'User',
                'type': 'registration',
                'requestData': null,
              },
            );
          } else {
            // Navigate to document upload for identity verification
            Navigator.pushReplacementNamed(context, '/document-upload');
          }
        });
      } else {
        _showError(response['message'] ?? 'Invalid verification code');
        _clearCode();
        _shakeError();
      }
    } catch (e) {
      _showError('Verification failed. Please try again.');
      _clearCode();
      _shakeError();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRegistration(String role) async {
    try {
      final response = await AuthService.completeRegistration(
        email: widget.email,
        password: widget.userData['password'] ?? '',
        role: role,
        name: widget.userData['name'] ?? '',
        cnic: widget.userData['cnic'] ?? '',
        address: widget.userData['address'] ?? '',
        phone: widget.userData['phone'] ?? '',
      );

      if (response['success'] == true) {
        print('✅ Registration completed with role: $role');
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _showError(response['message'] ?? 'Registration completion failed');
      }
    } catch (e) {
      print('❌ Complete registration error: $e');
      _showError('Failed to complete registration. Please try again.');
    }
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0) return;

    setState(() => _isResending = true);

    try {
      await AuthService.resendVerificationCode(email: widget.email);
      _showSuccess('New verification code sent to your email');
      _startResendCountdown();
    } catch (e) {
      _showError('Failed to resend code. Please try again.');
    } finally {
      setState(() => _isResending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 80;
    final fieldWidth = (availableWidth - 25) / 6;
    final actualFieldWidth = fieldWidth.clamp(35.0, 50.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F4F4), Color(0xFFE8F5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back Button
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Center Content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Email Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B4513).withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mark_email_read,
                          size: 50,
                          color: Color(0xFF8B4513),
                        ),
                      ),
                      const SizedBox(height: 32),

                      const Text(
                        'Verify Your Email',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B4513),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'We sent a 6-digit verification code to',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      Text(
                        widget.email,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B4513),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Code Input Fields
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(6, (index) {
                                return Container(
                                  width: actualFieldWidth,
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _controllers[index].text.isNotEmpty
                                          ? const Color(0xFF8B4513)
                                          : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextFormField(
                                    controller: _controllers[index],
                                    focusNode: _focusNodes[index],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: actualFieldWidth < 40 ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF8B4513),
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(1),
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      counterText: '',
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) =>
                                        _onCodeChanged(value, index),
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B4513),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Verify Code',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Resend code
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Didn't receive the code? ",
                            style: TextStyle(color: Colors.black54),
                          ),
                          if (_resendCountdown > 0)
                            Text(
                              'Resend in ${_resendCountdown}s',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: _isResending ? null : _resendCode,
                              child: Text(
                                _isResending ? 'Sending...' : 'Resend Code',
                                style: const TextStyle(
                                  color: Color(0xFF8B4513),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
