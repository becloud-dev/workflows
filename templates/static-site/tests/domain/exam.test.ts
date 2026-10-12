import { describe, expect, it } from 'vitest'
import { buildExam, decodeSession, encodeSession, isOver, remainingSeconds, score } from '../../src/domain/exam.ts'
import { fixtureContent, seq } from './fixtures.ts'

const content = fixtureContent()

describe('buildExam', () => {
  it('splits the questions across domains by weight', () => {
    const ids = buildExam(content, 5, seq(0.1, 0.5, 0.9))
    const d1 = ids.filter((id) => content.questions[id]?.domain === 1)
    const d2 = ids.filter((id) => content.questions[id]?.domain === 2)
    expect(ids).toHaveLength(5)
    expect(d1).toHaveLength(2) // 40% of 5
    expect(d2).toHaveLength(3) // 60% of 5
  })

  it('never repeats a question', () => {
    const ids = buildExam(content, 8, seq(0.3, 0.7))
    expect(new Set(ids).size).toBe(ids.length)
  })

  it('uses every question when more are asked for than exist', () => {
    expect(buildExam(content, 99, seq(0.2)).sort()).toEqual(Object.keys(content.questions).sort())
  })

  it('fills a short domain from the others', () => {
    // domain 1 is entitled to 4 of 10 (40%) but has only 3 questions: the 4th comes from domain 2
    const ids = buildExam(content, 8, seq(0.5))
    expect(ids.filter((id) => content.questions[id]?.domain === 1)).toHaveLength(3)
    expect(ids).toHaveLength(8)
  })

  it('gives a short domain all it has and makes up the rest from the others', () => {
    const skewed = {
      domains: [
        { id: 1, title: 'One', weight: 50 },
        { id: 2, title: 'Two', weight: 50 },
      ],
      topics: [],
      questions: Object.fromEntries(
        ['x1', ...Array.from({ length: 9 }, (_, i) => `y${i}`)].map((id) => [
          id,
          { domain: id.startsWith('x') ? 1 : 2, correct: 'B', text: id, options: [{ id: 'A', text: 'a' }, { id: 'B', text: 'b' }] },
        ]),
      ),
    }
    const ids = buildExam(skewed, 6, seq(0.4, 0.8))
    expect(ids).toHaveLength(6)
    expect(ids.filter((id) => id.startsWith('x'))).toHaveLength(1)
    expect(buildExam(skewed, 99, seq(0.4)).sort()).toEqual(Object.keys(skewed.questions).sort())
  })

  it('mixes the domains in the order of the exam', () => {
    const ids = buildExam(content, 8, () => 0)
    const firstThree = ids.slice(0, 3).map((id) => content.questions[id]?.domain)
    expect(new Set(firstThree).size).toBeGreaterThan(1)
  })

  it('is deterministic for the same random source', () => {
    expect(buildExam(content, 5, seq(0.1, 0.9, 0.4))).toEqual(buildExam(content, 5, seq(0.1, 0.9, 0.4)))
  })
})

describe('score', () => {
  const session = (answers: Record<string, string>) => ({
    start: 0,
    minutes: 90,
    ids: Object.keys(content.questions),
    answers,
    flags: [],
  })
  const allRight = Object.fromEntries(Object.keys(content.questions).map((id) => [id, 'B']))

  it('scores 1000 when everything is right and passes', () => {
    const r = score(content, session(allRight))
    expect(r.scaled).toBe(1000)
    expect(r.passed).toBe(true)
  })

  it('scores 0 when nothing is answered and fails', () => {
    const r = score(content, session({}))
    expect(r.scaled).toBe(0)
    expect(r.passed).toBe(false)
  })

  it('passes at exactly 700', () => {
    const c = { ...content, domains: [{ id: 1, title: 'One', weight: 70 }, { id: 2, title: 'Two', weight: 30 }] }
    const s = { start: 0, minutes: 90, ids: ['a1', 'b1'], answers: { a1: 'B', b1: 'A' }, flags: [] }
    expect(score(c, s).scaled).toBe(700)
    expect(score(c, s).passed).toBe(true)
  })

  it('weights domains: domain 2 right, domain 1 wrong is 600', () => {
    const answers = Object.fromEntries(Object.keys(content.questions).map((id) => [id, content.questions[id]?.domain === 2 ? 'B' : 'A']))
    expect(score(content, session(answers)).scaled).toBe(600)
  })

  it('passes at 700 and fails at 699', () => {
    // domain 1 all right (400) + domain 2 half right: 2.5 of 5 is not possible, so use 3 of 5 = 360 -> 760
    const ok = { a1: 'B', a2: 'B', a3: 'B', b1: 'B', b2: 'B', b3: 'B' }
    expect(score(content, session(ok)).scaled).toBe(760)
    expect(score(content, session(ok)).passed).toBe(true)
    const low = { a1: 'B', a2: 'B', a3: 'B', b1: 'B', b2: 'B' }
    expect(score(content, session(low)).scaled).toBe(640)
    expect(score(content, session(low)).passed).toBe(false)
  })

  it('reports each domain with its count and percent', () => {
    const r = score(content, session({ a1: 'B', a2: 'A', b1: 'B' }))
    expect(r.perDomain).toEqual([
      { domain: 1, correct: 1, total: 3, percent: 33 },
      { domain: 2, correct: 1, total: 5, percent: 20 },
    ])
  })

  it('only counts the questions in the session', () => {
    const s = { start: 0, minutes: 90, ids: ['a1', 'b1'], answers: { a1: 'B', b1: 'A' }, flags: [] }
    const r = score(content, s)
    expect(r.perDomain).toEqual([
      { domain: 1, correct: 1, total: 1, percent: 100 },
      { domain: 2, correct: 0, total: 1, percent: 0 },
    ])
    expect(r.scaled).toBe(400)
  })
})

