// The exam simulator: which questions to ask, what the visitor answered, the score. Pure functions;
// the session lives in a cookie and the Worker passes in the clock and the random source.
import type { Answers } from '../../scripts/content.ts'

export type Random = () => number

export type ExamSession = {
  /** Epoch milliseconds when the exam started. */
  start: number
  minutes: number
  ids: string[]
  answers: Record<string, string>
  flags: string[]
  /** Epoch milliseconds when the visitor finished; absent while running. */
  end?: number
}

export type DomainScore = { domain: number; correct: number; total: number; percent: number }
export type Report = { scaled: number; passed: boolean; perDomain: DomainScore[] }

export const PASS_MARK = 700
const SCALE = 1000

/** Fisher-Yates on a copy. */
function shuffled<T>(items: readonly T[], rng: Random): T[] {
  const a = [...items]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1))
    ;[a[i], a[j]] = [a[j] as T, a[i] as T]
  }
  return a
}

/**
 * `size` question ids split across the domains in proportion to their weight (largest remainder). A
 * domain with fewer questions than its share gives all it has and the others make up the difference.
 */
export function buildExam(content: Answers, size: number, rng: Random): string[] {
  const byDomain = new Map<number, string[]>()
  for (const d of content.domains) byDomain.set(d.id, [])
  for (const id of Object.keys(content.questions).sort()) {
    byDomain.get(content.questions[id]?.domain as number)?.push(id)
  }
  const n = Math.max(0, Math.floor(size))
  const totalWeight = content.domains.reduce((w, d) => w + d.weight, 0)

  const shares = content.domains.map((d, order) => {
    const exact = totalWeight === 0 ? 0 : (n * d.weight) / totalWeight
    return { id: d.id, order, floor: Math.floor(exact), frac: exact - Math.floor(exact) }
  })
  let spare = n - shares.reduce((s, x) => s + x.floor, 0)
  const take = new Map(shares.map((s) => [s.id, s.floor]))
  for (const s of [...shares].sort((a, b) => b.frac - a.frac || a.order - b.order)) {
    if (spare <= 0) break
    take.set(s.id, (take.get(s.id) as number) + 1)
    spare--
  }
  // Cap by what exists, then hand the shortfall to domains that still have questions, heaviest first.
  for (const s of shares) take.set(s.id, Math.min(take.get(s.id) as number, byDomain.get(s.id)?.length ?? 0))
  let missing = n - [...take.values()].reduce((a, b) => a + b, 0)
  const byWeight = [...content.domains].sort((a, b) => b.weight - a.weight)
  while (missing > 0) {
    const d = byWeight.find((x) => (take.get(x.id) as number) < (byDomain.get(x.id)?.length ?? 0))
    if (!d) break
    take.set(d.id, (take.get(d.id) as number) + 1)
    missing--
  }

  const picked = content.domains.flatMap((d) => shuffled(byDomain.get(d.id) ?? [], rng).slice(0, take.get(d.id) as number))
  return shuffled(picked, rng)
}

export function score(content: Answers, session: ExamSession): Report {
  const tally = new Map<number, { correct: number; total: number }>()
  for (const id of session.ids) {
    const q = content.questions[id]
    if (!q) continue
    const t = tally.get(q.domain) ?? { correct: 0, total: 0 }
    t.total++
    if (session.answers[id] === q.correct) t.correct++
    tally.set(q.domain, t)
  }
  const perDomain: DomainScore[] = []
  let weighted = 0
  let weights = 0
  for (const d of content.domains) {
    const t = tally.get(d.id)
    if (!t || t.total === 0) continue
    perDomain.push({ domain: d.id, correct: t.correct, total: t.total, percent: Math.round((100 * t.correct) / t.total) })
    weighted += d.weight * (t.correct / t.total)
    weights += d.weight
  }
  const scaled = weights === 0 ? 0 : Math.round((SCALE * weighted) / weights)
  return { scaled, passed: scaled >= PASS_MARK, perDomain }
}

export const remainingSeconds = (s: ExamSession, now: number): number =>
  Math.max(0, Math.floor((s.start + s.minutes * 60_000 - now) / 1000))

/** The exam is over when the visitor finished it or the time ran out. */
export const isOver = (s: ExamSession, now: number): boolean => s.end !== undefined || remainingSeconds(s, now) === 0

/**
 * `start~minutes~end~ids~answers~flags`: ids joined with `.`; answers as `<position><option>` (`12B`) and
 * flags as positions, both joined with `.`. Question ids are lower-case words with hyphens and options are
 * one capital letter, so no value needs URL escaping and a 65-question exam stays near 1.5 KB.
 */
export const encodeSession = (s: ExamSession): string => {
  const at = (id: string) => s.ids.indexOf(id)
  return [
    s.start,
    s.minutes,
    s.end ?? '',
    s.ids.join('.'),
    Object.entries(s.answers)
      .filter(([id]) => at(id) >= 0)
      .map(([id, o]) => `${at(id)}${o}`)
      .join('.'),
    s.flags
      .map(at)
      .filter((i) => i >= 0)
      .join('.'),
  ].join('~')
}

const list = (v: string): string[] => (v === '' ? [] : v.split('.'))

/** The session in a cookie value, or null when it is missing or not ours. Unknown ids and options are dropped. */
export function decodeSession(raw: string | undefined, content: Answers): ExamSession | null {
  if (!raw) return null
  const parts = raw.split('~')
  if (parts.length !== 6) return null
  const [startRaw, minutesRaw, endRaw, idsRaw, answersRaw, flagsRaw] = parts as [string, string, string, string, string, string]
  const start = Number(startRaw)
  const minutes = Number(minutesRaw)
  if (startRaw === '' || !Number.isFinite(start)) return null
  if (minutesRaw === '' || !Number.isFinite(minutes) || !(minutes > 0) || minutes > 600) return null
  const end = endRaw === '' ? undefined : Number(endRaw)
  if (end !== undefined && !Number.isFinite(end)) return null
  // Positions refer to the list as stored, so resolve them before dropping ids the content no longer has.
  const stored = list(idsRaw)
  const ids = stored.filter((id) => id in content.questions)
  const answers: Record<string, string> = {}
  for (const pair of list(answersRaw)) {
    const m = pair.match(/^(\d+)([A-Z])$/)
    const id = m ? stored[Number(m[1])] : undefined
    if (id && ids.includes(id) && content.questions[id]?.options.some((x) => x.id === m?.[2])) answers[id] = m?.[2] as string
  }
  const flags = list(flagsRaw)
    .map((i) => stored[Number(i)])
    .filter((id): id is string => id !== undefined && ids.includes(id))
  return { start, minutes, ids, answers, flags, ...(end === undefined ? {} : { end }) }
}
