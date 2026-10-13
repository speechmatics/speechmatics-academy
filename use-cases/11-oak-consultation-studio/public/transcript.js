const validWord = word => word && typeof word.text === 'string' && word.text.trim();
const utterancesOf = sample => Array.isArray(sample?.utterances) ? sample.utterances.filter(turn => turn && Array.isArray(turn.words)) : [];
const searchText = text => String(text ?? '').normalize('NFKD').replace(/\p{M}/gu, '').toLocaleLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();

export function formatTime(seconds) {
  const elapsed = Number.isFinite(seconds) ? Math.max(0, Math.floor(seconds)) : 0;
  return `${String(Math.floor(elapsed / 60)).padStart(2, '0')}:${String(elapsed % 60).padStart(2, '0')}`;
}

export function getWords(sample) {
  return utterancesOf(sample).flatMap(turn => turn.words.filter(validWord).map(word => ({ ...word, speaker: turn.speaker, utteranceId: turn.id })));
}

export function getStats(sample) {
  const words = getWords(sample);
  const languageCounts = {};
  let switchCount = 0;
  let previousLanguage;
  for (const word of words) {
    if (!word.language) continue;
    languageCounts[word.language] = (languageCounts[word.language] ?? 0) + 1;
    if (previousLanguage && previousLanguage !== word.language) switchCount++;
    previousLanguage = word.language;
  }
  return {
    wordCount: words.length,
    speakerCount: new Set(words.map(word => word.speaker).filter(Boolean)).size,
    languageCount: Object.keys(languageCounts).length,
    switchCount,
    languageCounts,
  };
}

export function filterUtterances(sample, { query = '', language = 'all', speaker = 'all' } = {}) {
  const search = searchText(query);
  return utterancesOf(sample).flatMap(turn => {
    if (speaker !== 'all' && turn.speaker !== speaker) return [];
    const words = turn.words.filter(validWord).map(word => ({ ...word }));
    const matchesLanguage = index => language === 'all' || words[index].language === language;
    const matches = new Set();
    if (!search) {
      words.forEach((word, index) => { if (matchesLanguage(index)) matches.add(index); });
    } else {
      let text = '';
      const spans = words.map((word, index) => {
        const token = searchText(word.text);
        if (text && token) text += ' ';
        const start = text.length;
        text += token;
        return { index, start, end: text.length };
      });
      for (let offset = text.indexOf(search); offset !== -1; offset = text.indexOf(search, offset + 1)) {
        const indexes = spans.filter(span => span.start < offset + search.length && span.end > offset).map(span => span.index);
        if (indexes.some(matchesLanguage)) indexes.forEach(index => matches.add(index));
      }
    }
    const matchingWordIndexes = [...matches].sort((a, b) => a - b);
    return matchingWordIndexes.length ? [{ ...turn, words, matchingWordIndexes }] : [];
  });
}

export function findWordAtTime(sample, seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) return null;
  return getWords(sample).find(word => Number.isFinite(word.start) && Number.isFinite(word.end) && word.start <= seconds && seconds < word.end) ?? null;
}

// Explicit seeks can land in silence. Reveal the next word without marking it
// as currently spoken; ordinary playback still uses findWordAtTime.
export function findWordForSeek(sample, seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) return null;
  let next = null;
  let last = null;
  for (const word of getWords(sample)) {
    if (!Number.isFinite(word.start) || !Number.isFinite(word.end) || word.start < 0 || word.end <= word.start) continue;
    if (word.start <= seconds && seconds < word.end) return word;
    if (word.start > seconds && (!next || word.start < next.start)) next = word;
    if (!last || word.end > last.end) last = word;
  }
  return next ?? last;
}

export function joinWords(words) {
  let text = '';
  for (const word of Array.isArray(words) ? words : []) {
    if (!validWord(word)) continue;
    const token = word.text.trim();
    const noSpace = /^[,.;:!?%،؛؟…\)\]\}»]/u.test(token) || /[\(\[\{«]$/u.test(text);
    const separator = typeof word.separatorBefore === 'string' ? word.separatorBefore : (noSpace ? '' : ' ');
    text += `${text ? separator : ''}${token}`;
  }
  return text;
}

export function toPlainText(sample, speakerNames = sample?.speakerNames ?? {}) {
  const disclosure = sample?.isDemo
    ? 'Scripted demonstration — fictional consultation. Synthetic word timings; no audio recording.\n\n'
    : '';
  return disclosure + utterancesOf(sample).filter(turn => turn.words.some(validWord)).map(turn =>
    `[${formatTime(turn.start)}] ${speakerNames?.[turn.speaker] ?? turn.speaker ?? 'Speaker'}: ${joinWords(turn.words)}`
  ).join('\n\n');
}

export function createRequestConfig({ locale = 'en-GB', diarization = 'speaker', hints = [] } = {}) {
  return {
    type: 'transcription',
    transcription_config: {
      model: 'oak-1', language: 'multi', diarization,
      ...(locale ? { output_locale: locale } : {}),
      ...(Array.isArray(hints) && hints.length ? { language_hints: [...hints] } : {}),
    },
  };
}
