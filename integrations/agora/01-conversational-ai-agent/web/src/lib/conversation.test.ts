import { expect, test } from 'bun:test'

import { normalizeTranscript, normalizeTranscriptSpacing } from './conversation'

test('normalizeTranscriptSpacing inserts spaces and collapses whitespace', () => {
  expect(normalizeTranscriptSpacing('Hello.World,now  ok')).toBe('Hello. World, now ok')
})

test("normalizeTranscript remaps uid '0' to the local uid and normalizes text", () => {
  const out = normalizeTranscript(
    [
      { uid: '0', text: 'Hi.There', turn_id: '1', status: 0 },
      { uid: '42', text: 'ok', turn_id: '2', status: 0 },
      // biome-ignore lint/suspicious/noExplicitAny: minimal test fixtures
    ] as any,
    'local-9',
  )
  expect(out[0].uid).toBe('local-9')
  expect(out[0].text).toBe('Hi. There')
  expect(out[1].uid).toBe('42')
})
