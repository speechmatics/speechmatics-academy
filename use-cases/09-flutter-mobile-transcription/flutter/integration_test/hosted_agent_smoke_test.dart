import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:speechmatics_translate/data/livekit_agent_config.dart';
import 'package:speechmatics_translate/data/livekit_agent_token_source.dart';
import 'package:speechmatics_translate/main.dart' as app;
import 'package:speechmatics_translate/screens/agent_connection_screen.dart';
import 'package:speechmatics_translate/screens/agent_screen.dart';
import 'package:speechmatics_translate/screens/home_screen.dart';
import 'package:speechmatics_translate/state/history_store.dart';
import 'package:speechmatics_translate/state/settings_store.dart';
import 'package:speechmatics_translate/state/speaker_store.dart';
import 'package:speechmatics_translate/widgets/speech_bottom_nav.dart';

// Run with the existing screenshot driver and --keep-app-running. Supply only
// the hosted Server ID through an ignored, local --dart-define-from-file file.
// This test uses existing device stores; it never seeds or clears configuration.
const _serverId = String.fromEnvironment('LIVEKIT_TOKEN_SERVER_ID');
const _agentName = 'everyvoice-agent';
const _serverUrl = 'wss://speechmatics-58s7pbzh.livekit.cloud';
const _nativeWait = Duration(seconds: 20);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Hosted Agent setup fetches a token and stays idle', (tester) async {
    expect(_serverId.trim().isNotEmpty, isTrue,
        reason: 'Provide LIVEKIT_TOKEN_SERVER_ID in the local defines file.');

    debugPrint('Hosted Agent test: starting the existing app');
    await app.main().timeout(_nativeWait);
    await _waitFor(tester, find.byType(HomeScreen));
    final preservedBoxes = {
      for (final name in [
        SettingsStore.boxName,
        HistoryStore.boxName,
        SpeakerStore.boxName,
      ])
        name: Map<dynamic, dynamic>.from(Hive.box(name).toMap()),
    };

    debugPrint('Hosted Agent test: checking loaded connection mode');
    final store = LiveKitAgentConfigStore();
    final config = await store.load().timeout(_nativeWait);
    _expectHostedConfig(config);
    expect(config.validationError, isNull);

    // Request only connection credentials. No room connection, Agent session,
    // microphone, or speech-model request is made by this smoke test.
    debugPrint('Hosted Agent test: requesting connection credentials');
    final tokenSource = LiveKitAgentTokenSource(config);
    try {
      final response = await tokenSource
          .fetch(lk.TokenRequestOptions(
            agentName: _agentName,
            agentMetadata: jsonEncode({'personality': ''}),
          ))
          .timeout(_nativeWait);
      expect(response.serverUrl == _serverUrl, isTrue,
          reason: 'The hosted token service returned a different project.');
      expect(response.participantToken.trim().isNotEmpty, isTrue,
          reason: 'The hosted token service returned an empty token.');
    } finally {
      tokenSource.cancel();
    }
    debugPrint('Hosted Agent test: connection credentials received');

    await tester
        .tap(find.descendant(
          of: find.byType(SpeechBottomNav),
          matching: find.text('AGENT'),
        ))
        .timeout(_nativeWait);
    await _waitFor(tester, find.byType(AgentScreen));
    _expectIdleAgent(tester);

    debugPrint('Hosted Agent test: opening hosted connection setup');
    await tester.tap(find.text('Connection setup')).timeout(_nativeWait);
    await _waitFor(tester, _field('Server ID'));
    expect(find.byType(AgentConnectionScreen), findsOneWidget);
    final mode = tester.widget<DropdownButton<LiveKitAgentConnectionMode>>(
        find.byWidgetPredicate(
            (widget) => widget is DropdownButton<LiveKitAgentConnectionMode>,
            description: 'Agent connection mode dropdown'));
    expect(mode.value, LiveKitAgentConnectionMode.hostedDevelopment);
    final server = tester.widget<TextField>(_field('Server ID'));
    final name = tester.widget<TextField>(_field('Agent name'));
    expect(server.controller?.text == _serverId.trim(), isTrue,
        reason: 'The setup screen did not load the hosted Server ID.');
    expect(name.controller?.text == _agentName, isTrue,
        reason: 'The setup screen did not load the expected Agent name.');
    expect(_field('Token endpoint URL'), findsNothing);
    expect(_field('Endpoint access token'), findsNothing);

    debugPrint('Hosted Agent test: capturing hosted connection setup');
    await binding.convertFlutterSurfaceToImage().timeout(_nativeWait);
    await tester.pump().timeout(_nativeWait);
    expect(
        await binding
            .takeScreenshot('agent-hosted-connection')
            .timeout(_nativeWait),
        isNotEmpty);

    debugPrint('Hosted Agent test: saving unchanged connection setup');
    final saveButton = find.widgetWithText(FilledButton, 'Save connection');
    await tester.ensureVisible(saveButton).timeout(_nativeWait);
    await tester.pump(const Duration(milliseconds: 300)).timeout(_nativeWait);
    await tester.tap(saveButton).timeout(_nativeWait);
    await _waitFor(tester, find.byType(AgentScreen));
    _expectIdleAgent(tester);
    _expectHostedConfig(await store.load().timeout(_nativeWait));
    for (final entry in preservedBoxes.entries) {
      expect(mapEquals(entry.value, Hive.box(entry.key).toMap()), isTrue,
          reason: 'Hosted Agent setup changed the existing ${entry.key} store.');
    }

    debugPrint('Hosted Agent test: capturing idle Agent');
    expect(
        await binding.takeScreenshot('agent-hosted-idle').timeout(_nativeWait),
        isNotEmpty);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 90)));
}

void _expectHostedConfig(LiveKitAgentConfig config) {
  expect(config.mode, LiveKitAgentConnectionMode.hostedDevelopment);
  // IDs and credentials are compared as booleans to keep failure logs private.
  expect(config.developmentServerId == _serverId.trim(), isTrue,
      reason: 'Hosted setup did not use the configured Server ID.');
  expect(config.agentName == _agentName, isTrue,
      reason: 'Hosted setup did not retain the expected Agent name.');
}

Finder _field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
      description: 'TextField labelled $label',
    );

void _expectIdleAgent(WidgetTester tester) {
  expect(find.text('Ready when you are'), findsOneWidget);
  expect(find.text('Start conversation'), findsOneWidget);
  expect(find.text('End session'), findsNothing);
  expect(find.text('Microphone on'), findsNothing);
  expect(tester.widget<SpeechBottomNav>(find.byType(SpeechBottomNav)).current,
      SpeechTab.agent);
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  // Home animates continuously; bound each native pump as well as the loop.
  final deadline = DateTime.now().add(_nativeWait);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100)).timeout(_nativeWait);
  }
  expect(finder, findsOneWidget);
  await tester.pump(const Duration(milliseconds: 400)).timeout(_nativeWait);
}
