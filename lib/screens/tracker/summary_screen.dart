import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/theme_provider.dart';
import '../../models/activity.dart';
import '../../services/storage_service.dart';
import '../home_screen.dart';

/// Workout summary screen - displays after completing an activity
class SummaryScreen extends StatelessWidget {
  final Activity activity;
  final StorageService storageService;

  const SummaryScreen({
    super.key,
    required this.activity,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark, textColor),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSuccessMessage(context, isDark, textColor),
                    const SizedBox(height: 28),
                    _buildRouteMap(isDark, textColor),
                    const SizedBox(height: 28),
                    _buildStatsGrid(isDark, textColor),
                    // Show splits for running/walking
                    if (activity.splits.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _buildSplits(isDark, textColor),
                    ],
                    const SizedBox(height: 36),
                    _buildActions(context, isDark, textColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Center(
              child: Text(
                'WORKOUT COMPLETE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _goHome(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.glassDecoration(
                isDark: isDark,
                borderRadius: 14,
                opacity: 0.15,
              ),
              child: Icon(Icons.close_rounded, color: textColor, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(BuildContext context, bool isDark, Color textColor) {
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.riseActive.withAlpha(30),
              border: Border.all(color: AppTheme.riseActive, width: 3),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 36,
              color: AppTheme.riseActive,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.activityType,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(activity.startTime),
                  style: TextStyle(
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMap(bool isDark, Color textColor) {
    if (activity.routePoints.isEmpty) {
      return Container(
        height: 220,
        decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 56,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
              ),
              const SizedBox(height: 12),
              Text(
                'No route recorded',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate bounds for the route
    double minLat = activity.routePoints.first.latitude;
    double maxLat = activity.routePoints.first.latitude;
    double minLng = activity.routePoints.first.longitude;
    double maxLng = activity.routePoints.first.longitude;

    for (var point in activity.routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    // Calculate appropriate zoom level
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    double zoom = 14.0;
    if (maxDiff > 0.1) zoom = 11;
    else if (maxDiff > 0.05) zoom = 12;
    else if (maxDiff > 0.02) zoom = 13;
    else if (maxDiff > 0.01) zoom = 14;
    else zoom = 15;

    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none, // Disable all interactions for summary view
          ),
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
          PolylineLayer(
            polylines: [
              Polyline(
                points: activity.routePoints,
                color: isDark ? Colors.white : Colors.black,
                strokeWidth: 5,
              ),
            ],
          ),
          // Start and end markers
          MarkerLayer(
            markers: [
              // Start marker (green)
              Marker(
                point: activity.routePoints.first,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
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
              ),
              // End marker (red)
              Marker(
                point: activity.routePoints.last,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark, Color textColor) {
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final isCycling = activity.activityType.toLowerCase() == 'cycling';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.timer_rounded,
                  value: activity.formattedDuration,
                  label: 'Duration',
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ),
              Container(
                width: 2,
                height: 70,
                color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
              ),
              Expanded(
                child: _StatTile(
                  icon: Icons.straighten_rounded,
                  value: '${activity.formattedDistance} km',
                  label: 'Distance',
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.speed_rounded,
                  value: isCycling 
                      ? '${activity.formattedSpeed} km/h' 
                      : '${activity.formattedPace} /km',
                  label: isCycling ? 'Avg Speed' : 'Avg Pace',
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ),
              Container(
                width: 2,
                height: 70,
                color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
              ),
              Expanded(
                child: _StatTile(
                  icon: Icons.route_rounded,
                  value: activity.routePoints.length.toString(),
                  label: 'GPS Points',
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSplits(bool isDark, Color textColor) {
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: mutedColor, size: 22),
              const SizedBox(width: 10),
              Text(
                'Kilometer Splits',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...activity.splits.asMap().entries.map((entry) {
            final km = entry.key + 1;
            final split = entry.value;
            final splitStr = Activity.formatSplit(split);
            
            // Color code splits - faster is green, slower is red
            Color splitColor = textColor;
            if (activity.splits.length > 1) {
              final avgSplit = activity.duration.inSeconds / activity.splits.length;
              if (split.inSeconds < avgSplit * 0.95) {
                splitColor = Colors.green;
              } else if (split.inSeconds > avgSplit * 1.05) {
                splitColor = Colors.red.shade400;
              }
            }
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppTheme.darkSurface : AppTheme.lightBackground,
                    ),
                    child: Center(
                      child: Text(
                        '$km',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: mutedColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Km $km',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: mutedColor,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    splitStr,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: splitColor,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => _postAsLoop(context, isDark),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.loop_rounded, color: textColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Post as Loop',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _goHome(context),
          child: Container(
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
                'DONE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _postAsLoop(BuildContext context, bool isDark) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Loop creation coming soon!',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HomeScreen(storageService: storageService),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
      (route) => false,
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} $ampm';
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color textColor;
  final Color mutedColor;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: mutedColor, size: 24),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: textColor,
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
