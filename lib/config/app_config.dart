class AppConfig {
  const AppConfig._();

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String hrApiUrl = String.fromEnvironment(
    'HR_API_URL',
    defaultValue: '',
  );

  static const String sqiApiUrl = String.fromEnvironment(
    'SQI_API_URL',
    defaultValue: '',
  );

  static const String bpApiUrl = String.fromEnvironment(
    'BP_API_URL',
    defaultValue:'',
  );

  static const String cardiacInsightsApiBase = String.fromEnvironment(
    'CARDIAC_INSIGHTS_API_BASE',
    defaultValue: '',
  );

  static bool get hasGeminiApiKey => geminiApiKey.trim().isNotEmpty;

  static List<String> get warmupUrls => <String>[
        hrApiUrl,
        sqiApiUrl,
        bpApiUrl,
      ];
}
