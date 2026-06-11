class UserModel {
  final String id; // Firebase UID
  final String phone;
  final String name;
  final String userType; // 'driver' or 'load_owner'
  final String? companyName;
  final String? city;
  final String? profilePhotoUrl;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.userType,
    this.companyName,
    this.city,
    this.profilePhotoUrl,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      phone: map['phone'] as String,
      name: map['name'] as String,
      userType: map['user_type'] as String,
      companyName: map['company_name'] as String?,
      city: map['city'] as String?,
      profilePhotoUrl: map['profile_photo_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'user_type': userType,
      'company_name': companyName,
      'city': city,
      'profile_photo_url': profilePhotoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
