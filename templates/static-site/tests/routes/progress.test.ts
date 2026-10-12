import { describe, expect, it } from 'vitest'
import { fixtureContent } from '../domain/fixtures.ts'
import { visitor } from './helpers.ts'

describe('progress routes', () => {
  it('offers to mark a topic complete', async () => {
    const v = visitor()
    const r = await v.get('/x/progress/topic-one')
    expect(r.status).toBe(200)
    expect(r.text).toContain('id="progress"')
    expect(r.text).toContain('Mark as complete')
    expect(r.text).toContain('hx-put="/x/progress/topic-one"')
    expect(r.text).not.toContain('<!doctype')
  })

  it('marks a topic complete and remembers it in a cookie', async () => {
    const v = visitor()
    const put = await v.put('/x/progress/topic-one', { done: 'true' })
    expect(put.status).toBe(200)
    expect(put.text).toContain('Completed')
    expect(v.cookie('progress')).toBe('topic-one')
    expect((await v.get('/x/progress/topic-one')).text).toContain('Completed')
  })

  it('sets the cookie with the attributes a cookie of ours needs', async () => {
    const v = visitor()
    const { setCookies } = await v.put('/x/progress/topic-one', { done: 'true' })
    const c = setCookies.find((x) => x.startsWith('progress=')) as string
    expect(c).toMatch(/HttpOnly/i)
    expect(c).toMatch(/SameSite=Lax/i)
    expect(c).toMatch(/Path=\//)
    expect(c).toMatch(/Max-Age=\d+/)
  })

  it('marks a topic not complete again', async () => {
    const v = visitor()
    await v.put('/x/progress/topic-one', { done: 'true' })
    await v.put('/x/progress/topic-two', { done: 'true' })
    const r = await v.put('/x/progress/topic-one', { done: 'false' })
    expect(r.text).toContain('Mark as complete')
    expect(v.cookie('progress')).toBe('topic-two')
  })

  it('rejects a value that is not true or false', async () => {
    const v = visitor()
    const r = await v.put('/x/progress/topic-one', { done: 'maybe' })
    expect(r.status).toBe(400)
    expect(v.cookie('progress')).toBeUndefined()
  })

  it('answers 404 for a topic that does not exist', async () => {
    const v = visitor()
    expect((await v.get('/x/progress/nope')).status).toBe(404)
    expect((await v.put('/x/progress/nope', { done: 'true' })).status).toBe(404)
  })

  it('summarises how many topics are complete', async () => {
    const v = visitor()
    expect((await v.get('/x/progress')).text).toContain('0 of 3 topics complete')
    await v.put('/x/progress/topic-one', { done: 'true' })
    await v.put('/x/progress/topic-three', { done: 'true' })
    expect((await v.get('/x/progress')).text).toContain('2 of 3 topics complete')
  })

  it('refuses a new topic when the cookie is full and leaves the cookie alone', async () => {
    const content = fixtureContent()
    content.topics = Array.from({ length: 400 }, (_, i) => `topic-number-${i}`)
    const v = visitor({ content })
    let full = 0
    for (const t of content.topics) {
      const r = await v.put(`/x/progress/${t}`, { done: 'true' })
      if (r.status === 409) break
      full++
    }
    expect(full).toBeGreaterThan(100)
    expect(full).toBeLessThan(400)
    const before = v.cookie('progress')
    const refused = await v.put(`/x/progress/${content.topics[full]}`, { done: 'true' })
    expect(refused.status).toBe(409)
    expect(refused.text).toContain('Progress is full')
    expect(v.cookie('progress')).toBe(before)
    expect((before as string).length).toBeLessThanOrEqual(3000)
  })

  it('ignores topics in the cookie that no longer exist', async () => {
    const v = visitor()
    v.jar.set('progress', 'topic-one.removed-topic')
    expect((await v.get('/x/progress')).text).toContain('1 of 3 topics complete')
  })
})
