const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const swift = readFileSync('XGizou/Services/FingerprintSpoofer.swift', 'utf8');
const template = swift.split('return """')[1].split('"""')[0]
  .replaceAll('\\\\', '\\');
const config = {
  userAgent: 'Mozilla/5.0 test', appVersion: '5.0 test', platform: 'iPhone',
  vendor: 'Apple Computer, Inc.', language: 'ja-JP', languages: ['ja-JP'],
  hardwareConcurrency: 6, maxTouchPoints: 5, screenWidth: 393, screenHeight: 852,
  availWidth: 393, availHeight: 852, colorDepth: 32, pixelDepth: 32, pixelRatio: 3,
  timezoneIdentifier: 'Asia/Tokyo', spoofTimezone: true, spoofCanvas: true,
  spoofWebGL: true, spoofAudio: true, webGLVendor: 'Apple Inc.',
  webGLRenderer: 'Apple GPU', seed: 1001
};
function runtime(overrides = {}) {
  const context = vm.createContext({});
  vm.runInContext(`
    globalThis.window = globalThis;
    globalThis.navigator = {}; globalThis.screen = {};
    globalThis.WebGLRenderingContext = class {
      getParameter(p) { return p === 42 ? 'native-value' : 'native-gpu'; }
    };
    globalThis.AudioBuffer = class {
      constructor() { this.data = new Float32Array(32).fill(0.5); }
      getChannelData(channel) { if (channel !== 0) throw new RangeError(); return this.data; }
    };
    globalThis.HTMLCanvasElement = class {};
    globalThis.CanvasRenderingContext2D = class {
      getImageData() { return { data: new Uint8ClampedArray(64).fill(128) }; }
      putImageData() {}
    };
  `, context);
  vm.runInContext(template.replace('\\(json)', JSON.stringify({ ...config, ...overrides })), context);
  return code => vm.runInContext(code, context);
}
test('iOS optional JSON fields remain absent and selected navigator values apply', () => {
  const run = runtime();
  assert.equal(run('navigator.userAgent'), config.userAgent);
  assert.equal(run('navigator.platform'), 'iPhone');
  assert.equal(run('screen.width'), 393);
  assert.equal(run('devicePixelRatio'), 3);
  assert.equal(run("'userAgentData' in navigator"), false);
  assert.equal(run("'deviceMemory' in navigator"), false);
});
test('Chromium profile exposes requested client hints', async () => {
  const run = runtime({ uaDataPlatform: 'Windows', uaDataMobile: false,
    uaDataArchitecture: 'x86', deviceMemory: 8, userAgent: 'Chrome/146.0.0.0' });
  assert.equal(run('navigator.userAgentData.platform'), 'Windows');
  assert.equal(run('navigator.deviceMemory'), 8);
  assert.equal((await run("navigator.userAgentData.getHighEntropyValues(['architecture'])")).architecture, 'x86');
});
test('timezone formats actual values, preserves explicit zones and handles DST', () => {
  const run = runtime({ timezoneIdentifier: 'America/New_York' });
  assert.equal(run("new Date('2026-01-01T12:00:00Z').getTimezoneOffset()"), 300);
  assert.equal(run("new Date('2026-07-01T12:00:00Z').getTimezoneOffset()"), 240);
  assert.equal(run("Intl.DateTimeFormat().resolvedOptions().timeZone"), 'America/New_York');
  assert.equal(run("Intl.DateTimeFormat('en', {timeZone:'UTC'}).resolvedOptions().timeZone"), 'UTC');
  assert.equal(run("new Intl.DateTimeFormat('en', {hour:'numeric',hourCycle:'h23'}).format(new Date('2026-01-01T12:00:00Z'))"), '07');
  assert.equal(run("Number.isNaN(new Date(NaN).getTimezoneOffset())"), true);
});
test('WebGL delegates unrelated queries and audio perturbation is stable', () => {
  const run = runtime();
  assert.equal(run('new WebGLRenderingContext().getParameter(37446)'), 'Apple GPU');
  assert.equal(run('new WebGLRenderingContext().getParameter(42)'), 'native-value');
  run('globalThis.buffer = new AudioBuffer()');
  const first = run('JSON.stringify(Array.from(buffer.getChannelData(0)))');
  assert.equal(run('JSON.stringify(Array.from(buffer.getChannelData(0)))'), first);
  assert.notEqual(first, JSON.stringify(Array(32).fill(0.5)));
});
test('Canvas readback remains stable per profile and changes across seeds', () => {
  const expression = 'JSON.stringify(Array.from(new CanvasRenderingContext2D().getImageData(0,0,4,4).data))';
  const a = runtime(); const b = runtime({seed: 2024});
  assert.equal(a(expression), a(expression));
  assert.notEqual(a(expression), b(expression));
});
test('disabled optional patches leave native values intact', () => {
  const run = runtime({spoofTimezone: false, spoofCanvas: false, spoofWebGL: false, spoofAudio: false});
  assert.equal(run('new WebGLRenderingContext().getParameter(37446)'), 'native-gpu');
  assert.equal(run('new AudioBuffer().getChannelData(0)[0]'), 0.5);
  assert.equal(run('new CanvasRenderingContext2D().getImageData().data[0]'), 128);
});
