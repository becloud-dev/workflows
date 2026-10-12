import { describe, expect, it } from 'vitest'
import { visitor } from './helpers.ts'

describe('POST /x/quiz/check', () => {
  it('says an answer is correct', async () => {
    const v = visitor()
    const r = await v.post('/x/quiz/check', { question_id: 'a1', option: 'B' })
    expect(r.status).toBe(200)
    expect(r.text).toContain('Correct')
    expect(r.text).not.toContain('Incorrect')
  })

  it('says an answer is incorrect and names the right one', async () => {
    const v = visitor()
    const r = await v.post('/x/quiz/check', { question_id: 'a1', option: 'A' })
    expect(r.text).toContain('Incorrect')
    expect(r.text).toContain('The correct answer is B')
  })

  it('pulls the rationale from the static question page', async () => {
    const v = visitor()
    const r = await v.post('/x/quiz/check', { question_id: 'a1', option: 'A' })
    expect(r.text).toContain('hx-get="/questions/a1/"')
    expect(r.text).toContain('hx-select="#rationale"')
    expect(r.text).toContain('hx-trigger="load"')
  })

  it('rejects an unknown question and an invalid option', async () => {
    const v = visitor()
    expect((await v.post('/x/quiz/check', { question_id: 'nope', option: 'A' })).status).toBe(404)
    expect((await v.post('/x/quiz/check', { question_id: 'a1', option: 'Z' })).status).toBe(422)
    expect((await v.post('/x/quiz/check', { question_id: 'a1' })).status).toBe(422)
  })

  it('remembers practice results in a cookie', async () => {
    const v = visitor()
    await v.post('/x/quiz/check', { question_id: 'a1', option: 'B' })
    await v.post('/x/quiz/check', { question_id: 'a2', option: 'A' })
    expect(v.cookie('practice')).toBe('a1!1.a2!0')
  })

  it('keeps the latest result when a question is answered again', async () => {
    const v = visitor()
    await v.post('/x/quiz/check', { question_id: 'a1', option: 'A' })
    await v.post('/x/quiz/check', { question_id: 'a1', option: 'B' })
    expect(v.cookie('practice')).toBe('a1!1')
  })
})
