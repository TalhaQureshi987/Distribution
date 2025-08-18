import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/donation_service.dart';

class DonateScreen extends StatefulWidget {
  @override
  _DonateScreenState createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  // Controllers and state variables
  String selectedCategory = 'Food';
  String selectedAmount = '';
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _packagingController = TextEditingController();
  final TextEditingController _prescriptionController = TextEditingController();
  final TextEditingController _genderAgeController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool isAnonymous = false;
  File? _donationImage;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _selectedDeliveryOption;
  final ImagePicker _picker = ImagePicker();

  // Constants
  final double platformFeePercentage = 0.05;
  final double deliveryFee = 2.99;

  final List<String> deliveryOptions = [
    'Self Pickup',
    'Volunteer Delivery',
    'Paid Delivery',
  ];

  final List<String> categories = ['Food', 'Medicine', 'Clothes', 'Money'];
  final List<IconData> categoryIcons = [
    Icons.restaurant,
    Icons.medical_services,
    Icons.checkroom,
    Icons.attach_money,
  ];
  final List<String> presetAmounts = ['\$10', '\$25', '\$50', '\$100', '\$250'];

  @override
  void dispose() {
    _customAmountController.dispose();
    _descriptionController.dispose();
    _expiryController.dispose();
    _packagingController.dispose();
    _prescriptionController.dispose();
    _genderAgeController.dispose();
    _conditionController.dispose();
    _contactController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        setState(() {
          _donationImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = const Color(0xFFF4F4F4);
    final Color cardColor = const Color(0xFFD6B6A4);
    final Color accentColor = Colors.brown;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Make a Donation'),
        backgroundColor: accentColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF4F4F4), Color(0xFFE8F5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18.0,
                vertical: 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Banner
                    _buildHeroBanner(cardColor),
                    const SizedBox(height: 18),

                    // Donation Category Selection
                    _sectionTitle("Donation Category"),
                    _buildCategoryCard(accentColor),
                    const SizedBox(height: 10),
                    Divider(height: 24, thickness: 1, color: Colors.grey[200]),

                    // Conditional sections based on donation type
                    selectedCategory == 'Money'
                        ? _buildMoneyDonationSection(accentColor)
                        : _buildInKindDonationSection(accentColor),

                    // Common sections
                    _buildPrivacySection(accentColor),
                    const SizedBox(height: 30),
                    if (selectedCategory != 'Money')
                      _buildDeliverySection(accentColor),
                    const SizedBox(height: 20),
                    _buildDonateButton(accentColor),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(Color cardColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardColor,
          image: DecorationImage(
            image: AssetImage('images/donations2.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              cardColor.withOpacity(0.25),
              BlendMode.darken,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Support a Cause",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black26)],
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Colors.yellow[700],
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Over \$10,000 donated this month!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black26),
                          ],
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
    );
  }

  Widget _buildCategoryCard(Color accentColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Container(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = selectedCategory == category;
              final icon = categoryIcons[index];
              return AnimatedContainer(
                duration: Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                margin: EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () => setState(() => selectedCategory = category),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? accentColor : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isSelected ? accentColor : Colors.grey.shade300,
                        width: 2,
                      ),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : [],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? Colors.white : accentColor,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMoneyDonationSection(Color accentColor) {
    return Column(
      children: [
        _sectionTitle("Donation Amount"),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: presetAmounts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == presetAmounts.length) {
                      return _buildAmountOption(
                        'Custom',
                        selectedAmount == 'Custom',
                        accentColor,
                      );
                    }
                    return _buildAmountOption(
                      presetAmounts[index],
                      selectedAmount == presetAmounts[index],
                      accentColor,
                    );
                  },
                ),
                if (selectedAmount == 'Custom') ...[
                  const SizedBox(height: 10),
                  _sectionTitle("Custom Amount"),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      child: _buildCustomAmountInput(accentColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountOption(String amount, bool isSelected, Color accentColor) {
    return GestureDetector(
      onTap:
          () => setState(() {
            selectedAmount = amount;
            if (amount == 'Custom') _customAmountController.clear();
          }),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : [],
        ),
        child: Center(
          child: Text(
            amount,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: amount == 'Custom' ? 14 : 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAmountInput(Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.attach_money, color: accentColor, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _customAmountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                prefixText: '\$',
                hintText: 'Enter amount',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInKindDonationSection(Color accentColor) {
    return Column(
      children: [
        _sectionTitle("Add a Photo (optional)"),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (_donationImage != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _donationImage!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected Image',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _donationImage = null),
                      ),
                    ],
                  ),
                  const Divider(),
                ],
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(Icons.upload),
                  label: Text(
                    _donationImage == null ? 'Upload Image' : 'Change Image',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload clear photos of your donation (max 5MB)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        _sectionTitle("Donation Details"),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              children: [
                _buildDonationDetails(accentColor),
                if (selectedCategory == 'Food') _buildFoodFields(),
                if (selectedCategory == 'Medicine') _buildMedicineFields(),
                if (selectedCategory == 'Clothes') _buildClothesFields(),
                _buildContactFields(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDonationDetails(Color accentColor) {
    IconData icon;
    Color iconColor;
    String hint;
    switch (selectedCategory) {
      case 'Food':
        icon = Icons.restaurant;
        iconColor = Colors.orange[700]!;
        hint = 'Describe the food you want to donate (type, quantity, etc.)';
        break;
      case 'Medicine':
        icon = Icons.medical_services;
        iconColor = Colors.red[700]!;
        hint = 'Describe the medicine you want to donate (name, expiry, etc.)';
        break;
      case 'Clothes':
        icon = Icons.checkroom;
        iconColor = Colors.blue[700]!;
        hint = 'Describe the clothes you want to donate (type, size, etc.)';
        break;
      default:
        icon = Icons.info_outline;
        iconColor = accentColor;
        hint = 'Tell us about your donation (optional)';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description*',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText: hint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red, width: 1.5),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        suffixIcon:
                            _descriptionController.text.isNotEmpty
                                ? IconButton(
                                  icon: Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _descriptionController.clear();
                                    });
                                  },
                                )
                                : null,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Description is required';
                        }
                        if (value.trim().length < 10) {
                          return 'Description must be at least 10 characters';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please include all relevant details',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_descriptionController.text.length}/2000',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        _descriptionController.text.length > 2000
                            ? Colors.red
                            : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodFields() {
    return Column(
      children: [
        const SizedBox(height: 10),
        TextFormField(
          controller: _expiryController,
          decoration: InputDecoration(
            labelText: 'Expiry Date',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator:
              (value) =>
                  value == null || value.isEmpty ? 'Enter expiry date' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _packagingController,
          decoration: InputDecoration(
            labelText: 'Packaging Type',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Enter packaging type'
                      : null,
        ),
      ],
    );
  }

  Widget _buildMedicineFields() {
    return Column(
      children: [
        const SizedBox(height: 10),
        TextFormField(
          controller: _expiryController,
          decoration: InputDecoration(
            labelText: 'Expiry Date',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator:
              (value) =>
                  value == null || value.isEmpty ? 'Enter expiry date' : null,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value:
              _prescriptionController.text.isNotEmpty
                  ? _prescriptionController.text
                  : null,
          items:
              [
                'Yes',
                'No',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged:
              (val) => setState(() => _prescriptionController.text = val ?? ''),
          decoration: InputDecoration(
            labelText: 'Prescription Required?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Select prescription requirement'
                      : null,
        ),
      ],
    );
  }

  Widget _buildClothesFields() {
    return Column(
      children: [
        const SizedBox(height: 10),
        TextFormField(
          controller: _genderAgeController,
          decoration: InputDecoration(
            labelText: 'Gender/Age Group',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Enter gender/age group'
                      : null,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value:
              _conditionController.text.isNotEmpty
                  ? _conditionController.text
                  : null,
          items:
              [
                'New',
                'Gently Used',
                'Used',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged:
              (val) => setState(() => _conditionController.text = val ?? ''),
          decoration: InputDecoration(
            labelText: 'Condition',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator:
              (value) =>
                  value == null || value.isEmpty ? 'Select condition' : null,
        ),
      ],
    );
  }

  Widget _buildContactFields() {
    return Column(
      children: [
        const SizedBox(height: 10),
        TextFormField(
          controller: _contactController,
          decoration: InputDecoration(
            labelText: 'Contact Number',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.phone,
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Enter contact number'
                      : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: 'Pickup Location',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Enter pickup location'
                      : null,
        ),
      ],
    );
  }

  Widget _buildPrivacySection(Color accentColor) {
    return Column(
      children: [
        _sectionTitle("Privacy"),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility_off, color: Colors.grey[600], size: 25),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Make this donation anonymous',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              softWrap: true,
                            ),
                          ),
                          SizedBox(width: 5),
                          Tooltip(
                            message:
                                'Your name will not be shown to the recipient.',
                            child: Icon(
                              Icons.info_outline,
                              color: Colors.grey[400],
                              size: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Switch(
                    value: isAnonymous,
                    onChanged: (value) => setState(() => isAnonymous = value),
                    activeColor: accentColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliverySection(Color accentColor) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Divider(height: 24, thickness: 1, color: Colors.grey[200]),
        _sectionTitle("Delivery Option"),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children:
                  deliveryOptions
                      .map(
                        (option) => RadioListTile<String>(
                          title: Text(option),
                          subtitle:
                              option == 'Paid Delivery'
                                  ? Text(
                                    'Small fee applies for logistics support',
                                  )
                                  : null,
                          value: option,
                          groupValue: _selectedDeliveryOption,
                          onChanged:
                              (value) => setState(
                                () => _selectedDeliveryOption = value,
                              ),
                          activeColor: accentColor,
                        ),
                      )
                      .toList(),
            ),
          ),
        ),
        if (_selectedDeliveryOption == null)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              "Please select a delivery option",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildDonateButton(Color accentColor) {
    return Center(
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isLoading
                      ? null
                      : () {
                        if (_formKey.currentState!.validate() ||
                            selectedCategory == 'Money') {
                          if (selectedCategory != 'Money' &&
                              _selectedDeliveryOption == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please select a delivery option',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          _showDonationConfirmation(context);
                        }
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 10,
                shadowColor: accentColor.withOpacity(0.25),
                textStyle: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child:
                  _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite, size: 28),
                          const SizedBox(width: 16),
                          Text(
                            "Donate Now",
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user, color: accentColor, size: 18),
              SizedBox(width: 6),
              Text(
                'Secure Payment',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2, top: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  void _showDonationConfirmation(BuildContext context) {
    final amount =
        selectedAmount == 'Custom'
            ? _customAmountController.text
            : selectedAmount;

    if (amount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select or enter an amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Donation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category: $selectedCategory'),
                if (selectedCategory == 'Money') ...[
                  Text('Amount: $amount'),
                  Text(
                    'Platform Fee: \$${(double.tryParse(amount.replaceAll('\$', '')) ?? 0.0 * platformFeePercentage).toStringAsFixed(2)}',
                  ),
                ] else ...[
                  if (_descriptionController.text.isNotEmpty)
                    Text('Description: ${_descriptionController.text}'),
                  Text('Delivery: $_selectedDeliveryOption'),
                  if (_selectedDeliveryOption == 'Paid Delivery')
                    Text('Delivery Fee: \$${deliveryFee.toStringAsFixed(2)}'),
                ],
                Text('Anonymous: ${isAnonymous ? "Yes" : "No"}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processDonation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                ),
                child: Text('Confirm'),
              ),
            ],
          ),
    );
  }

  Future<bool> _showMonetaryPaymentDialog(String amount) async {
    double donationAmount = double.tryParse(amount.replaceAll('\$', '')) ?? 0.0;
    double platformFee = donationAmount * platformFeePercentage;
    double totalAmount = donationAmount + platformFee;

    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Donation Payment'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Donation Amount: \$${donationAmount.toStringAsFixed(2)}',
                    ),
                    Text(
                      'Platform Fee (5%): \$${platformFee.toStringAsFixed(2)}',
                    ),
                    Divider(),
                    Text(
                      'Total Amount: \$${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The platform fee helps us maintain the service and support more people in need.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Pay & Donate'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<bool> _showDeliveryPaymentDialog() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Delivery Fee'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A delivery fee of \$${deliveryFee.toStringAsFixed(2)} will be charged for handling logistics.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This fee helps cover delivery costs and supports our volunteer network.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Pay & Continue'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  int _parseQuantity(String amountStr) {
    // remove non-digit characters, e.g. "$25" -> "25"
    final cleaned = amountStr.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cleaned) ?? 1;
  }

  Future<void> _processDonation() async {
    if (_descriptionController.text.trim().isEmpty &&
        selectedCategory != 'Money') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amountStr =
          selectedAmount == 'Custom'
              ? _customAmountController.text
              : selectedAmount;

      if (amountStr.isEmpty && selectedCategory == 'Money') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select or enter an amount'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Payment flows
      bool paymentSuccess = true;
      if (selectedCategory == 'Money') {
        paymentSuccess = await _showMonetaryPaymentDialog(amountStr);
        if (!paymentSuccess) {
          setState(() => _isLoading = false);
          return;
        }
      } else if (_selectedDeliveryOption == 'Paid Delivery') {
        paymentSuccess = await _showDeliveryPaymentDialog();
        if (!paymentSuccess) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // Quantity parsing (remove $ and non-digits)
      final qty = _parseQuantity(amountStr);

      // If we have a local File from ImagePicker, use multipart upload method:
      if (_donationImage != null) {
        final donation = await DonationService.createDonationWithFile(
          title: selectedCategory,
          description: _descriptionController.text.trim(),
          foodType: selectedCategory,
          quantity: qty,
          quantityUnit: selectedCategory == 'Money' ? 'USD' : 'pieces',
          expiryDate: DateTime.now().add(const Duration(days: 7)),
          pickupAddress: _locationController.text,
          latitude: 0.0,
          longitude: 0.0,
          notes: _packagingController.text,
          isUrgent: false,
          imageFile: _donationImage,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Donation created: ${donation.id}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // No file — use JSON method (pass remote URLs if available)
        final donation = await DonationService.createDonation(
          title: selectedCategory,
          description: _descriptionController.text.trim(),
          foodType: selectedCategory,
          quantity: qty,
          quantityUnit: selectedCategory == 'Money' ? 'USD' : 'pieces',
          expiryDate: DateTime.now().add(const Duration(days: 7)),
          pickupAddress: _locationController.text,
          latitude: 0.0,
          longitude: 0.0,
          notes: _packagingController.text,
          isUrgent: false,
          images: [], // add image URLs here if you uploaded separately
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Donation created: ${donation.id}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create donation: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
