import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Simple Kalman filter for 1D smoothing
class _KalmanFilter {
  double _estimate;
  double _errorEstimate;
  final double _errorMeasurement;
  final double _processNoise;

  _KalmanFilter({
    double initialEstimate = 0,
    double errorEstimate = 1,
    double errorMeasurement = 1,
    double processNoise = 0.01,
  })  : _estimate = initialEstimate,
        _errorEstimate = errorEstimate,
        _errorMeasurement = errorMeasurement,
        _processNoise = processNoise;

  double filter(double measurement) {
    // Prediction update
    _errorEstimate += _processNoise;

    // Measurement update
    final kalmanGain = _errorEstimate / (_errorEstimate + _errorMeasurement);
    _estimate = _estimate + kalmanGain * (measurement - _estimate);
    _errorEstimate = (1 - kalmanGain) * _errorEstimate;

    return _estimate;
  }

  void reset(double value) {
    _estimate = value;
    _errorEstimate = 1;
  }
}

/// GPS Location tracking service with jitter filtering and accuracy improvements
class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final _locationController = StreamController<LatLng>.broadcast();
  
  Stream<LatLng> get locationStream => _locationController.stream;
  
  LatLng? _lastPosition;
  LatLng? _lastValidPosition;
  DateTime? _lastPositionTime;
  double? _lastAccuracy;
  
  LatLng? get lastPosition => _lastValidPosition ?? _lastPosition;
  double? get lastAccuracy => _lastAccuracy;

  // Kalman filters for lat/lng smoothing
  _KalmanFilter? _latFilter;
  _KalmanFilter? _lngFilter;

  // Configuration constants
  static const double _minAccuracyThreshold = 25.0; // meters - ignore readings above this
  static const double _goodAccuracyThreshold = 10.0; // meters - high quality reading
  static const double _minMovementThreshold = 2.0; // meters - ignore tiny movements
  static const double _maxSpeedMps = 50.0; // m/s (~180 km/h) - max reasonable speed
  static const double _runningMaxSpeedMps = 12.0; // m/s (~43 km/h) - max for running
  static const double _walkingMaxSpeedMps = 3.0; // m/s (~11 km/h) - max for walking
  static const int _warmupPositions = 3; // positions to collect before trusting data
  
  int _positionCount = 0;
  String _currentActivityType = 'running';

  /// Set the current activity type for speed validation
  void setActivityType(String type) {
    _currentActivityType = type.toLowerCase();
  }

  /// Get max speed based on activity type
  double get _maxAllowedSpeed {
    switch (_currentActivityType) {
      case 'walking':
        return _walkingMaxSpeedMps;
      case 'running':
        return _runningMaxSpeedMps;
      case 'cycling':
        return _maxSpeedMps;
      default:
        return _maxSpeedMps;
    }
  }

  /// Check and request location permissions
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      // Open location settings
      await Geolocator.openLocationSettings();
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied');
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  /// Get current position with high accuracy
  Future<LatLng?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      
      final latLng = LatLng(position.latitude, position.longitude);
      _lastPosition = latLng;
      _lastValidPosition = latLng;
      _lastAccuracy = position.accuracy;
      
      // Initialize Kalman filters with current position
      _latFilter = _KalmanFilter(
        initialEstimate: position.latitude,
        errorMeasurement: position.accuracy / 111000, // Convert meters to degrees approx
      );
      _lngFilter = _KalmanFilter(
        initialEstimate: position.longitude,
        errorMeasurement: position.accuracy / (111000 * math.cos(position.latitude * math.pi / 180)),
      );
      
      return latLng;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Start tracking location updates with filtering
  Future<void> startTracking() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('No location permission for tracking');
      return;
    }

    // Reset state
    _positionCount = 0;
    _lastPositionTime = null;
    _lastValidPosition = null;

    // Use high accuracy with distance filter
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // Update every 3 meters minimum
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _handlePositionUpdate,
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  /// Process incoming GPS position with filtering
  void _handlePositionUpdate(Position position) {
    final now = DateTime.now();
    final rawLatLng = LatLng(position.latitude, position.longitude);
    _lastPosition = rawLatLng;
    _lastAccuracy = position.accuracy;
    _positionCount++;

    // Skip positions with poor accuracy
    if (position.accuracy > _minAccuracyThreshold) {
      debugPrint('GPS: Skipping low accuracy reading (${position.accuracy.toStringAsFixed(1)}m)');
      return;
    }

    // Initialize Kalman filters if needed
    _latFilter ??= _KalmanFilter(
      initialEstimate: position.latitude,
      errorMeasurement: position.accuracy / 111000,
    );
    _lngFilter ??= _KalmanFilter(
      initialEstimate: position.longitude,
      errorMeasurement: position.accuracy / (111000 * math.cos(position.latitude * math.pi / 180)),
    );

    // Apply Kalman filter for smoothing
    final smoothedLat = _latFilter!.filter(position.latitude);
    final smoothedLng = _lngFilter!.filter(position.longitude);
    final smoothedLatLng = LatLng(smoothedLat, smoothedLng);

    // Validate movement is physically possible
    if (_lastValidPosition != null && _lastPositionTime != null) {
      final timeDelta = now.difference(_lastPositionTime!).inMilliseconds / 1000.0;
      
      if (timeDelta > 0) {
        final distance = Geolocator.distanceBetween(
          _lastValidPosition!.latitude,
          _lastValidPosition!.longitude,
          smoothedLat,
          smoothedLng,
        );
        
        final speed = distance / timeDelta; // m/s

        // Skip if movement too small (jitter)
        if (distance < _minMovementThreshold && position.accuracy > _goodAccuracyThreshold) {
          debugPrint('GPS: Skipping micro-movement (${distance.toStringAsFixed(2)}m)');
          return;
        }

        // Skip if speed is impossibly fast
        if (speed > _maxAllowedSpeed) {
          debugPrint('GPS: Skipping impossible speed (${(speed * 3.6).toStringAsFixed(1)} km/h)');
          // Reset Kalman filters if we got a bad jump
          _latFilter!.reset(position.latitude);
          _lngFilter!.reset(position.longitude);
          return;
        }
      }
    }

    // During warmup, just collect positions without emitting
    if (_positionCount < _warmupPositions) {
      _lastValidPosition = smoothedLatLng;
      _lastPositionTime = now;
      debugPrint('GPS: Warmup position $_positionCount/$_warmupPositions');
      return;
    }

    // Valid position - emit it
    _lastValidPosition = smoothedLatLng;
    _lastPositionTime = now;
    _locationController.add(smoothedLatLng);
    
    debugPrint('GPS: Valid update (${smoothedLat.toStringAsFixed(6)}, ${smoothedLng.toStringAsFixed(6)}) '
        'accuracy: ${position.accuracy.toStringAsFixed(1)}m');
  }

  /// Stop tracking location
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _positionCount = 0;
  }

  /// Calculate distance between two points in kilometers
  static double calculateDistance(LatLng start, LatLng end) {
    final distanceInMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    return distanceInMeters / 1000; // Convert to km
  }

  /// Calculate total distance of a route with accuracy-weighted filtering
  static double calculateRouteDistance(List<LatLng> points) {
    if (points.length < 2) return 0;
    
    double totalDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final segmentDistance = calculateDistance(points[i], points[i + 1]);
      // Skip very small segments (likely jitter that slipped through)
      if (segmentDistance > 0.001) { // > 1 meter
        totalDistance += segmentDistance;
      }
    }
    return totalDistance;
  }

  /// Calculate speed between two points in km/h
  static double calculateSpeed(LatLng start, LatLng end, Duration timeDelta) {
    if (timeDelta.inSeconds <= 0) return 0;
    final distanceKm = calculateDistance(start, end);
    final hours = timeDelta.inMilliseconds / 3600000.0;
    return distanceKm / hours;
  }

  /// Calculate pace in minutes per km
  static double calculatePace(double distanceKm, Duration duration) {
    if (distanceKm <= 0) return 0;
    return duration.inMinutes / distanceKm;
  }

  void dispose() {
    stopTracking();
    _locationController.close();
  }
}
