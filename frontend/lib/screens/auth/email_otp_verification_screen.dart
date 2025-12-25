// -----------------------------------------------------------------------------
// Modern Email OTP Verification Screen (Fixed Overflow)
// -----------------------------------------------------------------------------
// Features:
// - 6 round OTP inputs (auto-fit, no overflow)
// - CNIC image preview
// - Modern card design with shadows
// - Countdown timer for resend
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class EmailOTPVerificationScreen extends StatefulWidget {
  final String email;
  final String userId;
  final Map<String, dynamic> userData;

  const EmailOTPVerificationScreen({
    Key? key,
    required this.email,
    required this.userId,
    required this.userData,
  }) : super(key: key);

  @override
  State<EmailOTPVerificationScreen> createState() =>
      _EmailOTPVerificationScreenState();
}

class _EmailOTPVerificationScreenState
    extends State<EmailOTPVerificationScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  bool _isLoading = false;
  bool _isResending = false;
  Timer? _timer;
  int _resendCountdown = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Don't automatically send OTP - it was already sent during registration
    // Only start the resend timer
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var c in _otpControllers) {
      c.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.sendEmailOTP(widget.email);
      
      if (response['success'] == true) {
        // Start the resend countdown
        _startResendTimer();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Verification code sent to your email'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to send verification code';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send verification code. Please try again.';
      });
      
      // Auto-clear error after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _errorMessage == 'Failed to send verification code. Please try again.') {
          setState(() => _errorMessage = null);
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyCode() async {
    final code = _otpControllers.map((c) => c.text).join();
    
    // Basic validation
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit verification code';
      });
      return;
    }

    // Validate that all characters are digits
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _errorMessage = 'Please enter only numbers';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.verifyEmailOTP(widget.email, code);
      
      if (response['success'] == true) {
        // Clear any existing error
        setState(() => _errorMessage = null);
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Email verified successfully! Please login to continue.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Navigate to login screen after successful verification
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            }
          });
        }
      } else {
        // Handle specific error cases with better messages
        String errorMsg = response['message'] ?? 'Verification failed';
        
        // Provide more specific feedback for common errors
        if (errorMsg.toLowerCase().contains('invalid')) {
          errorMsg = 'Invalid verification code. Please check and try again.';
        } else if (errorMsg.toLowerCase().contains('expired')) {
          errorMsg = 'Verification code has expired. Please request a new one.';
        } else if (errorMsg.toLowerCase().contains('not found')) {
          errorMsg = 'No verification code found. Please request a new one.';
        }
        
        setState(() => _errorMessage = errorMsg);
        
        // Clear OTP inputs if invalid code
        if (errorMsg.contains('Invalid')) {
          for (var controller in _otpControllers) {
            controller.clear();
          }
          // Focus on first input
          FocusScope.of(context).requestFocus(FocusNode());
        }
        
        // Auto-clear error after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _errorMessage == errorMsg) {
            setState(() => _errorMessage = null);
          }
        });
      }
    } catch (e) {
      String errorMsg = 'An error occurred. Please try again.';
      
      if (e.toString().contains('timeout') || e.toString().contains('connection')) {
        errorMsg = 'Connection timeout. Please check your internet and try again.';
      }
          
      setState(() => _errorMessage = errorMsg);
      
      // Auto-clear error after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _errorMessage == errorMsg) {
          setState(() => _errorMessage = null);
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _cnicPreview() {
    final frontPath = widget.userData['cnicFront'];
    final backPath = widget.userData['cnicBack'];

    if (frontPath == null && backPath == null) return const SizedBox.shrink();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (frontPath != null)
              Column(
                children: [
                  const Text('CNIC Front', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 80,
                    height: 50,
                    child: Image.network(frontPath, fit: BoxFit.cover),
                  ),
                ],
              ),
            if (backPath != null)
              Column(
                children: [
                  const Text('CNIC Back', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 80,
                    height: 50,
                    child: Image.network(backPath, fit: BoxFit.cover),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verify Email', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Section (removed logo)
              Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.email_outlined,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Email Verification',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the 6-digit code sent to',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      widget.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // OTP Input Fields
              _buildOtpInputs(),

              const SizedBox(height: 16),

              // Error Message Display
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Verify Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Resend Code
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    "Didn't receive a code? ",
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: _resendCountdown > 0 || _isResending ? null : _sendVerificationCode,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _resendCountdown > 0
                        ? Text(
                            'Resend in ${_formatTime(_resendCountdown)}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          )
                        : const Text(
                            'Resend Code',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ],
              ),
              if (_isResending)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Sending new code...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OTP Input Fields - Responsive layout
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            // Reduce margins to prevent overflow - use 30 instead of 40 for total spacing
            final fieldWidth = ((availableWidth - 30) / 6).clamp(35.0, 50.0); // 30 = 5 gaps * 6px
            
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return Container(
                  width: fieldWidth,
                  height: 55,
                  margin: const EdgeInsets.symmetric(horizontal: 2), // Reduced from 4 to 2
                  child: TextField(
                    controller: _otpControllers[index],
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fieldWidth > 40 ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    decoration: InputDecoration(
                      counterText: "",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _errorMessage = null; // Clear error when user types
                      });
                      
                      if (value.isNotEmpty) {
                        if (index < 5) {
                          FocusScope.of(context).nextFocus();
                        } else {
                          FocusScope.of(context).unfocus();
                          _verifyCode();
                        }
                      } else if (value.isEmpty && index > 0) {
                        FocusScope.of(context).previousFocus();
                      }
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}
