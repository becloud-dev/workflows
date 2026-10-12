import { describe, expect, it } from 'vitest'
import { decodeSession } from '../../src/domain/exam.ts'
import { fixtureContent } from '../domain/fixtures.ts'
import { visitor } from './helpers.ts'

const sessionOf = (v: ReturnType<typeof visitor>) => {
  const s = decodeSession(v.cookie('exam'), fixtureContent())
  if (!s) throw new Error('no exam cookie')
  return s
}

describe('exam routes', () => {
  it('offers to start when there is no session', async () => {
    const v = visitor()
    const r = await v.get('/x/exam')
    expect(r.status).toBe(200)
    expect(r.text).toContain('hx-post="/x/exam"')
    expect(r.text).toContain('Start exam')
  })

  it('starts an exam with the configured number of questions and shows the first', async () => {
    const v = visitor({ examSize: 5 })
    const r = await v.post('/x/exam')
    expect(r.status).toBe(200)
    expect(r.text).toContain('Question 1 of 5')
    expect(sessionOf(v).ids).toHaveLength(5)
    expect(sessionOf(v).minutes).toBe(90)
  })

  it('shows any question by position and 404s outside the exam', async () => {
    const v = visitor()
    await v.post('/x/exam')
    expect((await v.get('/x/exam/3')).text).toContain('Question 3 of 5')
    expect((await v.get('/x/exam/0')).status).toBe(404)
    expect((await v.get('/x/exam/6')).status).toBe(404)
    expect((await v.get('/x/exam/abc')).status).toBe(404)
  })

  it('sends visitors without a session back to the start', async () => {
    const v = visitor()
    expect((await v.get('/x/exam/1')).status).toBe(409)
    expect((await v.put('/x/exam/1/answer', { option: 'A' })).status).toBe(409)
  })

  it('records an answer and shows it selected', async () => {
    const v = visitor()
    await v.post('/x/exam')
    const first = sessionOf(v).ids[0]
    const r = await v.put('/x/exam/1/answer', { option: 'C' })
    expect(r.status).toBe(200)
    expect(sessionOf(v).answers[first]).toBe('C')
    expect(r.text).toMatch(/value="C"[^>]*checked/)
  })

  it('rejects an option the question does not have', async () => {
    const v = visitor()
    await v.post('/x/exam')
    expect((await v.put('/x/exam/1/answer', { option: 'Z' })).status).toBe(422)
  })

  it('flags and unflags a question', async () => {
    const v = visitor()
    await v.post('/x/exam')
    const first = sessionOf(v).ids[0]
    await v.put('/x/exam/1/flag', { flag: 'true' })
    expect(sessionOf(v).flags).toEqual([first])
    await v.put('/x/exam/1/flag', { flag: 'false' })
    expect(sessionOf(v).flags).toEqual([])
  })

  it('rejects a flag value that is not true or false', async () => {
    const v = visitor()
    await v.post('/x/exam')
    expect((await v.put('/x/exam/1/flag', { flag: 'maybe' })).status).toBe(400)
    expect(sessionOf(v).flags).toEqual([])
  })

  it('says the time ran out only when it did', async () => {
    const finished = visitor()
    await finished.post('/x/exam')
    expect((await finished.post('/x/exam/finish')).text).not.toContain('the time ran out')
    const expired = visitor({ examMinutes: 1 })
    await expired.post('/x/exam')
    expired.advance(61_000)
    expect((await expired.get('/x/exam')).text).toContain('the time ran out')
  })

  it('never says which option is correct while the exam is running', async () => {
    const a = visitor()
    await a.post('/x/exam')
    const content = fixtureContent()
    for (const q of Object.values(content.questions)) q.correct = 'A'
    const b = visitor({ content })
    await b.post('/x/exam')
    expect((await a.get('/x/exam/1')).text).toBe((await b.get('/x/exam/1')).text)
  })

  it('finishes with a report, and keeps showing it', async () => {
    const v = visitor({ examSize: 5 })
    await v.post('/x/exam')
    for (const [i, id] of sessionOf(v).ids.entries()) {
      void id
      await v.put(`/x/exam/${i + 1}/answer`, { option: 'B' })
    }
    const done = await v.post('/x/exam/finish')
    expect(done.status).toBe(200)
    expect(done.text).toContain('1000')
    expect(done.text).toContain('Passed')
    expect((await v.get('/x/exam')).text).toContain('1000')
  })

  it('reports a failing score', async () => {
    const v = visitor({ examSize: 5 })
    await v.post('/x/exam')
    const done = await v.post('/x/exam/finish')
    expect(done.text).toContain('Not passed')
    expect(done.text).toContain('0')
  })

  it('refuses answers after the exam is over', async () => {
    const v = visitor()
    await v.post('/x/exam')
    await v.post('/x/exam/finish')
    expect((await v.put('/x/exam/1/answer', { option: 'A' })).status).toBe(409)
  })

  it('starts a new exam after a finished one', async () => {
    const v = visitor()
    await v.post('/x/exam')
    await v.post('/x/exam/finish')
    const again = await v.post('/x/exam')
    expect(again.text).toContain('Question 1 of 5')
    expect(sessionOf(v).end).toBeUndefined()
  })

  it('shows the time left and refreshes the page once the time is up', async () => {
    const v = visitor({ examMinutes: 1 })
    await v.post('/x/exam')
    v.advance(20_000)
    expect((await v.get('/x/exam/timer')).text).toContain('0:40')
    v.advance(41_000)
    const t = await v.get('/x/exam/timer')
    expect(t.headers.get('HX-Refresh')).toBe('true')
    // an expired exam shows its report
    expect((await v.get('/x/exam')).text).toContain('Not passed')
  })

  it('does not take answers after the time is up', async () => {
    const v = visitor({ examMinutes: 1 })
    await v.post('/x/exam')
    v.advance(61_000)
    expect((await v.put('/x/exam/1/answer', { option: 'A' })).status).toBe(409)
  })

  it('ignores a cookie that is not ours', async () => {
    const v = visitor()
    v.jar.set('exam', 'garbage')
    expect((await v.get('/x/exam')).text).toContain('Start exam')
  })
})
