import '../models/classic_lang_catalog.dart';
import '../models/job_config.dart';

/// Builds the Speechmatics `transcription_config` from a [JobConfig].
///
/// This is the ONLY place a job config is constructed, for either engine:
///
/// * **Melia-1 (omni)** — the next-gen "v3" schema is a strict allow-list
///   that 400s any extra key ("Additional property X is not allowed").
///   WIRE MODEL VALUE = **`melia-1`** (re-verified live 2026-06-12). NOTE: the
///   deployed schema FLIPPED since launch — it now accepts `melia-1` and
///   REJECTS `omni-v1` ("model must be one of standard, enhanced"); the app's
///   internal id stays 'omni-v1' but `_buildOmni` emits 'melia-1'.
///   Accepted keys: `model`, `language` ('multi'|code), `language_hints`,
///   `language_hints_strict`, `diarization`.
///   Rejected: punctuation_overrides, additional_vocab, audio_filtering_config,
///   audio_events_config, translation_config, entities, summarization, etc.
///
/// * **classic (standard|enhanced)** — verified by live probes (eu1,
///   2026-06-11/12): `model: 'standard'|'enhanced'` (the API normalizes it to
///   `operating_point` internally — read-back verified for both values, jobs
///   complete; the classic schema is also strict, so this is a real alias, not
///   an ignored key); `language` = 'auto' (batch language identification,
///   unbiased — hints are Melia-1-only) or a classic catalog code incl.
///   bilingual packs (the Spanish & English pack = language 'es' +
///   `domain: "bilingual-en"`; 'multi' 400s: "Languagepack 'multi' is not
///   supported"); `domain: 'medical'|'finance'` (Enhanced + specific language
///   only — standard → "Domain medical is not supported for en-standard",
///   language auto → "Languagepack 'auto-medical' is not supported", 'legal'
///   rejected); `diarization`, `additional_vocab`, `punctuation_overrides`
///   (symbol `permitted_marks`, empty list = punctuation off, `sensitivity`),
///   `audio_filtering_config` ({volume_threshold}) inside transcription_config,
///   and `audio_events_config` ({types}) as a TOP-LEVEL sibling of
///   transcription_config.
///
/// Translation is handled separately by Google Translate for ALL models
/// (uniform pipeline) — `translation_config` is never emitted.
///
/// Speech intelligence (classic only; entitlement + shapes verified live
/// 2026-06-11, all blocks returned content): top-level `summarization_config`
/// ({content_type, summary_length, summary_type} → response `summary.content`),
/// `topic_detection_config` ({topics: seeds?} → `topics.summary.overall`),
/// `auto_chapters_config` ({} → `chapters[]{title,summary,start_time,end_time}`),
/// and `output_config.srt_overrides` ({max_line_length, max_lines} — tunes the
/// separately fetched `?format=srt` transcript). omni-v1 rejects all of them.
class ConfigMapper {
  ConfigMapper._();

  static Map<String, dynamic> build(JobConfig c) =>
      c.isClassic ? _buildClassic(c) : _buildOmni(c);

  /// Config for a speaker-ENROLLMENT job (Settings → Enrol speaker): always
  /// the Enhanced classic model + English (the panel's reading passage is
  /// English), speaker diarization with `get_speakers` so the transcript
  /// returns the voice identifiers in a top-level `speakers` array
  /// (probe-verified 2026-06-12).
  static Map<String, dynamic> buildEnrollment() => {
        'type': 'transcription',
        'transcription_config': {
          'model': 'enhanced',
          'language': 'en',
          'diarization': 'speaker',
          'speaker_diarization_config': {'get_speakers': true},
        },
      };

  static Map<String, dynamic> _buildOmni(JobConfig c) {
    final tc = <String, dynamic>{
      // WIRE VALUE is 'melia-1'. The app's internal model id is 'omni-v1'
      // (drives isClassic / Settings / display), but the deployed API now
      // ACCEPTS 'melia-1' and REJECTS 'omni-v1' ("model must be one of
      // standard, enhanced" — melia-1 passes a separate path). This FLIPPED
      // from the original launch (omni-v1 accepted, melia-1 rejected);
      // re-verified live 2026-06-12: model:'melia-1'+language:'multi'+hints+
      // strict+diarization → done.
      'model': 'melia-1',
      'language': c.isOmnilingual ? 'multi' : c.singleLanguage.toLowerCase(),
    };

    // Language hints only make sense with multilingual mode; omit when empty.
    if (c.isOmnilingual && c.languageHints.isNotEmpty) {
      tc['language_hints'] = c.languageHints.map((e) => e.toLowerCase()).toList();
      // Strict = constrain output to ONLY the hinted languages (a whitelist —
      // it does not force every hinted language to appear).
      if (c.languageHintsStrict) tc['language_hints_strict'] = true;
    }

    if (c.diarization) {
      tc['diarization'] = c.diarizationType; // 'speaker' | 'channel'
    }

    return {'type': 'transcription', 'transcription_config': tc};
  }

