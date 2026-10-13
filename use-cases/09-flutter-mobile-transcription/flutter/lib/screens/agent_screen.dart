import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/livekit_agent_config.dart';
import '../data/livekit_agent_transport.dart';
import '../models/livekit_agent.dart';
import '../routes.dart';
import '../state/history_store.dart';
import '../state/livekit_agent_controller.dart';
import '../state/settings_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';
import '../widgets/speech_bottom_nav.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});
  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final _config = LiveKitAgentConfigStore();
  final _scroll = ScrollController();
  LiveKitAgentController? _controller;
  bool _preparing = false;
  bool _resumeHandled = false;
  int _request = 0;
  String? _setupError;

  bool get _active => _preparing || (_controller?.isActive ?? false);
  LiveKitAgentPhase get _phase => _preparing
      ? LiveKitAgentPhase.connecting
      : _controller?.phase ?? LiveKitAgentPhase.idle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resumeHandled) return;
    _resumeHandled = true;
    if (ModalRoute.of(context)?.settings.arguments == 'resume-live') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_start());
      });
    }
  }

  Future<void> _start() async {
    if (_active) return;
    final request = ++_request;
    final history = context.read<HistoryStore>();
    final personality = context.read<SettingsStore>().agentPersonalityText;
    _controller?.removeListener(_changed);
    _controller?.dispose();
    setState(() {
      _controller = null;
      _preparing = true;
      _setupError = null;
    });
    try {
      final config = await _config.load();
      if (!mounted || request != _request) return;
      final validationError = config.validationError;
      if (validationError != null) {
        setState(() {
          _setupError = validationError;
          _preparing = false;
        });
        return;
      }
      final controller = LiveKitAgentController(
        transport:
            LiveKitSdkAgentTransport(config: config, personality: personality),
        saveHistory: history.add,
      );
      controller.addListener(_changed);
      setState(() {
        _controller = controller;
        _preparing = false;
      });
      await controller.start();
    } on FormatException catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _setupError = error.message;
          _preparing = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _setupError =
              'Unable to load Agent setup. Open connection settings and try again.';
          _preparing = false;
        });
      }
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _end() async {
    ++_request;
    if (_preparing) setState(() => _preparing = false);
    await _controller?.end();
  }

  @override
  void dispose() {
    ++_request;
    _controller?.removeListener(_changed);
    _controller?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _status => switch (_phase) {
        LiveKitAgentPhase.idle =>
          _controller == null ? 'Ready when you are' : 'Session ended',
        LiveKitAgentPhase.connecting => 'Connecting',
        LiveKitAgentPhase.listening => 'Listening',
        LiveKitAgentPhase.thinking => 'Thinking',
        LiveKitAgentPhase.speaking => 'Speaking',
        LiveKitAgentPhase.reconnecting => 'Reconnecting',
        LiveKitAgentPhase.ending => 'Ending session',
        LiveKitAgentPhase.error => 'Connection ended',
      };

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final messages = controller?.messages ?? const <LiveKitAgentMessage>[];
    final error = _setupError ?? controller?.error;
    final ending = _phase == LiveKitAgentPhase.ending;
    final canMute = _active &&
        !ending &&
        !_preparing &&
        _phase != LiveKitAgentPhase.connecting &&
        !(controller?.microphoneBusy ?? true);
    return PopScope(
      canPop: !_active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _active) unawaited(_end());
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: BrandTopBar(trailing: [
          IconButton(
              tooltip: 'Agent connection setup',
              onPressed: _active
                  ? null
                  : () =>
                      Navigator.of(context).pushNamed(Routes.agentConnection),
              icon: const Icon(Icons.tune)),
        ]),
        bottomNavigationBar: _active
            ? const SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('End the session to return to other tabs.',
                      textAlign: TextAlign.center),
                ))
            : const SpeechBottomNav(current: SpeechTab.agent),
        body: SafeArea(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Voice agent.', style: AppType.display()),
            const SizedBox(height: 8),
            Text('Speak naturally. Your agent listens and replies aloud.',
                style:
                    AppType.body(size: 14, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.graphic_eq,
                        color: Colors.white, size: 28)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Semantics(
                          liveRegion: true,
                          child:
                              Text(_status, style: AppType.headline(size: 19))),
                      const SizedBox(height: 3),
                      Text(
                          _active
                              ? (controller?.microphoneEnabled ?? false)
                                  ? 'Microphone on'
                                  : 'Microphone off'
                              : 'Powered by Speechmatics',
                          style: AppType.body(
                              size: 12, color: AppColors.onSurfaceVariant)),
                    ])),
                if (_phase == LiveKitAgentPhase.connecting ||
                    ending ||
                    _phase == LiveKitAgentPhase.reconnecting)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                    liveRegion: true,
                    child: Text(error,
                        style: AppType.body(size: 13, color: AppColors.error))),
              ),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.forum_outlined,
                          size: 44, color: AppColors.primary),
                      const SizedBox(height: 14),
                      Text(
                          _active
                              ? 'Your conversation will appear here.'
                              : 'A conversation starts with you.',
                          textAlign: TextAlign.center,
                          style: AppType.headline(size: 20)),
                      const SizedBox(height: 8),
                      Text(
                          _active
                              ? 'You can interrupt the agent while it speaks.'
                              : 'Start a session, then say hello.',
                          textAlign: TextAlign.center,
                          style: AppType.body(
                              size: 14, color: AppColors.onSurfaceVariant)),
                      if (!_active)
                        TextButton.icon(
                            onPressed: () => Navigator.of(context)
                                .pushNamed(Routes.agentConnection),
                            icon: const Icon(Icons.settings_outlined, size: 18),
                            label: const Text('Connection setup')),
                    ]))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          _caption(messages[index])),
            ),
            if (controller?.saved ?? false)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Conversation saved to History.',
                    textAlign: TextAlign.center,
                    style: AppType.body(
                        size: 12, color: AppColors.onSurfaceVariant)),
              ),
            Row(children: [
              if (_active) ...[
                IconButton.filledTonal(
                    tooltip: controller?.microphoneEnabled ?? false
                        ? 'Mute microphone'
                        : 'Unmute microphone',
                    onPressed: canMute
                        ? () => unawaited(controller!.toggleMicrophone())
                        : null,
                    icon: Icon(controller?.microphoneEnabled ?? false
                        ? Icons.mic
                        : Icons.mic_off)),
                const SizedBox(width: 12),
              ],
              Expanded(
                  child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor:
                        _active ? AppColors.technicalBg : AppColors.primary),
                onPressed: ending
                    ? null
                    : () => unawaited(_active ? _end() : _start()),
                icon: Icon(_active ? Icons.stop_rounded : Icons.mic_rounded),
                label: Text(_active
                    ? 'End session'
                    : controller == null
                        ? 'Start conversation'
                        : 'Start new conversation'),
              )),
            ]),
          ]),
        )),
      ),
    );
  }

  Widget _caption(LiveKitAgentMessage message) => Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          key: ValueKey(message.id),
          constraints: const BoxConstraints(maxWidth: 520),
          margin: EdgeInsets.fromLTRB(
              message.isUser ? 28 : 0, 0, message.isUser ? 0 : 28, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: message.isUser
                  ? AppColors.primaryContainer
                  : AppColors.surface,
              border: Border.all(color: AppColors.outlineVariant),
              borderRadius: BorderRadius.circular(16)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message.isUser ? 'YOU' : 'AGENT',
                style: AppType.labelCaps(size: 9, color: AppColors.primary)),
            const SizedBox(height: 6),
            SelectableText(message.text,
                style: AppType.body(size: 15, height: 1.4)),
          ]),
        ),
      );
}
