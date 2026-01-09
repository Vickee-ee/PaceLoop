/// App-wide constants for PaceLoop
class AppConstants {
  // App Info
  static const String appName = 'PaceLoop';
  static const String appTagline = 'Train. Track. Rise.';
  static const String contentDisclaimer = 
      'Only sports, fitness, and health content is allowed on PaceLoop.';
  
  // Activity Types - GPS Trackable only
  static const List<String> activityTypes = [
    'Running',
    'Cycling',
    'Walking',
  ];
  
  // Sport Tags
  static const List<String> sportTags = [
    '#running',
    '#cycling',
    '#walking',
    '#training',
    '#workout',
    '#fitness',
  ];
  
  // Animation Durations
  static const Duration splashDuration = Duration(milliseconds: 2000);
  static const Duration pageTransition = Duration(milliseconds: 300);
  
  // GPS Settings
  static const int locationUpdateIntervalMs = 1000;
  static const double minDistanceFilterMeters = 5.0;
  
  // Supabase Configuration (replace with your project credentials)
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
}
