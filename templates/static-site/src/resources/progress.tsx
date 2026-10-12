import { Hono } from 'hono'
import { parseProgress, serializeProgress, setDone } from '../domain/progress.ts'
import { COOKIES, readCookie, writeCookie } from '../shared/cookies.ts'
import { Notice, ProgressControl, ProgressSummary } from '../shared/ui/fragments.tsx'
import type { Answers } from '../../scripts/content.ts'

export const progressRoutes = (content: Answers) => {
  const known = new Set(content.topics)
  const done = (raw: string | undefined) => parseProgress(raw, known)
  const app = new Hono()

  // The overview: how many topics this visitor completed.
  app.get('/x/progress', (c) => {
    const list = done(readCookie(c, COOKIES.progress))
    return c.html(<ProgressSummary done={list.length} total={content.topics.length} />)
  })

  app.get('/x/progress/:topic', (c) => {
    const topic = c.req.param('topic')
    if (!known.has(topic)) return c.html(<Notice message="Unknown topic." />, 404)
    return c.html(<ProgressControl topic={topic} done={done(readCookie(c, COOKIES.progress)).includes(topic)} />)
  })

  app.put('/x/progress/:topic', async (c) => {
    const topic = c.req.param('topic')
    if (!known.has(topic)) return c.html(<Notice message="Unknown topic." />, 404)
    const value = (await c.req.parseBody()).done
    if (value !== 'true' && value !== 'false') return c.html(<Notice message="Invalid request." />, 400)
    const before = done(readCookie(c, COOKIES.progress))
    const after = setDone(before, topic, value === 'true', known)
    const full = value === 'true' && !after.includes(topic)
    if (full) {
      return c.html(<ProgressControl topic={topic} done={false} notice="Progress is full in this browser; clear some topics first." />, 409)
    }
    writeCookie(c, COOKIES.progress, serializeProgress(after))
    return c.html(<ProgressControl topic={topic} done={after.includes(topic)} />)
  })

  return app
}
