import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:latlong2/latlong.dart';
import '../models/user.dart' as app_user;
import '../models/activity.dart';
import '../models/loop.dart';

/// Firebase backend service for authentication and data persistence
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseAuth? _auth;
  static FirebaseFirestore? _firestore;
  static GoogleSignIn? _googleSignIn;
  
  FirebaseService._();
  
  static FirebaseService get instance {
    _instance ??= FirebaseService._();
    return _instance!;
  }
  
  FirebaseAuth get auth {
    if (_auth == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _auth!;
  }
  
  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _firestore!;
  }
  
  bool get isInitialized => _auth != null && _firestore != null;
  
  /// Initialize Firebase
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _googleSignIn = GoogleSignIn();
      debugPrint('✅ Firebase initialized');
    } catch (e) {
      debugPrint('⚠️ Firebase initialization failed: $e');
      debugPrint('⚠️ Running in offline mode.');
    }
  }
  
  // ============ Authentication ============
  
  User? get currentUser => _auth?.currentUser;
  bool get isAuthenticated => currentUser != null;
  String? get currentUserId => currentUser?.uid;
  
  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth?.authStateChanges() ?? const Stream.empty();
  
  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    if (_auth == null || _googleSignIn == null) return null;
    
    try {
      // Trigger Google sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) return null;
      
      // Get auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Sign in to Firebase
      final userCredential = await _auth!.signInWithCredential(credential);
      
      // Create/update profile
      if (userCredential.user != null) {
        await _createOrUpdateProfile(userCredential.user!);
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      rethrow;
    }
  }
  
  /// Sign up with email and password
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    String primarySport = 'Running',
  }) async {
    if (_auth == null) return null;
    
    try {
      final userCredential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        // Update display name
        await userCredential.user!.updateDisplayName(name);
        
        // Send email verification
        await userCredential.user!.sendEmailVerification();
        
        // Create profile
        await _createProfile(
          userId: userCredential.user!.uid,
          name: name,
          email: email,
          primarySport: primarySport,
        );
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Email sign-up error: $e');
      rethrow;
    }
  }
  
  /// Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_auth == null) return null;
    
    try {
      return await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('Email sign-in error: $e');
      rethrow;
    }
  }
  
  /// Send phone verification code
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String, int?) onCodeSent,
    required Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    if (_auth == null) return;
    
    await _auth!.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }
  
  /// Sign in with phone credential
  Future<UserCredential?> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    if (_auth == null) return null;
    
    try {
      final userCredential = await _auth!.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await _createOrUpdateProfile(userCredential.user!);
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Phone sign-in error: $e');
      rethrow;
    }
  }
  
  /// Verify OTP and sign in
  Future<UserCredential?> verifyOtpAndSignIn({
    required String verificationId,
    required String otp,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    return signInWithPhoneCredential(credential);
  }
  
  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _auth?.signOut();
  }
  
  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth?.sendPasswordResetEmail(email: email);
  }
  
  // ============ Profile ============
  
  Future<void> _createOrUpdateProfile(User user) async {
    final doc = await _firestore!.collection('users').doc(user.uid).get();
    
    if (!doc.exists) {
      await _createProfile(
        userId: user.uid,
        name: user.displayName ?? 'Athlete',
        email: user.email,
        phone: user.phoneNumber,
        photoUrl: user.photoURL,
      );
    } else {
      // Update last login
      await _firestore!.collection('users').doc(user.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    }
  }
  
  Future<void> _createProfile({
    required String userId,
    required String name,
    String? email,
    String? phone,
    String? photoUrl,
    String primarySport = 'Running',
  }) async {
    if (_firestore == null) return;
    
    await _firestore!.collection('users').doc(userId).set({
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'primarySport': primarySport,
      'bio': null,
      'totalDistanceKm': 0.0,
      'totalWorkouts': 0,
      'totalTimeSeconds': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }
  
  /// Get user profile
  Future<app_user.User?> getProfile() async {
    if (_firestore == null || currentUser == null) return null;
    
    try {
      final doc = await _firestore!.collection('users').doc(currentUser!.uid).get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return app_user.User(
        id: currentUser!.uid,
        name: data['name'] ?? 'Athlete',
        email: data['email'],
        phone: data['phone'],
        photoUrl: data['photoUrl'],
        bio: data['bio'],
        primarySport: data['primarySport'] ?? 'Running',
        stats: app_user.UserStats(
          totalDistanceKm: (data['totalDistanceKm'] ?? 0).toDouble(),
          totalWorkouts: data['totalWorkouts'] ?? 0,
          totalTime: Duration(seconds: data['totalTimeSeconds'] ?? 0),
        ),
      );
    } catch (e) {
      debugPrint('Get profile error: $e');
      return null;
    }
  }
  
  /// Update user profile
  Future<void> updateProfile({
    String? name,
    String? bio,
    String? primarySport,
    String? photoUrl,
  }) async {
    if (_firestore == null || currentUser == null) return;
    
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (bio != null) updates['bio'] = bio;
    if (primarySport != null) updates['primarySport'] = primarySport;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    
    if (updates.isNotEmpty) {
      await _firestore!.collection('users').doc(currentUser!.uid).update(updates);
    }
  }
  
  /// Update user stats after activity
  Future<void> updateStats(Activity activity) async {
    if (_firestore == null || currentUser == null) return;
    
    try {
      await _firestore!.collection('users').doc(currentUser!.uid).update({
        'totalDistanceKm': FieldValue.increment(activity.distanceKm),
        'totalWorkouts': FieldValue.increment(1),
        'totalTimeSeconds': FieldValue.increment(activity.duration.inSeconds),
      });
    } catch (e) {
      debugPrint('Update stats error: $e');
    }
  }
  
  // ============ Activities ============
  
  /// Save activity to Firestore (user-isolated)
  Future<void> saveActivity(Activity activity) async {
    if (_firestore == null || currentUser == null) return;
    
    try {
      await _firestore!
          .collection('users')
          .doc(currentUser!.uid)
          .collection('activities')
          .doc(activity.id)
          .set({
        'activityType': activity.activityType,
        'startTime': Timestamp.fromDate(activity.startTime),
        'endTime': activity.endTime != null ? Timestamp.fromDate(activity.endTime!) : null,
        'durationSeconds': activity.duration.inSeconds,
        'distanceKm': activity.distanceKm,
        'routePoints': activity.routePoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'splits': activity.splits.map((s) => s.inSeconds).toList(),
        'heartRate': activity.heartRate,
        'status': activity.status.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update user stats
      await updateStats(activity);
    } catch (e) {
      debugPrint('Save activity error: $e');
    }
  }
  
  /// Get user's activities (user-isolated)
  Future<List<Activity>> getUserActivities({int limit = 50}) async {
    if (_firestore == null || currentUser == null) return [];
    
    try {
      final querySnapshot = await _firestore!
          .collection('users')
          .doc(currentUser!.uid)
          .collection('activities')
          .orderBy('startTime', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Activity(
          id: doc.id,
          userId: currentUser!.uid,
          activityType: data['activityType'] ?? 'Running',
          startTime: (data['startTime'] as Timestamp).toDate(),
          endTime: data['endTime'] != null 
              ? (data['endTime'] as Timestamp).toDate() 
              : null,
          duration: Duration(seconds: data['durationSeconds'] ?? 0),
          distanceKm: (data['distanceKm'] ?? 0).toDouble(),
          routePoints: (data['routePoints'] as List?)
                  ?.map((p) => LatLng(
                        (p['lat'] as num).toDouble(),
                        (p['lng'] as num).toDouble(),
                      ))
                  .toList() ??
              [],
          splits: (data['splits'] as List?)
                  ?.map((s) => Duration(seconds: s as int))
                  .toList() ??
              [],
          heartRate: data['heartRate']?.toDouble(),
          status: ActivityStatus.values.byName(data['status'] ?? 'completed'),
        );
      }).toList();
    } catch (e) {
      debugPrint('Get activities error: $e');
      return [];
    }
  }
  
  // ============ Loops (Social Feed) ============
  
  /// Get loops feed (global)
  Future<List<Loop>> getLoops({int limit = 50}) async {
    if (_firestore == null) return [];
    
    try {
      final querySnapshot = await _firestore!
          .collection('loops')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      List<Loop> loops = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Get athlete name
        String athleteName = 'Unknown';
        try {
          final userDoc = await _firestore!
              .collection('users')
              .doc(data['userId'])
              .get();
          if (userDoc.exists) {
            athleteName = userDoc.data()?['name'] ?? 'Unknown';
          }
        } catch (_) {}
        
        loops.add(Loop(
          id: doc.id,
          athleteId: data['userId'],
          athleteName: athleteName,
          sportType: data['sportType'] ?? 'Running',
          caption: data['caption'] ?? '',
          tags: List<String>.from(data['tags'] ?? []),
          riseCount: data['riseCount'] ?? 0,
          isVideo: data['isVideo'] ?? false,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          hasRisen: false, // Will be checked separately
        ));
      }
      
      // Check which loops the current user has risen
      if (currentUser != null) {
        for (int i = 0; i < loops.length; i++) {
          final hasRisen = await this.hasRisen(loops[i].id);
          if (hasRisen) {
            loops[i] = loops[i].copyWith(hasRisen: true);
          }
        }
      }
      
      return loops;
    } catch (e) {
      debugPrint('Get loops error: $e');
      return [];
    }
  }
  
  /// Create a new loop from activity
  Future<void> createLoop({
    required String activityId,
    required String caption,
    required String sportType,
    required List<String> tags,
    bool isVideo = false,
    String? mediaUrl,
  }) async {
    if (_firestore == null || currentUser == null) return;
    
    try {
      await _firestore!.collection('loops').add({
        'userId': currentUser!.uid,
        'activityId': activityId,
        'caption': caption,
        'sportType': sportType,
        'tags': tags,
        'isVideo': isVideo,
        'mediaUrl': mediaUrl,
        'riseCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Create loop error: $e');
    }
  }
  
  /// Toggle rise (like) on a loop
  Future<bool> toggleRise(String loopId) async {
    if (_firestore == null || currentUser == null) return false;
    
    try {
      final riseRef = _firestore!
          .collection('loops')
          .doc(loopId)
          .collection('rises')
          .doc(currentUser!.uid);
      
      final riseDoc = await riseRef.get();
      
      if (riseDoc.exists) {
        // Remove rise
        await riseRef.delete();
        await _firestore!.collection('loops').doc(loopId).update({
          'riseCount': FieldValue.increment(-1),
        });
        return false;
      } else {
        // Add rise
        await riseRef.set({
          'userId': currentUser!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _firestore!.collection('loops').doc(loopId).update({
          'riseCount': FieldValue.increment(1),
        });
        return true;
      }
    } catch (e) {
      debugPrint('Toggle rise error: $e');
      return false;
    }
  }
  
  /// Check if user has risen a loop
  Future<bool> hasRisen(String loopId) async {
    if (_firestore == null || currentUser == null) return false;
    
    try {
      final riseDoc = await _firestore!
          .collection('loops')
          .doc(loopId)
          .collection('rises')
          .doc(currentUser!.uid)
          .get();
      
      return riseDoc.exists;
    } catch (e) {
      return false;
    }
  }
}
