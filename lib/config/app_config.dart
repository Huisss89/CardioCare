class AppConfig {
  const AppConfig._();

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String hrApiUrl = String.fromEnvironment(
    'HR_API_URL',
    defaultValue: 'https://cardio-ppg-hr.onrender.com/estimate-hr',
  );

  static const String sqiApiUrl = String.fromEnvironment(
    'SQI_API_URL',
    defaultValue: 'https://cardio-ppg-sqi.onrender.com/analyze-sqi',
  );

  static const String bpApiUrl = String.fromEnvironment(
    'BP_API_URL',
    defaultValue:
        'https://cardio-bp-estimation-ppg-only-1.onrender.com/estimate-bp',
  );

  static const String cardiacInsightsApiBase = String.fromEnvironment(
    'CARDIAC_INSIGHTS_API_BASE',
    defaultValue: 'https://cardiac-insights.onrender.com',
  );

  static bool get hasGeminiApiKey => geminiApiKey.trim().isNotEmpty;

  static List<String> get warmupUrls => <String>[
        hrApiUrl,
        sqiApiUrl,
        bpApiUrl,
      ];
}
