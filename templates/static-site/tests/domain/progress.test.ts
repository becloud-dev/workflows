import { describe, expect, it } from 'vitest'
import { MAX_VALUE, parseProgress, serializeProgress, setDone } from '../../src/domain/progress.ts'

const known = new Set(['topic-one', 'topic-two', 'topic-three'])

describe('progress', () => {
  it('parses a cookie value into known topic ids', () => {
    expect(parseProgress('topic-one.topic-three', known)).toEqual(['topic-one', 'topic-three'])
  })

  it('drops unknown, repeated and empty entries', () => {
    expect(parseProgress('topic-one.gone.topic-one..', known)).toEqual(['topic-one'])
  })

  it('treats a missing cookie as no progress', () => {
    expect(parseProgress(undefined, known)).toEqual([])
    expect(parseProgress('', known)).toEqual([])
  })

  it('serializes in a stable, sorted order', () => {
    expect(serializeProgress(['topic-two', 'topic-one'])).toBe('topic-one.topic-two')
  })

  it('marks a topic done and not done', () => {
    expect(setDone([], 'topic-one', true, known)).toEqual(['topic-one'])
    expect(setDone(['topic-one', 'topic-two'], 'topic-one', false, known)).toEqual(['topic-two'])
  })

  it('is idempotent', () => {
    expect(setDone(['topic-one'], 'topic-one', true, known)).toEqual(['topic-one'])
    expect(setDone([], 'topic-one', false, known)).toEqual([])
  })

  it('ignores a topic id that does not exist', () => {
    expect(setDone(['topic-one'], 'nope', true, known)).toEqual(['topic-one'])
  })

  it('uses only characters a cookie value needs no escaping for', () => {
    const v = serializeProgress(['topic-one', 'topic-two', 'topic-three'])
    expect(encodeURIComponent(v)).toBe(v)
  })

  it('keeps the value under the cookie budget', () => {
    expect(MAX_VALUE).toBeLessThanOrEqual(3000)
    const all = Array.from({ length: 600 }, (_, i) => `topic-number-${i}`)
    const everything = new Set(all)
    let done: string[] = []
    for (const id of all) done = setDone(done, id, true, everything)
    expect(serializeProgress(done).length).toBeLessThanOrEqual(MAX_VALUE)
    expect(done.length).toBeGreaterThan(100)
    expect(done.length).toBeLessThan(600)
  })

  it('lets a visitor remove topics from a cookie that is already over the budget', () => {
    const over = Array.from({ length: 400 }, (_, i) => `topic-number-${i}`)
    const everything = new Set(over)
    expect(serializeProgress(over).length).toBeGreaterThan(MAX_VALUE)
    expect(setDone(over, over[0] as string, false, everything)).toHaveLength(399)
  })

  it('refuses a new topic once the budget is used, but still allows removing one', () => {
    const all = Array.from({ length: 600 }, (_, i) => `topic-number-${i}`)
    const everything = new Set(all)
    let done: string[] = []
    for (const id of all) done = setDone(done, id, true, everything)
    const full = done.length
    const next = all.find((id) => !done.includes(id)) as string
    expect(setDone(done, next, true, everything)).toHaveLength(full)
    expect(setDone(done, done[0] as string, false, everything)).toHaveLength(full - 1)
  })
})
