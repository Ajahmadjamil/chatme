class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String? username;
  final String? bio;
  final String? avatarUrl;

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.username,
    this.bio,
    this.avatarUrl,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}