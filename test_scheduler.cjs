const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('app.js', 'utf8');
const context = vm.createContext({});
vm.runInContext(source.split('const documents = [')[0] + '\nthis.IntentRequests = IntentRequests;', context);
const IntentRequests = context.IntentRequests;

test('dispatches immediately, shares in-flight work, and caches successes', async () => {
  let calls = 0, finish;
  const requests = new IntentRequests(() => {
    calls++;
    return new Promise(resolve => { finish = resolve; });
  });
  const first = requests.get('Japan');
  assert.equal(calls, 1);
  assert.equal(requests.get('Japan'), first);
  finish(['flight']);
  await first;
  assert.deepEqual(await requests.get('Japan'), ['flight']);
  assert.equal(calls, 1);
});

test('bounds concurrency and replaces obsolete queued words', async () => {
  const completions = new Map();
  const requests = new IntentRequests(key => new Promise(resolve => completions.set(key, resolve)));
  const a = requests.get('a'), b = requests.get('b');
  const skipped = requests.get('old'), latest = requests.get('latest');
  assert.equal(requests.active, 2);
  assert.equal(await skipped, null);
  completions.get('a')([]);
  await a;
  assert.equal(completions.has('old'), false);
  assert.equal(completions.has('latest'), true);
  completions.get('b')([]);
  completions.get('latest')([]);
  await Promise.all([b, latest]);
});

test('errors can be retried and clearing cancels queued work', async () => {
  let calls = 0;
  const requests = new IntentRequests(async () => {
    if (++calls === 1) throw new Error('offline');
    return [];
  });
  await assert.rejects(requests.get('Japan'));
  await requests.get('Japan');
  assert.equal(calls, 2);
  const blocked = new IntentRequests(() => new Promise(() => {}), 1);
  blocked.get('running');
  const waiting = blocked.get('waiting');
  blocked.cancelQueued();
  assert.equal(await waiting, null);
});

test('space sends immediately; other input waits 120ms; short input invalidates responses', () => {
  const sent = [], timers = [];
  const element = { value: 'Japan ', classList: { toggle() {} } };
  const ctx = vm.createContext({
    folderInput: element, document: { querySelectorAll: () => [] },
    $: () => ({}), clearTimeout() {}, setTimeout(fn, delay) { timers.push({fn, delay}); },
    classificationRequests: { cancelQueued() {} }, setThinking() {},
    clearFolder() {}, classify: (name, version) => sent.push({name, version}),
  });
  const fn = source.slice(source.indexOf('function scheduleClassification('), source.indexOf('folderInput.addEventListener("input"'));
  vm.runInContext('let debounceTimer, requestVersion = 0, composing = false;\n' + fn, ctx);
  vm.runInContext('scheduleClassification({})', ctx);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].name, 'Japan');
  element.value = 'Japan tr';
  vm.runInContext('scheduleClassification({})', ctx);
  assert.equal(timers[0].delay, 120);
  assert.equal(sent.length, 1);
  element.value = 'x';
  vm.runInContext('scheduleClassification({})', ctx);
  assert.equal(vm.runInContext('requestVersion', ctx), 3);
});
