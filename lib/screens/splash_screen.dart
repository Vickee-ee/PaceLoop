import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import 'auth/login_screen.dart';
import 'home_screen.dart';

/// Animated splash screen with PaceLoop logo and infinity loop animation
class SplashScreen extends StatefulWidget {
  final StorageService storageService;

  const SplashScreen({super.key, required this.storageService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _infinityController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _pulseController;
  
  late Animation<double> _infinityProgress;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Infinity loop drawing animation
    _infinityController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _infinityProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _infinityController,
        curve: Curves.easeInOut,
      ),
    );

    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // Pulse animation controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Logo scale animation
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    // Logo fade animation
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeIn,
      ),
    );
    
    // Pulse animation for the ring
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Text fade animation
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );

    // Text slide animation
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );

    // Start animations in sequence
    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    // 1. Draw infinity loop (0-1000ms)
    _infinityController.forward();
    
    // 2. After infinity forms, show logo (at 800ms)
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      _logoController.forward();
      _pulseController.repeat(reverse: true);
    }
    
    // 3. Show text (at 1200ms)
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _textController.forward();
    
    // 4. Navigate after splash complete (at 2000ms total)
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) _navigateNext();
  }

  void _navigateNext() {
    if (!mounted) return;

    final isLoggedIn = widget.storageService.isLoggedIn;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => isLoggedIn
            ? HomeScreen(storageService: widget.storageService)
            : LoginScreen(storageService: widget.storageService),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _infinityController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    // Always use dark background for splash for dramatic effect
    const bgColor = Color(0xFF0A0A0A);
    final textColor = Colors.white;
    final mutedColor = Colors.white.withAlpha(150);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated infinity loop with logo
            AnimatedBuilder(
              animation: Listenable.merge([
                _infinityController,
                _logoController,
                _pulseController,
              ]),
              builder: (context, child) {
                return SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated infinity loop that transforms to circle
                      Transform.scale(
                        scale: _pulseAnimation.value,
                        child: CustomPaint(
                          size: const Size(160, 160),
                          painter: _InfinityToCirclePainter(
                            progress: _infinityProgress.value,
                            color: textColor,
                            strokeWidth: 4,
                          ),
                        ),
                      ),
                      // Logo appearing after infinity forms
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to infinity symbol if logo not found
                              return Text(
                                '∞',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w300,
                                  color: textColor,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            // App name with slide animation
            SlideTransition(
              position: _textSlideAnimation,
              child: FadeTransition(
                opacity: _textFadeAnimation,
                child: Text(
                  AppConstants.appName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Tagline
            SlideTransition(
              position: _textSlideAnimation,
              child: FadeTransition(
                opacity: _textFadeAnimation,
                child: Text(
                  AppConstants.appTagline,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that draws an infinity symbol that morphs into a circle
class _InfinityToCirclePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _InfinityToCirclePainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Calculate the morphing from infinity to circle
    // Progress 0-0.5: Draw infinity loop
    // Progress 0.5-1.0: Morph to circle
    
    final path = Path();
    
    if (progress <= 0.5) {
      // Drawing the infinity loop progressively
      final drawProgress = progress * 2; // 0 to 1 for drawing phase
      _drawPartialInfinity(path, centerX, centerY, size.width * 0.35, drawProgress);
    } else {
      // Morphing from infinity to circle
      final morphProgress = (progress - 0.5) * 2; // 0 to 1 for morphing phase
      _drawMorphingShape(path, centerX, centerY, size.width * 0.35, morphProgress);
    }
    
    canvas.drawPath(path, paint);
  }

  void _drawPartialInfinity(Path path, double cx, double cy, double radius, double progress) {
    // Draw infinity as two connected circles
    final points = <Offset>[];
    final totalPoints = 100;
    final drawPoints = (totalPoints * progress).round();
    
    for (int i = 0; i <= drawPoints; i++) {
      final t = (i / totalPoints) * 2 * math.pi;
      // Parametric equation for infinity (lemniscate of Bernoulli style)
      final scale = 2 / (3 - math.cos(2 * t));
      final x = cx + scale * math.cos(t) * radius;
      final y = cy + scale * math.sin(2 * t) / 2 * radius;
      points.add(Offset(x, y));
    }
    
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
  }

  void _drawMorphingShape(Path path, double cx, double cy, double radius, double morphProgress) {
    // Smoothly morph from infinity shape to circle
    final circleRadius = radius * 1.1;
    final points = <Offset>[];
    final totalPoints = 100;
    
    for (int i = 0; i <= totalPoints; i++) {
      final t = (i / totalPoints) * 2 * math.pi;
      
      // Infinity point
      final scale = 2 / (3 - math.cos(2 * t));
      final infX = scale * math.cos(t) * radius;
      final infY = scale * math.sin(2 * t) / 2 * radius;
      
      // Circle point
      final circX = math.cos(t) * circleRadius;
      final circY = math.sin(t) * circleRadius;
      
      // Interpolate between infinity and circle
      final x = cx + infX + (circX - infX) * morphProgress;
      final y = cy + infY + (circY - infY) * morphProgress;
      
      points.add(Offset(x, y));
    }
    
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      path.close();
    }
  }

  @override
  bool shouldRepaint(covariant _InfinityToCirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
