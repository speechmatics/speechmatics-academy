import { findWordForSeek } from './transcript.js';

// Explicit seeks align their destination; playback only reveals an obscured word.
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

export function followTranscriptWord(container, element) {
  if (!container || !element || (container.contains && !container.contains(element))) return null;
  const padding = 24;
  const deltaFor = (bounds, top, bottom) => bounds.top < top ? bounds.top - top
    : bounds.bottom > bottom ? bounds.bottom - bottom : 0;

  if (container.scrollHeight > container.clientHeight + 1) {
    const top = container.getBoundingClientRect().top + container.clientTop;
    const delta = deltaFor(element.getBoundingClientRect(), top + padding,
      top + container.clientHeight - padding);
    const target = Math.max(0, Math.min(container.scrollTop + delta,
      container.scrollHeight - container.clientHeight));
    if (target !== container.scrollTop) container.scrollTo({ top: target, behavior: 'instant' });
  }

  // Measure again after the panel moves; expanded mobile transcripts use only the page.
  const view = container.ownerDocument.defaultView;
  const delta = deltaFor(element.getBoundingClientRect(), padding, view.innerHeight - padding);
  if (delta) view.scrollBy({ top: delta, left: 0, behavior: 'instant' });
  return element;
}
