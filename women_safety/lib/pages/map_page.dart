import 'dart:async'; 
import 'dart:math'; // Import the dart:math library

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:women_safety/consts.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Location _locationController = Location();
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();

  static const LatLng _pGooglePlex =
      LatLng(19.046351927130566, 72.87109742372125);
  static const LatLng _pNuska = LatLng(19.036599804325423, 73.0197575589521);

  LatLng? _currentP;
  LatLng? _lastKnownLocation;
  double _currentZoomLevel = 13.0; // Default zoom level

  @override
  void initState() {
    super.initState();
    // Set location accuracy to high
    _locationController.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 5000, // Get location updates every 5 seconds
      distanceFilter: 10, // Only update if the user moves more than 10 meters
    );

    getLocationUpdates().then((_) {
      getPolylinePoints().then((coordinates) => {
            print(coordinates),
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentP == null
          ? const Center(
              child: Text("Loading..."),
            )
          : GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController.complete(controller);
              },
              initialCameraPosition: CameraPosition(
                target: _pGooglePlex,
                zoom: _currentZoomLevel, // Use the current zoom level
              ),
              onCameraMove: (CameraPosition position) {
                _currentZoomLevel = position.zoom; // Save current zoom level
              },
              markers: {
                Marker(
                  markerId: MarkerId("_currentLocation"),
                  icon: BitmapDescriptor.defaultMarker,
                  position: _currentP!,
                ),
                Marker(
                  markerId: MarkerId("_sourceLocation"),
                  icon: BitmapDescriptor.defaultMarker,
                  position: _pGooglePlex,
                ),
                Marker(
                  markerId: MarkerId("_DestinationLocation"),
                  icon: BitmapDescriptor.defaultMarker,
                  position: _pNuska,
                ),
              },
            ),
    );
  }

  Future<void> _cameraToPosition(LatLng pos) async {
    final GoogleMapController controller = await _mapController.future;
    CameraPosition _newCameraPosition = CameraPosition(
      target: pos,
      zoom: _currentZoomLevel, // Maintain the current zoom level
    );
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(_newCameraPosition),
    );
  }

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
    _locationController.onLocationChanged.listen((LocationData currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        LatLng newLocation =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);

        // Only update if the position is significantly different
        if (_lastKnownLocation == null ||
            _calculateDistance(_lastKnownLocation!, newLocation) > 10) {
          setState(() {
            _currentP = newLocation;
            _lastKnownLocation = newLocation;
          });
          // Smooth camera movement to new position
          _cameraToPosition(_currentP!);
        }
      }
    });
  }

  Future<List<LatLng>> getPolylinePoints() async {
    List<LatLng> polylineCoordinates = [];

    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: GOOGLE_MAPS_API_KEY,
      request: PolylineRequest(
        origin: PointLatLng(_pGooglePlex.latitude, _pGooglePlex.longitude),
        destination: PointLatLng(_pNuska.latitude, _pNuska.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    } else {
      // Handle the error here
      print('Error fetching polyline: ${result.errorMessage}');
    }

    return polylineCoordinates;
  }

  // Function to calculate distance between two coordinates using Haversine formula
  double _calculateDistance(LatLng start, LatLng end) {
    const double p = 0.017453292519943295; // Math.PI / 180
    const double Function(num radians) c = cos;
    final a = 0.5 - c((end.latitude - start.latitude) * p) / 2 +
        c(start.latitude * p) * c(end.latitude * p) *
            (1 - c((end.longitude - start.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}

