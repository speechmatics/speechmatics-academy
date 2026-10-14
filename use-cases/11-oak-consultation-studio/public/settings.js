import { API_KEY_STORAGE, createCredentialStore, readRuntimeConfig } from './credentials.js';
import { HINT_LANGUAGES, LANGUAGE_HINTS_STORAGE, languagePreferences } from './language-preferences.js';
import { icon } from './icons.js';

export const credentials = createCredentialStore();
export { languagePreferences };

export function initSettings(notify, {
  document = globalThis.document, window = globalThis.window,
  store = credentials, readConfig = readRuntimeConfig,
  preferences = languagePreferences, onHintsChanged = () => {}, onAddAudio = () => {},
} = {}) {
  const $ = id => document.getElementById(id);
  const dialog = $('settings-dialog');
  const input = $('settings-api-key');
  const settingsButton = $('open-settings');
  const demoAction = $('demo-add-audio');
  const defaultTitle = settingsButton.getAttribute('title');
  const hintSearch = $('language-hints-search');
  let draftHints = new Set(preferences.get());
  const hintOptions = HINT_LANGUAGES.map(language => {
    const label = document.createElement('label');
    label.className = 'language-hint-option';
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.value = language.code;
    checkbox.setAttribute('data-language-hint', language.code);
    const name = document.createElement('span');
    name.className = 'language-hint-name';
    name.textContent = language.name;
    const code = document.createElement('span');
    code.className = 'language-hint-code';
    code.textContent = language.code.toUpperCase();
    code.setAttribute('aria-hidden', 'true');
    label.append(checkbox, name, code);
    checkbox.addEventListener('change', () => {
      if (checkbox.checked) draftHints.add(language.code);
      else draftHints.delete(language.code);
      $('settings-error').hidden = true;
      renderHints();
    });
    return { ...language, label, checkbox };
  });
  $('language-hints-list').replaceChildren(...hintOptions.map(option => option.label));
  let runtime = null;
  let requestVersion = 0;
  let configurationChecked = false;
  let wasMissingKey = false;

  function hintsEqual(left, right) {
    return left.length === right.length && left.every(code => right.includes(code));
  }

  function renderHints() {
    const query = hintSearch.value.trim().toLowerCase();
    let matches = 0;
    for (const option of hintOptions) {
      option.checkbox.checked = draftHints.has(option.code);
      option.label.hidden = !`${option.name} ${option.code}`.toLowerCase().includes(query);
      if (!option.label.hidden) matches++;
    }
    const selectedNames = HINT_LANGUAGES.filter(language => draftHints.has(language.code)).map(language => language.name);
    const selection = selectedNames.length
      ? `Expected languages: ${selectedNames.join(', ')}.`
      : 'Automatic language detection. No expected languages selected.';
    $('language-hints-summary').textContent = matches ? selection : `No languages match your search. ${selection}`;
    $('clear-language-hints').disabled = draftHints.size === 0;
  }

  function resetHints() {
    draftHints = new Set(preferences.get());
    hintSearch.value = '';
    renderHints();
  }

  function refreshHints() {
    const previous = preferences.get();
    preferences.refresh();
    resetHints();
    const current = preferences.get();
    if (!hintsEqual(previous, current)) onHintsChanged(current);
  }

  function resetInput() {
    input.value = '';
    input.type = 'password';
    $('toggle-api-key').textContent = 'Show';
    $('toggle-api-key').setAttribute('aria-label', 'Show API key');
    $('toggle-api-key').setAttribute('aria-pressed', 'false');
    $('settings-error').hidden = true;
  }

  function render() {
    const state = store.status();
    const keyAvailable = state.hasKey || runtime?.environmentKeyConfigured;
    const needsKey = configurationChecked && !keyAvailable;
    if (demoAction) {
      demoAction.disabled = !state.hasKey && !configurationChecked;
      demoAction.setAttribute('aria-controls', keyAvailable ? 'new-dialog' : 'settings-dialog');
      $('demo-action-label').textContent = keyAvailable ? 'Add your audio' : 'Add API key';
      const actionIcon = $('demo-action-icon');
      const iconName = keyAvailable ? 'upload' : 'settings';
      actionIcon.setAttribute('data-icon', iconName);
      actionIcon.innerHTML = icon(iconName);
    }
    input.placeholder = state.hasKey ? 'Enter a replacement key' : 'Paste your Speechmatics API key';
    $('clear-api-key').hidden = !state.hasKey;
    $('key-session-status').textContent = state.hasKey
      ? 'Your key is saved in this browser. Leave the field empty to keep it.'
      : 'Saved in this browser until you clear it, including after a page refresh.';
    $('settings-indicator').hidden = !(state.hasKey || runtime?.environmentKeyConfigured);
    $('settings-summary').textContent = !state.storageAvailable ? 'Browser storage is unavailable.'
      : state.hasKey ? 'Saved API key'
      : runtime?.environmentKeyConfigured ? 'An API key is already provided by this app.'
      : !configurationChecked ? 'Checking the app’s API key configuration…'
      : 'No API key saved';
    settingsButton.classList.toggle('needs-api-key', needsKey);
    if (needsKey) {
      settingsButton.setAttribute('title', 'Add your Speechmatics API key');
      settingsButton.setAttribute('aria-describedby', 'settings-key-hint');
    } else {
      if (defaultTitle === null) settingsButton.removeAttribute('title');
      else settingsButton.setAttribute('title', defaultTitle);
      settingsButton.removeAttribute('aria-describedby');
    }
    const hint = $('settings-key-hint');
    if (hint) hint.hidden = !needsKey;
    const demoGuidance = $('demo-key-guidance');
    if (demoGuidance) demoGuidance.hidden = !needsKey;
    if (needsKey && !wasMissingKey) notify('Add your Speechmatics API key in Settings to start transcribing.');
    wasMissingKey = needsKey;
    return needsKey;
  }

  async function checkConfiguration() {
    const version = ++requestVersion;
    try {
      const result = await readConfig();
      if (version === requestVersion) runtime = result;
    } catch {
      if (version === requestVersion) runtime = null;
    } finally {
      if (version === requestVersion) { configurationChecked = true; render(); }
    }
  }

  function showError(message, focusTarget = input) {
    $('settings-error').textContent = message;
    $('settings-error').hidden = false;
    focusTarget.focus();
  }

  function openSettings() {
    store.refresh();
    refreshHints();
    resetInput();
    render();
    dialog.showModal();
    checkConfiguration();
  }
  settingsButton.addEventListener('click', openSettings);
  demoAction?.addEventListener('click', () => {
    store.refresh();
    const needsKey = render();
    if (demoAction.disabled) return;
    if (needsKey) {
      openSettings();
      input.focus();
    } else onAddAudio();
  });
  $('toggle-api-key').addEventListener('click', () => {
    const show = input.type === 'password';
    input.type = show ? 'text' : 'password';
    $('toggle-api-key').textContent = show ? 'Hide' : 'Show';
    $('toggle-api-key').setAttribute('aria-label', show ? 'Hide API key' : 'Show API key');
    $('toggle-api-key').setAttribute('aria-pressed', String(show));
  });
  $('clear-api-key').addEventListener('click', () => {
    try {
      store.clear();
      resetInput();
      const needsKey = render();
      if (!needsKey) notify('Saved API key cleared from this browser.');
    } catch (error) { showError(error.message); }
  });
  $('settings-form').addEventListener('submit', event => {
    event.preventDefault();
    let focusTarget = input;
    try {
      if (input.value.trim()) store.save(input.value);
      focusTarget = hintSearch;
      const nextHints = [...draftHints];
      if (!hintsEqual(preferences.get(), nextHints)) {
        preferences.save(nextHints);
        onHintsChanged(preferences.get());
      }
      resetInput();
      const needsKey = render();
      dialog.close();
      notify(needsKey ? 'Settings saved. Add your Speechmatics API key to start transcribing.' : 'Settings saved in this browser.');
    } catch (error) {
      render();
      showError(error.message, focusTarget);
    }
  });
  hintSearch.addEventListener('input', renderHints);
  $('clear-language-hints').addEventListener('click', () => {
    draftHints.clear();
    $('settings-error').hidden = true;
    renderHints();
  });
  input.addEventListener('input', () => { $('settings-error').hidden = true; });
  $('close-settings').addEventListener('click', () => dialog.close());
  $('cancel-settings').addEventListener('click', () => dialog.close());
  function discardDraft() { resetInput(); resetHints(); }
  dialog.addEventListener('close', discardDraft);
  window.addEventListener('pagehide', discardDraft);
  window.addEventListener('storage', event => {
    if (event.key === API_KEY_STORAGE || event.key === null) { store.refresh(); render(); }
    if (event.key === LANGUAGE_HINTS_STORAGE || event.key === null) refreshHints();
  });
  renderHints();
  render();
  checkConfiguration();
}
