import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:speechmatics_translate/data/livekit_agent_config.dart';
import 'package:speechmatics_translate/main.dart' as app;
import 'package:speechmatics_translate/screens/agent_connection_screen.dart';
import 'package:speechmatics_translate/screens/agent_screen.dart';
import 'package:speechmatics_translate/screens/home_screen.dart';
import 'package:speechmatics_translate/state/history_store.dart';
import 'package:speechmatics_translate/state/settings_store.dart';
import 'package:speechmatics_translate/state/speaker_store.dart';
import 'package:speechmatics_translate/widgets/speech_bottom_nav.dart';

// Supply these with an ignored, local --dart-define-from-file JSON file.
// The test writes only Agent setup and never starts a microphone/session.
const _endpoint = String.fromEnvironment('AGENT_SMOKE_TOKEN_ENDPOINT');
const _accessToken = String.fromEnvironment('AGENT_SMOKE_ACCESS_TOKEN');
const _agentName = String.fromEnvironment('AGENT_SMOKE_AGENT_NAME',
    defaultValue: 'everyvoice-agent');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Agent connection setup persists while the Agent stays idle',
      (tester) async {
    expect(_endpoint.trim().isNotEmpty, isTrue,
        reason:
            'Provide AGENT_SMOKE_TOKEN_ENDPOINT in the local defines file.');
    expect(_accessToken.trim().isNotEmpty, isTrue,
        reason: 'Provide AGENT_SMOKE_ACCESS_TOKEN in the local defines file.');

    final config = LiveKitAgentConfig(
      endpoint: _endpoint,
      accessToken: _accessToken,
      agentName: _agentName,
    );
    expect(config.validationError, isNull);
    final store = LiveKitAgentConfigStore();
    debugPrint('Agent setup test: saving isolated connection settings');
    await store.save(config).timeout(const Duration(seconds: 20));

    // Run normal initialization against existing device stores. Never clear
    // Hive or secure storage, or substitute test/mock storage on this phone.
    debugPrint('Agent setup test: starting app');
    await app.main().timeout(const Duration(seconds: 20));
    await _waitFor(tester, find.byType(HomeScreen));
    final preservedBoxes = {
      for (final name in [
        SettingsStore.boxName,
        HistoryStore.boxName,
        SpeakerStore.boxName,
      ])
        name: Map<dynamic, dynamic>.from(Hive.box(name).toMap()),
    };

    debugPrint('Agent setup test: opening Agent');
    await tester.tap(find.descendant(
      of: find.byType(SpeechBottomNav),
      matching: find.text('AGENT'),
    ));
    await _waitFor(tester, find.byType(AgentScreen));
    _expectIdleAgent(tester);

    debugPrint('Agent setup test: capturing idle screen');
    await binding.convertFlutterSurfaceToImage().timeout(_nativeWait);
    await tester.pump().timeout(_nativeWait);
    expect(await binding.takeScreenshot('agent-idle').timeout(_nativeWait),
        isNotEmpty);

    debugPrint('Agent setup test: opening connection setup');
    await tester.tap(find.text('Connection setup'));
    await _waitFor(tester, _field('Endpoint access token'));
    expect(find.byType(AgentConnectionScreen), findsOneWidget);
    _expectSavedFields(tester);
    expect(
        await binding
            .takeScreenshot('agent-connection-setup')
            .timeout(_nativeWait),
        isNotEmpty);

    // Saving unchanged setup exercises the real form and secure store without
    // changing any Home, Batch, personality, or history settings.
    final saveButton = find.widgetWithText(FilledButton, 'Save connection');
    await tester.ensureVisible(saveButton);
    await tester.pump(const Duration(milliseconds: 300)).timeout(_nativeWait);
    debugPrint('Agent setup test: saving connection form');
    await tester.tap(saveButton);
    await _waitFor(tester, find.byType(AgentScreen));
    _expectIdleAgent(tester);

    debugPrint('Agent setup test: checking persisted settings');
    final saved = await store.load().timeout(const Duration(seconds: 20));
    // Compare secrets as booleans so assertion failures never print tokens.
    expect(saved.endpoint == _endpoint.trim(), isTrue,
        reason: 'The saved token endpoint changed.');
    expect(saved.accessToken == _accessToken.trim(), isTrue,
        reason: 'The saved endpoint access token changed.');
    expect(saved.agentName == _agentName.trim(), isTrue,
        reason: 'The saved Agent name changed.');
    for (final entry in preservedBoxes.entries) {
      expect(mapEquals(entry.value, Hive.box(entry.key).toMap()), isTrue,
          reason: 'Agent setup changed the existing ${entry.key} store.');
    }
    expect(
        await binding
            .takeScreenshot('agent-idle-configured')
            .timeout(_nativeWait),
        isNotEmpty);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 90)));
}

const _nativeWait = Duration(seconds: 20);

Finder _field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
      description: 'TextField labelled $label',
    );

void _expectSavedFields(WidgetTester tester) {
  final endpoint = tester.widget<TextField>(_field('Token endpoint URL'));
  final token = tester.widget<TextField>(_field('Endpoint access token'));
  final name = tester.widget<TextField>(_field('Agent name'));
  expect(endpoint.controller?.text == _endpoint.trim(), isTrue,
      reason: 'The setup screen did not load the saved endpoint.');
  expect(token.controller?.text == _accessToken.trim(), isTrue,
      reason: 'The setup screen did not load the saved access token.');
  expect(token.obscureText, isTrue,
      reason: 'The access token must stay hidden, including in screenshots.');
  expect(name.controller?.text == _agentName.trim(), isTrue,
      reason: 'The setup screen did not load the saved Agent name.');
}

void _expectIdleAgent(WidgetTester tester) {
  expect(find.text('Ready when you are'), findsOneWidget);
  expect(find.text('Start conversation'), findsOneWidget);
  expect(find.text('End session'), findsNothing);
  expect(find.text('Microphone on'), findsNothing);
  expect(tester.widget<SpeechBottomNav>(find.byType(SpeechBottomNav)).current,
      SpeechTab.agent);
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  // Home animates continuously, so pumpAndSettle would never finish there.
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100)).timeout(_nativeWait);
  }
  expect(finder, findsOneWidget);
  await tester.pump(const Duration(milliseconds: 400)).timeout(_nativeWait);
}
