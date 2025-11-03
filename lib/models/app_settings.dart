// =============================================
// GROWLOG - App Settings Model
// =============================================

class AppSettings {
  final String language;      // 'de' oder 'en'
  final bool isDarkMode;

  AppSettings({
    this.language = 'de',
    this.isDarkMode = false,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      language: map['language'] as String? ?? 'de',
      isDarkMode: (map['is_dark_mode'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'language': language,
      'is_dark_mode': isDarkMode ? 1 : 0,
    };
  }

  AppSettings copyWith({
    String? language,
    bool? isDarkMode,
  }) {
    return AppSettings(
      language: language ?? this.language,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}
