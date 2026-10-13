import { SAMPLES } from './demo-data.js';
import { createLanguagePalette, getLanguagePresentation, normalizeLanguageCode, getWaveformLanguage } from './language-presentation.js';
import { formatTime, getWords, getStats, filterUtterances, findWordAtTime, toPlainText, createRequestConfig } from './transcript.js';
import { validateAudioFile, createRecorder, seekAudio } from './audio.js';
import { createAudioLoader } from './audio-loader.js';
import { createAudioWaveform, WAVEFORM_BARS } from './audio-waveform.js';
import { icon } from './icons.js';
import { initSettings, credentials } from './settings.js';
import { createBatchClient } from './batch-client.js';
import { prepareAudioFile } from './audio-convert.js';
import { normalizeBatchTranscript } from './batch-transcript.js';
import { createTranscriptionSession } from './transcription-session.js';
import { createConsultationLibrary } from './consultation-library.js';
import { BATCH_ENDPOINTS } from './batch-endpoints.js';
import { revealTranscriptAtTime } from './transcript-navigation.js';

const $ = id => document.getElementById(id);
const escape = value => String(value ?? '').replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]));
const samples = structuredClone(SAMPLES);
const state = { sample: samples[0], time: 0, speed: 1, playing: false, query: '', language: 'all', speaker: 'all', selected: null };
let frame = 0;
let previousFrame = 0;
let toastTimeout;
let renamingSpeaker;
let renamingConsultation;
let recorder;
let recordingFinishing = false;
const audioLoader = createAudioLoader();
let importGeneration = 0;
let playbackGeneration = 0;
const consultations = createConsultationLibrary({
  createSession: ({ onChange }) => createTranscriptionSession({
    createClient: createBatchClient, prepareAudio: prepareAudioFile, normalize: normalizeBatchTranscript, onChange,
  }),
  onChange: (entry, progress) => {
    if (progress.status === 'done') {
      if (state.sample === entry.sample) loadSample(entry.sample);
      else renderLibrary();
      notify(`Transcript ready: ${entry.sample.title}`);
    } else if (state.sample === entry.sample) renderTranscript();
  },
});
const allSamples = () => [...samples, ...consultations.entries().map(entry => entry.sample)];
const selectedEntry = () => consultations.get(state.sample.id);

const languagePalettes = new WeakMap();
function languageMeta(code, sample = state.sample) {
  const signature = sample.languages.join('|');
  let cached = languagePalettes.get(sample);
  if (cached?.signature !== signature) {
    cached = { signature, palette: createLanguagePalette(sample.languages) };
    languagePalettes.set(sample, cached);
  }
  return cached.palette.get(normalizeLanguageCode(code)) || getLanguagePresentation(code);
}

function languageStyle(code, sample = state.sample) {
  const { color, ink, soft, border } = languageMeta(code, sample);
  return `--language-color:${color};--language-ink:${ink};--language-soft:${soft};--language-border:${border}`;
}

document.querySelectorAll('[data-icon]').forEach(element => { element.innerHTML = icon(element.dataset.icon); });

function notify(message) {
  clearTimeout(toastTimeout);
  $('toast').textContent = message;
  $('toast').hidden = false;
  toastTimeout = setTimeout(() => { $('toast').hidden = true; }, 3500);
}

function initials(name) {
  return name.replace(/Dr\.\s*/u, '').split(/\s+/u).slice(0, 2).map(word => word[0] || '').join('').toUpperCase();
}

function speakerTone(speaker) {
  // Use the full consultation's identities so filters and display-name edits keep their colours.
  const index = Object.keys(state.sample.speakerNames).indexOf(speaker);
  return speaker === 'UU' || index < 0 ? 'speaker-tone-neutral' : `speaker-tone-${index % 6 + 1}`;
}

function avatar(speaker) {
  return `<span class="avatar ${speakerTone(speaker)}">${escape(initials(state.sample.speakerNames[speaker] || speaker))}</span>`;
}

