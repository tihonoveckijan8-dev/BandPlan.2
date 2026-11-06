# Music tools — implementation notes

## Guitar tuner (first implementation)

- Audio input: `record` PCM16, mono, 44.1 kHz stream.
- DSP: pure-Dart normalized autocorrelation with parabolic peak interpolation.
- Standard tuning: E2 (82.41 Hz), A2 (110 Hz), D3 (146.83 Hz), G3 (196.00 Hz), B3 (246.94 Hz), E4 (329.63 Hz).
- Feedback: detected frequency, target frequency, cents offset, and flat/in-tune/sharp state.
- Reference notes: locally synthesized mono WAV; no remote audio assets.
- Lifecycle: stop microphone on app backgrounding and when leaving the tuner; dispose recorder/player on page disposal.
- Web: browser microphone access requires HTTPS and explicit browser permission.

## Platform permissions

The Android build workflow generates the Android runner and inserts `android.permission.RECORD_AUDIO` into its manifest before building.

When the iOS runner is generated, add `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist`.

Use a user-facing value such as: `BandPlan uses the microphone to detect instrument pitch while tuning.`

Do not request microphone permission when the user merely opens Tools. Request it only after they press **Начать настройку**.

## Validation still required

- Run `flutter pub get`, `flutter analyze`, and `flutter test`.
- Test A2 and each open guitar string on a physical Android device in a quiet room.
- Verify browser permission flow on HTTPS.
- Verify iOS permission prompt after generating the iOS runner.
- Check latency, noisy-room stability, and octave errors with real instruments.

Pitch detection is an initial autocorrelation implementation, not a claim of laboratory-grade accuracy. If real-device tests expose octave errors or unstable readings, replace/refine the detector with a YIN/NSDF implementation while preserving the widget and audio lifecycle contracts.
