import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/speaker_profile.dart';

/// Persisted enrolled speakers (Hive box of JSON strings, keyed by id) —
/// same pattern as HistoryStore. Names are kept unique by suffixing " (2)"
/// because the name doubles as the API label in transcripts.
class SpeakerStore extends ChangeNotifier {
  SpeakerStore(this._box) {
    _load();
  }

  static const boxName = 'speakers';
  final Box _box;
  List<SpeakerProfile> _profiles = [];

  /// Oldest first — keeps the Settings list stable as speakers are added.
  List<SpeakerProfile> get profiles => List.unmodifiable(_profiles);

  void _load() {
    final list = <SpeakerProfile>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw is String) {
        try {
          final p = SpeakerProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          if (p != null) list.add(p);
        } catch (_) {/* skip corrupt entry */}
      }
    }
    list.sort((a, b) {
      final at = a.enrolledAt, bt = b.enrolledAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return at.compareTo(bt);
    });
    _profiles = list;
  }

  void _put(SpeakerProfile p) => _box.put(p.id, jsonEncode(p.toJson()));

  SpeakerProfile? byId(String id) {
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  void add(SpeakerProfile p) {
    _put(p.copyWith(name: _dedupe(p.name.trim(), exceptId: p.id)));
    _load();
    notifyListeners();
  }

  void rename(String id, String name) {
    final p = byId(id);
    final trimmed = name.trim();
    if (p == null || trimmed.isEmpty) return;
    _put(p.copyWith(name: _dedupe(trimmed, exceptId: id)));
    _load();
    notifyListeners();
  }

  void delete(String id) {
    _box.delete(id);
    _load();
    notifyListeners();
  }

  String _dedupe(String name, {String? exceptId}) {
    final taken =
        _profiles.where((p) => p.id != exceptId).map((p) => p.name).toSet();
    if (!taken.contains(name)) return name;
    var i = 2;
    while (taken.contains('$name ($i)')) {
      i++;
    }
    return '$name ($i)';
  }
}
