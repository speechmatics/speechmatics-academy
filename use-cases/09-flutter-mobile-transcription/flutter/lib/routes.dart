import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/speaker_enrollment_screen.dart';
import 'screens/synthesizing_screen.dart';
import 'screens/transcription_screen.dart';
import 'screens/language_hints_screen.dart';

/// Named routes for the whole design flow.
class Routes {
  Routes._();

  static const home = '/';
  static const upload = '/upload';
  static const history = '/history';
  static const settings = '/settings';
  static const recording = '/recording';
  static const synthesizing = '/synthesizing';
  static const transcription = '/transcription';
  static const hints = '/hints';
  static const enroll = '/enroll';

  static Map<String, WidgetBuilder> map = {
    home: (_) => const HomeScreen(),
    upload: (_) => const UploadScreen(),
    history: (_) => const HistoryScreen(),
    settings: (_) => const SettingsScreen(),
    recording: (_) => const RecordingScreen(),
    synthesizing: (_) => const SynthesizingScreen(),
    transcription: (_) => const TranscriptionScreen(),
    hints: (_) => const LanguageHintsScreen(),
    enroll: (_) => const SpeakerEnrollmentScreen(),
  };
}
