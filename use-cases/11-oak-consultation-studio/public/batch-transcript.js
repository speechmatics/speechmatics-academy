// Speechmatics json-v2 field locations and punctuation attachment:
// https://docs.speechmatics.com/speech-to-text/batch/output
// https://docs.speechmatics.com/speech-to-text/batch/batch-diarization
const label = value => typeof value === 'string' ? value.trim() : '';
const finiteDuration = value => Number.isFinite(value) && value >= 0 ? value : 0;
const modes = new Set(['none', 'speaker', 'channel']);

export function normalizeBatchTranscript(transcript, metadata = {}) {
  if (!Array.isArray(transcript?.results)) throw new TypeError('Transcript results must be an array.');
  const context = metadata && typeof metadata === 'object' ? metadata : {};
  const config = transcript.metadata?.transcription_config ?? {};
  const pack = transcript.metadata?.language_pack_info ?? {};
  const diarization = modes.has(context.diarization) ? context.diarization : modes.has(config.diarization) ? config.diarization
    : transcript.results.some(result => label(result?.channel)) ? 'channel'
      : transcript.results.some(result => label(result?.alternatives?.[0]?.speaker)) ? 'speaker' : 'none';
  const identity = result => label(diarization === 'channel' ? result.channel : result.alternatives[0].speaker);
  const delimiter = language => {
    const perLanguage = pack.per_language_word_delimiters;
    const specific = perLanguage && Object.hasOwn(perLanguage, language) ? perLanguage[language] : undefined;
    return typeof specific === 'string' ? specific : typeof pack.word_delimiter === 'string' ? pack.word_delimiter : ' ';
  };

  const records = transcript.results.flatMap((result, index) => {
    const alternative = Array.isArray(result?.alternatives) ? result.alternatives[0] : null;
    if (!['word', 'punctuation'].includes(result?.type) || !alternative || !label(alternative.content)
      || !Number.isFinite(result.start_time) || !Number.isFinite(result.end_time) || result.start_time < 0 || result.end_time < result.start_time) return [];
    const reportedLanguage = label(alternative.language).toLowerCase();
    return [{
      type: result.type, content: alternative.content, start: result.start_time, end: result.end_time,
      language: /^[a-z]{2,3}(?:-[a-z0-9]{2,8})*$/u.test(reportedLanguage) ? reportedLanguage : 'und',
      speaker: identity(result), index, attachesTo: result.attaches_to, eos: result.is_eos === true,
    }];
  });

  const lastByIdentity = new Map();
  const pending = new Map();
  const words = [];
  let lastWord;
  // Look forward only for unattributed leading punctuation, never to infer a word's identity.
  const firstIdentity = records.find(record => record.type === 'word')?.speaker || 'UU';
  for (const record of records) {
    if (record.type === 'word') {
      const speaker = record.speaker || 'UU';
      const prefix = pending.get(speaker);
      const separator = prefix?.separatorBefore ?? delimiter(record.language);
      const word = {
        text: (prefix?.text || '') + record.content,
        language: record.language, start: record.start, end: record.end,
        ...(separator !== ' ' ? { separatorBefore: separator } : {}),
      };
      const entry = { word, speaker, index: record.index, eos: prefix?.eos === true };
      words.push(entry);
      lastByIdentity.set(speaker, entry);
      lastWord = entry;
      pending.delete(speaker);
      continue;
    }
    const speaker = record.speaker || lastWord?.speaker || firstIdentity;
    const previous = lastByIdentity.get(speaker);
    const attachesTo = ['previous', 'next', 'both', 'none'].includes(record.attachesTo) ? record.attachesTo : 'previous';
    if (previous && attachesTo !== 'next') {
      previous.word.text += (attachesTo === 'none' ? delimiter(previous.word.language) : '') + record.content;
      previous.eos ||= record.eos;
    }
    if (attachesTo === 'next' || attachesTo === 'both' || (!previous && attachesTo === 'none')) {
      const prefix = pending.get(speaker) || { text: '' };
      if (attachesTo === 'both' && previous) prefix.separatorBefore = '';
      else prefix.text += record.content + (attachesTo === 'none' ? delimiter(record.language) : '');
      prefix.eos ||= record.eos;
      pending.set(speaker, prefix);
    }
  }

  words.sort((left, right) => left.word.start - right.word.start || left.index - right.index);
  const utterances = [];
  const speakerNames = new Map();
  const languages = new Set();
  let previous;
  for (const entry of words) {
    const { word, speaker } = entry;
    languages.add(word.language);
    if (!speakerNames.has(speaker)) {
      speakerNames.set(speaker, speaker === 'UU' ? (diarization === 'channel' ? 'Unattributed channel' : 'Unattributed')
        : diarization === 'speaker' && /^S\d+$/u.test(speaker) ? `Speaker ${speaker.slice(1)}` : speaker);
    }
    let current = utterances.at(-1);
    if (!current || current.speaker !== speaker || previous?.eos || word.start - current.end > 2) {
      current = { id: `utterance-${utterances.length + 1}`, speaker, start: word.start, end: word.end, words: [] };
      utterances.push(current);
    }
    current.end = Math.max(current.end, word.end);
    current.words.push(word);
    previous = entry;
  }
  const jobId = label(context.jobId) || label(transcript.job?.id) || null;
  return {
    id: jobId ? `batch-${jobId}` : 'batch-transcript', jobId,
    title: label(context.title) || label(transcript.job?.data_name) || 'Transcription',
    subtitle: 'Audio transcript', description: 'Transcript from supplied audio, with word timings and language labels reported by Speechmatics.',
    specialty: 'Consultation',
    duration: utterances.reduce((duration, turn) => Math.max(duration, turn.end), Math.max(finiteDuration(context.duration), finiteDuration(transcript.job?.duration))),
    languages: [...languages], speakerNames: Object.fromEntries(speakerNames),
    region: label(context.region), locale: label(context.locale) || label(config.output_locale), diarization,
    isDemo: false, transcribed: true, utterances,
  };
}
