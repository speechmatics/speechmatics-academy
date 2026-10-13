import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speechmatics_translate/data/livekit_agent_config.dart';
import 'package:speechmatics_translate/screens/agent_connection_screen.dart';

void main() {
  testWidgets('hosted setup shows server ID instead of endpoint credentials',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({
      'livekit_agent_connection_mode': 'hostedDevelopment',
      'livekit_agent_development_server_id': 'test-server-123',
      'livekit_agent_endpoint': 'https://example.com/token',
      'livekit_agent_access_token': 'saved-custom-token',
      'livekit_agent_name': 'everyvoice-agent',
    });
    await tester.pumpWidget(const MaterialApp(home: AgentConnectionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Connection method'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Server ID'), findsOneWidget);
    expect(
        find.widgetWithText(TextField, 'Endpoint access token'), findsNothing);
    expect(find.widgetWithText(TextField, 'Token endpoint URL'), findsNothing);
    expect(find.widgetWithText(TextField, 'Agent name'), findsOneWidget);
    expect(find.textContaining('development only'), findsOneWidget);
  });

  testWidgets(
      'switching to hosted validates and saves while retaining fallback',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'livekit_agent_connection_mode': 'customEndpoint',
      'livekit_agent_endpoint': 'https://example.com/token',
      'livekit_agent_access_token': 'saved-custom-token',
      'livekit_agent_name': 'everyvoice-agent',
    });
    await _openSetup(tester);
    expect(find.widgetWithText(TextField, 'Endpoint access token'),
        findsOneWidget);
    await tester.tap(find.text('Custom token endpoint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LiveKit hosted (development)').last);
    await tester.pumpAndSettle();

    final serverId = find.widgetWithText(TextField, 'Server ID');
    await tester.enterText(serverId, 'https://wrong.example.com');
    await _tapSave(tester);
    expect(find.textContaining('not a URL'), findsOneWidget);
    expect(
        await const FlutterSecureStorage()
            .read(key: 'livekit_agent_connection_mode'),
        'customEndpoint');

    await tester.ensureVisible(serverId);
    await tester.pumpAndSettle();
    await tester.enterText(serverId, 'entered-hosted-server');
    await _tapSave(tester);
    expect(find.text('Open setup'), findsOneWidget);
    final loaded = await LiveKitAgentConfigStore().load();
    expect(loaded.mode, LiveKitAgentConnectionMode.hostedDevelopment);
    expect(loaded.developmentServerId, 'entered-hosted-server');
    expect(loaded.endpoint, 'https://example.com/token');
    expect(loaded.accessToken, 'saved-custom-token');
  });

  testWidgets('switching back to custom restores saved endpoint and token',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'livekit_agent_connection_mode': 'hostedDevelopment',
      'livekit_agent_development_server_id': 'test-server-123',
      'livekit_agent_endpoint': 'https://example.com/token',
      'livekit_agent_access_token': 'saved-custom-token',
      'livekit_agent_name': 'everyvoice-agent',
    });
    await _openSetup(tester);
    await tester.tap(find.text('LiveKit hosted (development)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom token endpoint').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Server ID'), findsNothing);
    expect(
        tester
            .widget<TextField>(
                find.widgetWithText(TextField, 'Token endpoint URL'))
            .controller!
            .text,
        'https://example.com/token');
    expect(
        tester
            .widget<TextField>(
                find.widgetWithText(TextField, 'Endpoint access token'))
            .controller!
            .text,
        'saved-custom-token');

    await _tapSave(tester);
    final loaded = await LiveKitAgentConfigStore(
            defaultDevelopmentServerId: 'build-server-123')
        .load();
    expect(loaded.mode, LiveKitAgentConnectionMode.customEndpoint);
    expect(loaded.developmentServerId, 'test-server-123');
  });
}

Future<void> _tapSave(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Save connection'), 200,
      scrollable: find
          .descendant(
              of: find.byType(ListView), matching: find.byType(Scrollable))
          .first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save connection'));
  await tester.pumpAndSettle();
}

Future<void> _openSetup(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const AgentConnectionScreen())),
                  child: const Text('Open setup'))))));
  await tester.tap(find.text('Open setup'));
  await tester.pumpAndSettle();
}