function renderLibrary() {
  const items = allSamples();
  document.querySelector('.nav-count').textContent = items.length;
  $('sample-list').innerHTML = items.map(sample => `<button class="sample-button ${state.sample.id === sample.id ? 'active' : ''}" data-sample="${escape(sample.id)}" aria-pressed="${state.sample.id === sample.id}"><strong>${escape(sample.title)}</strong><p>${escape(sample.subtitle || sample.specialty)}</p><span class="sample-badges">${sample.languages.map(language => `<span class="lang-chip" data-lang="${escape(language)}" style="${languageStyle(language, sample)}">${escape(language.toUpperCase())}</span>`).join('')}${!sample.isDemo ? '<span class="lang-chip">LOCAL FILE</span>' : ''}<span class="sample-duration">${formatTime(sample.duration)}</span></span></button>`).join('');
}

function loadSample(sample) {
  if (!sample) return;
  pause();
  Object.assign(state, { sample, time: 0, query: '', language: 'all', speaker: 'all', selected: null });
  const media = selectedEntry()?.media;
  if (media && $('local-audio').getAttribute('src') !== media.url) {
    $('local-audio').src = media.url;
    $('local-audio').load();
    $('local-audio').playbackRate = state.speed;
  }
  $('play').setAttribute('aria-label', sample.isDemo ? 'Preview timeline' : 'Play audio');
  $('search').value = '';
  $('seek').max = sample.duration || 1;
  $('sample-title').textContent = sample.title;
  $('sample-description').textContent = sample.description;
  $('consultation-id').textContent = sample.isDemo ? `CONSULTATION ${String(samples.indexOf(sample) + 1).padStart(3, '0')}` : 'YOUR RECORDING';
  $('source-badge').innerHTML = `<span></span> ${sample.isDemo ? 'Scripted demo' : sample.transcribed ? 'Oak 1 transcript' : 'Local audio'}`;
  $('demo-notice').hidden = !sample.isDemo;
  $('duration-label').textContent = formatTime(sample.duration);
  $('total-time').textContent = formatTime(sample.duration);
  $('playback-note').textContent = sample.isDemo ? 'Timeline preview · no audio' : 'Local audio playback';
  $('transcript-disclosure').textContent = sample.isDemo ? 'Fictional consultation · authored transcript and illustrative timings.' : sample.transcribed ? 'Transcribed by Oak 1 · review the transcript against the original audio.' : 'Start transcription to send this audio to Speechmatics.';
  $('speaker-filter').innerHTML = '<option value="all">All speakers</option>' + Object.entries(sample.speakerNames).map(([key, value]) => `<option value="${escape(key)}">${escape(value)}</option>`).join('');
  $('language-filter').innerHTML = '<option value="all">All languages</option>' + sample.languages.map(key => `<option value="${escape(key)}">${escape(languageMeta(key).name)}</option>`).join('');
  const hasTranscript = sample.isDemo || sample.transcribed;
  $('speaker-filter').disabled = !hasTranscript;
  $('language-filter').disabled = !hasTranscript;
  $('search').disabled = !hasTranscript;
  $('copy-transcript').disabled = !hasTranscript;
  $('export-transcript').disabled = !hasTranscript;
  $('config-diarization').value = sample.diarization;
  $('config-locale').value = sample.locale;
  $('config-locale').disabled = sample.isDemo && !sample.languages.includes('en');
  $('config-region').value = sample.region;
  $('config-hints').checked = false;
  $('config-hints').disabled = !sample.languages.length;
  renderLibrary();
  renderTranscript();
  renderInspector();
  renderWaveform();
  renderWord();
  updateConfig();
  if (!sample.isDemo) seekAudio($('local-audio'), 0, sample.duration);
  updateTime();
}

