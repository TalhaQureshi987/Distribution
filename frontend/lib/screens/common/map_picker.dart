import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../../utils/location_utils.dart';

class MapPicker extends StatefulWidget {
  const MapPicker({super.key});
  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  LatLng? _picked;
  String? _address;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initPosition();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _initPosition() async {
    if (_isDisposed) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (_isDisposed) return;

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable location services to pick a place.'),
            ),
          );
        }
        // Default to Central Karachi if location services disabled
        if (!_isDisposed && mounted) {
          setState(
            () => _picked = LatLng(
              LocationUtils.centerLatitude,
              LocationUtils.centerLongitude,
            ),
          );
          await _reverseGeocode(_picked!);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (_isDisposed) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (_isDisposed) return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission permanently denied.'),
            ),
          );
        }
        // Default to Central Karachi if permission denied
        if (!_isDisposed && mounted) {
          setState(
            () => _picked = LatLng(
              LocationUtils.centerLatitude,
              LocationUtils.centerLongitude,
            ),
          );
          await _reverseGeocode(_picked!);
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (_isDisposed) return;

      if (mounted) {
        setState(() => _picked = LatLng(pos.latitude, pos.longitude));
        await _reverseGeocode(_picked!);
      }
    } catch (e) {
      if (_isDisposed) return;

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location error: $e')));
        // Default to Central Karachi on error
        setState(() => _picked = const LatLng(24.8607, 67.0011));
        await _reverseGeocode(_picked!);
      }
    }
  }

  Future<void> _reverseGeocode(LatLng p) async {
    if (_isDisposed) return;

    try {
      final placemarks = await placemarkFromCoordinates(
        p.latitude,
        p.longitude,
      );
      if (_isDisposed) return;

      if (placemarks.isNotEmpty && mounted) {
        final t = placemarks.first;
        setState(
          () => _address = [
            t.street,
            t.locality,
            t.administrativeArea,
            t.country,
          ].where((e) => e != null && e!.isNotEmpty).join(', '),
        );
      }
    } catch (_) {
      if (!_isDisposed && mounted) {
        setState(() => _address = 'Unknown location');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Location')),
      body: _picked == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _picked!,
                      zoom: 16,
                    ),
                    onTap: (pos) async {
                      if (!_isDisposed && mounted) {
                        setState(() => _picked = pos);
                        await _reverseGeocode(pos);
                      }
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('picked'),
                        position: _picked!,
                      ),
                    },
                  ),
                ),
                if (_address != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_address!, textAlign: TextAlign.center),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_isDisposed && _picked != null) {
                          Navigator.pop(context, {
                            'lat': _picked!.latitude,
                            'lng': _picked!.longitude,
                            'address': _address ?? '',
                          });
                        }
                      },
                      child: const Text('Select This Location'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
