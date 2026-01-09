/// Loop (social post) model for PaceLoop
class Loop {
  final String id;
  final String athleteId;
  final String athleteName;
  final String? athletePhotoUrl;
  final String sportType;
  final String? mediaUrl;
  final bool isVideo;
  final String caption;
  final List<String> tags;
  final int riseCount;
  final bool hasRisen;
  final DateTime createdAt;

  Loop({
    required this.id,
    required this.athleteId,
    required this.athleteName,
    this.athletePhotoUrl,
    required this.sportType,
    this.mediaUrl,
    this.isVideo = false,
    required this.caption,
    this.tags = const [],
    this.riseCount = 0,
    this.hasRisen = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'athleteId': athleteId,
        'athleteName': athleteName,
        'athletePhotoUrl': athletePhotoUrl,
        'sportType': sportType,
        'mediaUrl': mediaUrl,
        'isVideo': isVideo,
        'caption': caption,
        'tags': tags,
        'riseCount': riseCount,
        'hasRisen': hasRisen,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Loop.fromJson(Map<String, dynamic> json) => Loop(
        id: json['id'],
        athleteId: json['athleteId'],
        athleteName: json['athleteName'],
        athletePhotoUrl: json['athletePhotoUrl'],
        sportType: json['sportType'],
        mediaUrl: json['mediaUrl'],
        isVideo: json['isVideo'] ?? false,
        caption: json['caption'],
        tags: List<String>.from(json['tags'] ?? []),
        riseCount: json['riseCount'] ?? 0,
        hasRisen: json['hasRisen'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
      );

  Loop copyWith({
    int? riseCount,
    bool? hasRisen,
  }) =>
      Loop(
        id: id,
        athleteId: athleteId,
        athleteName: athleteName,
        athletePhotoUrl: athletePhotoUrl,
        sportType: sportType,
        mediaUrl: mediaUrl,
        isVideo: isVideo,
        caption: caption,
        tags: tags,
        riseCount: riseCount ?? this.riseCount,
        hasRisen: hasRisen ?? this.hasRisen,
        createdAt: createdAt,
      );
}
