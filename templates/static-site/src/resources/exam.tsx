import type { Context } from 'hono'
import { Hono } from 'hono'
import {
  buildExam,
  decodeSession,
  type ExamSession,
  encodeSession,
  isOver,
  type Random,
  remainingSeconds,
  score,
} from '../domain/exam.ts'
import { COOKIES, readCookie, writeCookie } from '../shared/cookies.ts'
import {
  ExamQuestion,
  type ExamQuestionView,
  ExamReport,
  ExamStart,
  Notice,
  Timer,
} from '../shared/ui/fragments.tsx'
import type { Answers } from '../../scripts/content.ts'

export type ExamOptions = { now: () => number; random: Random; examSize: number; examMinutes: number }
type Bindings = { EXAM_QUESTIONS?: string; EXAM_MINUTES?: string }

const positive = (v: string | undefined, fallback: number) => {
  const n = Number(v)
  return Number.isInteger(n) && n > 0 ? n : fallback
}

export const examRoutes = (content: Answers, opts: ExamOptions) => {
  const app = new Hono<{ Bindings: Bindings }>()
  const titles = Object.fromEntries(content.domains.map((d) => [d.id, d.title]))
  const size = (c: Context) => positive(c.env?.EXAM_QUESTIONS, opts.examSize)
  const minutes = (c: Context) => positive(c.env?.EXAM_MINUTES, opts.examMinutes)
  const sessionOf = (c: Context) => decodeSession(readCookie(c, COOKIES.exam), content)
  const save = (c: Context, s: ExamSession) => writeCookie(c, COOKIES.exam, encodeSession(s))

  const report = (s: ExamSession, now: number) => (
    <ExamReport
      report={score(content, s)}
      titles={titles}
      answered={Object.keys(s.answers).length}
      total={s.ids.length}
      expired={s.end === undefined && remainingSeconds(s, now) === 0}
    />
  )

  const question = (s: ExamSession, n: number, now: number) => {
    const id = s.ids[n - 1] as string
    const q = content.questions[id]
    if (!q) return <Notice message="No such question." />
    const view: ExamQuestionView = {
      n,
      total: s.ids.length,
      text: q.text,
      options: q.options,
      chosen: s.answers[id],
      flagged: s.flags.includes(id),
      seconds: remainingSeconds(s, now),
      grid: s.ids.map((x, i) => ({ n: i + 1, answered: x in s.answers, flagged: s.flags.includes(x) })),
    }
    return <ExamQuestion {...view} />
  }

  /** The visitor's running session, or the response to send instead. */
  const running = (c: Context): { s: ExamSession } | { res: Response | Promise<Response> } => {
    const s = sessionOf(c)
    if (!s) return { res: c.html(<ExamStart size={size(c)} minutes={minutes(c)} notice="No exam in progress." />, 409) }
    if (isOver(s, opts.now())) return { res: c.html(<Notice message="The exam is over." />, 409) }
    return { s }
  }

  const position = (c: Context, s: ExamSession) => {
    const n = Number(c.req.param('n'))
    return Number.isInteger(n) && n >= 1 && n <= s.ids.length ? n : null
  }

  app.get('/x/exam', (c) => {
    const s = sessionOf(c)
    if (!s) return c.html(<ExamStart size={size(c)} minutes={minutes(c)} />)
    const now = opts.now()
    if (isOver(s, now)) return c.html(report(s, now))
    const firstOpen = s.ids.findIndex((id) => !(id in s.answers)) + 1
    return c.html(question(s, firstOpen || 1, now))
  })

  app.post('/x/exam', (c) => {
    const ids = buildExam(content, size(c), opts.random)
    if (ids.length === 0) return c.html(<Notice message="There are no questions yet." />, 409)
    const s: ExamSession = { start: opts.now(), minutes: minutes(c), ids, answers: {}, flags: [] }
    save(c, s)
    return c.html(question(s, 1, s.start))
  })

  app.get('/x/exam/timer', (c) => {
    const s = sessionOf(c)
    if (!s) return c.body(null, 204)
    const now = opts.now()
    if (isOver(s, now)) return c.body(null, 200, { 'HX-Refresh': 'true' })
    return c.html(<Timer seconds={remainingSeconds(s, now)} />)
  })

  app.post('/x/exam/finish', (c) => {
    const r = running(c)
    if ('res' in r) return r.res
    const now = opts.now()
    const s = { ...r.s, end: now }
    save(c, s)
    return c.html(report(s, now))
  })

  app.get('/x/exam/:n', (c) => {
    const r = running(c)
    if ('res' in r) return r.res
    const n = position(c, r.s)
    if (n === null) return c.html(<Notice message="No such question." />, 404)
    return c.html(question(r.s, n, opts.now()))
  })

  app.put('/x/exam/:n/answer', async (c) => {
    const r = running(c)
    if ('res' in r) return r.res
    const n = position(c, r.s)
    if (n === null) return c.html(<Notice message="No such question." />, 404)
    const id = r.s.ids[n - 1] as string
    const option = (await c.req.parseBody()).option
    if (typeof option !== 'string' || !content.questions[id]?.options.some((o) => o.id === option)) {
      return c.html(<Notice message="Choose one of the options." />, 422)
    }
    const s = { ...r.s, answers: { ...r.s.answers, [id]: option } }
    save(c, s)
    return c.html(question(s, n, opts.now()))
  })

  app.put('/x/exam/:n/flag', async (c) => {
    const r = running(c)
    if ('res' in r) return r.res
    const n = position(c, r.s)
    if (n === null) return c.html(<Notice message="No such question." />, 404)
    const id = r.s.ids[n - 1] as string
    const flag = (await c.req.parseBody()).flag
    if (flag !== 'true' && flag !== 'false') return c.html(<Notice message="Invalid request." />, 400)
    const flags = flag === 'true' ? [...new Set([...r.s.flags, id])] : r.s.flags.filter((x) => x !== id)
    const s = { ...r.s, flags }
    save(c, s)
    return c.html(question(s, n, opts.now()))
  })

  return app
}
