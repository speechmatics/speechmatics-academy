/// One enrolled speaker for batch speaker identification.
///
/// The [name] is used VERBATIM as the job label — identified speakers come
/// back in `results[].alternatives[0].speaker` under exactly this string
/// (spaces fine, probe-verified). [identifiers] are the opaque voice
/// identifiers returned by a `get_speakers` enrollment job; they are
/// reusable across jobs (probe-verified).
class SpeakerProfile {
  const SpeakerProfile({
    required this.id,
    required this.name,
    required this.identifiers,
    this.enrolledAt,
  });

  final String id;
  final String name;
  final List<String> identifiers;
  final DateTime? enrolledAt;

  SpeakerProfile copyWith({String? name}) => SpeakerProfile(
        id: id,
        name: name ?? this.name,
        identifiers: identifiers,
        enrolledAt: enrolledAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'identifiers': identifiers,
        if (enrolledAt != null) 'enrolledAt': enrolledAt!.toIso8601String(),
      };

  /// Tolerant: returns null for entries missing the essentials.
  static SpeakerProfile? fromJson(Map<String, dynamic> m) {
    final id = m['id'];
    final name = m['name'];
    final ids = (m['identifiers'] as List?)?.whereType<String>().toList();
    if (id is! String || name is! String || ids == null || ids.isEmpty) return null;
    return SpeakerProfile(
      id: id,
      name: name,
      identifiers: ids,
      enrolledAt: DateTime.tryParse(m['enrolledAt']?.toString() ?? ''),
    );
  }
}