  static Map<String, dynamic> _buildClassic(JobConfig c) {
    final tc = <String, dynamic>{
      // 'standard' | 'enhanced' — same param name as Melia-1; the API
      // normalizes it to operating_point internally (read-back verified).
      'model': c.model,
    };

    if (c.classicLanguageMode == 'auto') {
      // Batch language identification (probe-verified on both models).
      // Domains are NOT emitted here — they need a specific language
      // ('auto-medical' 400s).
      tc['language'] = 'auto';
    } else {
      final info = ClassicLangCatalog.byId(c.classicLanguage);
      tc['language'] = info?.language ?? c.classicLanguage.toLowerCase();
      // User-selected domain pack — Enhanced only (standard + domain 400s).
      if (c.model == 'enhanced' && c.domain != 'none') tc['domain'] = c.domain;
      // Spanish & English bilingual = language "es" + domain "bilingual-en" —
      // a bilingual pack's own domain always wins over the user selection.
      if (info?.domain != null) tc['domain'] = info!.domain;
    }

    if (c.diarization) {
      tc['diarization'] = c.diarizationType; // 'speaker' | 'channel'
      // Speaker identification (probe-verified 2026-06-12): enrolled voices
      // are matched and labelled by name in results; unmatched speakers keep
      // S-labels. Classic-only — omni-v1 ACCEPTS this block but ignores it
      // (results stay S1/S2), and `speakers_sensitivity` is rejected
      // ("Additional property not allowed") so it is never sent.
      if (c.speakerIdentification &&
          c.diarizationType == 'speaker' &&
          c.speakers.isNotEmpty) {
        tc['speaker_diarization_config'] = {
          'speakers': [
            for (final p in c.speakers)
              {'label': p.name, 'speaker_identifiers': p.identifiers},
          ],
          // Matching sensitivity. NOTE: the docs call this
          // `speakers_sensitivity`, but the deployed schema REJECTS that name
          // at every placement ("Additional property not allowed",
          // probe-verified 2026-06-12); the accepted param is
          // `speaker_sensitivity` (verified working alongside identification:
          // enrolled label still returned). Lower → favours matching enrolled
          // speakers; higher → favours detecting new generic ones.
          'speaker_sensitivity': c.speakerSensitivity,
        };
      }
    }

    if (c.customDictEnabled) {
      final vocab = parseVocab(c.customDictText);
      if (vocab.isNotEmpty) tc['additional_vocab'] = vocab;
    }

    // Punctuation: empty permitted_marks == punctuation off (probe-verified).
    tc['punctuation_overrides'] = c.punctuation
        ? {
            'permitted_marks': c.marks.map(_markSymbol).whereType<String>().toList(),
            'sensitivity': c.sensitivity,
          }
        : {'permitted_marks': <String>[]};

    if (c.audioFiltering) {
      tc['audio_filtering_config'] = {'volume_threshold': c.volumeThreshold.round()};
    }

    final body = <String, dynamic>{'type': 'transcription', 'transcription_config': tc};

    // NOTE: language hints are a Melia-1 (omni) feature — classic auto-detect
    // runs unbiased. (`language_identification_config` exists in the API as a
    // TOP-LEVEL block, probe-verified, but the app deliberately doesn't use it.)

    // Audio events lives at the TOP LEVEL of the job config (probe-verified).
    if (c.audioEvents && c.eventTypes.isNotEmpty) {
      body['audio_events_config'] = {'types': c.eventTypes};
    }

    // Speech intelligence — all top-level siblings of transcription_config.
    if (c.summaryEnabled) {
      body['summarization_config'] = {
        'content_type': 'auto',
        'summary_length': c.summaryLength,
        'summary_type': c.summaryType,
      };
    }
    if (c.topicsEnabled) {
      final seeds = parseTopics(c.topicsText);
      body['topic_detection_config'] =
          seeds.isEmpty ? <String, dynamic>{} : {'topics': seeds};
    }
    if (c.chaptersEnabled) {
      body['auto_chapters_config'] = <String, dynamic>{};
    }
    if (c.subtitlesEnabled) {
      body['output_config'] = {
        'srt_overrides': {
          'max_line_length': c.subtitleMaxLineLength,
          'max_lines': c.subtitleMaxLines,
        },
      };
    }

    return body;
  }

  /// Parses comma-separated seed topics (`cooking, space travel`) → list.
  static List<String> parseTopics(String text) => text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  /// UI mark ids → the symbol form the classic API accepts (probe-verified).
  static String? _markSymbol(String id) => switch (id) {
        'comma' => ',',
        'period' => '.',
        'question_mark' => '?',
        'exclamation_mark' => '!',
        _ => null,
      };

  /// Parses `gnocchi (nyohki, nochi), CEO (C.E.O.), Speechmatics` into
  /// `[{content, sounds_like?}]`.
  static List<Map<String, dynamic>> parseVocab(String text) {
    final entries = <Map<String, dynamic>>[];
    final re = RegExp(r'([^,()]+?)(?:\s*\(([^)]*)\))?\s*(?:,|$)');
    for (final m in re.allMatches(text)) {
      final content = (m.group(1) ?? '').trim();
      if (content.isEmpty) continue;
      final soundsRaw = m.group(2);
      final soundsLike = soundsRaw == null
          ? const <String>[]
          : soundsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      entries.add(soundsLike.isEmpty
          ? {'content': content}
          : {'content': content, 'sounds_like': soundsLike});
    }
    return entries;
  }
}
