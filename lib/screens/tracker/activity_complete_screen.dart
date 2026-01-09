import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/theme_provider.dart';
import '../../models/activity.dart';
import '../../services/storage_service.dart';
import 'summary_screen.dart';

/// Activity completion animation screen with "Activity Saved" message
class ActivityCompleteScreen extends StatefulWidget {
  final Activity activity;
  final StorageService storageService;

  const ActivityCompleteScreen({
    super.key,
    required this.activity,
    required this.storageService,
  });

  @override
  State<ActivityCompleteScreen> createState() => _ActivityCompleteScreenState();
}

class _ActivityCompleteScreenState extends State<ActivityCompleteScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _statsController;
  late AnimationController _pulseController;
  late AnimationController _savedTextController;
  
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;
  late Animation<double> _statsOpacity;
  late Animation<Offset> _statsSlide;
  late Animation<double> _pulseScale;
  late Animation<double> _savedTextOpacity;
  late Animation<Offset> _savedTextSlide;

  @override
  void initState() {
    super.initState();
    
    // Checkmark animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: Curves.elasticOut,
      ),
    );
    
    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
    
    // "Activity Saved" text animation
    _savedTextController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _savedTextOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _savedTextController,
        curve: Curves.easeOut,
      ),
    );
    
    _savedTextSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _savedTextController,
        curve: Curves.easeOut,
      ),
    );
    
    // Stats animation
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _statsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _statsController,
        curve: Curves.easeOut,
      ),
    );
    
    _statsSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _statsController,
        curve: Curves.easeOut,
      ),
    );
    
    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start animations in sequence
    _startAnimations();
  }
  
  void _startAnimations() async {
    // 1. Checkmark with pulse
    _checkController.forward();
    _pulseController.repeat(reverse: true);
    
    // 2. "Activity Saved" text appears (at 400ms)
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _savedTextController.forward();
    
    // 3. Stats appear (at 800ms)
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _statsController.forward();
    
    // 4. Auto-navigate to summary after animation (at 2500ms total)
    await Future.delayed(const Duration(milliseconds: 1300));
    if (mounted) _navigateToSummary();
  }

  void _navigateToSummary() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SummaryScreen(
          activity: widget.activity,
          storageService: widget.storageService,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    _statsController.dispose();
    _pulseController.dispose();
    _savedTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated checkmark with expanding pulse
              AnimatedBuilder(
                animation: Listenable.merge([_checkController, _pulseController]),
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Expanding pulse rings
                      ...List.generate(3, (index) {
                        final delay = index * 0.3;
                        final pulseValue = (_pulseController.value + delay) % 1.0;
                        return Opacity(
                          opacity: (1.0 - pulseValue) * _checkOpacity.value * 0.3,
                          child: Transform.scale(
                            scale: 1.0 + (pulseValue * 0.5),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.riseActive,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      // Main checkmark circle
                      Opacity(
                        opacity: _checkOpacity.value,
                        child: Transform.scale(
                          scale: _checkScale.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.riseActive.withAlpha(30),
                              border: Border.all(
                                color: AppTheme.riseActive,
                                width: 4,
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 64,
                              color: AppTheme.riseActive,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              // "Activity Saved" text
              SlideTransition(
                position: _savedTextSlide,
                child: FadeTransition(
                  opacity: _savedTextOpacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.riseActive.withAlpha(20),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppTheme.riseActive.withAlpha(100)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save_rounded, color: AppTheme.riseActive, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Activity Saved',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.riseActive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Activity type
              FadeTransition(
                opacity: _checkOpacity,
                child: Text(
                  widget.activity.activityType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _checkOpacity,
                child: Text(
                  'COMPLETE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: mutedColor,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Stats
              SlideTransition(
                position: _statsSlide,
                child: FadeTransition(
                  opacity: _statsOpacity,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(28),
                    decoration: AppTheme.glassCard(isDark: isDark, borderRadius: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          value: widget.activity.formattedDistance,
                          unit: 'km',
                          label: 'Distance',
                          textColor: textColor,
                          mutedColor: mutedColor,
                        ),
                        Container(
                          width: 2,
                          height: 60,
                          color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                        ),
                        _StatItem(
                          value: widget.activity.formattedDuration,
                          unit: '',
                          label: 'Time',
                          textColor: textColor,
                          mutedColor: mutedColor,
                        ),
                        Container(
                          width: 2,
                          height: 60,
                          color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                        ),
                        _StatItem(
                          value: widget.activity.formattedPace,
                          unit: '/km',
                          label: 'Pace',
                          textColor: textColor,
                          mutedColor: mutedColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color textColor;
  final Color mutedColor;

  const _StatItem({
    required this.value,
    required this.unit,
    required this.label,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: mutedColor,
          ),
        ),
      ],
    );
  }
}
