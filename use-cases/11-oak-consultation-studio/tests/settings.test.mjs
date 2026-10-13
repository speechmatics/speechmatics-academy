import test from 'node:test';
import assert from 'node:assert/strict';
import { initSettings } from '../public/settings.js';
import { API_KEY_STORAGE, createCredentialStore } from '../public/credentials.js';

const tick = () => new Promise(resolve => setImmediate(resolve));
const prompt = 'Add your Speechmatics API key in Settings to start transcribing.';

class Element {
  constructor() {
    this.events = new Map();
    this.attributes = new Map();
    this.classes = new Set();
    this.hidden = true;
    this.value = '';
    this.type = 'password';
    this.textContent = '';
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
  focus() { this.focused = true; }
  showModal() { this.open = true; }
  close() { this.open = false; this.emit('close'); }
}

function harness({ savedKey = '' } = {}) {
  const values = new Map(savedKey ? [[API_KEY_STORAGE, savedKey]] : []);
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value), removeItem: key => values.delete(key) };
  const store = createCredentialStore(storage);
  const nodes = new Map();
  const document = { getElementById: id => { if (!nodes.has(id)) nodes.set(id, new Element()); return nodes.get(id); } };
  const window = new Element();
  const notifications = [];
  const checks = [];
  const readConfig = () => new Promise((resolve, reject) => checks.push({ resolve, reject }));
  initSettings(message => notifications.push(message), { document, window, store, readConfig });
  return { $: id => document.getElementById(id), window, storage, store, notifications, checks };
}

function assertAttention(h, expected) {
  assert.equal(h.$('open-settings').classList.contains('needs-api-key'), expected);
  assert.equal(h.$('open-settings').getAttribute('aria-describedby'), expected ? 'settings-key-hint' : null);
  assert.equal(h.$('open-settings').getAttribute('title'), expected ? 'Add your Speechmatics API key' : null);
  assert.equal(h.$('settings-key-hint').hidden, !expected);
}

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
});

test('cross-tab key saves and removals update attention and notify only when entering missing state', async () => {
  const h = harness({ savedKey: 'fictional-key' });
  h.checks[0].resolve({ environmentKeyConfigured: false });
  await tick();
  h.storage.removeItem(API_KEY_STORAGE);
  h.window.emit('storage', { key: API_KEY_STORAGE });
  assertAttention(h, true);
  assert.deepEqual(h.notifications, [prompt]);
  h.window.emit('storage', { key: API_KEY_STORAGE });
  assert.deepEqual(h.notifications, [prompt]);
  h.storage.setItem(API_KEY_STORAGE, 'another-fictional-key');
  h.window.emit('storage', { key: API_KEY_STORAGE });
  assertAttention(h, false);
  h.storage.removeItem(API_KEY_STORAGE);
  h.window.emit('storage', { key: null });
  assertAttention(h, true);
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
