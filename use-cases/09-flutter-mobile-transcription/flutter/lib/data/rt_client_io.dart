import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../app_config.dart';
import 'rt_protocol.dart';

/// One Speechmatics real-time websocket session (standard RT or Agent STT —
/// the protocols share transport; only the message vocabulary differs, and
/// that lives in rt_protocol.dart).
///
/// Lifecycle: [start] connects, sends StartRecognition and completes once the
/// server answers RecognitionStarted. Stream PCM via [addAudio]. [finish]
/// sends EndOfStream with the true audio-frame count and waits (bounded) for
/// EndOfTranscript so trailing finals drain to listeners. [abort] closes
/// immediately without ceremony.
class RtSession {
  RtSession({
    required String apiKey,
    required Uri endpoint,
    required Map<String, dynamic> startRecognition,
  })  : _apiKey = apiKey,
        _endpoint = endpoint,
        _startRecognition = startRecognition;

  final String _apiKey;
  final Uri _endpoint;
  final Map<String, dynamic> _startRecognition;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _events = StreamController<RtEvent>.broadcast();
  int _seqNo = 0;
  bool _closed = false;

  /// Typed server events. Binary frames are ignored; socket errors surface as
  /// [RtErrorEvent] followed by [SocketClosedEvent].
  Stream<RtEvent> get events => _events.stream;

  /// Count of binary audio frames sent — the spec-correct `last_seq_no`.
  int get seqNo => _seqNo;

  Future<void> start() async {
    final channel = IOWebSocketChannel.connect(
      _endpoint,
      headers: {'Authorization': 'Bearer $_apiKey'},
      connectTimeout: AppConfig.rtConnectTimeout,
    );
    _channel = channel;

    // Fail fast on handshake errors (401, DNS, refused) instead of surfacing
    // them later as a stream error mid-StartRecognition.
    await channel.ready.timeout(AppConfig.rtConnectTimeout);

    final started = Completer<void>();
    _sub = channel.stream.listen(
      (frame) {
        if (frame is! String) return; // binary frames: not expected, ignore
        Map<String, dynamic> json;
        try {
          json = jsonDecode(frame) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        final event = parseRtMessage(json);
        if (event == null) return;
        if (!started.isCompleted) {
          if (event is RecognitionStartedEvent) {
            started.complete();
          } else if (event is RtErrorEvent) {
            started.completeError(
                StateError('${event.type}: ${event.reason}'));
          }
        }
        _events.add(event);
      },
      onError: (Object e) {
        if (!started.isCompleted) started.completeError(e);
        _events.add(RtErrorEvent('socket', e.toString()));
      },
      onDone: () {
        final closeError = !started.isCompleted;
        if (closeError) {
          started.completeError(
              StateError('Connection closed during handshake'));
        }
        _events.add(SocketClosedEvent(
            code: channel.closeCode, reason: channel.closeReason));
      },
      cancelOnError: false,
    );

    channel.sink.add(jsonEncode(_startRecognition));
    await started.future.timeout(AppConfig.rtStartTimeout);
  }

  void addAudio(Uint8List chunk) {
    if (_closed) return;
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(chunk);
    _seqNo++;
  }

  /// Graceful end: EndOfStream → wait for EndOfTranscript (finals keep
  /// flowing to [events] during the wait) → close. A missing EndOfTranscript
  /// only costs the timeout — locally assembled content is already safe.
  Future<void> finish() async {
    final channel = _channel;
    if (channel == null || _closed) return;
    try {
      channel.sink
          .add(jsonEncode({'message': 'EndOfStream', 'last_seq_no': _seqNo}));
      await events
          .firstWhere((e) => e is EndOfTranscriptEvent || e is SocketClosedEvent)
          .timeout(AppConfig.rtFinishTimeout);
    } catch (_) {
      // Timeout or sink failure — close anyway.
    }
    await _close(1000, 'client done');
  }

  Future<void> abort() => _close(1000, 'client cancelled');

  Future<void> _close(int code, String reason) async {
    if (_closed) return;
    _closed = true;
    try {
      await _channel?.sink.close(code, reason);
    } catch (_) {}
    await _sub?.cancel();
    await _events.close();
  }
}
