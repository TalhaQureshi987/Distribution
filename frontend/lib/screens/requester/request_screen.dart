import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../services/payment_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../utils/location_utils.dart';
import '../../config/theme.dart';
import '../common/map_picker.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _formKey = GlobalKey<FormState>();

  // Core fields
  String _selectedCategory = 'Food';
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _streetAddressCtrl = TextEditingController();
  final TextEditingController _phoneNumberCtrl = TextEditingController();
  DateTime? _neededBy;

  // Food specific fields
  final TextEditingController _foodNameCtrl = TextEditingController();
  String _selectedFoodCategory = 'Cereals & Grains';
  final TextEditingController _foodExpiryCtrl = TextEditingController();
  final TextEditingController _foodPackagingCtrl = TextEditingController();

  // Medicine specific fields
  final TextEditingController _medicineNameCtrl = TextEditingController();
  String? _prescriptionRequired; // Yes/No
  final TextEditingController _medExpiryCtrl = TextEditingController();

  // Clothes specific fields
  final TextEditingController _clothesGenderAgeCtrl = TextEditingController();
  String? _clothesCondition; // New/Gently Used/Used

  // Other category fields
  final TextEditingController _otherDescriptionCtrl = TextEditingController();

  // Delivery
  String _deliveryOption = 'Self delivery'; // Default option
  double _paidDeliveryFee = 0; // Dynamic fee based on distance
  int _serviceCost = 100; // Service cost from backend

  // Media & geo
  File? _image;
  double? _lat = LocationUtils.centerLatitude; // Default to Central Karachi
  double? _lng = LocationUtils.centerLongitude;

  bool _submitting = false;
  bool _showMoreDetails = false;

  // Main request categories
  final List<String> _mainCategories = ['Food', 'Clothes', 'Medicine', 'Other'];

  // Food subcategories
  final List<String> _foodCategories = [
    'Cereals & Grains',
    'Rice & Flour',
    'Spices & Seasonings',
    'Fruits & Vegetables',
    'Dairy Products',
    'Meat & Poultry',
    'Seafood',
    'Bakery Items',
    'Beverages',
    'Prepared Meals',
    'Snacks & Sweets',
    'Cooking Oil & Ghee',
    'Pulses & Lentils',
    'Dry Fruits & Nuts',
    'Other Food Items',
  ];

  final List<IconData> _categoryIcons = [
    Icons.fastfood,
    Icons.checkroom,
    Icons.medical_services,
    Icons.more_horiz,
  ];

  String get _quantityLabel => 'Quantity';
  TextInputType get _quantityKeyboard => TextInputType.number;

  @override
  void initState() {
    super.initState();
    _neededBy = DateTime.now().add(const Duration(days: 7));
    // Initialize with Central Karachi for default Self delivery option
    _locationCtrl.text = 'Central Karachi';
    _loadServiceCost();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _quantityCtrl.dispose();
    _contactCtrl.dispose();
    _locationCtrl.dispose();
    _streetAddressCtrl.dispose();
    _phoneNumberCtrl.dispose();
    _foodNameCtrl.dispose();
    _foodExpiryCtrl.dispose();
    _foodPackagingCtrl.dispose();
    _medicineNameCtrl.dispose();
    _medExpiryCtrl.dispose();
    _clothesGenderAgeCtrl.dispose();
    _otherDescriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServiceCost() async {
    try {
      // Fetch service cost from backend configuration
      final response = await http.get(
        Uri.parse('${ApiService.base}/api/requests/service-cost'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await AuthService.getValidToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _serviceCost = data['serviceCost'] ?? 100;
        });
      }
    } catch (e) {
      print('Error loading service cost: $e');
      // Keep default value of 100
    }
  }

  Future<void> _pickNeededBy() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _neededBy ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _neededBy = picked);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file != null) setState(() => _image = File(file.path));
  }

  bool _validateBeforeSubmit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return false;

    if (_deliveryOption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery option')),
      );
      return false;
    }

    // Pickup address is always required
    if (_lat == null || _lng == null || _locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup address')),
      );
      return false;
    }

    if (_neededBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a needed-by date')),
      );
      return false;
    }

    // Category-specific hard requirements
    if (_selectedCategory == 'Medicine') {
      if (_medicineNameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicine name is required')),
        );
        return false;
      }
      if (_prescriptionRequired == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please specify if prescription is required'),
          ),
        );
        return false;
      }
      // Medicine expiry date validation removed - using neededBy date instead
    }
    if (_selectedCategory == 'Food') {
      if (_foodNameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Food name is required')));
        return false;
      }
      // Food category is always selected from dropdown, no need to validate
      // Food expiry date validation removed - using neededBy date instead
    }
    if (_selectedCategory == 'Clothes') {
      if (_clothesGenderAgeCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clothes gender/age is required')),
        );
        return false;
      }
      if (_clothesCondition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please specify clothes condition')),
        );
        return false;
      }
    }
    if (_selectedCategory == 'Other') {
      if (_otherDescriptionCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Other description is required')),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validateBeforeSubmit()) return;

    // Show attractive service cost confirmation dialog
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.credit_card,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Service Cost Required',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Complete your request',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            content: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Payment breakdown card
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade50, Colors.green.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.green.shade200,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.green.shade600,
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Payment Breakdown',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Service Fee
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Service Fee',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade800,
                                ),
                              ),
                              Text(
                                '${_serviceCost} PKR',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Delivery Fee (if applicable)
                        if (_deliveryOption == 'Paid Delivery' &&
                            _paidDeliveryFee > 0) ...[
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Delivery Fee',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                                Text(
                                  '${_paidDeliveryFee.toStringAsFixed(0)} PKR',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: 12),

                        // Total Amount
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              Text(
                                '${(_serviceCost + _paidDeliveryFee).toStringAsFixed(0)} PKR',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Benefits section
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Request verification & processing',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Priority support & assistance',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Secure payment processing',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
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
            actions: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Pay ${(_serviceCost + _paidDeliveryFee).toStringAsFixed(0)} PKR & Submit',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!approved) return;

    setState(() => _submitting = true);
    try {
      final quantity = int.tryParse(_quantityCtrl.text.trim()) ?? 1;

      // Calculate distance for backend
      double? distanceKm;
      if (_deliveryOption != 'Self delivery') {
        distanceKm = LocationUtils.calculateDistanceToCenter(_lat, _lng);
      } else {
        distanceKm = 0.0;
      }

      // All requests now require payment (100 PKR base + delivery fee if applicable)
      // Fetch payment preview from backend
      Map<String, dynamic>? preview;
      try {
        final paymentService = PaymentService();
        preview = await paymentService.calculatePaymentPreview(
          type: 'request',
          distance: distanceKm,
          latitude: _lat,
          longitude: _lng,
          deliveryOption: _deliveryOption,
        );

        print('💰 Payment preview received: ${preview.toString()}');

        // Ensure we have payment info for all requests
        if (preview != null && preview['success'] == true) {
          final paymentInfo = preview['paymentInfo'];
          final totalAmount = paymentInfo['totalAmount'] ?? 100.0;

          print(
            '💰 Total payment required: $totalAmount PKR for $_deliveryOption',
          );

          // ALL requests require payment (minimum 100 PKR service fee)
          if (totalAmount < 100.0) {
            throw Exception(
              'Invalid payment amount: All requests require minimum 100 PKR service fee',
            );
          }
        } else {
          throw Exception('Failed to get payment preview from server');
        }
      } catch (e) {
        print('❌ Payment preview error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment calculation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;

      // ALWAYS navigate to Stripe payment screen for ALL requests
      // (Self delivery: 100 PKR, Volunteer: 100 PKR, Paid: 100 PKR + delivery charges)
      final user = AuthService.getCurrentUser();
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User not found. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final paymentInfo = preview['paymentInfo'];
      final totalAmount = paymentInfo['totalAmount'] ?? 100.0;

      Navigator.pushNamed(
        context,
        '/stripe-payment',
        arguments: {
          'userId': user.id,
          'amount': totalAmount.toInt(),
          'userEmail': user.email,
          'userName': user.name,
          'type': 'request',
          'requestData': {
            'title': _titleCtrl.text.trim(),
            'description': _descriptionCtrl.text.trim(),
            'foodType': _selectedCategory,
            'quantity': quantity,
            'quantityUnit': _selectedCategory == 'Food'
                ? 'kg'
                : _selectedCategory == 'Medicine'
                ? 'units'
                : 'items',
            'neededBy': _neededBy?.toIso8601String(),
            'pickupAddress':
                '${_streetAddressCtrl.text.trim()}, ${_locationCtrl.text.trim()}',
            'latitude': _lat,
            'longitude': _lng,
            'deliveryOption': _deliveryOption,
            'imagePath': _image?.path,
            'distance': distanceKm,
            'paymentInfo': paymentInfo,
            'notes': _buildNotesForBackend(),
            'isUrgent': false,
            'requestFee': 100, // Mandatory 100 PKR request fee
            // Category-specific fields
            'medicineName': _selectedCategory == 'Medicine'
                ? _medicineNameCtrl.text.trim()
                : null,
            'prescriptionRequired': _selectedCategory == 'Medicine'
                ? _prescriptionRequired
                : null,
            'foodName': _selectedCategory == 'Food'
                ? _foodNameCtrl.text.trim()
                : null,
            'foodCategory': _selectedCategory == 'Food'
                ? _selectedFoodCategory
                : null,
            'clothesGenderAge': _selectedCategory == 'Clothes'
                ? _clothesGenderAgeCtrl.text.trim()
                : null,
            'clothesCondition': _selectedCategory == 'Clothes'
                ? _clothesCondition
                : null,
            'otherDescription': _selectedCategory == 'Other'
                ? _otherDescriptionCtrl.text.trim()
                : null,
          },
        },
      );
    } catch (e) {
      print('❌ Request submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _buildNotesForBackend() {
    final parts = <String>[];
    if (_selectedCategory == 'Food') {
      if (_foodNameCtrl.text.isNotEmpty)
        parts.add('Name: ${_foodNameCtrl.text.trim()}');
      parts.add('Category: $_selectedFoodCategory');
      if (_neededBy != null)
        parts.add(
          'Needed By: ${_neededBy!.toIso8601String().split('T').first}',
        );
      if (_foodPackagingCtrl.text.isNotEmpty)
        parts.add('Packaging: ${_foodPackagingCtrl.text}');
    } else if (_selectedCategory == 'Medicine') {
      if (_medicineNameCtrl.text.isNotEmpty)
        parts.add('Medicine: ${_medicineNameCtrl.text.trim()}');
      if (_neededBy != null)
        parts.add(
          'Needed By: ${_neededBy!.toIso8601String().split('T').first}',
        );
      if (_prescriptionRequired != null)
        parts.add('Prescription Required: $_prescriptionRequired');
    } else if (_selectedCategory == 'Clothes') {
      if (_clothesGenderAgeCtrl.text.isNotEmpty)
        parts.add('Gender/Age: ${_clothesGenderAgeCtrl.text}');
      if (_clothesCondition != null) parts.add('Condition: $_clothesCondition');
    } else if (_selectedCategory == 'Other') {
      if (_otherDescriptionCtrl.text.isNotEmpty)
        parts.add('Description: ${_otherDescriptionCtrl.text.trim()}');
    }
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Item'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category chips
                    Text(
                      'Category',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, i) {
                          final c = _mainCategories[i];
                          final selected = _selectedCategory == c;
                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _categoryIcons[i],
                                  size: 18,
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  c,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : AppTheme.primaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                            selected: selected,
                            selectedColor: AppTheme.primaryColor,
                            onSelected: (_) => setState(() {
                              _selectedCategory = c;
                              // reset category-specific inputs when switching
                              _foodNameCtrl.clear();
                              _foodExpiryCtrl.clear();
                              _foodPackagingCtrl.clear();
                              _medicineNameCtrl.clear();
                              _prescriptionRequired = null;
                              _medExpiryCtrl.clear();
                              _clothesGenderAgeCtrl.clear();
                              _clothesCondition = null;
                              _otherDescriptionCtrl.clear();
                            }),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: _mainCategories.length,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Request Title',
                        hintText: 'What are you requesting?',
                        prefixIcon: Icon(
                          Icons.title,
                          color: AppTheme.primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a request title'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextFormField(
                      controller: _descriptionCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Why do you need this?',
                        prefixIcon: Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      maxLines: 3,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a description'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Quantity field
                    TextFormField(
                      controller: _quantityCtrl,
                      decoration: InputDecoration(
                        labelText: _quantityLabel,
                        prefixIcon: Icon(
                          Icons.format_list_numbered,
                          color: AppTheme.primaryColor,
                        ),
                        prefixText: _selectedCategory == 'Food'
                            ? 'kg '
                            : _selectedCategory == 'Medicine'
                            ? 'units '
                            : 'items ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      keyboardType: _quantityKeyboard,
                      inputFormatters:
                          _selectedCategory == 'Food' ||
                              _selectedCategory == 'Medicine'
                          ? [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ]
                          : [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Please enter a quantity';
                        final ok =
                            _selectedCategory == 'Food' ||
                                _selectedCategory == 'Medicine'
                            ? double.tryParse(v) != null && double.parse(v) > 0
                            : int.tryParse(v) != null && int.parse(v) > 0;
                        return ok ? null : 'Please enter a valid quantity';
                      },
                    ),
                    const SizedBox(height: 12),

                    // Food name - only required for Food category
                    if (_selectedCategory == 'Food') ...[
                      TextFormField(
                        controller: _foodNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Food Name',
                          prefixIcon: Icon(
                            Icons.fastfood,
                            color: AppTheme.primaryColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter a food name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Food category
                    if (_selectedCategory == 'Food') ...[
                      DropdownButtonFormField<String>(
                        value: _selectedFoodCategory,
                        items: _foodCategories
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedFoodCategory = v!),
                        decoration: InputDecoration(
                          labelText: 'Food Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Expiry date for food/medicine
                    if (_selectedCategory == 'Food' ||
                        _selectedCategory == 'Medicine') ...[
                      InkWell(
                        onTap: _pickNeededBy,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Needed By Date',
                            prefixIcon: Icon(
                              Icons.event,
                              color: AppTheme.primaryColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            _neededBy == null
                                ? 'Select date'
                                : _neededBy!.toIso8601String().split('T').first,
                            style: TextStyle(
                              color: _neededBy == null
                                  ? Colors.grey
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Category-specific required fields
                    if (_selectedCategory == 'Medicine') ...[
                      Text(
                        'Medicine Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _medicineNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Medicine Name *',
                          hintText: 'Enter the medicine name',
                          prefixIcon: Icon(Icons.medical_services),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Medicine name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _prescriptionRequired,
                        items: const ['Yes', 'No']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _prescriptionRequired = v),
                        decoration: const InputDecoration(
                          labelText: 'Prescription Required? *',
                          prefixIcon: Icon(Icons.receipt),
                        ),
                        validator: (v) => v == null
                            ? 'Please specify if prescription is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_selectedCategory == 'Food') ...[
                      Text(
                        'Food Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _foodNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Food Name *',
                          hintText: 'Enter the food name',
                          prefixIcon: Icon(Icons.fastfood),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Food name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _DateField(
                        controller: _foodExpiryCtrl,
                        label: 'Expiry Date',
                        requiredMark: true,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _foodPackagingCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Packaging Type (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_selectedCategory == 'Clothes') ...[
                      Text(
                        'Clothes Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _clothesGenderAgeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Gender/Age Group *',
                          hintText: 'Enter the clothes gender/age group',
                          prefixIcon: Icon(Icons.checkroom),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Clothes gender/age is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _clothesCondition,
                        items: const ['New', 'Gently Used', 'Used']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _clothesCondition = v),
                        decoration: const InputDecoration(
                          labelText: 'Condition *',
                        ),
                        validator: (v) => v == null
                            ? 'Please specify clothes condition'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_selectedCategory == 'Other') ...[
                      Text(
                        'Other Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _otherDescriptionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          hintText: 'Enter the other description',
                          prefixIcon: Icon(Icons.more_horiz),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Other description is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Delivery options
                    DropdownButtonFormField<String>(
                      value: _deliveryOption,
                      decoration: InputDecoration(
                        labelText: 'Delivery Option',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(
                          Icons.local_shipping,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Self delivery',
                          child: Text('Self delivery'),
                        ),
                        DropdownMenuItem(
                          value: 'Volunteer Delivery',
                          child: Text('Volunteer Delivery'),
                        ),
                        DropdownMenuItem(
                          value: 'Paid Delivery',
                          child: Text('Paid Delivery'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _deliveryOption = value!;

                          // For self delivery, set fixed office location
                          if (value == 'Self delivery') {
                            _locationCtrl.text =
                                'Care Connect Office - Central Karachi';
                            _streetAddressCtrl.text =
                                'Care Connect Office, Main Building';
                            _lat = LocationUtils
                                .centerLatitude; // Fixed office coordinates
                            _lng = LocationUtils.centerLongitude;
                          } else {
                            // Clear location for other options to allow user selection
                            if (_deliveryOption == 'Self delivery') {
                              _locationCtrl.clear();
                              _streetAddressCtrl.clear();
                              _lat = null;
                              _lng = null;
                            }
                          }
                        });
                      },
                      validator: (value) => value == null
                          ? 'Please select delivery option'
                          : null,
                    ),

                    // Show info text for self delivery
                    if (_deliveryOption == 'Self delivery')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You will pick up your request from our Care Connect office in Central Karachi. No delivery charges apply.',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Location (map picker) - only visible when delivery selected
                    if (_deliveryOption != 'Self delivery') ...[
                      TextFormField(
                        controller: _locationCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Pickup/Delivery Location',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.map, color: AppTheme.primaryColor),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MapPicker(),
                                ),
                              );
                              if (result != null && result is Map) {
                                setState(() {
                                  _locationCtrl.text = (result['address'] ?? '')
                                      .toString();
                                  _lat = (result['lat'] as num?)?.toDouble();
                                  _lng = (result['lng'] as num?)?.toDouble();
                                });
                              }
                            },
                          ),
                        ),
                        validator: (v) {
                          if (_deliveryOption != 'Self delivery' &&
                              (v == null || v.trim().isEmpty)) {
                            return 'Please select a location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ] else
                      const SizedBox.shrink(),

                    // Street Address
                    TextFormField(
                      controller: _streetAddressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Street Address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your street address'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Phone Number
                    TextFormField(
                      controller: _phoneNumberCtrl,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Please enter a phone number';
                        final cleaned = v.replaceAll(RegExp(r'\D'), '');
                        return cleaned.length < 7
                            ? 'Please enter a valid phone number'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Optional details (collapsible)
                    Row(
                      children: [
                        Text(
                          'More details (optional)',
                          style: theme.textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(
                            () => _showMoreDetails = !_showMoreDetails,
                          ),
                          child: Text(_showMoreDetails ? 'Hide' : 'Show'),
                        ),
                      ],
                    ),
                    if (_showMoreDetails) ...[
                      // Image picker
                      Text(
                        'Add a Photo (optional)',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image preview
                          _image != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _image!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () =>
                                            setState(() => _image = null),
                                        child: const CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.red,
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey[400],
                                    size: 36,
                                  ),
                                ),
                          const SizedBox(height: 12),
                          // Buttons in flexible row
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.photo_camera),
                                label: const Text('Camera'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.upload),
                                label: const Text('Gallery'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Submit Request',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool requiredMark;
  const _DateField({
    required this.controller,
    required this.label,
    this.requiredMark = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: requiredMark ? '$label *' : label,
        prefixIcon: const Icon(Icons.event),
      ),
      validator: (v) =>
          requiredMark && (v == null || v.isEmpty) ? 'Select $label' : null,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: now,
          lastDate: now.add(const Duration(days: 365)),
        );
        if (picked != null) {
          controller.text = picked.toIso8601String().split('T').first;
        }
      },
    );
  }
}
