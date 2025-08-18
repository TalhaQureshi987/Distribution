import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import '../../services/delivery_service.dart';

class DeliveryScreen extends StatefulWidget {
  @override
  _DeliveryScreenState createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  LatLng? currentLocation;
  LatLng? selectedLocation;
  String selectedAddress = '';
  bool isLoading = true;

  Completer<GoogleMapController> _controller = Completer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        selectedLocation = currentLocation;
        isLoading = false;
      });
      _addMarker();
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _addMarker() {
    if (selectedLocation != null) {
      setState(() {
        markers.clear();
        markers.add(
          Marker(
            markerId: MarkerId('selected_location'),
            position: selectedLocation!,
            infoWindow: InfoWindow(
              title: 'Delivery Location',
              snippet:
                  selectedAddress.isNotEmpty
                      ? selectedAddress
                      : 'Selected location',
            ),
          ),
        );
      });
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      selectedLocation = location;
    });
    _addMarker();
    _getAddressFromLatLng(location);
  }

  Future<void> _getAddressFromLatLng(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          selectedAddress =
              '${place.street}, ${place.locality}, ${place.administrativeArea}';
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Delivery Location'), leading: BackButton()),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Getting your location...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Location'),
        leading: BackButton(),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: () {
              if (currentLocation != null) {
                mapController?.animateCamera(
                  CameraUpdate.newLatLng(currentLocation!),
                );
                setState(() {
                  selectedLocation = currentLocation;
                });
                _addMarker();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Map Section
          Container(
            height: 300,
            width: double.infinity,
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) async {
                _controller.complete(controller);
                mapController = controller;
                // Delay marker addition slightly
                Future.delayed(Duration(milliseconds: 300), () {
                  _addMarker();
                });
              },
              initialCameraPosition: CameraPosition(
                target: currentLocation ?? LatLng(0, 0),
                zoom: 15.0,
              ),
              markers: markers,
              onTap: _onMapTap,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
            ),
          ),
          // Delivery Options Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedAddress.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Address:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(selectedAddress),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: 16),
                  _deliveryOption(
                    'Self Pickup',
                    'Pick up the food yourself from the donor',
                    Icons.person,
                    () => _selectDeliveryOption('Self Pickup'),
                  ),
                  SizedBox(height: 12),
                  _deliveryOption(
                    'Volunteer Delivery',
                    'Request volunteer to deliver (Free)',
                    Icons.volunteer_activism,
                    () => _selectDeliveryOption('Volunteer Delivery'),
                  ),
                  SizedBox(height: 12),
                  _deliveryOption(
                    'Paid Delivery',
                    'Professional delivery service ( 5)',
                    Icons.delivery_dining,
                    () => _selectDeliveryOption('Paid Delivery'),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          selectedLocation != null
                              ? () => _confirmDelivery()
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Confirm Delivery',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliveryOption(
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.brown.withOpacity(0.1),
          child: Icon(icon, color: Colors.brown),
        ),
        title: Text(title),
        subtitle: Text(description),
        onTap: onTap,
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  void _selectDeliveryOption(String option) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delivery Option'),
            content: Text('You selected: $option'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    // Save delivery option using backend API
                    await DeliveryService.requestDelivery(
                      pickupAddress:
                          'Current Location', // TODO: Get actual pickup address
                      deliveryAddress:
                          selectedAddress.isNotEmpty
                              ? selectedAddress
                              : 'Selected Location',
                      pickupLatitude: currentLocation?.latitude ?? 0.0,
                      pickupLongitude: currentLocation?.longitude ?? 0.0,
                      deliveryLatitude: selectedLocation?.latitude ?? 0.0,
                      deliveryLongitude: selectedLocation?.longitude ?? 0.0,
                      deliveryType: option,
                      itemType: 'Food Donation',
                      itemDescription: 'Food delivery service',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Delivery option selected: $option'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save delivery option: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text('Confirm'),
              ),
            ],
          ),
    );
  }

  void _confirmDelivery() {
    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a delivery location')),
      );
      return;
    }
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Delivery'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location: ${selectedAddress.isNotEmpty ? selectedAddress : 'Selected location'}',
                ),
                SizedBox(height: 8),
                Text(
                  'Coordinates: ${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)}',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    // Process delivery confirmation using backend API
                    // TODO: Get actual delivery ID from context or parameters
                    const deliveryId = 'sample-delivery-id';
                    await DeliveryService.confirmDelivery(deliveryId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Delivery confirmed!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pop(context); // Go back to previous screen
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to confirm delivery: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text('Confirm'),
              ),
            ],
          ),
    );
  }
}
