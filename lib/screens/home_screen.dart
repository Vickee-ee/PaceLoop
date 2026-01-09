import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import 'loops/loops_feed_screen.dart';
import 'tracker/tracker_screen.dart';
import 'profile/profile_screen.dart';

/// Main home screen with bottom navigation
class HomeScreen extends StatefulWidget {
  final StorageService storageService;

  const HomeScreen({super.key, required this.storageService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _screens = [
      LoopsFeedScreen(storageService: widget.storageService),
      TrackerScreen(storageService: widget.storageService),
      ProfileScreen(storageService: widget.storageService),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final dividerColor = isDark ? AppTheme.darkDivider : AppTheme.lightDivider;

    return Scaffold(
      backgroundColor: bgColor,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(
            top: BorderSide(color: dividerColor, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  index: 0,
                  currentIndex: _currentIndex,
                  icon: _buildInfinityIcon(
                    isSelected: _currentIndex == 0,
                    isDark: isDark,
                  ),
                  label: 'Loops',
                  onTap: () => _onTabTapped(0),
                  isDark: isDark,
                ),
                _NavItem(
                  index: 1,
                  currentIndex: _currentIndex,
                  icon: Icon(
                    Icons.timer_rounded,
                    size: 28,
                    color: _currentIndex == 1
                        ? (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)
                        : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                  ),
                  label: 'Tracker',
                  onTap: () => _onTabTapped(1),
                  isDark: isDark,
                  isCenter: true,
                ),
                _NavItem(
                  index: 2,
                  currentIndex: _currentIndex,
                  icon: Icon(
                    Icons.person_rounded,
                    size: 26,
                    color: _currentIndex == 2
                        ? (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)
                        : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                  ),
                  label: 'Profile',
                  onTap: () => _onTabTapped(2),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Custom infinity icon widget
  Widget _buildInfinityIcon({required bool isSelected, required bool isDark}) {
    final color = isSelected
        ? (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)
        : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted);
    
    return Text(
      '∞',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool isCenter;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 14,
          vertical: 8,
        ),
        decoration: isSelected
            ? BoxDecoration(
                color: textColor.withAlpha(isDark ? 12 : 8),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? textColor : mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
