import test from 'node:test';
import assert from 'node:assert/strict';
import { initSettings } from '../public/settings.js';
import { API_KEY_STORAGE, createCredentialStore } from '../public/credentials.js';
import { LANGUAGE_HINTS_STORAGE, createLanguagePreferences } from '../public/language-preferences.js';

const tick = () => new Promise(resolve => setImmediate(resolve));
const prompt = 'Add your Speechmatics API key in Settings to start transcribing.';

class Element {
  constructor(tagName = 'div') {
    this.tagName = tagName;
    this.events = new Map();
    this.attributes = new Map();
    this.classes = new Set();
    this.hidden = true;
    this.value = '';
    this.type = 'password';
    this.textContent = '';
    this.children = [];
    this.checked = false;
    this.disabled = false;
    this.classList = {
      toggle: (name, enabled) => enabled ? this.classes.add(name) : this.classes.delete(name),
      contains: name => this.classes.has(name),
    };
  }
  addEventListener(type, listener) { this.events.set(type, [...(this.events.get(type) || []), listener]); }
  emit(type, event = {}) { for (const listener of this.events.get(type) || []) listener({ preventDefault() {}, ...event }); }
  setAttribute(name, value) { this.attributes.set(name, String(value)); }
  getAttribute(name) { return this.attributes.get(name) ?? null; }
  removeAttribute(name) { this.attributes.delete(name); }
  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this.children = [...children]; }
  focus() { this.focused = true; }
  showModal() { this.open = true; }
  close() { this.open = false; this.emit('close'); }
}

function harness({ savedKey = '', savedHints = [], failHintsSave = false } = {}) {
  const values = new Map(savedKey ? [[API_KEY_STORAGE, savedKey]] : []);
  values.set(LANGUAGE_HINTS_STORAGE, JSON.stringify(savedHints));
  const storage = {
    getItem: key => values.get(key) ?? null,
    setItem: (key, value) => {
      if (key === LANGUAGE_HINTS_STORAGE && failHintsSave) throw new Error('Quota');
      values.set(key, value);
    },
    removeItem: key => values.delete(key),
  };
  const store = createCredentialStore(storage);
  const preferences = createLanguagePreferences(storage);
  const nodes = new Map();
  const document = {
    getElementById: id => { if (!nodes.has(id)) nodes.set(id, new Element()); return nodes.get(id); },
    createElement: tag => new Element(tag),
  };
  const window = new Element();
  const notifications = [];
  const checks = [];
  const hintChanges = [];
  const readConfig = () => new Promise((resolve, reject) => checks.push({ resolve, reject }));
  initSettings(message => notifications.push(message), {
    document, window, store, preferences, readConfig, onHintsChanged: hints => hintChanges.push(hints),
    onAddAudio: () => document.getElementById('new-dialog').showModal(),
  });
  const $ = id => document.getElementById(id);
  const hint = code => {
    const node = $('language-hints-list').children.flatMap(label => label.children)
      .find(child => child.getAttribute('data-language-hint') === code);
    assert.ok(node, `Expected a checkbox for ${code}`);
    return node;
  };
  return {
    $, window, storage, store, preferences, notifications, checks, hintChanges, hint,
    select(code, checked = true) { const node = hint(code); node.checked = checked; node.emit('change'); },
    option: code => $('language-hints-list').children.find(label => label.children.includes(hint(code))),
  };
}

function assertAttention(h, expected) {
  assert.equal(h.$('open-settings').classList.contains('needs-api-key'), expected);
  assert.equal(h.$('open-settings').getAttribute('aria-describedby'), expected ? 'settings-key-hint' : null);
  assert.equal(h.$('open-settings').getAttribute('title'), expected ? 'Add your Speechmatics API key' : null);
  assert.equal(h.$('settings-key-hint').hidden, !expected);
}

test('the demo action waits for key availability, then opens Settings with the API input focused', async () => {
  const h = harness();
  assert.equal(h.$('demo-add-audio').disabled, true);
  h.$('demo-add-audio').emit('click');
  assert.equal(Boolean(h.$('settings-dialog').open), false);
  assert.equal(Boolean(h.$('new-dialog').open), false);
  h.checks[0].resolve({ environmentKeyConfigured: false });
  await tick();
  assert.equal(h.$('demo-add-audio').disabled, false);
  assert.equal(h.$('demo-action-label').textContent, 'Add API key');
  assert.equal(h.$('demo-add-audio').getAttribute('aria-controls'), 'settings-dialog');
  h.$('demo-add-audio').emit('click');
  assert.equal(h.$('settings-dialog').open, true);
  assert.equal(h.$('settings-api-key').focused, true);
  assert.equal(Boolean(h.$('new-dialog').open), false);
  assert.equal(h.checks.length, 2, 'the action uses the existing Settings configuration refresh');
});

