import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:women_safety/classes/ApiService.dart';
import 'package:women_safety/classes/CrimeData.dart';
import '../consts.dart'; // Adjust the import according to your structure

class MapPage extends StatefulWidget {
  final List<CrimeData> crimeList;

  const MapPage({Key? key, required this.crimeList}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Location _locationController = Location();
  late GoogleMapController mapController;
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  Set<Marker> _markers = {}; // To store the markers
  LatLng? _currentLocation;
  LatLng? _lastKnownLocation;
  double _currentZoomLevel = 13.0; // Default zoom level
  ApiService apiService =
      ApiService('http://10.0.2.2:5000'); // For Android emulator

  @override
  void initState() {
    super.initState();
    _fetchCrimeDataAndSetMarkers(); // Fetch data and set markers
    getLocationUpdates(); // Start tracking the user's location
  }

  // Fetch the crime data and add markers to the map
  void _fetchCrimeDataAndSetMarkers() async {
    try {
      Set<Marker> newMarkers = widget.crimeList.map((crime) {
        return Marker(
          markerId: MarkerId(crime.title), // Unique marker ID
          position: LatLng(crime.latitude, crime.longitude), // Marker position
          infoWindow: InfoWindow(
            title: crime.title,
            snippet: crime.location,
          ),
        );
      }).toSet();

      setState(() {
        _markers = newMarkers; // Update the markers on the map
      });
    } catch (e) {
      print("Error fetching crime data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crime Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchCrimeDataAndSetMarkers(); // Refresh markers on button press
            },
          ),
        ],
      ),
      body: _currentLocation == null
          ? const Center(
              child:
                  CircularProgressIndicator()) // Show loading until location is found
          : GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
                _mapController.complete(controller);
              },
              initialCameraPosition: CameraPosition(
                target: _currentLocation ??
                    LatLng(
                        19.0760, 72.8777), // Default to Mumbai or user location
                zoom: _currentZoomLevel,
              ),
              markers: _markers
                ..add(
                  Marker(
                    markerId: const MarkerId(
                        'current_location'), // Unique ID for the current location marker
                    position: _currentLocation!, // Current location position
                    infoWindow: const InfoWindow(
                        title:
                            'Current Location'), // Info for the current location marker
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor
                        .hueBlue), // Different marker color for current location
                  ),
                ),
            ),
    );
  }

  // Fetch the user's current location and move the camera
  Future<void> getLocationUpdates() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    // Check if location services are enabled, and request to enable if not
    _serviceEnabled = await _locationController.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _locationController.requestService();
      if (!_serviceEnabled) {
        return; // Exit if service is still disabled
      }
    }

    // Check and request location permission if needed
    _permissionGranted = await _locationController.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _locationController.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return; // Exit if permission is not granted
      }
    }

    // Listen for location changes
    _locationController.onLocationChanged
        .listen((LocationData currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        LatLng newLocation =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);

        // Only update if the position is significantly different
        if (_lastKnownLocation == null ||
            _calculateDistance(_lastKnownLocation!, newLocation) > 10) {
          setState(() {
            _currentLocation = newLocation;
            _lastKnownLocation = newLocation;
          });
          // Smooth camera movement to new position
          _cameraToPosition(_currentLocation!);
        }
      }
    });
  }

  // Move the camera to the current position
  Future<void> _cameraToPosition(LatLng pos) async {
    final GoogleMapController controller = await _mapController.future;
    CameraPosition _newCameraPosition = CameraPosition(
      target: pos,
      zoom: _currentZoomLevel,
    );
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(_newCameraPosition),
    );
  }

  // Function to calculate distance between two coordinates using Haversine formula
  double _calculateDistance(LatLng start, LatLng end) {
    const double p = 0.017453292519943295; // Math.PI / 180
    double h(double radians) =>
        0.5 - cos(radians) / 2; // Regular function without const
    final a = h((end.latitude - start.latitude) * p) +
        cos(start.latitude * p) *
            cos(end.latitude * p) *
            (1 - h((end.longitude - start.longitude) * p));
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
