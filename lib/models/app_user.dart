class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.fetusName,
    required this.profileImageIndex,
    required this.profileBackgroundIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String fetusName;
  final int profileImageIndex;
  final int profileBackgroundIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AppUser.fromFirestore(String uid, Map<String, Object?> data) {
    return AppUser(
      id: uid,
      email: data['email']! as String,
      displayName: data['display_name']! as String,
      fetusName: data['fetus_name'] as String? ?? 'Ding-Dong',
      profileImageIndex: data['profile_image_index'] as int? ?? 0,
      profileBackgroundIndex: data['profile_background_index'] as int? ?? 0,
      createdAt: DateTime.parse(data['created_at']! as String),
      updatedAt: DateTime.parse(data['updated_at']! as String),
    );
  }

  Map<String, Object?> toFirestore() {
    return <String, Object?>{
      'email': email,
      'display_name': displayName,
      'fetus_name': fetusName,
      'profile_image_index': profileImageIndex,
      'profile_background_index': profileBackgroundIndex,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
