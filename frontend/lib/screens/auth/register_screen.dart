import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';
import '../../theme/app_theme.dart';
import '../payment/payment_confirmation_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _selectedRole = 'donor';
  bool _obscurePassword = true;
  bool _isRoleProcessing = false;
  bool _registrationInProgress = false;

  final Map<String, Map<String, dynamic>> _roleInfo = {
    'donor': {
      'title': 'Donor',
      'description': 'Donate food to help reduce waste',
      'icon': '🍽️',
      'price': 0,
      'isFree': true,
    },
    'volunteer': {
      'title': 'Volunteer',
      'description': 'Help deliver food and support the community',
      'icon': '🤝',
      'price': 0,
      'isFree': true,
    },
    'requester': {
      'title': 'Requester',
      'description': 'Request food assistance when needed',
      'icon': '🙏',
      'price': 500,
      'isFree': false,
    },
    'delivery': {
      'title': 'Delivery & Earn',
      'description': 'Earn money by delivering food',
      'icon': '🚚',
      'price': 500,
      'isFree': false,
    },
  };

  void _register() async {
    if (_formKey.currentState!.validate()) {
      if (_registrationInProgress) {
        print('⚠️ Registration already in progress - ignoring duplicate attempt');
        return;
      }
      
      setState(() {
        _isLoading = true;
        _registrationInProgress = true;
      });
      
      try {
        print('🚀 Starting registration with data:');
        print('Name: ${_nameController.text.trim()}');
        print('Email: ${_emailController.text.trim()}');
        print('Role: $_selectedRole');
        print('Phone: ${_phoneController.text.trim()}');
        print('Address: ${_addressController.text.trim()}');
        
        final response = await AuthService.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
        );

        print('📥 Registration response received:');
        print('Response keys: ${response.keys.toList()}');
        print('RequiresPayment: ${response['requiresPayment']}');
        print('Success: ${response['success']}');
        print('User data: ${response['user']}');

        if (response['requiresPayment'] == true) {
          print('💳 Paid role detected - navigating to payment');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Registration successful! Please complete payment to continue."),
            backgroundColor: Colors.green,
          ));
          
          print('🔄 Navigating to /stripe-payment with args:');
          final args = {
            'userId': response['userId'] ?? response['user']?['_id'] ?? response['user']?['id'],
            'amount': 500,
            'userEmail': _emailController.text.trim(),
            'userName': _nameController.text.trim(),
            'type': 'registration',
            'requestData': null,
          };
          print('Payment args: $args');
          
          try {
            await Navigator.pushReplacementNamed(context, '/stripe-payment', arguments: args);
            print('✅ Successfully navigated to Stripe payment screen');
          } catch (navError) {
            print('❌ Navigation to payment failed: $navError');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Navigation error: $navError'), backgroundColor: Colors.red),
            );
          }
        } else {
          print('🆓 Free role detected - navigating to email verification');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Registration successful! Please verify your email to continue."),
            backgroundColor: Colors.green,
          ));

          print('🔄 Navigating to /email-otp-verification with args:');
          final args = {
            'email': _emailController.text.trim(),
            'userId': response['userId'] ?? response['user']?['_id'] ?? response['user']?['id'],
            'userData': response['user'],
          };
          print('Email verification args: $args');
          
          try {
            await Navigator.pushReplacementNamed(context, '/email-otp-verification', arguments: args);
            print('✅ Successfully navigated to email OTP verification screen');
          } catch (navError) {
            print('❌ Navigation to email verification failed: $navError');
            print('❌ Navigation error type: ${navError.runtimeType}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Navigation error: $navError'), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        print('❌ Registration error: $e');
        print('❌ Error type: ${e.runtimeType}');
        print('❌ Error stack trace: ${StackTrace.current}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _registrationInProgress = false;
          });
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    AuthService.checkLogin().then((_) {
      if (AuthService.isLoggedIn) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => Navigator.pushReplacementNamed(context, '/'),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Your Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose your role and start making a difference',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              const Text(
                'Select Your Role',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              
              ...(_roleInfo.entries.map((entry) {
                final role = entry.key;
                final info = entry.value;
                final isSelected = _selectedRole == role;
                final isFree = info['isFree'];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedRole = role;
                        _isRoleProcessing = true;
                      });
                      
                      Future.delayed(Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() {
                            _isRoleProcessing = false;
                          });
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : Colors.white,
                      ),
                      child: Row(
                        children: [
                          _isRoleProcessing && isSelected 
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                ),
                              )
                            : Text(info['icon'], style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _isRoleProcessing && isSelected ? 'Processing...' : info['title'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? AppTheme.primaryColor : Colors.black87,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isFree ? Colors.green : Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isFree ? 'FREE' : 'PKR ${info['price']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  info['description'],
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Radio<String>(
                            value: role,
                            groupValue: _selectedRole,
                            onChanged: (value) => setState(() => _selectedRole = value!),
                            activeColor: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList()),

              const SizedBox(height: 24),

              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person, color: AppTheme.primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Please enter your name";
                  if (v.trim().length < 2) return "Name must be at least 2 characters";
                  if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) return "Name can only contain letters and spaces";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone, color: AppTheme.primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Please enter your phone number";
                  if (v.trim().length < 10) return "Phone number must be at least 10 digits";
                  if (!RegExp(r'^[0-9]+$').hasMatch(v.trim())) return "Phone number can only contain digits";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  prefixIcon: const Icon(Icons.location_on, color: AppTheme.primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Please enter your address";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email, color: AppTheme.primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Please enter your email";
                  final emailOk = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());
                  return emailOk ? null : "Enter a valid email";
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Please enter your password";
                  if (v.length < 8) return "Password must be at least 8 characters";
                  if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(v)) {
                    return "Password must contain uppercase, lowercase, and number";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _roleInfo[_selectedRole]!['isFree']
                              ? 'Create Account (Free)'
                              : 'Continue to Payment (PKR ${_roleInfo[_selectedRole]!['price']})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