describe('remainingSeconds', () => {
  const s = { start: 1_000_000, minutes: 1, ids: [], answers: {}, flags: [] }
  it('counts down from the start', () => {
    expect(remainingSeconds(s, 1_000_000)).toBe(60)
    expect(remainingSeconds(s, 1_030_000)).toBe(30)
  })
  it('never goes below zero', () => {
    expect(remainingSeconds(s, 1_500_000)).toBe(0)
  })
})

describe('session cookie', () => {
  const s = { start: 1700000000000, minutes: 90, ids: ['a1', 'b2'], answers: { a1: 'B' }, flags: ['b2'] }

  it('round-trips', () => {
    expect(decodeSession(encodeSession(s), content)).toEqual(s)
  })

  it('stays compact and needs no escaping', () => {
    const big = {
      start: 1700000000000,
      minutes: 90,
      ids: Array.from({ length: 65 }, (_, i) => `aif-question-${String(i).padStart(3, '0')}`),
      answers: {} as Record<string, string>,
      flags: [] as string[],
    }
    for (const id of big.ids) big.answers[id] = 'B'
    big.flags = big.ids.slice(0, 20)
    const v = encodeSession(big)
    expect(encodeURIComponent(v)).toBe(v)
    expect(v.length).toBeLessThan(1700)
  })

  it('maps answers and flags by position, so dropped ids do not shift them', () => {
    const raw = '1700000000000~90~~a1.zzz.b2~2B~2'
    const got = decodeSession(raw, content)
    expect(got?.ids).toEqual(['a1', 'b2'])
    expect(got?.answers).toEqual({ b2: 'B' })
    expect(got?.flags).toEqual(['b2'])
  })

  it('rejects garbage', () => {
    expect(decodeSession('not json', content)).toBeNull()
    expect(decodeSession(undefined, content)).toBeNull()
    expect(decodeSession('{}', content)).toBeNull()
    expect(decodeSession('1~2~3', content)).toBeNull()
    expect(decodeSession('x~90~~a1~~', content)).toBeNull()
  })

  it('rejects a duration that is not credible', () => {
    expect(decodeSession(encodeSession({ ...s, minutes: 601 }), content)).toBeNull()
    expect(decodeSession(encodeSession({ ...s, minutes: 0 }), content)).toBeNull()
    expect(decodeSession(encodeSession({ ...s, minutes: 600 }), content)?.minutes).toBe(600)
  })

  it('drops ids and answers that the content does not know', () => {
    const tampered = encodeSession({ ...s, ids: ['a1', 'zzz'], answers: { a1: 'Z', zzz: 'A' }, flags: ['zzz'] })
    const got = decodeSession(tampered, content)
    expect(got?.ids).toEqual(['a1'])
    expect(got?.answers).toEqual({})
    expect(got?.flags).toEqual([])
  })
})

describe('isOver', () => {
  const s = { start: 0, minutes: 1, ids: [], answers: {}, flags: [] }
  it('is not over while there is time and it was not finished', () => {
    expect(isOver(s, 30_000)).toBe(false)
  })
  it('is over when the time is up', () => {
    expect(isOver(s, 60_000)).toBe(true)
  })
  it('is over when the visitor finished, however much time is left', () => {
    expect(isOver({ ...s, end: 10_000 }, 20_000)).toBe(true)
  })
  it('keeps the end through the cookie', () => {
    expect(decodeSession(encodeSession({ ...s, end: 12345 }), fixtureContent())?.end).toBe(12345)
  })
  it('rejects an end that is not a number', () => {
    expect(decodeSession('1700000000000~90~soon~a1~~', fixtureContent())).toBeNull()
  })
})
