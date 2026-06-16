import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'data/api_keys.dart';
import 'models/sample_data.dart';
import 'routes.dart';
import 'state/history_store.dart';
import 'state/job_controller.dart';
import 'state/settings_store.dart';
import 'state/speaker_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  await Hive.initFlutter();
  final settingsBox = await Hive.openBox(SettingsStore.boxName);
  final historyBox = await Hive.openBox(HistoryStore.boxName);
  final speakersBox = await Hive.openBox(SpeakerStore.boxName);

  final settings = SettingsStore(settingsBox);
  final history = HistoryStore(historyBox)..seedIfEmpty(sampleHistory);
  final speakers = SpeakerStore(speakersBox);
  final jobController = JobController(apiKeys: ApiKeys(), history: history);

  runApp(SpeechmaticsTranslateApp(
    settings: settings,
    history: history,
    speakers: speakers,
    jobController: jobController,
  ));
}

class SpeechmaticsTranslateApp extends StatelessWidget {
  const SpeechmaticsTranslateApp({
    super.key,
    required this.settings,
    required this.history,
    required this.speakers,
    required this.jobController,
  });

  final SettingsStore settings;
  final HistoryStore history;
  final SpeakerStore speakers;
  final JobController jobController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<HistoryStore>.value(value: history),
        ChangeNotifierProvider<SpeakerStore>.value(value: speakers),
        ChangeNotifierProvider<JobController>.value(value: jobController),
      ],
      child: MaterialApp(
        title: 'EveryVoice',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: Routes.home,
        routes: Routes.map,
      ),
    );
  }
}
