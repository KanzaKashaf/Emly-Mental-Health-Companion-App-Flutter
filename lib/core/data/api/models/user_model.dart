class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? gender;
  final String? dateOfBirth;
  final String? profileImageUrl;
  final String languagePreference;
  final bool isEmailVerified;
  final String subscriptionTier;
  final int sessionsUsed;
  final bool needsProfileCompletion;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.gender,
    this.dateOfBirth,
    this.profileImageUrl,
    required this.languagePreference,
    required this.isEmailVerified,
    required this.subscriptionTier,
    required this.sessionsUsed,
    required this.needsProfileCompletion,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: json['name']?.toString(),
      gender: json['gender']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      profileImageUrl: json['profileImageUrl']?.toString(),
      languagePreference: (json['languagePreference'] ?? 'en').toString(),
      isEmailVerified: json['isEmailVerified'] == true,
      subscriptionTier: (json['subscriptionTier'] ?? 'free').toString(),
      sessionsUsed: json['sessionsUsed'] is int
          ? json['sessionsUsed'] as int
          : int.tryParse((json['sessionsUsed'] ?? 0).toString()) ?? 0,
      needsProfileCompletion: json['needsProfileCompletion'] == true,
    );
  }
}