test('a key restored from browser storage makes the demo action open audio before runtime configuration resolves', () => {
  const h = harness({ savedKey: 'fictional-key' });
  assert.equal(h.$('demo-add-audio').disabled, false);
  assert.equal(h.$('demo-action-label').textContent, 'Add your audio');
  assert.equal(h.$('demo-add-audio').getAttribute('aria-controls'), 'new-dialog');
  h.$('demo-add-audio').emit('click');
  assert.equal(h.$('new-dialog').open, true);
  assert.equal(Boolean(h.$('settings-dialog').open), false);
});

test('saving and clearing the final key switch the demo action between audio and Settings', async () => {
  const h = harness();
  h.checks[0].resolve({ environmentKeyConfigured: false });
  await tick();
  h.$('demo-add-audio').emit('click');
  h.$('settings-api-key').value = 'fictional-key';
  h.$('settings-form').emit('submit');
  assert.equal(createCredentialStore(h.storage).status().hasKey, true);
  assert.equal(h.$('demo-action-label').textContent, 'Add your audio');
  h.$('demo-add-audio').emit('click');
  assert.equal(h.$('new-dialog').open, true);
  h.$('new-dialog').close();
  h.$('clear-api-key').emit('click');
  assert.equal(h.$('demo-action-label').textContent, 'Add API key');
  h.$('demo-add-audio').emit('click');
  assert.equal(h.$('settings-dialog').open, true);
  assert.equal(h.$('new-dialog').open, false);
});

test('the demo action refreshes credentials before routing even without a storage event', async () => {
  const h = harness();
  h.checks[0].resolve({ environmentKeyConfigured: false });
  await tick();
  h.storage.setItem(API_KEY_STORAGE, 'external-fictional-key');
  h.$('demo-add-audio').emit('click');
  assert.equal(h.$('new-dialog').open, true);
  assert.equal(h.$('demo-action-label').textContent, 'Add your audio');
  h.$('new-dialog').close();
  h.storage.removeItem(API_KEY_STORAGE);
  h.$('demo-add-audio').emit('click');
  assert.equal(h.$('settings-dialog').open, true);
  assert.equal(h.$('new-dialog').open, false);
  assert.equal(h.$('demo-action-label').textContent, 'Add API key');
});

test('waits for runtime configuration, then prompts once when both key sources are missing', async () => {
  const h = harness();
  assertAttention(h, false);
  assert.deepEqual(h.notifications, []);
  h.checks[0].resolve({ environmentKeyConfigured: false });
  await tick();
  assertAttention(h, true);
  assert.deepEqual(h.notifications, [prompt]);
  h.$('open-settings').emit('click');
  assertAttention(h, true);
  h.checks[1].resolve({ environmentKeyConfigured: false });
  await tick();
  assert.deepEqual(h.notifications, [prompt], 'opening and rechecking do not repeat the prompt');
});

test('an environment key prevents attention and an unnecessary missing-key notification', async () => {
  const h = harness();
  assertAttention(h, false);
  h.checks[0].resolve({ environmentKeyConfigured: true });
  await tick();
  assertAttention(h, false);
  assert.equal(h.$('settings-indicator').hidden, false);
  assert.deepEqual(h.notifications, []);
});

test('a browser key saved while configuration is loading prevents a late missing-key flash', async () => {
  const h = harness();
  h.$('settings-api-key').value = 'fictional-key';
  h.$('settings-form').emit('submit');
  assert.equal(h.store.status().hasKey, true);
  h.checks[0].resolve({ environmentKeyConfigured: false });
  await tick();
  assertAttention(h, false);
  assert.equal(h.notifications.includes(prompt), false);
  assert.equal(h.$('settings-api-key').value, '');
});

test('saving stops the pulse and clearing the final key keeps the add-key notification visible', async () => {
  const h = harness();
  h.checks[0].resolve({ environmentKeyConfigured: false });
  await tick();
  h.$('settings-api-key').value = 'fictional-key';
  h.$('settings-form').emit('submit');
  assertAttention(h, false);
  h.$('clear-api-key').emit('click');
  assertAttention(h, true);
  assert.equal(h.notifications.at(-1), prompt);
  assert.equal(h.notifications.filter(message => message === prompt).length, 2);
  assert.equal(h.notifications.some(message => /key cleared/.test(message)), false);
});

