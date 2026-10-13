import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;

import '../models/livekit_agent.dart';
import 'livekit_agent_config.dart';
import 'livekit_agent_token_source.dart';

/// Session supplies official lk.transcription messages and remote audio playback.
class LiveKitSdkAgentTransport extends LiveKitAgentTransport {
  LiveKitSdkAgentTransport(
      {required LiveKitAgentConfig config,
      required String personality,
      LiveKitAgentRoom? room,
      http.Client? tokenClient}) {
    if (personality.runes.length > 12000) {
      throw const FormatException(
          'Personality must be at most 12,000 characters.');
    }
    _tokens = LiveKitAgentTokenSource(config, client: tokenClient);
    _room = room ?? LiveKitAgentRoom();
    _session = lk.Session.withAgent(
      config.agentName.trim(),
      agentMetadata: jsonEncode({'personality': personality}),
      tokenSource: _tokens,
      // Capture only after a valid token and successful room connection.
      options: lk.SessionOptions(room: _room, preConnectAudio: false),
    );
    _session.addListener(_changed);
  }
  late final lk.Session _session;
  late final LiveKitAgentRoom _room;
  late final LiveKitAgentTokenSource _tokens;
  bool _interrupted = false;
  bool _closed = false;
  bool _started = false;
  bool _connectedOnce = false;

  void _changed() {
    if (_session.connectionState == lk.ConnectionState.connected) {
      _connectedOnce = true;
    }
    if (!_closed && !_interrupted) notifyListeners();
  }

  @override
  String? get error {
    final sessionError = _session.error;
    if (sessionError != null) {
      // Never display arbitrary server bodies, JWTs or endpoint credentials.
      final cause = sessionError.cause;
      if (cause is StateError) return cause.message.toString();
      return 'Unable to connect to the Agent. Check connection setup and microphone permission.';
    }
    if (_session.agent.error != null) return _session.agent.error!.message;
    if (_connectedOnce &&
        !_interrupted &&
        _session.connectionState == lk.ConnectionState.disconnected) {
      return 'The Agent session disconnected. Start again to reconnect.';
    }
    return null;
  }

  @override
  LiveKitAgentPhase get phase {
    if (error != null) return LiveKitAgentPhase.error;
    if (_session.connectionState == lk.ConnectionState.reconnecting) {
      return LiveKitAgentPhase.reconnecting;
    }
    return switch (_session.agent.agentState) {
      lk.AgentState.listening => LiveKitAgentPhase.listening,
      lk.AgentState.thinking => LiveKitAgentPhase.thinking,
      lk.AgentState.speaking => LiveKitAgentPhase.speaking,
      _ => _started ? LiveKitAgentPhase.connecting : LiveKitAgentPhase.idle,
    };
  }

  @override
  List<LiveKitAgentMessage> get messages => _session.messages
      .map((message) => LiveKitAgentMessage(
            id: message.id,
            timestamp: message.timestamp,
            text: message.content.text,
            isUser: message.content is lk.UserTranscript ||
                message.content is lk.UserInput,
          ))
      .toList(growable: false);

  @override
  bool get microphoneEnabled => !_interrupted && _room.microphoneEnabled;

  @override
  Future<void> start() async {
    if (_interrupted) return;
    _started = true;
    await _session.start(); // SDK reports start failures through Session.error.
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_interrupted) return;
    await _room.setMicrophoneEnabled(enabled);
    // unmute can finish getUserMedia after Room has removed its participant.
    // The retained track is the only reliable owner of that late native stream.
    if (_interrupted) await _room.stopOwnedMicrophone();
    _changed();
  }

  @override
  Future<void> interrupt() async {
    _interrupted = true;
    _tokens.cancel();
    _room.cancelled = true;
    try {
      await _room.stopOwnedMicrophone();
    } finally {
      await _session.end();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _tokens.cancel();
    _session.removeListener(_changed);
    try {
      await _room.disposeOwnedMicrophone();
    } finally {
      try {
        await _session.end();
      } finally {
        await _session.dispose();
        await _room.dispose();
        super.dispose();
      }
    }
  }
}

/// Session.start enables the microphone immediately after Room.connect returns.
/// Publish an explicitly owned track first, so that call reuses the publication
/// instead of hiding getUserMedia ownership inside a LocalParticipant future.
class LiveKitAgentRoom extends lk.Room {
  bool cancelled = false;
  LiveKitAgentMicrophone? _ownedMicrophone;
  bool get microphoneEnabled =>
      localParticipant?.isMicrophoneEnabled() ?? false;

  Future<void> stopOwnedMicrophone() async {
    await _ownedMicrophone?.stop();
  }

  /// Called after pending start and microphone operations have settled. Stop
  /// once more: a pending unmute may have replaced the native stream meanwhile.
  Future<void> disposeOwnedMicrophone() async {
    final microphone = _ownedMicrophone;
    if (microphone == null) return;
    try {
      await microphone.stop();
    } finally {
      await microphone.dispose();
      _ownedMicrophone = null;
    }
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    await localParticipant?.setMicrophoneEnabled(enabled);
  }

  /// Native boundaries are overridable so permission/connection races can be
  /// exercised without opening a real microphone or network connection.
  Future<void> connectRoom(
    String url,
    String token, {
    lk.ConnectOptions? connectOptions,
    lk.FastConnectOptions? fastConnectOptions,
  }) =>
      super.connect(url, token,
          connectOptions: connectOptions,
          fastConnectOptions: fastConnectOptions);

  Future<LiveKitAgentMicrophone> createMicrophone() async {
    final participant = localParticipant;
    if (participant == null) throw StateError('Agent room disconnected.');
    final track =
        await lk.LocalAudioTrack.create(roomOptions.defaultAudioCaptureOptions);
    return _SdkAgentMicrophone(participant, track);
  }

  @override
  Future<void> connect(
    String url,
    String token, {
    lk.ConnectOptions? connectOptions,
    lk.RoomOptions? roomOptions,
    lk.FastConnectOptions? fastConnectOptions,
  }) async {
    if (cancelled) throw StateError('Agent connection cancelled.');
    await connectRoom(url, token,
        connectOptions: connectOptions, fastConnectOptions: fastConnectOptions);
    if (cancelled) {
      await disconnect();
      throw StateError('Agent connection cancelled.');
    }
    final microphone = await createMicrophone();
    _ownedMicrophone = microphone;
    try {
      if (cancelled) throw StateError('Agent connection cancelled.');
      await microphone.publish();
      if (cancelled) throw StateError('Agent connection cancelled.');
    } catch (_) {
      // Includes capture returned after End and publication finishing after
      // disconnect. Never rely on a disposed participant to find this track.
      await microphone.stop();
      rethrow;
    }
  }
}

/// Owns the captured native track independently of room/participant teardown.
abstract class LiveKitAgentMicrophone {
  Future<void> publish();
  Future<void> stop();
  Future<void> dispose();
}

class _SdkAgentMicrophone implements LiveKitAgentMicrophone {
  _SdkAgentMicrophone(this.participant, this.track);
  final lk.LocalParticipant participant;
  final lk.LocalAudioTrack track;
  @override
  Future<void> publish() async {
    await participant.publishAudioTrack(track);
  }

  @override
  Future<void> stop() async {
    await track.stop();
  }

  @override
  Future<void> dispose() async {
    await track.dispose();
  }
}
