import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { validateContent } from '../scripts/content.ts'

const DOMAINS = `- { id: 1, title: Fundamentals, weight: 40 }
- { id: 2, title: Applications, weight: 60 }
`
const topic = (extra: string, title = 'A topic') => `---\ntitle: ${title}\nextra:\n${extra}\n---\nBody.\n`
const TOPIC_EXTRA = `  topic_id: a-topic
  domain_id: 1
  estimated_reading_time: 3 min
  summary:
    - One line.`
const question = (extra: string) => `---\ntitle: A question\nextra:\n${extra}\n---\n`
const QUESTION_EXTRA = `  question_id: q1
  domain_id: 2
  type: single-choice
  question_text: Which one?
  options:
    - { id: A, text: First }
    - { id: B, text: Second }
  correct: B
  rationale:
    summary: Because.
    breakdown:
      A: No.
      B: Yes.`

/** A throwaway site root with the given files (path relative to the root, content). */
function site(files: Record<string, string>) {
  const root = mkdtempSync(join(tmpdir(), 'content-'))
  const all: Record<string, string> = {
    'data/domains.yaml': DOMAINS,
    'content/study/a-topic.md': topic(TOPIC_EXTRA),
    'content/questions/q1.md': question(QUESTION_EXTRA),
    ...files,
  }
  for (const [path, text] of Object.entries(all)) {
    mkdirSync(dirname(join(root, path)), { recursive: true })
    writeFileSync(join(root, path), text)
  }
  return root
}

const errorsOf = (files: Record<string, string>) => {
  const result = validateContent(site(files))
  return result.ok ? [] : result.errors
}

describe('validateContent', () => {
  it('accepts valid content and returns what the Worker needs', () => {
    const result = validateContent(site({}))
    expect(result.ok).toBe(true)
    if (!result.ok) return
    expect(result.answers.topics).toEqual(['a-topic'])
    expect(result.answers.questions.q1).toEqual({
      domain: 2,
      correct: 'B',
      text: 'Which one?',
      options: [
        { id: 'A', text: 'First' },
        { id: 'B', text: 'Second' },
      ],
    })
    expect(result.answers.domains).toEqual([
      { id: 1, title: 'Fundamentals', weight: 40 },
      { id: 2, title: 'Applications', weight: 60 },
    ])
  })

  it('ignores section index files', () => {
    expect(errorsOf({ 'content/study/_index.md': '---\ntitle: Study\n---\n' })).toEqual([])
  })

  it('rejects domain weights that do not add up to 100', () => {
    const errors = errorsOf({ 'data/domains.yaml': '- { id: 1, title: A, weight: 40 }\n- { id: 2, title: B, weight: 50 }\n' })
    expect(errors.join('\n')).toMatch(/weights.*100/)
  })

  it('rejects a question whose correct option is not among the options', () => {
    const bad = QUESTION_EXTRA.replace('correct: B', 'correct: C')
    expect(errorsOf({ 'content/questions/q1.md': question(bad) }).join('\n')).toMatch(/correct.*C/)
  })

  it('rejects a rationale that does not explain every option', () => {
    const bad = QUESTION_EXTRA.replace('      B: Yes.', '')
    expect(errorsOf({ 'content/questions/q1.md': question(bad) }).join('\n')).toMatch(/breakdown/)
  })

  it('rejects a duplicate question id', () => {
    const errors = errorsOf({ 'content/questions/q2.md': question(QUESTION_EXTRA) })
    expect(errors.join('\n')).toMatch(/duplicate question_id q1/)
  })

  it('rejects a duplicate topic id', () => {
    const errors = errorsOf({ 'content/study/b-topic.md': topic(TOPIC_EXTRA, 'Another') })
    expect(errors.join('\n')).toMatch(/duplicate topic_id a-topic/)
  })

  it('rejects an unknown domain', () => {
    const bad = QUESTION_EXTRA.replace('domain_id: 2', 'domain_id: 9')
    expect(errorsOf({ 'content/questions/q1.md': question(bad) }).join('\n')).toMatch(/domain_id 9/)
  })

  it('rejects a topic with an unknown domain', () => {
    const bad = TOPIC_EXTRA.replace('domain_id: 1', 'domain_id: 7')
    expect(errorsOf({ 'content/study/a-topic.md': topic(bad) }).join('\n')).toMatch(/domain_id 7/)
  })

  it('rejects repeated option ids', () => {
    const bad = QUESTION_EXTRA.replace('{ id: B, text: Second }', '{ id: A, text: Second }')
    expect(errorsOf({ 'content/questions/q1.md': question(bad) }).join('\n')).toMatch(/option ids are not unique/)
  })

  it('rejects a missing required field and names the file', () => {
    const bad = QUESTION_EXTRA.replace('  question_text: Which one?\n', '')
    const errors = errorsOf({ 'content/questions/q1.md': question(bad) })
    expect(errors.join('\n')).toMatch(/content\/questions\/q1\.md.*question_text/)
  })

  it('rejects a field the schema does not know', () => {
    const bad = `${QUESTION_EXTRA}\n  surprise: true`
    expect(errorsOf({ 'content/questions/q1.md': question(bad) }).join('\n')).toMatch(/surprise/)
  })

  it('rejects a page without front matter', () => {
    expect(errorsOf({ 'content/study/plain.md': 'No front matter here.\n' }).join('\n')).toMatch(/front matter/)
  })

  it('reports every problem, not only the first', () => {
    const errors = errorsOf({
      'content/questions/q1.md': question(QUESTION_EXTRA.replace('correct: B', 'correct: C')),
      'content/study/plain.md': 'No front matter here.\n',
    })
    expect(errors.length).toBeGreaterThanOrEqual(2)
  })
})