test('clearing a browser key keeps the automatic environment connection configured', async () => {
  const h = harness({ savedKey: 'fictional-key' });
  h.checks[0].resolve({ environmentKeyConfigured: true });
  await tick();
  h.$('clear-api-key').emit('click');
  assertAttention(h, false);
  assert.equal(h.store.status().hasKey, false);
  assert.equal(h.notifications.includes(prompt), false);
  assert.equal(h.notifications.at(-1), 'Saved API key cleared from this browser.');
  assert.equal(h.$('demo-action-label').textContent, 'Add your audio');
  assert.equal(h.$('demo-add-audio').getAttribute('aria-controls'), 'new-dialog');
  h.$('demo-add-audio').emit('click');
  assert.equal(h.$('new-dialog').open, true);
  assert.equal(Boolean(h.$('settings-dialog').open), false);
});

test('cross-tab key saves and removals update attention and notify only when entering missing state', async () => {
  const h = harness({ savedKey: 'fictional-key' });
  h.checks[0].resolve({ environmentKeyConfigured: false });
  await tick();
  h.storage.removeItem(API_KEY_STORAGE);
  h.window.emit('storage', { key: API_KEY_STORAGE });
  assertAttention(h, true);
  assert.equal(h.$('demo-action-label').textContent, 'Add API key');
  assert.deepEqual(h.notifications, [prompt]);
  h.window.emit('storage', { key: API_KEY_STORAGE });
  assert.deepEqual(h.notifications, [prompt]);
  h.storage.setItem(API_KEY_STORAGE, 'another-fictional-key');
  h.window.emit('storage', { key: API_KEY_STORAGE });
  assertAttention(h, false);
  assert.equal(h.$('demo-action-label').textContent, 'Add your audio');
  h.storage.removeItem(API_KEY_STORAGE);
  h.window.emit('storage', { key: null });
  assertAttention(h, true);
  assert.equal(h.$('demo-action-label').textContent, 'Add API key');
  assert.deepEqual(h.notifications, [prompt, prompt]);
});

test('only the latest runtime check controls attention when checks finish out of order', async () => {
  const h = harness();
  h.$('open-settings').emit('click');
  assert.equal(h.checks.length, 2);
  h.checks[1].resolve({ environmentKeyConfigured: true });
  await tick();
  h.checks[0].resolve({ environmentKeyConfigured: false });
  await tick();
  assertAttention(h, false);
  assert.deepEqual(h.notifications, []);
});

test('configuration failure prompts after checking completes only when no browser key exists', async () => {
  for (const savedKey of ['', 'fictional-key']) {
    const h = harness({ savedKey });
    assertAttention(h, false);
    h.checks[0].reject(new Error('Configuration unavailable'));
    await tick();
    assertAttention(h, !savedKey);
    assert.deepEqual(h.notifications, savedKey ? [] : [prompt]);
  }
});

test('opening refreshes saved hints and Cancel discards changes', () => {
  const h = harness({ savedHints: ['en'] });
  h.storage.setItem(LANGUAGE_HINTS_STORAGE, '["en","cy"]');
  h.$('open-settings').emit('click');
  assert.equal(h.hint('en').checked, true);
  assert.equal(h.hint('cy').checked, true);
  h.select('ja');
  h.select('cy', false);
  h.$('cancel-settings').emit('click');
  assert.deepEqual(h.preferences.get(), ['en', 'cy']);
  h.$('open-settings').emit('click');
  assert.equal(h.hint('ja').checked, false);
  assert.equal(h.hint('cy').checked, true);
});

test('search filters by name or code without losing selected languages', () => {
  const h = harness({ savedHints: ['en'] });
  h.$('open-settings').emit('click');
  h.$('language-hints-search').value = 'welsh';
  h.$('language-hints-search').emit('input');
  assert.equal(h.option('cy').hidden, false);
  assert.equal(h.option('en').hidden, true);
  assert.equal(h.hint('en').checked, true);
  h.select('cy');
  h.$('language-hints-search').value = 'CMN';
  h.$('language-hints-search').emit('input');
  assert.equal(h.option('cmn').hidden, false);
  assert.equal(h.option('cy').hidden, true);
  h.$('settings-form').emit('submit');
  assert.deepEqual(createLanguagePreferences(h.storage).get(), ['en', 'cy']);
  assert.deepEqual(h.hintChanges.at(-1), ['en', 'cy']);
});

test('language preferences can be saved without an API key while missing-key attention stays visible', async () => {
  const h = harness();
  h.checks[0].resolve({ environmentKeyConfigured: false });
  await tick();
  h.$('open-settings').emit('click');
  h.select('cy');
  h.$('settings-form').emit('submit');
  assert.equal(h.$('settings-dialog').open, false);
  assert.deepEqual(h.preferences.get(), ['cy']);
  assert.equal(h.$('settings-error').hidden, true);
  assert.equal(h.store.status().hasKey, false);
  assertAttention(h, true);
  assert.match(h.notifications.at(-1), /settings saved/i);
});

