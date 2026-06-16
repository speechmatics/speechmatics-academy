// Playback of persisted transcript audio with word-level position tracking.
// Real implementation on mobile (audio_waveforms needs dart:io); inert stub on
// web — TranscriptPlayer.create() returns null there, so no playback UI shows.
export 'transcript_player_stub.dart' if (dart.library.io) 'transcript_player_io.dart';
