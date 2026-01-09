import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/loop.dart';
import '../providers/theme_provider.dart';
import 'demo_video_player.dart';

/// Full-screen Loop card widget for the vertical feed
class LoopCard extends StatefulWidget {
  final Loop loop;
  final VoidCallback onRise;
  final VoidCallback onShare;

  const LoopCard({
    super.key,
    required this.loop,
    required this.onRise,
    required this.onShare,
  });

  @override
  State<LoopCard> createState() => _LoopCardState();
}

class _LoopCardState extends State<LoopCard> with SingleTickerProviderStateMixin {
  late AnimationController _riseController;
  late Animation<double> _riseScale;

  @override
  void initState() {
    super.initState();
    _riseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _riseScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _riseController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _riseController.dispose();
    super.dispose();
  }

  void _handleRise() {
    _riseController.forward().then((_) => _riseController.reverse());
    widget.onRise();
  }

  void _playDemoVideo() {
    // Demo video URL - replace with actual video URLs
    const demoVideoUrl = 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
    
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => DemoVideoPlayer(
          videoUrl: demoVideoUrl,
          title: '${widget.loop.sportType} Demo',
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

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final secondaryColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor.withAlpha(100),
                    bgColor.withAlpha(180),
                    bgColor,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Sport type background icon
          Center(
            child: Icon(
              _getSportIcon(widget.loop.sportType),
              size: 220,
              color: textColor.withAlpha(isDark ? 10 : 8),
            ),
          ),
          // Demo video button (for video loops)
          if (widget.loop.isVideo)
            Center(
              child: GestureDetector(
                onTap: _playDemoVideo,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: AppTheme.glassDecoration(
                    isDark: isDark,
                    borderRadius: 30,
                    opacity: 0.25,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: textColor,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: bgColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Play Demo',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Content overlay at bottom with glassmorphism
          Positioned(
            left: 20,
            right: 80,
            bottom: 120,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Athlete info row
                  Row(
                    children: [
                      // Profile avatar
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: textColor, width: 2.5),
                          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                        ),
                        child: Center(
                          child: Text(
                            widget.loop.athleteName[0].toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Name and sport
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.loop.athleteName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  _getSportIcon(widget.loop.sportType),
                                  size: 14,
                                  color: mutedColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.loop.sportType,
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Caption
                  Text(
                    widget.loop.caption,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  // Tags
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: widget.loop.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: textColor.withAlpha(isDark ? 20 : 15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          // Right side action buttons with glassmorphism
          Positioned(
            right: 16,
            bottom: 140,
            child: Column(
              children: [
                // Rise button with trending_up icon
                _RiseButton(
                  riseCount: widget.loop.riseCount,
                  hasRisen: widget.loop.hasRisen,
                  onTap: _handleRise,
                  scaleAnimation: _riseScale,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
                // Share button
                _ActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: widget.onShare,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSportIcon(String sportType) {
    switch (sportType.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'swimming':
        return Icons.pool_rounded;
      default:
        return Icons.sports_rounded;
    }
  }
}

/// Rise button with trending_up icon and animation
class _RiseButton extends StatelessWidget {
  final int riseCount;
  final bool hasRisen;
  final VoidCallback onTap;
  final Animation<double> scaleAnimation;
  final bool isDark;

  const _RiseButton({
    required this.riseCount,
    required this.hasRisen,
    required this.onTap,
    required this.scaleAnimation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return GestureDetector(
      onTap: onTap,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasRisen
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.riseActive,
                          AppTheme.riseActive.withAlpha(200),
                        ],
                      )
                    : null,
                color: hasRisen ? null : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10)),
                border: Border.all(
                  color: hasRisen ? AppTheme.riseActive : (isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(20)),
                  width: 2,
                ),
                boxShadow: hasRisen
                    ? [
                        BoxShadow(
                          color: AppTheme.riseActive.withAlpha(100),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.trending_up_rounded,
                color: hasRisen ? Colors.white : mutedColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Rise',
              style: TextStyle(
                fontSize: 13,
                color: hasRisen ? AppTheme.riseActive : mutedColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _formatCount(riseCount),
              style: TextStyle(
                fontSize: 14,
                color: hasRisen ? textColor : mutedColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: AppTheme.glassDecoration(
              isDark: isDark,
              borderRadius: 26,
              opacity: 0.15,
            ),
            child: Icon(
              icon,
              color: textColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
