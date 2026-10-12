import { Hono } from 'hono'
import type { Answers } from '../scripts/content.ts'
import { type ExamOptions, examRoutes } from './resources/exam.tsx'
import { progressRoutes } from './resources/progress.tsx'
import { quizRoutes } from './resources/quiz.tsx'

/**
 * The Worker's logic, with the content and the clock injected so tests need no Cloudflare runtime.
 * Static pages are served by the assets layer and never reach this app (wrangler `run_worker_first`).
 */
export const createApp = (content: Answers, options: ExamOptions) => {
  const app = new Hono()
  app.route('/', progressRoutes(content))
  app.route('/', quizRoutes(content))
  app.route('/', examRoutes(content, options))
  return app
}
