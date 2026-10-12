// Practice-mode results: the last result per question, kept in a cookie as `id!1.id!0`.
import { MAX_VALUE } from './progress.ts'

export type Entry = [id: string, correct: boolean]

export const serializePractice = (entries: readonly Entry[]): string =>
  entries.map(([id, ok]) => `${id}!${ok ? 1 : 0}`).join('.')

export function parsePractice(raw: string | undefined, known: ReadonlySet<string>): Entry[] {
  if (!raw) return []
  const seen = new Map<string, boolean>()
  for (const part of raw.split('.')) {
    const [id, flag] = part.split('!')
    if (id && known.has(id) && (flag === '0' || flag === '1')) seen.set(id, flag === '1')
  }
  return [...seen]
}

/** Records a result in place (or appends it); when the cookie would grow past the budget the oldest go first. */
export function recordResult(entries: readonly Entry[], id: string, correct: boolean): Entry[] {
  const next: Entry[] = entries.some(([x]) => x === id)
    ? entries.map(([x, ok]): Entry => (x === id ? [x, correct] : [x, ok]))
    : [...entries, [id, correct]]
  while (next.length > 1 && serializePractice(next).length > MAX_VALUE) next.shift()
  return next
}
