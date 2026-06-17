/// The 56 languages Speechmatics omni-v1 supports for `language_hints`,
/// with display names, native names and writing direction.
///
/// One source of truth for language metadata + the app's casing convention:
/// transcript/UI use UPPER-case codes ('EN'); the APIs use lower-case ('en').
class LangInfo {
  const LangInfo(this.code, this.name, this.native, {this.rtl = false});

  /// Lower-case API code, e.g. 'en', 'ar', 'cmn'.
  final String code;
  final String name;
  final String native;
  final bool rtl;
}

class LangCatalog {
  LangCatalog._();

  static const List<LangInfo> all = [
    LangInfo('ar', 'Arabic', 'العربية', rtl: true),
    LangInfo('ba', 'Bashkir', 'Башҡортса'),
    LangInfo('eu', 'Basque', 'Euskara'),
    LangInfo('be', 'Belarusian', 'Беларуская'),
    LangInfo('bn', 'Bengali', 'বাংলা'),
    LangInfo('bg', 'Bulgarian', 'Български'),
    LangInfo('yue', 'Cantonese', '粵語'),
    LangInfo('ca', 'Catalan', 'Català'),
    LangInfo('hr', 'Croatian', 'Hrvatski'),
    LangInfo('cs', 'Czech', 'Čeština'),
    LangInfo('da', 'Danish', 'Dansk'),
    LangInfo('nl', 'Dutch', 'Nederlands'),
    LangInfo('en', 'English', 'English'),
    LangInfo('eo', 'Esperanto', 'Esperanto'),
    LangInfo('et', 'Estonian', 'Eesti'),
    LangInfo('fi', 'Finnish', 'Suomi'),
    LangInfo('fr', 'French', 'Français'),
    LangInfo('gl', 'Galician', 'Galego'),
    LangInfo('de', 'German', 'Deutsch'),
    LangInfo('el', 'Greek', 'Ελληνικά'),
    LangInfo('he', 'Hebrew', 'עברית', rtl: true),
    LangInfo('hi', 'Hindi', 'हिन्दी'),
    LangInfo('hu', 'Hungarian', 'Magyar'),
    LangInfo('id', 'Indonesian', 'Bahasa Indonesia'),
    LangInfo('ia', 'Interlingua', 'Interlingua'),
    LangInfo('ga', 'Irish', 'Gaeilge'),
    LangInfo('it', 'Italian', 'Italiano'),
    LangInfo('ja', 'Japanese', '日本語'),
    LangInfo('ko', 'Korean', '한국어'),
    LangInfo('lv', 'Latvian', 'Latviešu'),
    LangInfo('lt', 'Lithuanian', 'Lietuvių'),
    LangInfo('ms', 'Malay', 'Bahasa Melayu'),
    LangInfo('mt', 'Maltese', 'Malti'),
    LangInfo('cmn', 'Mandarin', '普通话'),
    LangInfo('mr', 'Marathi', 'मराठी'),
    LangInfo('mn', 'Mongolian', 'Монгол'),
    LangInfo('no', 'Norwegian', 'Norsk'),
    LangInfo('fa', 'Persian', 'فارسی', rtl: true),
    LangInfo('pl', 'Polish', 'Polski'),
    LangInfo('pt', 'Portuguese', 'Português'),
    LangInfo('ro', 'Romanian', 'Română'),
    LangInfo('ru', 'Russian', 'Русский'),
    LangInfo('sk', 'Slovak', 'Slovenčina'),
    LangInfo('sl', 'Slovenian', 'Slovenščina'),
    LangInfo('es', 'Spanish', 'Español'),
    LangInfo('sw', 'Swahili', 'Kiswahili'),
    LangInfo('sv', 'Swedish', 'Svenska'),
    LangInfo('tl', 'Tagalog', 'Tagalog'),
    LangInfo('ta', 'Tamil', 'தமிழ்'),
    LangInfo('th', 'Thai', 'ไทย'),
    LangInfo('tr', 'Turkish', 'Türkçe'),
    LangInfo('uk', 'Ukrainian', 'Українська'),
    LangInfo('ur', 'Urdu', 'اردو', rtl: true),
    LangInfo('ug', 'Uyghur', 'ئۇيغۇرچە', rtl: true),
    LangInfo('vi', 'Vietnamese', 'Tiếng Việt'),
    LangInfo('cy', 'Welsh', 'Cymraeg'),
  ];

  static final Map<String, LangInfo> _byCode = {
    for (final l in all) l.code: l,
  };

  static const Set<String> _rtlFallback = {'ar', 'he', 'fa', 'ur', 'ug'};

  /// API form (lower-case).
  static String toApi(String code) => code.toLowerCase();

  /// UI/transcript form (upper-case).
  static String toDisplay(String code) => code.toUpperCase();

  static LangInfo? info(String code) => _byCode[code.toLowerCase()];

  /// English display name for a code, falling back to the upper-cased code.
  static String nameFor(String code) =>
      _byCode[code.toLowerCase()]?.name ?? code.toUpperCase();

  /// Whether a language is written right-to-left (catalog or fallback set).
  static bool isRtl(String code) {
    final c = code.toLowerCase();
    return _byCode[c]?.rtl ?? _rtlFallback.contains(c);
  }
}