test('clearing expected languages is a draft until Save, with empty hints restoring automatic detection', () => {
  const h = harness({ savedHints: ['en', 'cy'] });
  h.$('open-settings').emit('click');
  h.$('clear-language-hints').emit('click');
  assert.equal(h.hint('en').checked, false);
  assert.match(h.$('language-hints-summary').textContent, /automatic/i);
  assert.deepEqual(h.preferences.get(), ['en', 'cy']);
  h.$('cancel-settings').emit('click');
  h.$('open-settings').emit('click');
  assert.equal(h.hint('en').checked, true);
  h.$('clear-language-hints').emit('click');
  h.$('settings-form').emit('submit');
  assert.deepEqual(createLanguagePreferences(h.storage).get(), []);
  assert.deepEqual(h.hintChanges, [[]]);
});

test('clearing a saved API key keeps the current language draft', () => {
  const h = harness({ savedKey: 'fictional-key', savedHints: ['en'] });
  h.$('open-settings').emit('click');
  h.select('cy');
  h.$('clear-api-key').emit('click');
  assert.equal(h.store.status().hasKey, false);
  assert.equal(h.hint('en').checked, true);
  assert.equal(h.hint('cy').checked, true);
  h.$('settings-form').emit('submit');
  assert.deepEqual(h.preferences.get(), ['en', 'cy']);
});

test('a key storage event preserves unsaved hints, while a language event reloads external preferences', () => {
  const h = harness({ savedHints: ['en'] });
  h.$('open-settings').emit('click');
  h.select('cy');
  h.storage.setItem(API_KEY_STORAGE, 'fictional-key');
  h.window.emit('storage', { key: API_KEY_STORAGE });
  assert.equal(h.hint('cy').checked, true);
  assert.deepEqual(h.hintChanges, []);
  h.storage.setItem(LANGUAGE_HINTS_STORAGE, '["ja"]');
  h.window.emit('storage', { key: LANGUAGE_HINTS_STORAGE });
  assert.deepEqual(h.preferences.get(), ['ja']);
  assert.equal(h.hint('ja').checked, true);
  assert.equal(h.hint('cy').checked, false);
  assert.deepEqual(h.hintChanges, [['ja']]);
  h.window.emit('storage', { key: LANGUAGE_HINTS_STORAGE });
  assert.equal(h.hintChanges.length, 1, 'unchanged storage events do not report a change');
  h.storage.removeItem(LANGUAGE_HINTS_STORAGE);
  h.window.emit('storage', { key: null });
  assert.deepEqual(h.preferences.get(), []);
  assert.deepEqual(h.hintChanges, [['ja'], []]);
});

test('saving a new API key and language draft persists both and only reports actual hint changes', () => {
  const h = harness({ savedHints: ['en'] });
  h.$('open-settings').emit('click');
  h.$('settings-api-key').value = 'fictional-key';
  h.select('cy');
  h.$('settings-form').emit('submit');
  assert.equal(h.storage.getItem(API_KEY_STORAGE), 'fictional-key');
  assert.deepEqual(createLanguagePreferences(h.storage).get(), ['en', 'cy']);
  assert.deepEqual(h.hintChanges, [['en', 'cy']]);
  h.$('open-settings').emit('click');
  h.$('settings-form').emit('submit');
  assert.equal(h.hintChanges.length, 1);
});

test('invalid API keys leave both preferences and the unsaved language draft intact', () => {
  const h = harness({ savedHints: ['en'] });
  h.$('open-settings').emit('click');
  h.select('cy');
  h.$('settings-api-key').value = 'invalid key';
  h.$('settings-form').emit('submit');
  assert.equal(h.$('settings-dialog').open, true);
  assert.equal(h.$('settings-error').hidden, false);
  assert.deepEqual(h.preferences.get(), ['en']);
  assert.equal(h.hint('cy').checked, true);
  assert.deepEqual(h.hintChanges, []);
});

test('a language storage failure leaves the dialog open and the draft available for retry', () => {
  const h = harness({ savedHints: ['en'], failHintsSave: true });
  h.$('open-settings').emit('click');
  h.select('cy');
  h.$('settings-form').emit('submit');
  assert.equal(h.$('settings-dialog').open, true);
  assert.equal(h.$('settings-error').hidden, false);
  assert.match(h.$('settings-error').textContent, /storage.*unavailable/i);
  assert.deepEqual(h.preferences.get(), ['en']);
  assert.equal(h.hint('cy').checked, true);
  assert.deepEqual(h.hintChanges, []);
});
