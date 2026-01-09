import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/loop.dart';
import '../../providers/theme_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/loop_card.dart';

/// Loops feed screen - vertical full-screen scrolling feed
class LoopsFeedScreen extends StatefulWidget {
  final StorageService storageService;

  const LoopsFeedScreen({super.key, required this.storageService});

  @override
  State<LoopsFeedScreen> createState() => _LoopsFeedScreenState();
}

class _LoopsFeedScreenState extends State<LoopsFeedScreen> {
  late List<Loop> _loops;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadLoops();
  }

  void _loadLoops() {
    var storedLoops = widget.storageService.getLoops();
    if (storedLoops.isEmpty) {
      storedLoops = _getMockLoops();
      widget.storageService.saveLoops(storedLoops);
    }
    _loops = storedLoops;
  }

  List<Loop> _getMockLoops() {
    return [
      Loop(
        id: '1',
        athleteId: 'u1',
        athleteName: 'Alex Runner',
        sportType: 'Running',
        caption: 'Morning 10K done. Every step counts, every mile matters. Keep pushing forward!',
        tags: ['#running', '#10k', '#morningrun'],
        riseCount: 234,
        isVideo: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Loop(
        id: '2',
        athleteId: 'u2',
        athleteName: 'Sarah Cyclist',
        sportType: 'Cycling',
        caption: '50 miles in the mountains today. The climb never gets easier, you just get stronger.',
        tags: ['#cycling', '#mountains', '#endurance'],
        riseCount: 456,
        isVideo: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Loop(
        id: '3',
        athleteId: 'u3',
        athleteName: 'Mike Lifter',
        sportType: 'Gym / Fitness',
        caption: 'New PR on deadlift: 180kg. Consistency beats motivation every single day.',
        tags: ['#gym', '#deadlift', '#strength'],
        riseCount: 892,
        isVideo: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      Loop(
        id: '4',
        athleteId: 'u4',
        athleteName: 'Emma Swimmer',
        sportType: 'Swimming',
        caption: '2000m open water swim complete. The ocean does not care about your excuses.',
        tags: ['#swimming', '#openwater', '#endurance'],
        riseCount: 178,
        isVideo: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      Loop(
        id: '5',
        athleteId: 'u5',
        athleteName: 'David Walker',
        sportType: 'Walking',
        caption: '15,000 steps before sunrise. Small steps, big results. Stay consistent.',
        tags: ['#walking', '#steps', '#consistency'],
        riseCount: 89,
        isVideo: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  void _onRise(int index) {
    setState(() {
      final loop = _loops[index];
      _loops[index] = loop.copyWith(
        hasRisen: !loop.hasRisen,
        riseCount: loop.hasRisen ? loop.riseCount - 1 : loop.riseCount + 1,
      );
    });
    widget.storageService.saveLoops(_loops);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Full-screen vertical feed
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount: _loops.length,
            itemBuilder: (context, index) {
              return LoopCard(
                loop: _loops[index],
                onRise: () => _onRise(index),
                onShare: () => _shareLoop(_loops[index]),
              );
            },
          ),
          // Header with glassmorphism
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo and app name
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: AppTheme.glassDecoration(
                          isDark: isDark,
                          borderRadius: 18,
                          opacity: 0.2,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, st) => Center(
                              child: Text(
                                'P',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: AppTheme.glassDecoration(
                        isDark: isDark,
                        borderRadius: 12,
                        opacity: 0.15,
                      ),
                      child: Icon(Icons.info_outline_rounded, size: 22, color: textColor),
                    ),
                    onPressed: _showDisclaimer,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisclaimer() {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Content Policy',
          style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
        ),
        content: Text(
          AppConstants.contentDisclaimer,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareLoop(Loop loop) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sharing "${loop.caption.substring(0, 25)}..."',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
