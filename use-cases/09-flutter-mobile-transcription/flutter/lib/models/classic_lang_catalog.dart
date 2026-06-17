/// Language catalog for the classic engine (operating_point standard/enhanced)
/// — distinct from the omni-v1 catalog. Per the Speechmatics languages docs.
///
/// Entries are looked up by [id] (what the settings store persists). For most
/// entries id == the API `language` code; the Spanish & English bilingual pack
/// is special: `language: "es"` plus `domain: "bilingual-en"` (probe-verified
/// 2026-06-11, as were `language: "auto"` and the bilingual pack codes).
class ClassicLangInfo {
  const ClassicLangInfo._(this.id, this.name, this._language, this.domain, this.bilingual);

  final String id;
  final String name;
  final String? _language;
  final String? domain;

  /// Bilingual/multilingual packs are excluded from expected-language hints.
  final bool bilingual;

  /// The API `language` value to emit.
  String get language => _language ?? id;
}

class ClassicLangCatalog {
  ClassicLangCatalog._();

  /// Bilingual / multilingual packs (listed first in the picker).
  static const packs = <ClassicLangInfo>[
    ClassicLangInfo._('ar_en', 'Arabic & English', null, null, true),
    ClassicLangInfo._('cmn_en', 'Mandarin & English', null, null, true),
    ClassicLangInfo._('en_ms', 'Malay & English', null, null, true),
    ClassicLangInfo._('en_ta', 'Tamil & English', null, null, true),
    ClassicLangInfo._('cmn_en_ms_ta', 'Mandarin, Malay, Tamil & English', null, null, true),
    ClassicLangInfo._('tl', 'Tagalog/Filipino & English', null, null, true),
    // Special: emitted as language "es" + domain "bilingual-en".
    ClassicLangInfo._('es-bilingual', 'Spanish & English', 'es', 'bilingual-en', true),
  ];

  /// Monolingual languages (alphabetical).
  static const languages = <ClassicLangInfo>[
    ClassicLangInfo._('ba', 'Bashkir', null, null, false),
    ClassicLangInfo._('eu', 'Basque', null, null, false),
    ClassicLangInfo._('be', 'Belarusian', null, null, false),
    ClassicLangInfo._('bn', 'Bengali', null, null, false),
    ClassicLangInfo._('bg', 'Bulgarian', null, null, false),
    ClassicLangInfo._('yue', 'Cantonese', null, null, false),
    ClassicLangInfo._('ca', 'Catalan', null, null, false),
    ClassicLangInfo._('hr', 'Croatian', null, null, false),
    ClassicLangInfo._('cs', 'Czech', null, null, false),
    ClassicLangInfo._('da', 'Danish', null, null, false),
    ClassicLangInfo._('nl', 'Dutch', null, null, false),
    ClassicLangInfo._('en', 'English', null, null, false),
    ClassicLangInfo._('eo', 'Esperanto', null, null, false),
    ClassicLangInfo._('et', 'Estonian', null, null, false),
    ClassicLangInfo._('fi', 'Finnish', null, null, false),
    ClassicLangInfo._('fr', 'French', null, null, false),
    ClassicLangInfo._('gl', 'Galician', null, null, false),
    ClassicLangInfo._('de', 'German', null, null, false),
    ClassicLangInfo._('el', 'Greek', null, null, false),
    ClassicLangInfo._('he', 'Hebrew', null, null, false),
    ClassicLangInfo._('hi', 'Hindi', null, null, false),
    ClassicLangInfo._('hu', 'Hungarian', null, null, false),
    ClassicLangInfo._('id', 'Indonesian', null, null, false),
    ClassicLangInfo._('ia', 'Interlingua', null, null, false),
    ClassicLangInfo._('ga', 'Irish', null, null, false),
    ClassicLangInfo._('it', 'Italian', null, null, false),
    ClassicLangInfo._('ja', 'Japanese', null, null, false),
    ClassicLangInfo._('ko', 'Korean', null, null, false),
    ClassicLangInfo._('lv', 'Latvian', null, null, false),
    ClassicLangInfo._('lt', 'Lithuanian', null, null, false),
    ClassicLangInfo._('ms', 'Malay', null, null, false),
    ClassicLangInfo._('mt', 'Maltese', null, null, false),
    ClassicLangInfo._('cmn', 'Mandarin', null, null, false),
    ClassicLangInfo._('mr', 'Marathi', null, null, false),
    ClassicLangInfo._('mn', 'Mongolian', null, null, false),
    ClassicLangInfo._('no', 'Norwegian', null, null, false),
    ClassicLangInfo._('fa', 'Persian', null, null, false),
    ClassicLangInfo._('pl', 'Polish', null, null, false),
    ClassicLangInfo._('pt', 'Portuguese', null, null, false),
    ClassicLangInfo._('ro', 'Romanian', null, null, false),
    ClassicLangInfo._('ru', 'Russian', null, null, false),
    ClassicLangInfo._('sk', 'Slovakian', null, null, false),
    ClassicLangInfo._('sl', 'Slovenian', null, null, false),
    ClassicLangInfo._('es', 'Spanish', null, null, false),
    ClassicLangInfo._('sw', 'Swahili', null, null, false),
    ClassicLangInfo._('sv', 'Swedish', null, null, false),
    ClassicLangInfo._('ta', 'Tamil', null, null, false),
    ClassicLangInfo._('th', 'Thai', null, null, false),
    ClassicLangInfo._('tr', 'Turkish', null, null, false),
    ClassicLangInfo._('uk', 'Ukrainian', null, null, false),
    ClassicLangInfo._('ur', 'Urdu', null, null, false),
    ClassicLangInfo._('ug', 'Uyghur', null, null, false),
    ClassicLangInfo._('vi', 'Vietnamese', null, null, false),
    ClassicLangInfo._('cy', 'Welsh', null, null, false),
  ];

  /// Picker order: bilingual packs first, then monolinguals.
  static List<ClassicLangInfo> get all => [...packs, ...languages];

  static final Map<String, ClassicLangInfo> _byId = {for (final l in all) l.id: l};

  static ClassicLangInfo? byId(String id) => _byId[id];

  static String nameFor(String id) => _byId[id]?.name ?? id.toUpperCase();
}
