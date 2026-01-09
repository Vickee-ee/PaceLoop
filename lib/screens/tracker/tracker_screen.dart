import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/theme_provider.dart';
import '../../services/storage_service.dart';
import '../../services/location_service.dart';
import '../../services/activity_service.dart';
import 'activity_screen.dart';

/// Tracker screen - activity type selection
class TrackerScreen extends StatelessWidget {
  final StorageService storageService;

  const TrackerScreen({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header
              Text(
                'Start Training',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 32),
              // Activity grid
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: AppConstants.activityTypes.length,
                  itemBuilder: (context, index) {
                    final activityType = AppConstants.activityTypes[index];
                    return _ActivityCard(
                      activityType: activityType,
                      onTap: () => _startActivity(context, activityType),
                      isDark: isDark,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Quick stats from last activity
              _buildQuickStats(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  void _startActivity(BuildContext context, String activityType) {
    final user = storageService.getUser();
    if (user == null) return;

    final locationService = LocationService();
    final activityService = ActivityService(
      locationService: locationService,
      storageService: storageService,
      userId: user.id,
    );

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ActivityScreen(
          activityType: activityType,
          activityService: activityService,
          locationService: locationService,
          storageService: storageService,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, bool isDark) {
    final user = storageService.getUser();
    if (user == null) return const SizedBox.shrink();

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Total Distance',
            value: '${user.stats.totalDistanceKm.toStringAsFixed(1)} km',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          Container(
            width: 2,
            height: 50,
            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
          ),
          _StatItem(
            label: 'Workouts',
            value: user.stats.totalWorkouts.toString(),
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          Container(
            width: 2,
            height: 50,
            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
          ),
          _StatItem(
            label: 'Total Time',
            value: _formatDuration(user.stats.totalTime),
            textColor: textColor,
            mutedColor: mutedColor,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _ActivityCard extends StatefulWidget {
  final String activityType;
  final VoidCallback onTap;
  final bool isDark;

  const _ActivityCard({
    required this.activityType,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: AppTheme.glassCard(isDark: widget.isDark, borderRadius: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIcon(),
                size: 52,
                color: textColor,
              ),
              const SizedBox(height: 14),
              Text(
                widget.activityType,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (widget.activityType.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'jogging':
        return Icons.directions_run_outlined;
      case 'gym / fitness':
        return Icons.fitness_center_rounded;
      case 'swimming':
        return Icons.pool_rounded;
      case 'yoga':
        return Icons.self_improvement_rounded;
      default:
        return Icons.sports_rounded;
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: mutedColor,
          ),
        ),
      ],
    );
  }
}
