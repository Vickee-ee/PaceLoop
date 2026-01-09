import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/theme_provider.dart';
import '../../services/activity_service.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import '../../models/activity.dart';
import 'activity_complete_screen.dart';

/// Active workout screen with fullscreen map and floating controls
class ActivityScreen extends StatefulWidget {
  final String activityType;
  final ActivityService activityService;
  final LocationService locationService;
  final StorageService storageService;

  const ActivityScreen({
    super.key,
    required this.activityType,
    required this.activityService,
    required this.locationService,
    required this.storageService,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isStarted = false;
  bool _isMapReady = false;
  bool _hasGpsSignal = true;
  bool _showCountdown = false;
  int _countdownValue = 3;
  LatLng? _currentPosition;
  LatLng? _startPosition;
  Timer? _gpsCheckTimer;
  
  late AnimationController _buttonAnimController;
  late Animation<double> _buttonScale;
  late AnimationController _countdownAnimController;
  late Animation<double> _countdownScale;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Default location (India center)
  static const LatLng _defaultLocation = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    widget.activityService.addListener(_onActivityUpdate);
    
    _buttonAnimController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonAnimController, curve: Curves.easeInOut),
    );
    
    _countdownAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _countdownScale = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _countdownAnimController, curve: Curves.elasticOut),
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Get initial position
    _initializeLocation();
    
    // Start GPS signal check
    _gpsCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkGpsSignal();
    });
  }

  Future<void> _initializeLocation() async {
    final position = await widget.locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = position;
        _hasGpsSignal = true;
        _isMapReady = true;
      });
      _centerOnPosition(position);
    } else {
      setState(() => _isMapReady = true);
    }
  }

  void _checkGpsSignal() {
    final activity = widget.activityService.currentActivity;
    if (activity != null && _isStarted) {
      final lastUpdate = widget.locationService.lastPosition;
      final accuracy = widget.locationService.lastAccuracy;
      if (lastUpdate == null || (accuracy != null && accuracy > 30)) {
        setState(() => _hasGpsSignal = false);
      } else {
        setState(() => _hasGpsSignal = true);
      }
    }
  }

  void _onActivityUpdate() {
    if (!mounted) return;
    setState(() {});
    
    final activity = widget.activityService.currentActivity;
    if (activity != null && activity.routePoints.isNotEmpty) {
      final lastPoint = activity.routePoints.last;
      _currentPosition = lastPoint;
      
      // Store start position
      if (_startPosition == null && activity.routePoints.isNotEmpty) {
        _startPosition = activity.routePoints.first;
      }
      
      _centerOnPosition(lastPoint);
    }
  }

  void _centerOnPosition(LatLng position) {
    if (_isMapReady) {
      try {
        _mapController.move(position, 17);
      } catch (e) {
        debugPrint('Map controller not ready: $e');
      }
    }
  }

  void _centerOnCurrentLocation() async {
    final position = await widget.locationService.getCurrentPosition();
    if (position != null) {
      setState(() {
        _currentPosition = position;
        _hasGpsSignal = true;
      });
      _centerOnPosition(position);
    } else {
      setState(() => _hasGpsSignal = false);
    }
  }

  @override
  void dispose() {
    widget.activityService.removeListener(_onActivityUpdate);
    _buttonAnimController.dispose();
    _countdownAnimController.dispose();
    _pulseController.dispose();
    _gpsCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _startWorkout() async {
    // Show countdown animation
    setState(() => _showCountdown = true);
    
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      _countdownAnimController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 800));
    }
    
    if (!mounted) return;
    setState(() {
      _countdownValue = 0; // "GO!"
      _showCountdown = false;
    });
    
    await widget.activityService.startActivity(widget.activityType);
    
    // Start pulse animation for current location marker
    _pulseController.repeat(reverse: true);
    
    setState(() => _isStarted = true);
  }

  void _pauseWorkout() {
    widget.activityService.pauseActivity();
    _pulseController.stop();
  }

  void _resumeWorkout() {
    widget.activityService.resumeActivity();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _stopWorkout() async {
    _pulseController.stop();
    final completed = await widget.activityService.stopActivity();
    if (completed != null && mounted) {
      // Navigate to completion animation screen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ActivityCompleteScreen(
            activity: completed,
            storageService: widget.storageService,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  void _discardWorkout() {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Discard Activity?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        content: Text(
          'This workout will not be saved.',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _pulseController.stop();
              widget.activityService.discardActivity();
              Navigator.pop(context);
              Navigator.pop(this.context);
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final activity = widget.activityService.currentActivity;
    final isTracking = widget.activityService.isTracking;
    final isPaused = widget.activityService.isPaused;

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Fullscreen OpenStreetMap
          Positioned.fill(
            child: _buildMap(activity, isDark),
          ),
          
          // Countdown overlay
          if (_showCountdown)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(180),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _countdownAnimController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _countdownScale.value,
                        child: Text(
                          _countdownValue > 0 ? '$_countdownValue' : 'GO!',
                          style: TextStyle(
                            fontSize: 120,
                            fontWeight: FontWeight.w900,
                            color: _countdownValue > 0 ? Colors.white : Colors.greenAccent,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          
          // GPS Signal Warning
          if (!_hasGpsSignal && !_showCountdown)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gps_off_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Weak GPS signal. Move to an open area.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Top header
          if (!_showCountdown)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _isStarted ? _discardWorkout : () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.glassDecoration(
                          isDark: isDark,
                          borderRadius: 14,
                          opacity: 0.3,
                        ),
                        child: Icon(Icons.close_rounded, color: textColor, size: 24),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: AppTheme.glassDecoration(
                            isDark: isDark,
                            borderRadius: 20,
                            opacity: 0.3,
                          ),
                          child: Text(
                            widget.activityType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          
          // My location button
          if (!_showCountdown)
            Positioned(
              right: 20,
              top: MediaQuery.of(context).padding.top + 80,
              child: GestureDetector(
                onTap: _centerOnCurrentLocation,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.glassDecoration(
                    isDark: isDark,
                    borderRadius: 16,
                    opacity: 0.35,
                  ),
                  child: Icon(
                    Icons.my_location_rounded,
                    color: textColor,
                    size: 26,
                  ),
                ),
              ),
            ),
          
          // Bottom stats and controls
          if (!_showCountdown)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bgColor.withAlpha(0),
                      bgColor.withAlpha(200),
                      bgColor,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStats(activity, isDark),
                    const SizedBox(height: 24),
                    _buildControls(isTracking, isPaused, isDark, textColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(Activity? activity, bool isDark) {
    final routePoints = activity?.routePoints ?? [];
    final center = _currentPosition ?? (routePoints.isNotEmpty ? routePoints.last : _defaultLocation);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        onMapReady: () {
          setState(() => _isMapReady = true);
        },
      ),
      children: [
        // OpenStreetMap tile layer
        TileLayer(
          urlTemplate: isDark
              ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'
              : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.paceloop.app',
        ),
        // Route polyline
        if (routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: isDark ? Colors.blue.shade300 : Colors.blue.shade600,
                strokeWidth: 5,
              ),
            ],
          ),
        // Markers layer
        if (routePoints.isNotEmpty)
          MarkerLayer(
            markers: [
              // Start point marker (green)
              if (_startPosition != null)
                Marker(
                  point: _startPosition!,
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              // Current position marker (blue with pulse)
              Marker(
                point: routePoints.last,
                width: 28,
                height: 28,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulse ring
                        if (widget.activityService.isTracking)
                          Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.withAlpha(50),
                              ),
                            ),
                          ),
                        // Current position dot
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(60),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStats(Activity? activity, bool isDark) {
    final isCycling = widget.activityType.toLowerCase() == 'cycling';
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatDisplay(
            value: activity?.formattedDuration ?? '00:00',
            label: 'Duration',
            isLarge: true,
            isDark: isDark,
          ),
          Container(
            width: 2,
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          _StatDisplay(
            value: activity?.formattedDistance ?? '0.00',
            label: 'km',
            isDark: isDark,
          ),
          Container(
            width: 2,
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          _StatDisplay(
            value: isCycling 
                ? (activity?.formattedCurrentSpeed ?? '0.0')
                : (activity?.formattedPace ?? '--:--'),
            label: isCycling ? 'km/h' : '/km',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildControls(bool isTracking, bool isPaused, bool isDark, Color textColor) {
    if (!_isStarted) {
      return GestureDetector(
        onTapDown: (_) => _buttonAnimController.forward(),
        onTapUp: (_) {
          _buttonAnimController.reverse();
          _startWorkout();
        },
        onTapCancel: () => _buttonAnimController.reverse(),
        child: ScaleTransition(
          scale: _buttonScale,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: textColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: textColor.withAlpha(60),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'START',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: isPaused ? _resumeWorkout : _pauseWorkout,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(18),
                color: isPaused 
                    ? (isDark ? Colors.green.withAlpha(30) : Colors.green.withAlpha(20))
                    : (isDark ? AppTheme.darkSurface.withAlpha(200) : AppTheme.lightSurface.withAlpha(200)),
              ),
              child: Center(
                child: Text(
                  isPaused ? 'RESUME' : 'PAUSE',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isPaused ? Colors.green : textColor,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: _stopWorkout,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: textColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  'STOP',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatDisplay extends StatelessWidget {
  final String value;
  final String label;
  final bool isLarge;
  final bool isDark;

  const _StatDisplay({
    required this.value,
    required this.label,
    this.isLarge = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 38 : 30,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: mutedColor,
          ),
        ),
      ],
    );
  }
}
