import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  static const _unset = Object();
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.profilePhoto,
    this.phone,
    this.currency = 'INR',
    this.language = 'en',
    this.timezone = 'Asia/Kolkata',
    required this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String? profilePhoto;
  final String? phone;
  final String currency;
  final String language;
  final String timezone;
  final DateTime createdAt;

  UserProfile copyWith({
    String? name,
    String? profilePhoto,
    Object? phone = _unset,
    String? currency,
    String? language,
    String? timezone,
  }) {
    return UserProfile(
      id: id,
      email: email,
      name: name ?? this.name,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      currency: currency ?? this.currency,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'name': name,
    'profilePhoto': profilePhoto,
    'phone': phone,
    'currency': currency,
    'language': language,
    'timezone': timezone,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserProfile.fromMap(String id, Map<String, dynamic> map) {
    return UserProfile(
      id: id,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      profilePhoto: map['profilePhoto'] as String?,
      phone: map['phone'] as String?,
      currency: map['currency'] as String? ?? 'INR',
      language: map['language'] as String? ?? 'en',
      timezone: map['timezone'] as String? ?? 'Asia/Kolkata',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    profilePhoto,
    phone,
    currency,
    language,
    timezone,
  ];
}
