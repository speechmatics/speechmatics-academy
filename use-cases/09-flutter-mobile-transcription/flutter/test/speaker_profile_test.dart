import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:speechmatics_translate/models/speaker_profile.dart';

void main() {
  group('SpeakerProfile', () {
    test('round-trips through JSON', () {
      final p = SpeakerProfile(
        id: 'spk_1',
        name: 'Edgars A',
        identifiers: const ['id-one', 'id-two'],
        enrolledAt: DateTime(2026, 6, 12, 10, 30),
      );
      final back = SpeakerProfile.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>)!;
      expect(back.id, p.id);
      expect(back.name, p.name);
      expect(back.identifiers, p.identifiers);
      expect(back.enrolledAt, p.enrolledAt);
    });

    test('fromJson is tolerant: missing essentials → null', () {
      expect(SpeakerProfile.fromJson(const {}), isNull);
      expect(SpeakerProfile.fromJson(const {'id': 'x', 'name': 'y'}), isNull);
      expect(
          SpeakerProfile.fromJson(const {'id': 'x', 'name': 'y', 'identifiers': []}), isNull);
      // enrolledAt optional.
      final p = SpeakerProfile.fromJson(
          const {'id': 'x', 'name': 'y', 'identifiers': ['a']});
      expect(p, isNotNull);
      expect(p!.enrolledAt, isNull);
    });

    test('copyWith renames without touching identifiers', () {
      const p = SpeakerProfile(id: 'a', name: 'Old', identifiers: ['i']);
      final r = p.copyWith(name: 'New');
      expect(r.name, 'New');
      expect(r.id, 'a');
      expect(r.identifiers, ['i']);
    });
  });
}
