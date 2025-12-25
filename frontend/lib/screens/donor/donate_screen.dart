// lib/screens/donor/DonateScreen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/donation_service.dart';
import '../../services/payment_service.dart';
import '../../models/donation_model.dart';
import '../../config/theme.dart';
import '../../utils/location_utils.dart';
import '../common/map_picker.dart';

class DonateScreen extends StatefulWidget {
  @override
  _DonateScreenState createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  final _formKey = GlobalKey<FormState>();

  // Core
  String _selectedCategory = 'Food';
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _streetAddressCtrl = TextEditingController();
  final TextEditingController _phoneNumberCtrl = TextEditingController();
  final TextEditingController _foodNameCtrl = TextEditingController();
  DateTime? _expiryDate;

  // Main donation categories
  final List<String> _mainCategories = ['Food', 'Clothes', 'Medicine', 'Other'];

  // Food subcategories
  String _selectedFoodCategory = 'Cereals & Grains';
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

  // Optional / category-specific
  final TextEditingController _foodPackagingCtrl = TextEditingController();
  final TextEditingController _medPrescriptionCtrl = TextEditingController();
  final TextEditingController _clothesGenderAgeCtrl = TextEditingController();
  String? _clothesCondition; // New/Gently Used/Used

  // Delivery
  String _deliveryOption = 'Self delivery';

  // Media & geo
  File? _image;
  double? _lat = LocationUtils.centerLatitude; // Default to Central Karachi
  double? _lng = LocationUtils.centerLongitude;

  bool _submitting = false;
  bool _showMoreDetails = false;

  @override
  void initState() {
    super.initState();
    _expiryDate = DateTime.now().add(const Duration(days: 7));
    // Initialize with Central Karachi for default Self delivery option
    _locationCtrl.text = 'Central Karachi';
  }

