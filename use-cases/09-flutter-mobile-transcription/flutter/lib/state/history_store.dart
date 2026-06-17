import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../data/audio_store.dart';
import '../models/history_item.dart';

/// Persisted store of transcription history (Hive box of JSON strings keyed by
/// item id). Exposes reactive CRUD for History/Home and is written to by the
/// JobController when a job completes.
class HistoryStore extends ChangeNotifier {
  HistoryStore(this._box) {
    _load();
  }

  static const boxName = 'history';
  final Box _box;
  List<HistoryItem> _items = [];

  /// Newest first (items with a createdAt sort above those without).
  List<HistoryItem> get items => List.unmodifiable(_items);

  List<HistoryItem> get recent => _items.take(5).toList();

  HistoryItem? byId(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  void _load() {
    final list = <HistoryItem>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw is String) {
        try {
          list.add(HistoryItem.fromJson(jsonDecode(raw) as Map<String, dynamic>));
        } catch (_) {/* skip corrupt entry */}
      }
    }
    list.sort((a, b) {
      final at = a.createdAt, bt = b.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    _items = list;
  }

  void _put(HistoryItem item) => _box.put(item.id, jsonEncode(item.toJson()));

  /// Seed once on first launch so the demo isn't empty. Assigns a descending
  /// synthetic createdAt so the seed order is preserved as "recent".
  void seedIfEmpty(List<HistoryItem> seed) {
    if (_box.isNotEmpty) return;
    final base = DateTime.now();
    for (var i = 0; i < seed.length; i++) {
      final map = seed[i].toJson();
      map['createdAt'] = base.subtract(Duration(minutes: i + 1)).millisecondsSinceEpoch;
      _box.put(seed[i].id, jsonEncode(map));
    }
    _load();
    notifyListeners();
  }

  void add(HistoryItem item) {
    _put(item);
    _load();
    notifyListeners();
  }

  void rename(String id, String title) {
    final existing = byId(id);
    if (existing == null) return;
    _put(existing.copyWith(title: title));
    _load();
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final existing = byId(id);
    if (existing == null) return;
    _put(existing.copyWith(favorite: !existing.favorite));
    _load();
    notifyListeners();
  }

  void delete(String id) {
    final item = byId(id);
    _box.delete(id);
    _load();
    notifyListeners();
    // Remove the persisted audio too (best-effort, after the UI updates).
    unawaited(AudioStore.delete(item?.audioFile));
  }
}