function renderWaveform() {
  const media = selectedEntry()?.media;
  const peaks = media?.waveform;
  // Scripted samples have no audio; real consultations use locally measured peaks.
  const words = getWords(state.sample).sort((a, b) => a.start - b.start);
  $('playback-note').textContent = state.sample.isDemo ? 'Timeline preview · no audio'
    : media?.waveformStatus === 'loading' ? 'Preparing waveform…'
    : media?.waveformStatus === 'unavailable' ? 'Audio playback · waveform unavailable'
    : 'Local audio playback';
  $('waveform-bars').innerHTML = Array.from({ length: WAVEFORM_BARS }, (_, index) => {
    const time = index / WAVEFORM_BARS * state.sample.duration;
    const word = words.find(word => word.start <= time && word.end > time);
    const height = state.sample.isDemo
      ? word ? 12 + Math.abs(Math.sin(index * 1.9) * Math.cos(index * .37)) * 40 : 4
      : 4 + 48 * Math.pow(peaks?.[index] || 0, .65);
    const language = state.sample.isDemo ? word?.language : getWaveformLanguage(words, time);
    const color = language ? languageMeta(language).color : words.length ? 'var(--line)' : 'var(--orange)';
    return `<i data-lang="${escape(language || '')}" style="height:${height.toFixed(1)}px;--wave-color:${color}"></i>`;
  }).join('');
}

async function loadWaveform(entry) {
  const { media, file } = entry;
  const controller = new AbortController();
  const release = media.release;
  media.release = () => { controller.abort(); release(); };
  try {
    media.waveform = await createAudioWaveform(file, { signal: controller.signal });
    media.waveformStatus = 'ready';
  } catch {
    // A preview failure must never stop playback or automatic transcription.
    media.waveformStatus = 'unavailable';
  }
  if (!controller.signal.aborted && selectedEntry() === entry) {
    renderWaveform();
    updateTime();
  }
}

function renderTranscript() {
  if (!state.sample.isDemo && !state.sample.transcribed) {
    const liveSession = selectedEntry().session;
    const progress = liveSession.state;
    const busy = liveSession.busy;
    const heading = busy ? 'Transcribing your conversation.' : progress.status === 'error' ? 'Let’s reconnect.' : 'Your audio is ready to explore.';
    const message = progress.message || 'Start transcription to send this audio to Speechmatics. You can review the region and options in the API request panel.';
    const action = busy ? `<button id="cancel-transcription" ${progress.status === 'cancelling' ? 'disabled' : ''}>Cancel transcription ${icon('close')}</button>`
      : `<button id="start-transcription">${progress.canResume ? 'Resume transcription' : 'Transcribe audio'} ${icon('arrow')}</button>`;
    $('transcript-body').innerHTML = `<div class="empty-state" role="status">${icon('headphones')}<strong>${heading}</strong><p>${escape(message)}</p>${action}${progress.canResume ? '<button id="cancel-transcription">Cancel this job</button><button id="abandon-transcription" title="Stop tracking locally; the Speechmatics job is not cancelled.">Stop tracking this job</button>' : ''}</div>`;
    $('result-count').textContent = busy ? 'Transcription in progress' : progress.canResume ? 'Ready to reconnect' : 'Ready to transcribe';
    return;
  }
  if (state.sample.transcribed && !getWords(state.sample).length) {
    $('transcript-body').innerHTML = `<div class="empty-state">${icon('info')}<strong>No speech was detected.</strong><p>Oak 1 completed this job without recognized words. Play the audio to check the recording, or add another file.</p></div>`;
    $('result-count').textContent = 'Transcription complete';
    return;
  }
  const turns = filterUtterances(state.sample, state);
  const filtering = Boolean(state.query || state.language !== 'all' || state.speaker !== 'all');
  $('result-count').textContent = filtering ? `${turns.length} matching ${turns.length === 1 ? 'turn' : 'turns'}` : 'Click a word to explore';
  $('transcript-body').innerHTML = turns.map(turn => {
    const runs = [];
    turn.words.forEach((word, index) => {
      const current = runs.at(-1);
      if (current?.language === word.language) current.words.push({ ...word, index });
      else runs.push({ language: word.language, words: [{ ...word, index }] });
    });
    return `<article class="turn" data-turn="${escape(turn.id)}">${avatar(turn.speaker)}<div><div class="turn-meta"><span class="speaker-label ${speakerTone(turn.speaker)}">${escape(state.sample.speakerNames[turn.speaker] || turn.speaker)}</span><span class="speaker-code">${escape(turn.speaker)}</span><button class="turn-time" data-seek="${turn.start}" aria-label="Go to ${formatTime(turn.start)}">${formatTime(turn.start)} ${icon('play')}</button></div><p class="turn-words">${runs.map(run => `<span class="language-run" style="${languageStyle(run.language)}" lang="${escape(run.language)}" dir="${languageMeta(run.language).dir}">${run.words.map(word => {
      const match = state.query && turn.matchingWordIndexes.includes(word.index);
      const label = `${word.text} · ${languageMeta(word.language).name} · ${formatTime(word.start)}`;
      return `${word.index ? escape(word.separatorBefore ?? ' ') : ''}<button class="word" data-turn-id="${escape(turn.id)}" data-word="${word.index}" data-lang="${escape(word.language)}" aria-label="${escape(label)}">${match ? '<mark>' : ''}${escape(word.text)}${match ? '</mark>' : ''}</button>`;
    }).join('')}</span>`).join('')}</p></div></article>`;
  }).join('') || `<div class="empty-state">${icon('search')}<strong>No matching words.</strong><p>Try another phrase or clear the speaker and language filters.</p><button id="clear-filters">Clear all filters</button></div>`;
  updateTime();
}

