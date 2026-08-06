import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  const AppSettings({
    this.theme = 'system',
    this.language = 'en',
    this.currency = 'INR',
    this.biometric = false,
    this.notifications = true,
    this.pinEnabled = false,
  });

  final String theme; // light | dark | system
  final String language;
  final String currency;
  final bool biometric;
  final bool notifications;
  final bool pinEnabled;

  AppSettings copyWith({
    String? theme,
    String? language,
    String? currency,
    bool? biometric,
    bool? notifications,
    bool? pinEnabled,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      biometric: biometric ?? this.biometric,
      notifications: notifications ?? this.notifications,
      pinEnabled: pinEnabled ?? this.pinEnabled,
    );
  }

  Map<String, dynamic> toMap() => {
        'theme': theme,
        'language': language,
        'currency': currency,
        'biometric': biometric,
        'notifications': notifications,
        'pinEnabled': pinEnabled,
      };

  factory AppSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AppSettings();
    return AppSettings(
      theme: map['theme'] as String? ?? 'system',
      language: map['language'] as String? ?? 'en',
      currency: map['currency'] as String? ?? 'INR',
      biometric: map['biometric'] as bool? ?? false,
      notifications: map['notifications'] as bool? ?? true,
      pinEnabled: map['pinEnabled'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [theme, language, currency, biometric, notifications, pinEnabled];
}
