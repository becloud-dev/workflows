import type { Answers } from '../scripts/content.ts'
import { createApp } from './app.tsx'
import answers from './generated/answers.json'

// Entry point: the generated content (npm run content) plus the real clock and random source. The exam
// size and duration come from the `vars` in wrangler.jsonc (EXAM_QUESTIONS, EXAM_MINUTES).
export default createApp(answers as Answers, {
  now: () => Date.now(),
  random: Math.random,
  examSize: 65,
  examMinutes: 90,
})