function renderInspector() {
  const stats = getStats(state.sample);
  const hasTranscript = state.sample.isDemo || state.sample.transcribed;
  $('speaker-count').textContent = hasTranscript ? `${stats.speakerCount} ${state.sample.diarization === 'channel' ? 'channel' : 'speaker'}${stats.speakerCount === 1 ? '' : 's'}` : 'Not transcribed';
  $('language-count').textContent = hasTranscript ? `${stats.languageCount} language${stats.languageCount === 1 ? '' : 's'}` : 'Languages pending';
  $('word-count').textContent = `${stats.wordCount} words`;
  $('language-total').textContent = hasTranscript ? `${stats.languageCount} in ${state.sample.isDemo ? 'sample' : 'audio'}` : 'Awaiting transcript';
  $('language-ribbon').innerHTML = Object.entries(stats.languageCounts).map(([code, count]) => `<span data-lang="${escape(code)}" style="width:${count / stats.wordCount * 100}%;background:${languageMeta(code).color}" title="${escape(languageMeta(code).name)}"></span>`).join('');
  $('language-breakdown').innerHTML = Object.entries(stats.languageCounts).map(([code, count]) => `<div class="language-row" data-lang="${escape(code)}" style="${languageStyle(code)}"><span class="language-dot"></span><span>${escape(languageMeta(code).name)} <small>${escape(code.toUpperCase())}</small></span><strong>${Math.round(count / stats.wordCount * 100)}%</strong></div>`).join('');
  $('switch-count').textContent = stats.switchCount;
  const words = getWords(state.sample);
  const switches = words.flatMap((word, index) => index && word.language !== words[index - 1].language ? [{ ...word, from: words[index - 1].language }] : []);
  $('language-switches').innerHTML = switches.map(word => `<button class="switch-item" data-seek="${word.start}" aria-label="Go to language switch at ${formatTime(word.start)}"><span class="switch-time">${formatTime(word.start)}</span><span class="switch-tag" data-lang="${escape(word.from)}" style="${languageStyle(word.from)}">${escape(word.from.toUpperCase())}</span>${icon('chevron')}<span class="switch-tag" data-lang="${escape(word.language)}" style="${languageStyle(word.language)}">${escape(word.language.toUpperCase())}</span></button>`).join('') || '<span class="preview-note">No language switches to show.</span>';
  $('speaker-list').innerHTML = Object.entries(state.sample.speakerNames).map(([code, name]) => `<button class="speaker-button" data-rename="${escape(code)}" aria-label="Rename ${escape(name)}">${avatar(code)}<span><strong>${escape(name)}</strong><small>${state.sample.diarization === 'channel' ? 'Audio channel' : 'Speaker'} ${escape(code)}</small></span>${icon('edit')}</button>`).join('') || '<span class="preview-note">Available after transcription.</span>';
}

