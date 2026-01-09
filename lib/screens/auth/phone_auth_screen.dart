import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/user.dart' as app_user;
import '../../providers/theme_provider.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';
import '../home_screen.dart';

/// Phone authentication screen with OTP verification
class PhoneAuthScreen extends StatefulWidget {
  final StorageService storageService;

  const PhoneAuthScreen({super.key, required this.storageService});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false;
  bool _showNameField = false;
  String? _verificationId;
  String? _errorMessage;
  int? _resendToken;

  final _firebaseService = FirebaseService.instance;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }

    // Add country code if not present
    final fullPhone = phone.startsWith('+') ? phone : '+91$phone';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (!_firebaseService.isInitialized) {
      // Offline mode - simulate OTP
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isLoading = false;
        _codeSent = true;
        _verificationId = 'offline-verification';
      });
      return;
    }

    try {
      await _firebaseService.verifyPhoneNumber(
        phoneNumber: fullPhone,
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android
          await _signInWithCredential(credential);
        },
        onVerificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _errorMessage = _getPhoneErrorMessage(e.code);
          });
        },
        onCodeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _codeSent = true;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to send OTP. Please try again.';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (!_firebaseService.isInitialized || _verificationId == 'offline-verification') {
      // Offline mode - accept any 6-digit OTP
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _isLoading = false;
        _showNameField = true;
      });
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(credential);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid OTP. Please try again.';
      });
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _firebaseService.signInWithPhoneCredential(credential);
      
      if (userCredential != null) {
        // Check if this is a new user
        final profile = await _firebaseService.getProfile();
        
        if (profile == null) {
          // New user - show name field
          setState(() {
            _isLoading = false;
            _showNameField = true;
          });
        } else {
          // Existing user - go home
          await widget.storageService.saveUser(profile);
          await widget.storageService.setLoggedIn(true);
          _navigateHome();
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sign-in failed. Please try again.';
      });
    }
  }

  Future<void> _completeSignup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_firebaseService.isInitialized && _firebaseService.currentUser != null) {
        // Update Firebase profile
        await _firebaseService.updateProfile(name: name);
        final profile = await _firebaseService.getProfile();
        if (profile != null) {
          await widget.storageService.saveUser(profile);
        }
      } else {
        // Offline mode - create local user
        final phone = _phoneController.text.trim();
        final fullPhone = phone.startsWith('+') ? phone : '+91$phone';
        
        await widget.storageService.saveUser(app_user.User(
          id: const Uuid().v4(),
          name: name,
          phone: fullPhone,
        ));
      }

      await widget.storageService.setLoggedIn(true);
      _navigateHome();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to complete signup. Please try again.';
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

  String _getPhoneErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      default:
        return 'Failed to send OTP. Please try again.';
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Phone Login',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.glassDecoration(
                    isDark: isDark,
                    borderRadius: 40,
                    opacity: 0.15,
                  ),
                  child: Icon(
                    _showNameField 
                        ? Icons.person_rounded 
                        : (_codeSent ? Icons.sms_rounded : Icons.phone_rounded),
                    size: 48,
                    color: textColor,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                _showNameField 
                    ? 'What\'s your name?' 
                    : (_codeSent ? 'Enter verification code' : 'Enter your phone number'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                _showNameField
                    ? 'This will be your display name in PaceLoop'
                    : (_codeSent 
                        ? 'We sent a 6-digit code to ${_phoneController.text}' 
                        : 'We\'ll send you a verification code'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
                textAlign: TextAlign.center,
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
              
              // Input field based on state
              if (_showNameField)
                _buildNameField(isDark, textColor, mutedColor)
              else if (_codeSent)
                _buildOtpField(isDark, textColor, mutedColor)
              else
                _buildPhoneField(isDark, textColor, mutedColor),
              
              const SizedBox(height: 28),
              
              // Action button
              _buildActionButton(isDark, textColor),
              
              // Resend OTP
              if (_codeSent && !_showNameField) ...[
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: _isLoading ? null : _sendOtp,
                    child: Text(
                      'Resend Code',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField(bool isDark, Color textColor, Color mutedColor) {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: TextStyle(
        color: textColor, 
        fontWeight: FontWeight.w600,
        fontSize: 18,
        letterSpacing: 1,
      ),
      decoration: InputDecoration(
        hintText: '10-digit phone number',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+91',
                style: TextStyle(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 24,
                color: mutedColor.withAlpha(100),
              ),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }

  Widget _buildOtpField(bool isDark, Color textColor, Color mutedColor) {
    return TextFormField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      style: TextStyle(
        color: textColor, 
        fontWeight: FontWeight.w800,
        fontSize: 28,
        letterSpacing: 8,
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: '------',
        counterText: '',
        hintStyle: TextStyle(
          color: mutedColor.withAlpha(100),
          letterSpacing: 8,
        ),
      ),
    );
  }

  Widget _buildNameField(bool isDark, Color textColor, Color mutedColor) {
    return TextFormField(
      controller: _nameController,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Your name',
        prefixIcon: Icon(Icons.person_outline_rounded, color: mutedColor),
      ),
    );
  }

  Widget _buildActionButton(bool isDark, Color textColor) {
    String buttonText;
    VoidCallback? onTap;
    
    if (_showNameField) {
      buttonText = 'COMPLETE SIGNUP';
      onTap = _completeSignup;
    } else if (_codeSent) {
      buttonText = 'VERIFY';
      onTap = _verifyOtp;
    } else {
      buttonText = 'SEND CODE';
      onTap = _sendOtp;
    }
    
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: textColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: textColor.withAlpha(60),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
                  ),
                )
              : Text(
                  buttonText,
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
