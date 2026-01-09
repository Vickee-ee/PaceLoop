import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/user.dart';
import '../../providers/theme_provider.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';

/// Edit profile screen - update user name, bio, and primary sport
class EditProfileScreen extends StatefulWidget {
  final StorageService storageService;
  final User? currentUser;

  const EditProfileScreen({
    super.key,
    required this.storageService,
    this.currentUser,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late String _selectedSport;
  bool _isLoading = false;
  bool _hasChanges = false;

  final _firebaseService = FirebaseService.instance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser?.name ?? '');
    _bioController = TextEditingController(text: widget.currentUser?.bio ?? '');
    _selectedSport = widget.currentUser?.primarySport ?? AppConstants.activityTypes.first;

    _nameController.addListener(_onFieldChange);
    _bioController.addListener(_onFieldChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onFieldChange() {
    final hasChanges = _nameController.text != (widget.currentUser?.name ?? '') ||
        _bioController.text != (widget.currentUser?.bio ?? '') ||
        _selectedSport != (widget.currentUser?.primarySport ?? AppConstants.activityTypes.first);
    
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Update Firebase if authenticated
      if (_firebaseService.isAuthenticated) {
        await _firebaseService.updateProfile(
          name: _nameController.text.trim(),
          bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
          primarySport: _selectedSport,
        );
      }

      // Update local storage
      final updatedUser = (widget.currentUser ?? User(id: '', name: '')).copyWith(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        primarySport: _selectedSport,
      );
      await widget.storageService.saveUser(updatedUser);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Profile updated',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppTheme.riseActive,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

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
          'Edit Profile',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_hasChanges)
            GestureDetector(
              onTap: _isLoading ? null : _saveProfile,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: textColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: bgColor,
                        ),
                      )
                    : Text(
                        'Save',
                        style: TextStyle(
                          color: bgColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar section
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
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
                        child: widget.currentUser?.photoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  widget.currentUser!.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildAvatarFallback(textColor),
                                ),
                              )
                            : _buildAvatarFallback(textColor),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: textColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: bgColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Name field
                _buildLabel('Name', textColor),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    prefixIcon: Icon(Icons.person_outline_rounded, color: mutedColor),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Bio field
                _buildLabel('Bio', textColor),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  maxLines: 3,
                  maxLength: 150,
                  decoration: InputDecoration(
                    hintText: 'Tell us about yourself...',
                    alignLabelWithHint: true,
                    counterStyle: TextStyle(color: mutedColor),
                  ),
                ),
                const SizedBox(height: 16),

                // Primary sport
                _buildLabel('Primary Sport', textColor),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedSport,
                  dropdownColor: surfaceColor,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.sports_rounded, color: mutedColor),
                  ),
                  items: AppConstants.activityTypes.map((sport) {
                    return DropdownMenuItem(value: sport, child: Text(sport));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedSport = value);
                      _onFieldChange();
                    }
                  },
                ),
                const SizedBox(height: 40),

                // Account info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightSurfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Info',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.currentUser?.email != null)
                        _buildInfoRow(Icons.email_outlined, widget.currentUser!.email!, mutedColor),
                      if (widget.currentUser?.phone != null)
                        _buildInfoRow(Icons.phone_rounded, widget.currentUser!.phone!, mutedColor),
                      if (widget.currentUser?.email == null && widget.currentUser?.phone == null)
                        _buildInfoRow(Icons.info_outline, 'No account linked', mutedColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color textColor) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
    );
  }

  Widget _buildAvatarFallback(Color textColor) {
    return Center(
      child: Text(
        (widget.currentUser?.name ?? 'A').substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: mutedColor),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: mutedColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
