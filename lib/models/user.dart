/// User/Athlete model for PaceLoop
class User {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String? bio;
  final String primarySport;
  final UserStats stats;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.bio,
    this.primarySport = 'Running',
    UserStats? stats,
    DateTime? createdAt,
  })  : stats = stats ?? UserStats(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        'bio': bio,
        'primarySport': primarySport,
        'stats': stats.toJson(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phone: json['phone'],
        photoUrl: json['photoUrl'],
        bio: json['bio'],
        primarySport: json['primarySport'] ?? 'Running',
        stats: UserStats.fromJson(json['stats'] ?? {}),
        createdAt: DateTime.parse(json['createdAt']),
      );

  User copyWith({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? bio,
    String? primarySport,
    UserStats? stats,
  }) =>
      User(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        photoUrl: photoUrl ?? this.photoUrl,
        bio: bio ?? this.bio,
        primarySport: primarySport ?? this.primarySport,
        stats: stats ?? this.stats,
        createdAt: createdAt,
      );
}

/// User statistics
class UserStats {
  final double totalDistanceKm;
  final int totalWorkouts;
  final Duration totalTime;

  UserStats({
    this.totalDistanceKm = 0,
    this.totalWorkouts = 0,
    this.totalTime = Duration.zero,
  });

  Map<String, dynamic> toJson() => {
        'totalDistanceKm': totalDistanceKm,
        'totalWorkouts': totalWorkouts,
        'totalTimeSeconds': totalTime.inSeconds,
      };

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalDistanceKm: (json['totalDistanceKm'] ?? 0).toDouble(),
        totalWorkouts: json['totalWorkouts'] ?? 0,
        totalTime: Duration(seconds: json['totalTimeSeconds'] ?? 0),
      );

  UserStats copyWith({
    double? totalDistanceKm,
    int? totalWorkouts,
    Duration? totalTime,
  }) =>
      UserStats(
        totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
        totalWorkouts: totalWorkouts ?? this.totalWorkouts,
        totalTime: totalTime ?? this.totalTime,
      );
}