function renderWord() {
  const header = `<div class="section-label">WORD EXPLORER ${icon('code')}</div>`;
  const word = state.selected;
  $('word-inspector').innerHTML = !word ? `${header}<p>Select any word in the transcript to see its language, speaker, and timing.</p>` : `${header}<h3 dir="auto" style="${languageStyle(word.language)};color:var(--language-ink)">${escape(word.text)}</h3><dl class="word-details"><div><dt>Language</dt><dd>${escape(languageMeta(word.language).name)}</dd></div><div><dt>Speaker</dt><dd>${escape(state.sample.speakerNames[word.speaker] || word.speaker)}</dd></div><div><dt>Start → end</dt><dd>${word.start.toFixed(2)} → ${word.end.toFixed(2)}s</dd></div></dl><p>${state.sample.isDemo ? 'Illustrative metadata from this scripted sample.' : 'Word-level transcript metadata.'}</p>`;
}

function updateTime() {
  const duration = state.sample.duration || 1;
  $('current-time').textContent = formatTime(state.time);
  $('seek').value = state.time;
  $('seek').setAttribute('aria-valuetext', `${formatTime(state.time)} of ${formatTime(state.sample.duration)}`);
  $('playhead').style.left = `${Math.min(100, state.time / duration * 100)}%`;
  [...$('waveform-bars').children].forEach((bar, index) => bar.classList.toggle('played', index / WAVEFORM_BARS <= state.time / duration));
  const current = findWordAtTime(state.sample, state.time);
  $('transcript-body').querySelectorAll('.word').forEach(element => {
    const turn = state.sample.utterances.find(turn => turn.id === element.dataset.turnId);
    const word = turn?.words[Number(element.dataset.word)];
    element.classList.toggle('current', Boolean(current && current.utteranceId === turn.id && current.start === word.start));
    element.classList.toggle('selected', Boolean(state.selected && state.selected.utteranceId === turn.id && state.selected.start === word.start));
  });
}

function seek(time, { revealTranscript = true } = {}) {
  state.time = Math.max(0, Math.min(Number(time) || 0, state.sample.duration));
  if (!state.sample.isDemo && !seekAudio($('local-audio'), state.time, state.sample.duration)) {
    state.time = $('local-audio').currentTime || 0;
    notify('This recording cannot seek to that position yet.');
  }
  updateTime();
  if (revealTranscript) revealTranscriptAtTime($('transcript-body'), state.sample, state.time);
}

function pause() {
  playbackGeneration++;
  state.playing = false;
  cancelAnimationFrame(frame);
  $('local-audio').pause();
  $('play').innerHTML = icon('play');
  $('play').setAttribute('aria-label', state.sample.isDemo ? 'Preview timeline' : 'Play audio');
}

function animate(timestamp) {
  if (!state.playing) return;
  const elapsed = previousFrame ? (timestamp - previousFrame) / 1000 : 0;
  previousFrame = timestamp;
  state.time = Math.min(state.sample.duration, state.time + elapsed * state.speed);
  updateTime();
  if (state.time >= state.sample.duration) pause();
  else frame = requestAnimationFrame(animate);
}

async function play() {
  if (state.playing) return pause();
  if (state.time >= state.sample.duration) seek(0);
  state.playing = true;
  const generation = ++playbackGeneration;
  $('play').innerHTML = icon('pause');
  $('play').setAttribute('aria-label', 'Pause playback');
  if (state.sample.isDemo) {
    previousFrame = 0;
    frame = requestAnimationFrame(animate);
  } else {
    try { await $('local-audio').play(); }
    catch (error) {
      if (generation !== playbackGeneration) return;
      pause();
      if (error.name !== 'AbortError') notify('This audio format cannot be played in this browser. Try a WAV or MP3 file.');
    }
  }
}

