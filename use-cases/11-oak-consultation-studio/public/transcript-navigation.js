import { findWordForSeek } from './transcript.js';

// Only explicit seeks reveal text; regular playback leaves reading position alone.
export function revealTranscriptAtTime(container, sample, seconds) {
  const word = findWordForSeek(sample, seconds);
  if (!container || !word) return null;
  const turn = sample.utterances.find(turn => turn.id === word.utteranceId);
  const index = turn.words.findIndex(item => item?.start === word.start && item?.end === word.end && item?.text === word.text);
  const element = [...container.querySelectorAll('.word')].find(element =>
    element.dataset.turnId === String(word.utteranceId) && Number(element.dataset.word) === index);
  // An active filter can exclude the destination. Preserve it instead of jumping
  // to unrelated speech or clearing the user's search.
  if (!element) return null;

  if (container.scrollHeight > container.clientHeight + 1) {
    const top = container.scrollTop + element.getBoundingClientRect().top
      - container.getBoundingClientRect().top - container.clientTop - 24;
    container.scrollTo({ top: Math.max(0, Math.min(top, container.scrollHeight - container.clientHeight)), behavior: 'instant' });
    const bounds = element.getBoundingClientRect();
    if (bounds.top < 0 || bounds.bottom > container.ownerDocument.defaultView.innerHeight) {
      element.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'instant' });
    }
  } else {
    // The mobile layout expands the transcript; the document is its scroller.
    element.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'instant' });
  }
  return element;
}
