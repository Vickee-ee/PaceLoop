import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../models/activity.dart';
import 'location_service.dart';
import 'storage_service.dart';

/// Activity tracking service - manages workout sessions with real-time metrics
class ActivityService extends ChangeNotifier {
  final LocationService _locationService;
  final StorageService _storageService;
  final String userId;

  Activity? _currentActivity;
  Timer? _timer;
  StreamSubscription? _locationSubscription;
  DateTime? _lastTickTime;
  
  // Splits tracking
  double _lastSplitDistance = 0;
  Duration _lastSplitTime = Duration.zero;
  
  // Speed calculation
  LatLng? _speedCalcLastPosition;
  DateTime? _speedCalcLastTime;
  double _currentSpeed = 0; // km/h

  Activity? get currentActivity => _currentActivity;
  bool get isTracking => _currentActivity?.status == ActivityStatus.active;
  bool get isPaused => _currentActivity?.status == ActivityStatus.paused;
  double get currentSpeed => _currentSpeed;

  ActivityService({
    required LocationService locationService,
    required StorageService storageService,
    required this.userId,
  })  : _locationService = locationService,
        _storageService = storageService;

  /// Start a new activity
  Future<void> startActivity(String activityType) async {
    if (_currentActivity != null) {
      debugPrint('Activity already in progress');
      return;
    }

    // Set activity type in location service for speed validation
    _locationService.setActivityType(activityType);

    // Get initial position
    final initialPosition = await _locationService.getCurrentPosition();
    
    if (initialPosition == null) {
      debugPrint('Could not get initial position');
    }

    // Reset tracking state
    _lastSplitDistance = 0;
    _lastSplitTime = Duration.zero;
    _speedCalcLastPosition = initialPosition;
    _speedCalcLastTime = DateTime.now();
    _currentSpeed = 0;

    _currentActivity = Activity(
      id: const Uuid().v4(),
      userId: userId,
      activityType: activityType,
      startTime: DateTime.now(),
      status: ActivityStatus.active,
      routePoints: initialPosition != null ? [initialPosition] : [],
      splits: [],
    );

    // Start location tracking
    await _locationService.startTracking();
    _locationSubscription = _locationService.locationStream.listen(_onLocationUpdate);

    // Start timer with accurate tracking
    _lastTickTime = DateTime.now();
    _startTimer();

    notifyListeners();
  }

  void _onLocationUpdate(LatLng position) {
    if (_currentActivity == null || _currentActivity!.status != ActivityStatus.active) {
      return;
    }

    final now = DateTime.now();
    final updatedPoints = [..._currentActivity!.routePoints, position];
    final totalDistance = LocationService.calculateRouteDistance(updatedPoints);

    // Calculate current speed
    if (_speedCalcLastPosition != null && _speedCalcLastTime != null) {
      final timeDelta = now.difference(_speedCalcLastTime!);
      if (timeDelta.inMilliseconds >= 1000) { // Calculate speed every second minimum
        final segmentDistance = LocationService.calculateDistance(
          _speedCalcLastPosition!,
          position,
        );
        _currentSpeed = LocationService.calculateSpeed(
          _speedCalcLastPosition!,
          position,
          timeDelta,
        );
        _speedCalcLastPosition = position;
        _speedCalcLastTime = now;
      }
    } else {
      _speedCalcLastPosition = position;
      _speedCalcLastTime = now;
    }

    // Check for new km split
    List<Duration> updatedSplits = [..._currentActivity!.splits];
    final currentKm = totalDistance.floor();
    final lastRecordedKm = updatedSplits.length;
    
    if (currentKm > lastRecordedKm && _currentActivity!.duration > Duration.zero) {
      // Calculate split time for this km
      final splitTime = _currentActivity!.duration - _lastSplitTime;
      updatedSplits.add(splitTime);
      _lastSplitTime = _currentActivity!.duration;
      _lastSplitDistance = currentKm.toDouble();
      debugPrint('New split: Km ${currentKm} in ${Activity.formatSplit(splitTime)}');
    }

    _currentActivity = _currentActivity!.copyWith(
      routePoints: updatedPoints,
      distanceKm: totalDistance,
      splits: updatedSplits,
      currentSpeed: _currentSpeed,
    );

    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentActivity?.status == ActivityStatus.active) {
        final now = DateTime.now();
        if (_lastTickTime != null) {
          final elapsed = now.difference(_lastTickTime!);
          _currentActivity = _currentActivity!.copyWith(
            duration: _currentActivity!.duration + elapsed,
          );
          notifyListeners();
        }
        _lastTickTime = now;
      }
    });
  }

  /// Pause the current activity
  void pauseActivity() {
    if (_currentActivity?.status != ActivityStatus.active) return;

    _currentActivity = _currentActivity!.copyWith(
      status: ActivityStatus.paused,
    );
    _lastTickTime = null;
    _speedCalcLastPosition = null;
    _speedCalcLastTime = null;
    _currentSpeed = 0;
    notifyListeners();
  }

  /// Resume the paused activity
  void resumeActivity() {
    if (_currentActivity?.status != ActivityStatus.paused) return;

    _currentActivity = _currentActivity!.copyWith(
      status: ActivityStatus.active,
    );
    _lastTickTime = DateTime.now();
    
    // Reset speed calculation on resume
    if (_currentActivity!.routePoints.isNotEmpty) {
      _speedCalcLastPosition = _currentActivity!.routePoints.last;
      _speedCalcLastTime = DateTime.now();
    }
    
    notifyListeners();
  }

  /// Stop and complete the activity
  Future<Activity?> stopActivity() async {
    if (_currentActivity == null) return null;

    _timer?.cancel();
    _timer = null;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationService.stopTracking();

    final completedActivity = _currentActivity!.copyWith(
      status: ActivityStatus.completed,
      endTime: DateTime.now(),
      currentSpeed: null, // Clear current speed for completed activity
    );

    // Save to storage
    await _storageService.saveActivity(completedActivity);
    await _storageService.updateUserStats(completedActivity);

    _currentActivity = null;
    _currentSpeed = 0;
    notifyListeners();

    return completedActivity;
  }

  /// Discard the current activity without saving
  void discardActivity() {
    _timer?.cancel();
    _timer = null;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationService.stopTracking();

    _currentActivity = null;
    _currentSpeed = 0;
    _lastSplitDistance = 0;
    _lastSplitTime = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}
