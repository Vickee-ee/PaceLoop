import 'package:latlong2/latlong.dart';

/// Activity tracking model with enhanced metrics
class Activity {
  final String id;
  final String userId;
  final String activityType;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration duration;
  final double distanceKm;
  final List<LatLng> routePoints;
  final ActivityStatus status;
  final List<Duration> splits; // Time per km
  final double? heartRate; // Average heart rate if available
  final double? currentSpeed; // Current speed in km/h (for cycling)

  Activity({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.startTime,
    this.endTime,
    this.duration = Duration.zero,
    this.distanceKm = 0,
    this.routePoints = const [],
    this.status = ActivityStatus.idle,
    this.splits = const [],
    this.heartRate,
    this.currentSpeed,
  });

  /// Calculate pace in minutes per km (more accurate)
  double get paceMinPerKm {
    if (distanceKm <= 0 || duration.inSeconds <= 0) return 0;
    // Use seconds for precision
    return (duration.inSeconds / 60) / distanceKm;
  }

  /// Calculate average speed in km/h
  double get avgSpeedKmh {
    if (distanceKm <= 0 || duration.inSeconds <= 0) return 0;
    final hours = duration.inSeconds / 3600.0;
    return distanceKm / hours;
  }

  /// Format pace as MM:SS /km
  String get formattedPace {
    if (paceMinPerKm <= 0 || paceMinPerKm > 60) return '--:--';
    final totalSeconds = (paceMinPerKm * 60).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format speed as X.X km/h
  String get formattedSpeed {
    if (avgSpeedKmh <= 0) return '0.0';
    return avgSpeedKmh.toStringAsFixed(1);
  }

  /// Format current speed as X.X km/h
  String get formattedCurrentSpeed {
    if (currentSpeed == null || currentSpeed! <= 0) return '0.0';
    return currentSpeed!.toStringAsFixed(1);
  }

  /// Format duration as HH:MM:SS or MM:SS
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format distance
  String get formattedDistance {
    return distanceKm.toStringAsFixed(2);
  }

  /// Get the appropriate metric label based on activity type
  String get primaryMetricLabel {
    switch (activityType.toLowerCase()) {
      case 'cycling':
        return 'km/h';
      case 'running':
      case 'walking':
      default:
        return '/km';
    }
  }

  /// Get the appropriate metric value based on activity type
  String get primaryMetricValue {
    switch (activityType.toLowerCase()) {
      case 'cycling':
        return formattedSpeed;
      case 'running':
      case 'walking':
      default:
        return formattedPace;
    }
  }

  /// Format a split time as MM:SS
  static String formatSplit(Duration split) {
    final totalSeconds = split.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get splits with kilometer markers
  List<String> get formattedSplits {
    return splits.asMap().entries.map((entry) {
      final km = entry.key + 1;
      final time = formatSplit(entry.value);
      return 'Km $km: $time';
    }).toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'activityType': activityType,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationSeconds': duration.inSeconds,
        'distanceKm': distanceKm,
        'routePoints': routePoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'status': status.name,
        'splits': splits.map((s) => s.inSeconds).toList(),
        'heartRate': heartRate,
        'currentSpeed': currentSpeed,
      };

  factory Activity.fromJson(Map<String, dynamic> json) {
    // Handle different key formats (camelCase vs snake_case)
    final userId = json['userId'] ?? json['user_id'] ?? '';
    final activityType = json['activityType'] ?? json['activity_type'] ?? 'Running';
    final startTime = json['startTime'] ?? json['start_time'];
    final endTime = json['endTime'] ?? json['end_time'];
    final durationSeconds = json['durationSeconds'] ?? json['duration_seconds'] ?? 0;
    final distanceKm = json['distanceKm'] ?? json['distance_km'] ?? 0;
    
    return Activity(
      id: json['id'],
      userId: userId,
      activityType: activityType,
      startTime: DateTime.parse(startTime),
      endTime: endTime != null ? DateTime.parse(endTime) : null,
      duration: Duration(seconds: durationSeconds),
      distanceKm: (distanceKm).toDouble(),
      routePoints: (json['routePoints'] ?? json['route_points'] as List?)
              ?.map((p) => LatLng(
                    (p['lat'] as num).toDouble(),
                    (p['lng'] as num).toDouble(),
                  ))
              .toList() ??
          [],
      status: ActivityStatus.values.byName(json['status'] ?? 'idle'),
      splits: (json['splits'] as List?)
              ?.map((s) => Duration(seconds: s as int))
              .toList() ??
          [],
      heartRate: json['heartRate']?.toDouble() ?? json['heart_rate']?.toDouble(),
      currentSpeed: json['currentSpeed']?.toDouble() ?? json['current_speed']?.toDouble(),
    );
  }

  Activity copyWith({
    DateTime? endTime,
    Duration? duration,
    double? distanceKm,
    List<LatLng>? routePoints,
    ActivityStatus? status,
    List<Duration>? splits,
    double? heartRate,
    double? currentSpeed,
  }) =>
      Activity(
        id: id,
        userId: userId,
        activityType: activityType,
        startTime: startTime,
        endTime: endTime ?? this.endTime,
        duration: duration ?? this.duration,
        distanceKm: distanceKm ?? this.distanceKm,
        routePoints: routePoints ?? this.routePoints,
        status: status ?? this.status,
        splits: splits ?? this.splits,
        heartRate: heartRate ?? this.heartRate,
        currentSpeed: currentSpeed ?? this.currentSpeed,
      );
}

enum ActivityStatus {
  idle,
  active,
  paused,
  completed,
}
