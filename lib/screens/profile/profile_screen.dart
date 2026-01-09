import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/user.dart';
import '../../models/activity.dart';
import '../../providers/theme_provider.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

/// Profile screen - displays user info, stats, and activity history
class ProfileScreen extends StatefulWidget {
  final StorageService storageService;

  const ProfileScreen({super.key, required this.storageService});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  User? _user;
  List<Activity> _activities = [];
  bool _isLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load user and activities
    final user = await widget.storageService.getUserAsync();
    final activities = await widget.storageService.getActivities(limit: 20);

    if (mounted) {
      setState(() {
        _user = user;
        _activities = activities;
        _isLoading = false;
      });
      _fadeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: textColor,
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        child: _isLoading
            ? _buildLoadingState(textColor)
            : FadeTransition(
                opacity: _fadeAnimation,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    _buildHeader(context, isDark, textColor, mutedColor),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            _buildProfileCard(isDark, textColor, mutedColor),
                            const SizedBox(height: 24),
                            _buildStatsCards(isDark, textColor, mutedColor),
                            const SizedBox(height: 28),
                            _buildActionButtons(context, isDark, textColor, mutedColor),
                            const SizedBox(height: 32),
                            _buildActivityHistoryHeader(textColor, mutedColor),
                          ],
                        ),
                      ),
                    ),
                    _buildActivityList(isDark, textColor, mutedColor),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingState(Color textColor) {
    return Center(
      child: CircularProgressIndicator(color: textColor),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, Color textColor, Color mutedColor) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      floating: true,
      snap: true,
      centerTitle: true,
      title: Text(
        'PROFILE',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 4,
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  SettingsScreen(storageService: widget.storageService),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                  child: child,
                );
              },
            ),
          ).then((_) => _loadData()),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(10),
            decoration: AppTheme.glassDecoration(
              isDark: isDark,
              borderRadius: 14,
              opacity: 0.15,
            ),
            child: Icon(Icons.settings_rounded, color: textColor, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(bool isDark, Color textColor, Color mutedColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 24),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [Colors.white.withAlpha(30), Colors.white.withAlpha(10)]
                    : [Colors.black.withAlpha(10), Colors.black.withAlpha(5)],
              ),
              border: Border.all(
                color: isDark ? Colors.white.withAlpha(40) : Colors.black.withAlpha(20),
                width: 2,
              ),
            ),
            child: _user?.photoUrl != null
                ? ClipOval(
                    child: Image.network(
                      _user!.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAvatarFallback(textColor),
                    ),
                  )
                : _buildAvatarFallback(textColor),
          ),
          const SizedBox(width: 20),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?.name ?? 'Athlete',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      _getSportIcon(_user?.primarySport ?? 'Running'),
                      size: 16,
                      color: mutedColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _user?.primarySport ?? 'Runner',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: mutedColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (_user?.bio != null && _user!.bio!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _user!.bio!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: mutedColor,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(Color textColor) {
    return Center(
      child: Text(
        (_user?.name ?? 'A').substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  IconData _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      default:
        return Icons.sports_rounded;
    }
  }

  Widget _buildStatsCards(bool isDark, Color textColor, Color mutedColor) {
    final stats = _user?.stats ?? UserStats();

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.straighten_rounded,
            value: stats.totalDistanceKm.toStringAsFixed(1),
            unit: 'km',
            label: 'Distance',
            isDark: isDark,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.fitness_center_rounded,
            value: stats.totalWorkouts.toString(),
            unit: '',
            label: 'Workouts',
            isDark: isDark,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.timer_rounded,
            value: _formatTotalTime(stats.totalTime),
            unit: '',
            label: 'Time',
            isDark: isDark,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
        ),
      ],
    );
  }

  String _formatTotalTime(Duration duration) {
    final hours = duration.inHours;
    if (hours >= 100) {
      return '${hours}h';
    } else if (hours > 0) {
      return '${hours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  Widget _buildActionButtons(BuildContext context, bool isDark, Color textColor, Color mutedColor) {
    return Column(
      children: [
        _ActionButton(
          icon: Icons.edit_rounded,
          label: 'Edit Profile',
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  EditProfileScreen(
                    storageService: widget.storageService,
                    currentUser: _user,
                  ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                  child: child,
                );
              },
            ),
          ).then((_) => _loadData()),
          isDark: isDark,
          textColor: textColor,
          mutedColor: mutedColor,
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: Icons.watch_rounded,
          label: 'Connected Devices',
          badge: 'Coming Soon',
          onTap: () {},
          isDark: isDark,
          textColor: textColor,
          mutedColor: mutedColor,
        ),
      ],
    );
  }

  Widget _buildActivityHistoryHeader(Color textColor, Color mutedColor) {
    return Row(
      children: [
        Icon(Icons.history_rounded, color: mutedColor, size: 22),
        const SizedBox(width: 10),
        Text(
          'Activity History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const Spacer(),
        Text(
          '${_activities.length} activities',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: mutedColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityList(bool isDark, Color textColor, Color mutedColor) {
    if (_activities.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(40),
          decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 20),
          child: Column(
            children: [
              Icon(
                Icons.directions_run_rounded,
                size: 56,
                color: mutedColor.withAlpha(100),
              ),
              const SizedBox(height: 16),
              Text(
                'No activities yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start your first workout to see it here!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final activity = _activities[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: _ActivityCard(
              activity: activity,
              isDark: isDark,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          );
        },
        childCount: _activities.length,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 18),
      child: Column(
        children: [
          Icon(icon, color: mutedColor, size: 22),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: mutedColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: mutedColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.badge,
    required this.onTap,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const Spacer(),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: mutedColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: mutedColor,
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, color: mutedColor, size: 24),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Activity activity;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;

  const _ActivityCard({
    required this.activity,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 16),
      child: Row(
        children: [
          // Activity icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
            ),
            child: Icon(
              _getActivityIcon(activity.activityType),
              color: textColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.activityType,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(activity.startTime),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
              ],
            ),
          ),
          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${activity.formattedDistance} km',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                activity.formattedDuration,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      default:
        return Icons.sports_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    }
  }
}
