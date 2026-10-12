import { describe, expect, it } from 'vitest'
import { parsePractice, recordResult, serializePractice } from '../../src/domain/practice.ts'
import { MAX_VALUE } from '../../src/domain/progress.ts'

const known = new Set(['q1', 'q2', 'q3'])

describe('practice results', () => {
  it('round-trips', () => {
    expect(parsePractice(serializePractice([['q1', true], ['q2', false]]), known)).toEqual([['q1', true], ['q2', false]])
  })

  it('drops unknown ids and malformed entries', () => {
    expect(parsePractice('q1!1.zz!1.q2!x.q3', known)).toEqual([['q1', true]])
    expect(parsePractice(undefined, known)).toEqual([])
  })

  it('uses only characters a cookie value needs no escaping for', () => {
    const v = serializePractice([['question-1', true], ['question-2', false]])
    expect(v).toBe('question-1!1.question-2!0')
    expect(encodeURIComponent(v)).toBe(v)
  })

  it('replaces a result in place and appends a new one', () => {
    const a = recordResult([['q1', false]], 'q2', true)
    expect(a).toEqual([['q1', false], ['q2', true]])
    expect(recordResult(a, 'q1', true)).toEqual([['q1', true], ['q2', true]])
  })

  it('forgets the oldest results when the budget is used', () => {
    let entries: [string, boolean][] = []
    for (let i = 0; i < 800; i++) entries = recordResult(entries, `question-${i}`, i % 2 === 0)
    expect(serializePractice(entries).length).toBeLessThanOrEqual(MAX_VALUE)
    expect(entries.at(-1)?.[0]).toBe('question-799')
    expect(entries[0]?.[0]).not.toBe('question-0')
  })
})
