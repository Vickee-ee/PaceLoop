import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/user.dart';
import '../../providers/theme_provider.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';
import '../home_screen.dart';

/// Sign up screen with Firebase email verification
class SignupScreen extends StatefulWidget {
  final StorageService storageService;

  const SignupScreen({super.key, required this.storageService});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedSport = AppConstants.activityTypes.first;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _verificationSent = false;
  String? _errorMessage;

  final _firebaseService = FirebaseService.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_firebaseService.isInitialized) {
        // Firebase signup with email verification
        final userCredential = await _firebaseService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          primarySport: _selectedSport,
        );

        if (userCredential != null) {
          // Show verification sent message
          setState(() {
            _verificationSent = true;
            _isLoading = false;
          });
          
          // Also save locally
          final user = User(
            id: userCredential.user!.uid,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            primarySport: _selectedSport,
          );
          await widget.storageService.saveUser(user);
          await widget.storageService.setLoggedIn(true);
        }
      } else {
        // Offline mode
        await Future.delayed(const Duration(milliseconds: 800));
        
        final user = User(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          primarySport: _selectedSport,
        );

        await widget.storageService.saveUser(user);
        await widget.storageService.setLoggedIn(true);
        _navigateHome();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _getErrorMessage(e.toString());
      });
    }
  }

  void _navigateHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HomeScreen(storageService: widget.storageService),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
  }

  String _getErrorMessage(String error) {
    if (error.contains('email-already-in-use')) {
      return 'This email is already registered.';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email address.';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak.';
    } else if (error.contains('network')) {
      return 'Network error. Check your connection.';
    }
    return 'Sign up failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    if (_verificationSent) {
      return _buildVerificationSentScreen(isDark, bgColor, textColor, mutedColor);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: AppTheme.glassDecoration(
              isDark: isDark,
              borderRadius: 12,
              opacity: 0.15,
            ),
            child: Icon(Icons.arrow_back_rounded, color: textColor),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Join the athletes community',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 36),
                
                // Error message
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withAlpha(100)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                _buildNameField(textColor, mutedColor),
                const SizedBox(height: 18),
                _buildEmailField(textColor, mutedColor),
                const SizedBox(height: 18),
                _buildPasswordField(textColor, mutedColor),
                const SizedBox(height: 18),
                _buildSportDropdown(isDark, textColor, mutedColor, surfaceColor),
                const SizedBox(height: 36),
                _buildSignUpButton(isDark, textColor),
                const SizedBox(height: 28),
                Text(
                  AppConstants.contentDisclaimer,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 44),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationSentScreen(
      bool isDark, Color bgColor, Color textColor, Color mutedColor) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.riseActive.withAlpha(30),
                  border: Border.all(color: AppTheme.riseActive, width: 3),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  size: 56,
                  color: AppTheme.riseActive,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We sent a verification link to\n${_emailController.text}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _navigateHome,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: textColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'CONTINUE TO APP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'You can verify your email later from settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField(Color textColor, Color mutedColor) {
    return TextFormField(
      controller: _nameController,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: 'Athlete name',
        prefixIcon: Icon(Icons.person_outline_rounded, color: mutedColor),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your name';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField(Color textColor, Color mutedColor) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Email address',
        prefixIcon: Icon(Icons.email_outlined, color: mutedColor),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(Color textColor, Color mutedColor) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Password (min 6 characters)',
        prefixIcon: Icon(Icons.lock_outline_rounded, color: mutedColor),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: mutedColor,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildSportDropdown(bool isDark, Color textColor, Color mutedColor, Color surfaceColor) {
    return DropdownButtonFormField<String>(
      value: _selectedSport,
      dropdownColor: surfaceColor,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Primary sport',
        prefixIcon: Icon(Icons.sports_rounded, color: mutedColor),
      ),
      items: AppConstants.activityTypes.map((sport) {
        return DropdownMenuItem(value: sport, child: Text(sport));
      }).toList(),
      onChanged: (value) {
        if (value != null) setState(() => _selectedSport = value);
      },
    );
  }

  Widget _buildSignUpButton(bool isDark, Color textColor) {
    return GestureDetector(
      onTap: _isLoading ? null : _signUp,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: textColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: textColor.withAlpha(60),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
                  ),
                )
              : Text(
                  'CREATE ACCOUNT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
                    letterSpacing: 2,
                  ),
                ),
        ),
      ),
    );
  }
}
