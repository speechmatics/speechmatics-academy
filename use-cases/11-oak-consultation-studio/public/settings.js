import { API_KEY_STORAGE, createCredentialStore, readRuntimeConfig } from './credentials.js';

export const credentials = createCredentialStore();

export function initSettings(notify, {
  document = globalThis.document, window = globalThis.window,
  store = credentials, readConfig = readRuntimeConfig,
} = {}) {
  const $ = id => document.getElementById(id);
  const dialog = $('settings-dialog');
  const input = $('settings-api-key');
  const settingsButton = $('open-settings');
  const defaultTitle = settingsButton.getAttribute('title');
  let runtime = null;
  let requestVersion = 0;
  let configurationChecked = false;
  let wasMissingKey = false;

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
    const needsKey = configurationChecked && !state.hasKey && !runtime?.environmentKeyConfigured;
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

  function showError(message) {
    $('settings-error').textContent = message;
    $('settings-error').hidden = false;
    input.focus();
  }

  $('open-settings').addEventListener('click', () => {
    store.refresh();
    resetInput();
    render();
    dialog.showModal();
    checkConfiguration();
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
    try {
      if (input.value.trim()) store.save(input.value);
      else if (!store.status().hasKey && !runtime?.environmentKeyConfigured) throw new Error('Enter an API key.');
      const hasKey = store.status().hasKey;
      resetInput();
      render();
      dialog.close();
      notify(hasKey ? 'API key saved in this browser.' : 'Settings saved. The app’s API key will be used automatically.');
    } catch (error) { showError(error.message); }
  });
  input.addEventListener('input', () => { $('settings-error').hidden = true; });
  $('close-settings').addEventListener('click', () => dialog.close());
  $('cancel-settings').addEventListener('click', () => dialog.close());
  dialog.addEventListener('close', resetInput);
  window.addEventListener('pagehide', resetInput);
  window.addEventListener('storage', event => {
    if (event.key === API_KEY_STORAGE || event.key === null) { store.refresh(); render(); }
  });
  render();
  checkConfiguration();
}
