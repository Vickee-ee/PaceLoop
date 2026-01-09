import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/activity.dart';
import '../models/loop.dart';
import 'firebase_service.dart';

/// Local storage service for caching and offline support
class StorageService {
  static const String _userKey = 'paceloop_user';
  static const String _activitiesKey = 'paceloop_activities';
  static const String _loopsKey = 'paceloop_loops';
  static const String _isLoggedInKey = 'paceloop_logged_in';
  
  SharedPreferences? _prefs;
  User? _cachedUser;
  
  final _firebaseService = FirebaseService.instance;

  bool get isLoggedIn => _prefs?.getBool(_isLoggedInKey) ?? false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> setLoggedIn(bool value) async {
    await _prefs?.setBool(_isLoggedInKey, value);
    if (!value) {
      // Clear cache on logout
      _cachedUser = null;
      await _prefs?.remove(_userKey);
      await _prefs?.remove(_activitiesKey);
    }
  }

  // ============ User ============

  Future<void> saveUser(User user) async {
    _cachedUser = user;
    final json = jsonEncode(user.toJson());
    await _prefs?.setString(_userKey, json);
  }

  User? getUser() {
    if (_cachedUser != null) return _cachedUser;
    
    final json = _prefs?.getString(_userKey);
    if (json == null) return null;
    
    try {
      _cachedUser = User.fromJson(jsonDecode(json));
      return _cachedUser;
    } catch (e) {
      debugPrint('Error parsing stored user: $e');
      return null;
    }
  }

  Future<User?> getUserAsync() async {
    // Try to get from Firebase first
    if (_firebaseService.isAuthenticated) {
      try {
        final profile = await _firebaseService.getProfile();
        if (profile != null) {
          _cachedUser = profile;
          await saveUser(profile);
          return profile;
        }
      } catch (e) {
        debugPrint('Error fetching profile from Firebase: $e');
      }
    }
    
    // Fall back to local cache
    return getUser();
  }

  // ============ Activities ============

  Future<void> saveActivity(Activity activity) async {
    // Save to Firebase if authenticated
    if (_firebaseService.isAuthenticated) {
      try {
        await _firebaseService.saveActivity(activity);
      } catch (e) {
        debugPrint('Error saving activity to Firebase: $e');
      }
    }
    
    // Also save locally as cache
    final activities = List<Activity>.from(_getLocalActivities());
    activities.insert(0, activity);
    
    // Keep only last 100 activities locally
    final trimmed = activities.take(100).toList();
    final json = jsonEncode(trimmed.map((a) => a.toJson()).toList());
    await _prefs?.setString(_activitiesKey, json);
  }

  List<Activity> _getLocalActivities() {
    final json = _prefs?.getString(_activitiesKey);
    if (json == null) return [];
    
    try {
      final list = jsonDecode(json) as List;
      return list.map((item) => Activity.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error parsing stored activities: $e');
      return [];
    }
  }

  Future<List<Activity>> getActivities({int limit = 50}) async {
    // Get from Firebase if authenticated (user-isolated)
    if (_firebaseService.isAuthenticated) {
      try {
        final activities = await _firebaseService.getUserActivities(limit: limit);
        if (activities.isNotEmpty) {
          return activities;
        }
      } catch (e) {
        debugPrint('Error fetching activities from Firebase: $e');
      }
    }
    
    // Fall back to local cache
    return _getLocalActivities().take(limit).toList();
  }

  Future<void> updateUserStats(Activity activity) async {
    // Update Firebase stats
    if (_firebaseService.isAuthenticated) {
      try {
        await _firebaseService.updateStats(activity);
      } catch (e) {
        debugPrint('Error updating Firebase stats: $e');
      }
    }
    
    // Update local stats
    final user = getUser();
    if (user != null) {
      final updatedUser = user.copyWith(
        stats: UserStats(
          totalDistanceKm: user.stats.totalDistanceKm + activity.distanceKm,
          totalWorkouts: user.stats.totalWorkouts + 1,
          totalTime: user.stats.totalTime + activity.duration,
        ),
      );
      await saveUser(updatedUser);
    }
  }

  // ============ Loops ============

  Future<void> saveLoops(List<Loop> loops) async {
    final json = jsonEncode(loops.map((l) => l.toJson()).toList());
    await _prefs?.setString(_loopsKey, json);
  }

  List<Loop> getLoops() {
    final json = _prefs?.getString(_loopsKey);
    if (json == null) return [];
    
    try {
      final list = jsonDecode(json) as List;
      return list.map((item) => Loop.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error parsing stored loops: $e');
      return [];
    }
  }

  Future<List<Loop>> getLoopsAsync({int limit = 50}) async {
    // Get from Firebase
    if (_firebaseService.isInitialized) {
      try {
        final loops = await _firebaseService.getLoops(limit: limit);
        if (loops.isNotEmpty) {
          await saveLoops(loops);
          return loops;
        }
      } catch (e) {
        debugPrint('Error fetching loops from Firebase: $e');
      }
    }
    
    // Fall back to local cache
    return getLoops().take(limit).toList();
  }

  Future<void> updateLoop(Loop loop) async {
    // Toggle rise in Firebase
    if (_firebaseService.isInitialized) {
      try {
        await _firebaseService.toggleRise(loop.id);
      } catch (e) {
        debugPrint('Error toggling rise in Firebase: $e');
      }
    }
    
    // Update local cache
    final loops = getLoops();
    final index = loops.indexWhere((l) => l.id == loop.id);
    if (index >= 0) {
      loops[index] = loop;
      await saveLoops(loops);
    }
  }

  /// Clear all local data (for logout)
  Future<void> clearAll() async {
    _cachedUser = null;
    await _prefs?.remove(_userKey);
    await _prefs?.remove(_activitiesKey);
    await _prefs?.remove(_loopsKey);
    await _prefs?.setBool(_isLoggedInKey, false);
  }
}
