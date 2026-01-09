import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/theme_provider.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';
import '../auth/login_screen.dart';

/// Settings screen with theme toggle, account settings, and logout
class SettingsScreen extends StatefulWidget {
  final StorageService storageService;

  const SettingsScreen({super.key, required this.storageService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;
  final _firebaseService = FirebaseService.instance;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = context.watch<ThemeProvider>().isDarkMode;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Log Out?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          content: Text(
            'You\'ll need to log in again to access your activities.',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log Out', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isLoggingOut = true);

      try {
        // Sign out from Firebase
        await _firebaseService.signOut();
        
        // Clear local storage
        await widget.storageService.clearAll();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  LoginScreen(storageService: widget.storageService),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoggingOut = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // App section
            _buildSectionHeader('App', mutedColor),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark Mode',
              subtitle: isDark ? 'On' : 'Off',
              trailing: Switch(
                value: isDark,
                onChanged: (value) => themeProvider.toggleTheme(),
                activeColor: textColor,
              ),
              isDark: isDark,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            _SettingsTile(
              icon: Icons.notifications_rounded,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              trailing: Icon(Icons.chevron_right_rounded, color: mutedColor),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coming soon!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              isDark: isDark,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            
            const SizedBox(height: 28),
            
            // Connected services
            _buildSectionHeader('Connected Services', mutedColor),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.watch_rounded,
              title: 'Wearables',
              subtitle: 'Connect fitness devices',
              badge: 'Coming Soon',
              trailing: Icon(Icons.chevron_right_rounded, color: mutedColor),
              onTap: () {},
              isDark: isDark,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            _SettingsTile(
              icon: Icons.favorite_rounded,
              title: 'Health Connect',
              subtitle: 'Sync health data',
              badge: 'Coming Soon',
              trailing: Icon(Icons.chevron_right_rounded, color: mutedColor),
              onTap: () {},
              isDark: isDark,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            
            const SizedBox(height: 28),
            
            // Account section
            _buildSectionHeader('Account', mutedColor),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.person_rounded,
              title: 'Account Details',
              subtitle: _firebaseService.currentUser?.email ?? 
                        _firebaseService.currentUser?.phoneNumber ?? 
                        'Not logged in',
              trailing: Icon(Icons.chevron_right_rounded, color: mutedColor),
              onTap: () {},
              isDark: isDark,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            _SettingsTile(
              icon: Icons.lock_rounded,
              title: 'Privacy',
              subtitle: 'Manage your data',
              trailing: Icon(Icons.chevron_right_rounded, color: mutedColor),
              onTap: () {},
              isDark: isDark,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            
            const SizedBox(height: 28),
            
            // About section
            _buildSectionHeader('About', mutedColor),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.info_rounded,
              title: 'About ${AppConstants.appName}',
              subtitle: 'Version 1.0.0 (Alpha)',
              trailing: Icon(Icons.chevron_right_rounded, color: mutedColor),
              onTap: () {},
              isDark: isDark,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            _SettingsTile(
              icon: Icons.description_rounded,
              title: 'Terms & Privacy',
              subtitle: 'Legal information',
              trailing: Icon(Icons.chevron_right_rounded, color: mutedColor),
              onTap: () {},
              isDark: isDark,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            
            const SizedBox(height: 32),
            
            // Logout button
            GestureDetector(
              onTap: _isLoggingOut ? null : _logout,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.withAlpha(150), width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoggingOut)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    else
                      const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color mutedColor) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: mutedColor,
        letterSpacing: 2,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.trailing,
    this.onTap,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: textColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: mutedColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: mutedColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: mutedColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
