import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/request_service.dart';
import '../../models/request_model.dart';

class RequestScreen extends StatefulWidget {
  @override
  _RequestScreenState createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = 'Food';
  String _reason = '';
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _packagingController = TextEditingController();
  final TextEditingController _prescriptionController = TextEditingController();
  final TextEditingController _genderAgeController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  File? _requestImage;
  String? _selectedDeliveryOption;

  final List<String> categories = [
    'Food',
    'Medicine',
    'Clothes',
    'Money',
    'Other',
  ];
  final List<IconData> categoryIcons = [
    Icons.fastfood,
    Icons.medical_services,
    Icons.checkroom,
    Icons.attach_money,
    Icons.more_horiz,
  ];
  final List<String> deliveryOptions = [
    'Self Pickup',
    'Volunteer Delivery',
    'Paid Delivery',
  ];

  final double paidDeliveryFee = 2.99; // Example fee in your currency

  void _submitRequest() async {
    if (_formKey.currentState!.validate() && _selectedDeliveryOption != null) {
      try {
        if (_selectedDeliveryOption == 'Paid Delivery') {
          bool paymentSuccess = await _showPaymentDialog();
          if (!paymentSuccess) return; // Stop if payment fails or is cancelled
        }

        // Create request using backend API
        final request = await RequestService.createRequest(
          title: _selectedCategory,
          description: _reason,
          foodType: _selectedCategory,
          quantity: int.tryParse(_amountController.text) ?? 1,
          quantityUnit: _selectedCategory == 'Money' ? 'USD' : 'pieces',
          neededBy: DateTime.now().add(Duration(days: 3)), // Default needed by
          pickupAddress: _locationController.text,
          latitude: 0.0, // TODO: Get actual location
          longitude: 0.0, // TODO: Get actual location
          notes: _conditionController.text,
          isUrgent: false,
          images: _requestImage != null ? [_requestImage!.path] : [],
        );

        // Navigate to confirmation screen
        Navigator.pushNamed(
          context,
          '/confirm',
          arguments: {
            'category': _selectedCategory,
            'description': _reason,
            'expiry': _expiryController.text,
            'packaging': _packagingController.text,
            'prescription': _prescriptionController.text,
            'genderAge': _genderAgeController.text,
            'condition': _conditionController.text,
            'amount': _amountController.text,
            'contact': _contactController.text,
            'location': _locationController.text,
            'deliveryOption': _selectedDeliveryOption,
            'image': _requestImage?.path,
            'type': 'request',
          },
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (_selectedDeliveryOption == null) {
      setState(() {}); // To show the error message
      // Optionally, show a snackbar or dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a delivery option')),
      );
    }
  }

  Future<bool> _showPaymentDialog() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Paid Delivery Fee'),
                content: Text(
                  'A delivery fee of \$${paidDeliveryFee.toStringAsFixed(2)} will be charged. Proceed to payment?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Here, integrate real payment logic
                      Navigator.pop(context, true); // Simulate payment success
                    },
                    child: Text('Pay & Continue'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Request Item")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Request an Item",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 20),
                  // Category Selector
                  SizedBox(
                    height: 56,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = _selectedCategory == category;
                        final icon = categoryIcons[index];
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          margin: EdgeInsets.only(right: 14),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.brown : Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Colors.brown
                                          : Colors.grey.shade300,
                                  width: 2,
                                ),
                                boxShadow:
                                    isSelected
                                        ? [
                                          BoxShadow(
                                            color: Colors.brown.withOpacity(
                                              0.18,
                                            ),
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
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.brown,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
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
                  SizedBox(height: 20),
                  // Image Picker
                  Text("Add a Photo (optional)"),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          _requestImage != null
                              ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _requestImage!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap:
                                          () => setState(
                                            () => _requestImage = null,
                                          ),
                                      child: CircleAvatar(
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
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (picked != null) {
                                setState(() {
                                  _requestImage = File(picked.path);
                                });
                              }
                            },
                            icon: Icon(Icons.upload),
                            label: Text('Upload'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Dynamic Fields
                  if (_selectedCategory == 'Food') ...[
                    TextFormField(
                      controller: _expiryController,
                      decoration: InputDecoration(
                        labelText: 'Latest Acceptable Expiry Date',
                        hintText: 'e.g. 2024-06-20',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Enter expiry date'
                                  : null,
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (picked != null) {
                          _expiryController.text =
                              picked.toIso8601String().split('T').first;
                        }
                      },
                      readOnly: true,
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _packagingController,
                      decoration: InputDecoration(
                        labelText: 'Packaging Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Enter packaging type'
                                  : null,
                    ),
                    SizedBox(height: 10),
                  ] else if (_selectedCategory == 'Medicine') ...[
                    TextFormField(
                      controller: _expiryController,
                      decoration: InputDecoration(
                        labelText: 'Expiry Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Enter expiry date'
                                  : null,
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value:
                          _prescriptionController.text.isNotEmpty
                              ? _prescriptionController.text
                              : null,
                      items:
                          ['Yes', 'No']
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged:
                          (val) => setState(
                            () => _prescriptionController.text = val ?? '',
                          ),
                      decoration: InputDecoration(
                        labelText: 'Prescription Required?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Select prescription requirement'
                                  : null,
                    ),
                    SizedBox(height: 10),
                  ] else if (_selectedCategory == 'Clothes') ...[
                    TextFormField(
                      controller: _genderAgeController,
                      decoration: InputDecoration(
                        labelText: 'Gender/Age Group',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Enter gender/age group'
                                  : null,
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value:
                          _conditionController.text.isNotEmpty
                              ? _conditionController.text
                              : null,
                      items:
                          ['New', 'Gently Used', 'Used']
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged:
                          (val) => setState(
                            () => _conditionController.text = val ?? '',
                          ),
                      decoration: InputDecoration(
                        labelText: 'Condition',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Select condition'
                                  : null,
                    ),
                    SizedBox(height: 10),
                  ] else if (_selectedCategory == 'Money') ...[
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount Needed',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Enter amount needed'
                                  : null,
                    ),
                    SizedBox(height: 10),
                  ],
                  // Reason (always shown)
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: "Reason",
                      hintText: "Why do you need this?",
                      prefixIcon: Icon(Icons.info_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 3,
                    onChanged: (value) => _reason = value,
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? "Enter reason"
                                : null,
                  ),
                  SizedBox(height: 10),
                  // Contact and Location
                  TextFormField(
                    controller: _contactController,
                    decoration: InputDecoration(
                      labelText: 'Contact Number',
                      helperText:
                          'We will only use this to contact you about your request.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Enter contact number'
                                : null,
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Pickup/Delivery Location',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.map),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MapPicker(),
                            ),
                          );
                          if (result != null && result['address'] != null) {
                            setState(() {
                              _locationController.text = result['address'];
                            });
                          }
                        },
                      ),
                    ),
                    readOnly: true,
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Enter location'
                                : null,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Delivery Option",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Column(
                    children:
                        deliveryOptions.map((option) {
                          return RadioListTile<String>(
                            title: Text(option),
                            value: option,
                            groupValue: _selectedDeliveryOption,
                            onChanged: (value) {
                              setState(() {
                                _selectedDeliveryOption = value;
                              });
                            },
                          );
                        }).toList(),
                  ),
                  if (_selectedDeliveryOption == null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Text(
                        "Please select a delivery option",
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitRequest,
                    child: Text(
                      "Submit Request",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
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

class MapPicker extends StatefulWidget {
  @override
  _MapPickerState createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;
  String? _address;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _pickedLocation = LatLng(position.latitude, position.longitude);
    });
    _getAddress(_pickedLocation!);
  }

  Future<void> _getAddress(LatLng pos) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    );
    if (placemarks.isNotEmpty) {
      Placemark place = placemarks.first;
      setState(() {
        _address =
            "${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
      });
    }
  }

  void _onMapTap(LatLng pos) {
    setState(() {
      _pickedLocation = pos;
    });
    _getAddress(pos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pick Location')),
      body:
          _pickedLocation == null
              ? Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Expanded(
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _pickedLocation!,
                        zoom: 16,
                      ),
                      onMapCreated: (controller) => _mapController = controller,
                      onTap: _onMapTap,
                      markers:
                          _pickedLocation == null
                              ? {}
                              : {
                                Marker(
                                  markerId: MarkerId('picked'),
                                  position: _pickedLocation!,
                                ),
                              },
                    ),
                  ),
                  if (_address != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(_address!, textAlign: TextAlign.center),
                    ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'lat': _pickedLocation!.latitude,
                        'lng': _pickedLocation!.longitude,
                        'address': _address ?? '',
                      });
                    },
                    child: Text('Select This Location'),
                  ),
                  SizedBox(height: 10),
                ],
              ),
    );
  }
}
