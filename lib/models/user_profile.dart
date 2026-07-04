class UserProfile {
  final String uid;
  final String userName;
  final String? iconUrl;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.userName,
    this.iconUrl,
    required this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String id) {
    return UserProfile(
      uid: id,
      userName: data['userName'] as String,
      iconUrl: data['iconUrl'] as String?,
      createdAt: data['createdAt'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'iconUrl': iconUrl,
      'createdAt': createdAt,
    };
  }
}
