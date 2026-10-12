import { Hono } from 'hono'
import { parsePractice, recordResult, serializePractice } from '../domain/practice.ts'
import { COOKIES, readCookie, writeCookie } from '../shared/cookies.ts'
import { Feedback, Notice } from '../shared/ui/fragments.tsx'
import type { Answers } from '../../scripts/content.ts'

export const quizRoutes = (content: Answers) => {
  const known = new Set(Object.keys(content.questions))
  const app = new Hono()

  // Practice mode: check one answer. The question page is static; only this answer comes from here.
  app.post('/x/quiz/check', async (c) => {
    const body = await c.req.parseBody()
    const id = typeof body.question_id === 'string' ? body.question_id : ''
    const option = typeof body.option === 'string' ? body.option : ''
    const q = content.questions[id]
    if (!q) return c.html(<Notice message="Unknown question." />, 404)
    if (!q.options.some((o) => o.id === option)) return c.html(<Notice message="Choose one of the options." />, 422)
    const correct = option === q.correct
    const entries = recordResult(parsePractice(readCookie(c, COOKIES.practice), known), id, correct)
    writeCookie(c, COOKIES.practice, serializePractice(entries))
    return c.html(<Feedback questionId={id} correct={correct} right={q.correct} />)
  })

  return app
}