function updateConfig() {
  const config = createRequestConfig({ locale: $('config-locale').value, diarization: $('config-diarization').value, hints: $('config-hints').checked ? state.sample.languages : [] });
  $('config-endpoint').textContent = `${BATCH_ENDPOINTS[$('config-region').value].replace('https://', '')}/jobs`;
  $('config-code').textContent = JSON.stringify(config, null, 2);
}

async function copyText(text, message) {
  try { await navigator.clipboard.writeText(text); notify(message); }
  catch { notify('Clipboard unavailable. Use the download button to save the transcript.'); }
}

function downloadText(text, filename, type = 'text/plain;charset=utf-8') {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function showAudioError(message) {
  $('upload-error').textContent = message;
  $('upload-error').hidden = !message;
}

async function loadAudioFile(file, { source = 'upload' } = {}) {
  const error = validateAudioFile(file);
  if (error) return showAudioError(error);
  const generation = ++importGeneration;
  pause();
  showAudioError('');
  try {
    const media = await audioLoader.load(file);
    if (!media) return;
    if (generation !== importGeneration) { media.release(); return; }
    credentials.refresh();
    const entry = consultations.add(file, media, { source, apiKey: credentials.forRequest().key });
    media.waveformStatus = 'loading';
    loadSample(entry.sample);
    void loadWaveform(entry);
    $('new-dialog').close();
    notify(source === 'recording' ? 'Recording saved. Starting transcription…' : 'Audio added. Starting transcription…');
  } catch (error) {
    if (generation === importGeneration) showAudioError(error.message);
  } finally {
    if (generation === importGeneration) $('audio-file').value = '';
  }
}

function openNew() {
  pause();
  showAudioError('');
  $('new-dialog').showModal();
}

function startTranscription() {
  const entry = selectedEntry();
  if (!entry) return;
  credentials.refresh();
  consultations.transcribe(entry.sample.id, { apiKey: credentials.forRequest().key });
}

function setInputTab(tab) {
  const upload = tab === 'upload';
  if (upload) { recorder?.cancel(); resetRecording(); }
  ['upload', 'record'].forEach(name => {
    const active = name === tab;
    $(`${name}-tab`).classList.toggle('active', active);
    $(`${name}-tab`).setAttribute('aria-selected', String(active));
    $(`${name}-tab`).tabIndex = active ? 0 : -1;
    $(`${name}-panel`).hidden = !active;
  });
  showAudioError('');
}

function resetRecording() {
  recordingFinishing = false;
  $('record-status').textContent = 'Your microphone, your conversation.';
  $('record-button').innerHTML = `${icon('mic')} Start recording`;
  $('record-button').disabled = false;
}

async function toggleRecording() {
  if (recordingFinishing) return;
  if (recorder?.active) {
    recordingFinishing = true;
    $('record-button').disabled = true;
    $('record-status').textContent = 'Finishing your recording…';
    recorder.stop();
    return;
  }
  const currentRecorder = createRecorder({
    onTick: seconds => { $('record-status').textContent = `Recording · ${formatTime(seconds)} / 05:00`; },
    onStopped: file => {
      Object.defineProperty(file, 'recordedDuration', { value: Math.max(currentRecorder.recordedDuration, .1) });
      recordingFinishing = true;
      $('record-button').disabled = true;
      $('record-status').textContent = 'Preparing your consultation…';
      loadAudioFile(file, { source: 'recording' }).finally(() => {
        if (recorder === currentRecorder) resetRecording();
      });
    },
    onError: error => { resetRecording(); showAudioError(error.message || 'Recording failed. Please try again.'); },
  });
  recorder = currentRecorder;
  $('record-button').disabled = true;
  $('record-status').textContent = 'Waiting for microphone permission…';
  showAudioError('');
  try {
    const started = await currentRecorder.start();
    if (started === false || recorder !== currentRecorder || !$('new-dialog').open || $('record-panel').hidden) return;
    $('record-button').disabled = false;
    $('record-button').innerHTML = `${icon('stop')} Finish &amp; transcribe`;
    $('record-status').textContent = 'Recording · 00:00 / 05:00';
  } catch (error) {
    if (recorder !== currentRecorder) return;
    resetRecording();
    if ($('new-dialog').open) showAudioError(error.name === 'NotAllowedError' ? 'Microphone access was denied. Allow it in your browser, or upload a recording.' : error.message);
  }
}

$('sample-list').addEventListener('click', event => {
  const button = event.target.closest('[data-sample]');
  if (button) loadSample(allSamples().find(sample => sample.id === button.dataset.sample));
});
$('transcript-body').addEventListener('click', event => {
  const button = event.target.closest('.word');
  if (button) {
    const turn = state.sample.utterances.find(turn => turn.id === button.dataset.turnId);
    state.selected = { ...turn.words[Number(button.dataset.word)], speaker: turn.speaker, utteranceId: turn.id };
    seek(state.selected.start, { revealTranscript: false });
    renderWord();
  }
  if (event.target.closest('#clear-filters')) {
    Object.assign(state, { query: '', speaker: 'all', language: 'all' });
    $('search').value = ''; $('speaker-filter').value = 'all'; $('language-filter').value = 'all';
    renderTranscript();
  }
  if (event.target.closest('#back-to-demo')) loadSample(samples[0]);
  if (event.target.closest('#start-transcription')) startTranscription();
  if (event.target.closest('#cancel-transcription')) selectedEntry()?.session.cancel();
  if (event.target.closest('#abandon-transcription')) selectedEntry()?.session.abandon();
});
document.addEventListener('click', event => {
  const target = event.target.closest('[data-seek]');
  if (target) seek(Number(target.dataset.seek));
});
$('search').addEventListener('input', event => { state.query = event.target.value; renderTranscript(); });
$('language-filter').addEventListener('change', event => { state.language = event.target.value; renderTranscript(); });
$('speaker-filter').addEventListener('change', event => { state.speaker = event.target.value; renderTranscript(); });
$('seek').addEventListener('input', event => seek(event.target.value, { revealTranscript: false }));
// Reveal on release/commit, so mobile scrubbing does not move the slider mid-drag.
$('seek').addEventListener('change', () => revealTranscriptAtTime($('transcript-body'), state.sample, state.time));
$('play').addEventListener('click', play);
$('restart').addEventListener('click', () => seek(0));
$('speed').addEventListener('click', () => {
  const speeds = [1, 1.25, 1.5, 2];
  state.speed = speeds[(speeds.indexOf(state.speed) + 1) % speeds.length];
  $('speed').textContent = `${state.speed}×`;
  $('local-audio').playbackRate = state.speed;
  $('speed').setAttribute('aria-label', `Playback speed ${state.speed} times`);
});
$('local-audio').addEventListener('timeupdate', () => { if (!state.sample.isDemo) { state.time = $('local-audio').currentTime; updateTime(); } });
$('local-audio').addEventListener('ended', pause);
$('copy-transcript').addEventListener('click', () => copyText(toPlainText(state.sample), 'Transcript copied.'));
$('export-transcript').addEventListener('click', () => { downloadText(toPlainText(state.sample), `${state.sample.id}-transcript.txt`); notify('Transcript downloaded.'); });
$('rename-consultation').addEventListener('click', () => {
  renamingConsultation = state.sample;
  $('consultation-title').value = renamingConsultation.title;
  $('consultation-title').setCustomValidity('');
  $('title-dialog').showModal();
  $('consultation-title').focus();
  $('consultation-title').select();
});
$('title-form').addEventListener('submit', event => {
  event.preventDefault();
  const title = $('consultation-title').value.trim();
  if (!title) { $('consultation-title').setCustomValidity('Enter a consultation title.'); $('consultation-title').reportValidity(); return; }
  if (consultations.get(renamingConsultation.id)) consultations.rename(renamingConsultation.id, title);
  else renamingConsultation.title = title;
  if (state.sample === renamingConsultation) $('sample-title').textContent = renamingConsultation.title;
  renderLibrary();
  $('title-dialog').close();
  notify('Consultation title updated.');
});
$('consultation-title').addEventListener('input', () => $('consultation-title').setCustomValidity(''));
$('close-title').addEventListener('click', () => $('title-dialog').close());
$('cancel-title').addEventListener('click', () => $('title-dialog').close());
$('show-config').addEventListener('click', () => { updateConfig(); $('config-dialog').showModal(); });
['config-region', 'config-locale', 'config-diarization', 'config-hints'].forEach(id => $(id).addEventListener('change', () => {
  const entry = selectedEntry();
  if (entry && !entry.sample.transcribed && !entry.session.busy && !entry.session.state.canResume) {
    Object.assign(entry.sample, { region: $('config-region').value, locale: $('config-locale').value, diarization: $('config-diarization').value });
  }
  updateConfig();
}));
$('copy-config').addEventListener('click', () => copyText($('config-code').textContent, 'Request JSON copied.'));
$('speaker-list').addEventListener('click', event => {
  const button = event.target.closest('[data-rename]');
  if (!button) return;
  renamingSpeaker = button.dataset.rename;
  $('speaker-name').value = state.sample.speakerNames[renamingSpeaker];
  $('rename-dialog').showModal();
  $('speaker-name').focus();
  $('speaker-name').select();
});
$('rename-form').addEventListener('submit', event => {
  event.preventDefault();
  const name = $('speaker-name').value.trim();
  if (!name) { $('speaker-name').setCustomValidity('Enter a display name.'); $('speaker-name').reportValidity(); return; }
  state.sample.speakerNames[renamingSpeaker] = name;
  $('speaker-filter').querySelectorAll('option').forEach(option => { if (option.value === renamingSpeaker) option.textContent = name; });
  renderTranscript(); renderInspector(); renderWord();
  $('rename-dialog').close();
  notify('Speaker display name updated.');
});
$('speaker-name').addEventListener('input', () => $('speaker-name').setCustomValidity(''));
$('close-rename').addEventListener('click', () => $('rename-dialog').close());
$('new-consultation').addEventListener('click', openNew);
$('sidebar-upload').addEventListener('click', openNew);
$('demo-add-audio').addEventListener('click', openNew);
$('demo-settings').addEventListener('click', () => $('open-settings').click());
$('audio-file').addEventListener('change', event => { if (event.target.files[0]) loadAudioFile(event.target.files[0]); });
$('drop-zone').addEventListener('dragover', event => { event.preventDefault(); $('drop-zone').classList.add('dragover'); });
$('drop-zone').addEventListener('dragleave', () => $('drop-zone').classList.remove('dragover'));
$('drop-zone').addEventListener('drop', event => { event.preventDefault(); $('drop-zone').classList.remove('dragover'); if (event.dataTransfer.files[0]) loadAudioFile(event.dataTransfer.files[0]); });
['upload', 'record'].forEach(name => $(`${name}-tab`).addEventListener('click', () => setInputTab(name)));
document.querySelector('.input-tabs').addEventListener('keydown', event => {
  if (['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) {
    event.preventDefault();
    const name = event.key === 'Home' ? 'upload' : event.key === 'End' ? 'record' : $('upload-tab').getAttribute('aria-selected') === 'true' ? 'record' : 'upload';
    setInputTab(name); $(`${name}-tab`).focus();
  }
});
$('record-button').addEventListener('click', toggleRecording);
$('new-dialog').addEventListener('close', () => { importGeneration++; audioLoader.cancel(); $('audio-file').value = ''; recorder?.cancel(); resetRecording(); });
document.querySelectorAll('dialog').forEach(dialog => dialog.addEventListener('click', event => {
  if (event.target !== dialog) return;
  const bounds = dialog.getBoundingClientRect();
  if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) dialog.close();
}));
window.addEventListener('pagehide', () => { pause(); audioLoader.cancel(); recorder?.cancel(); consultations.stopWaiting(); });
window.addEventListener('beforeunload', event => {
  if (consultations.entries().some(entry => entry.session.busy || entry.session.state.canResume)) { event.preventDefault(); event.returnValue = ''; }
});
window.addEventListener('unload', () => consultations.releaseAll());
loadSample(samples[0]);
initSettings(notify);
