## Secure deployment notes

### What changed
- The Gemini key is no longer hardcoded in source.
- Runtime API URLs are now centralized in `lib/config/app_config.dart`.

### Build with runtime secrets
Use `--dart-define` when building:

```bash
flutter build apk --dart-define=GEMINI_API_KEY=your_key_here
```

Optional endpoint overrides:

```bash
flutter build apk \
  --dart-define=GEMINI_API_KEY=your_key_here \
  --dart-define=HR_API_URL=https://your-hr-api.example.com/estimate-hr \
  --dart-define=SQI_API_URL=https://your-sqi-api.example.com/analyze-sqi \
  --dart-define=BP_API_URL=https://your-bp-api.example.com/estimate-bp
```

### Important
- A mobile app cannot truly hide a secret from a determined attacker.
- For real production security, move Gemini calls behind your own backend and keep the API key only on the server.
- Firebase `apiKey` values in `firebase_options.dart` are app identifiers, not private secrets. Protect Firebase with Authentication, App Check, and strict Firestore rules.