  final List<IconData> _categoryIcons = [
    Icons.fastfood,
    Icons.checkroom,
    Icons.medical_services,
    Icons.more_horiz,
  ];

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _quantityCtrl.dispose();
    _contactCtrl.dispose();
    _locationCtrl.dispose();
    _streetAddressCtrl.dispose();
    _phoneNumberCtrl.dispose();
    _foodNameCtrl.dispose();
    _foodPackagingCtrl.dispose();
    _medPrescriptionCtrl.dispose();
    _clothesGenderAgeCtrl.dispose();
    super.dispose();
  }

  String get _quantityLabel => _selectedCategory == 'Food'
      ? 'Weight (kg)'
      : _selectedCategory == 'Medicine'
      ? 'Quantity (units)'
      : 'Quantity (items)';
  TextInputType get _quantityKeyboard =>
      _selectedCategory == 'Food' || _selectedCategory == 'Medicine'
      ? const TextInputType.numberWithOptions(decimal: true)
      : TextInputType.number;

  Future<void> _pickExpiryDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiryDate = picked);
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

  bool get _deliverySelected =>
      _deliveryOption == 'Volunteer Delivery' ||
      _deliveryOption == 'Paid Delivery';

  bool _validateBeforeSubmit() {
    if (!_formKey.currentState!.validate()) return false;
    if (_deliverySelected && (_lat == null || _lng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location for delivery'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image for donation verification'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    print('🔍 DonateScreen: _submit called');
    if (!_validateBeforeSubmit()) {
      print('🔍 DonateScreen: Validation failed');
      return;
    }

    print('🔍 DonateScreen: Proceeding with donation submission');
    setState(() => _submitting = true);
    try {
      // Compute distance to center
      double distanceKm = LocationUtils.calculateDistanceToCenter(_lat, _lng);

      // Check if this is a free donation (Self delivery or Volunteer Delivery)
      if (_deliveryOption == 'Self delivery' ||
          _deliveryOption == 'Volunteer Delivery') {
        print('🔍 DonateScreen: Creating free donation directly');
        await _createFreeDonation(distanceKm);
        return;
      }

      // For Paid Delivery, go through payment flow
      print('💰 DonateScreen: Calculating payment for Paid Delivery');
      print('💰 DonateScreen: Distance: ${distanceKm}km');
      print('💰 DonateScreen: Coordinates: (${_lat}, ${_lng})');
      print('💰 DonateScreen: Delivery Option: $_deliveryOption');

      final preview = await PaymentService().calculatePaymentPreview(
        type: 'donate',
        distance: distanceKm,
        latitude: _lat,
        longitude: _lng,
        deliveryOption: _deliveryOption,
      );

      if (!mounted) return;

      // Validate payment preview response
      if (preview == null || preview['paymentInfo'] == null) {
        throw Exception('Invalid payment preview response from server');
      }

      print(
        '💰 DonateScreen: Payment preview received: ${preview['paymentInfo']}',
      );

      // Debug: Log the payment info being passed
      final paymentInfo = preview['paymentInfo'];
      print('💰 DonateScreen: Fixed Amount: ${paymentInfo['fixedAmount']}');
      print(
        '💰 DonateScreen: Delivery Charges: ${paymentInfo['deliveryCharges']}',
      );
      print('💰 DonateScreen: Total Amount: ${paymentInfo['totalAmount']}');

      Navigator.pushNamed(
        context,
        '/confirm',
        arguments: {
          'category': _selectedCategory,
          'description': _descriptionCtrl.text.trim(),
          'quantity': _quantityCtrl.text.trim(),
          'contact': _contactCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
          'streetAddress': _streetAddressCtrl.text.trim(),
          'phoneNumber': _phoneNumberCtrl.text.trim(),
          'deliveryOption': _deliveryOption,
          'expiryDate': _expiryDate?.toIso8601String(),
          'imagePath': _image?.path,
          'type': 'donate',
          'latitude': _lat,
          'longitude': _lng,
          'distance': distanceKm,
          'paymentInfo': preview['paymentInfo'],
          'notes': _buildNotesForBackend(),
          'foodName': _foodNameCtrl.text.trim(),
          'foodCategory': _selectedFoodCategory,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create donation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createFreeDonation(double distanceKm) async {
    try {
      print('🔍 DonateScreen: Creating free donation with DonationService');

      final title = '${_selectedCategory} Donation';
      final description = _descriptionCtrl.text.trim();
      final quantity =
          _selectedCategory == 'Food' || _selectedCategory == 'Medicine'
          ? double.parse(_quantityCtrl.text.trim()).toInt()
          : int.parse(_quantityCtrl.text.trim());
      final quantityUnit = _selectedCategory == 'Food'
          ? 'kg'
          : _selectedCategory == 'Medicine'
          ? 'units'
          : 'items';
      final expiryDate =
          _expiryDate ?? DateTime.now().add(const Duration(days: 7));
      final pickupAddress =
          '${_streetAddressCtrl.text.trim()}, ${_locationCtrl.text.trim()}';
      final notes = _buildNotesForBackend();

      print('🔍 DonateScreen: Donation data prepared:');
      print('🔍 Title: $title');
      print('🔍 Description: $description');
      print('🔍 Food Type: $_selectedCategory');
      print('🔍 Quantity: $quantity $quantityUnit');
      print('🔍 Pickup Address: $pickupAddress');
      print('🔍 Delivery Option: $_deliveryOption');
      print('🔍 Latitude: $_lat, Longitude: $_lng');

      DonationModel donation;

      if (_image != null && _image!.existsSync()) {
        print('🔍 DonateScreen: Creating donation with image file');
        donation = await DonationService.createDonationWithFile(
          title: title,
          description: description,
          foodType: _selectedCategory,
          quantity: quantity,
          quantityUnit: quantityUnit,
          expiryDate: expiryDate,
          pickupAddress: pickupAddress,
          latitude: _lat ?? LocationUtils.centerLatitude,
          longitude: _lng ?? LocationUtils.centerLongitude,
          notes: notes,
          isUrgent: false,
          imageFiles: [_image!],
          extraImageUrls: const [],
          fileFieldName: 'images',
          distance: distanceKm,
          deliveryOption: _deliveryOption,
          foodName: _foodNameCtrl.text.trim(),
          foodCategory: _selectedFoodCategory,
        );
      } else {
        print('🔍 DonateScreen: Creating donation without image');
        donation = await DonationService.createDonation(
          title: title,
          description: description,
          foodType: _selectedCategory,
          quantity: quantity,
          quantityUnit: quantityUnit,
          expiryDate: expiryDate,
          pickupAddress: pickupAddress,
          latitude: _lat ?? LocationUtils.centerLatitude,
          longitude: _lng ?? LocationUtils.centerLongitude,
          notes: notes,
          isUrgent: false,
          images: const [],
          distance: distanceKm,
          deliveryOption: _deliveryOption, // 👈 make sure this comes from UI
          foodName: _foodNameCtrl.text.trim(),
          foodCategory: _selectedFoodCategory,
        );
      }

      print('✅ DonateScreen: Donation created successfully: ${donation.id}');

      if (!mounted) return;

      // Show appropriate alert message based on delivery type
      _showDonationSubmissionAlert();
    } catch (e) {
      print('💥 DonateScreen: Error creating free donation: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to create donation: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _buildNotesForBackend() {
    final parts = <String>[];
    if (_selectedCategory == 'Food') {
      if (_expiryDate != null)
        parts.add('Expiry: ${_expiryDate!.toIso8601String().split('T').first}');
      if (_foodPackagingCtrl.text.isNotEmpty)
        parts.add('Packaging: ${_foodPackagingCtrl.text}');
    } else if (_selectedCategory == 'Medicine') {
      if (_expiryDate != null)
        parts.add('Expiry: ${_expiryDate!.toIso8601String().split('T').first}');
      if (_medPrescriptionCtrl.text.isNotEmpty)
        parts.add('Prescription: ${_medPrescriptionCtrl.text}');
    } else if (_selectedCategory == 'Clothes') {
      if (_clothesGenderAgeCtrl.text.isNotEmpty)
        parts.add('Gender/Age: ${_clothesGenderAgeCtrl.text}');
      if (_clothesCondition != null) parts.add('Condition: $_clothesCondition');
    }
    return parts.join(' | ');
  }

  void _showDonationSubmissionAlert() {
    final isSelfDelivery = _deliveryOption == 'Self delivery';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelfDelivery
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isSelfDelivery
                      ? Icons.directions_car
                      : Icons.volunteer_activism,
                  color: isSelfDelivery ? Colors.blue : Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Donation Submitted Successfully!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelfDelivery
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelfDelivery
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: isSelfDelivery ? Colors.blue : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isSelfDelivery
                                ? 'Self Delivery Selected'
                                : 'Volunteer Delivery Selected',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelfDelivery
                                  ? Colors.blue
                                  : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSelfDelivery
                          ? 'Your donation has been submitted successfully! You will deliver this donation to our Care Connect office in Central Karachi. Admin will verify your donation and you will receive email notification once approved.'
                          : 'Your donation has been submitted successfully! A volunteer will be assigned to pick up your donation as soon as possible. You will receive email notifications throughout the process.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to donor dashboard instead of logout
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/donor-dashboard',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Go to Dashboard'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donate Item'),
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
                              _foodPackagingCtrl.clear();
                              _medPrescriptionCtrl.clear();
                              _clothesGenderAgeCtrl.clear();
                              _clothesCondition = null;
                              _expiryDate = null;
                            }),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: _mainCategories.length,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'What are you donating?',
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
                        onTap: _pickExpiryDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Expiry Date',
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
                            _expiryDate == null
                                ? 'Select date'
                                : _expiryDate!
                                      .toIso8601String()
                                      .split('T')
                                      .first,
                            style: TextStyle(
                              color: _expiryDate == null
                                  ? Colors.grey
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
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
                                  'You will deliver this donation to our Care Connect office in Central Karachi. No delivery charges apply.',
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
                    if (_deliverySelected &&
                        _deliveryOption != 'Self delivery') ...[
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
                          if (_deliverySelected &&
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(
                            () => _showMoreDetails = !_showMoreDetails,
                          ),
                          child: Text(
                            _showMoreDetails ? 'Hide' : 'Show',
                            style: TextStyle(color: AppTheme.primaryColor),
                          ),
                        ),
                      ],
                    ),
                    if (_showMoreDetails) ...[
                      if (_selectedCategory == 'Food') ...[
                        TextFormField(
                          controller: _foodPackagingCtrl,
                          decoration: InputDecoration(
                            labelText: 'Packaging Type (optional)',
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
                      if (_selectedCategory == 'Medicine') ...[
                        TextFormField(
                          controller: _medPrescriptionCtrl,
                          decoration: InputDecoration(
                            labelText: 'Prescription Details (optional)',
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
                      if (_selectedCategory == 'Clothes') ...[
                        TextFormField(
                          controller: _clothesGenderAgeCtrl,
                          decoration: InputDecoration(
                            labelText: 'Gender/Age Group (optional)',
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
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _clothesCondition,
                          items: const ['New', 'Gently Used', 'Used']
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _clothesCondition = v),
                          decoration: InputDecoration(
                            labelText: 'Condition (optional)',
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

                      // Image picker
                      Text(
                        'Add a Photo (Required)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.primaryTextColor,
                        ),
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
                                    border: Border.all(
                                      color: _image == null
                                          ? Colors.red.withOpacity(0.5)
                                          : Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey[400],
                                    size: 36,
                                  ),
                                ),
                          const SizedBox(height: 8),
                          // Required field indicator
                          if (_image == null)
                            Text(
                              '* Photo is required for donation verification',
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
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
                                icon: Icon(
                                  Icons.photo_camera,
                                  color: AppTheme.primaryColor,
                                ),
                                label: Text(
                                  'Camera',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppTheme.primaryColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.upload),
                                label: const Text('Gallery'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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
                                'Submit Donation',
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
