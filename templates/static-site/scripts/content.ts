// Validates the site's Markdown front matter and data files, and writes the facts the Worker needs
// (which option is correct, which domain a question belongs to) to src/generated/answers.json.
// `npm run content` runs it; CI and the deploy run it before the build.
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join, relative } from 'node:path'
import { parse } from 'yaml'
import { z } from 'zod'
import { domainSchema, pageSchema, questionExtraSchema, topicExtraSchema } from '../schemas/content.ts'

export type Answers = {
  topics: string[]
  questions: Record<string, { domain: number; correct: string; options: string[] }>
  domains: { id: number; weight: number }[]
}
export type Result = { ok: true; answers: Answers } | { ok: false; errors: string[] }

const SECTION_INDEX = '_index.md'

function markdownFiles(dir: string): string[] {
  try {
    return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
      e.isDirectory() ? markdownFiles(join(dir, e.name)) : e.name.endsWith('.md') && e.name !== SECTION_INDEX ? [join(dir, e.name)] : [],
    )
  } catch {
    return []
  }
}

/** The YAML between the first two `---` lines, or null when there is none. */
function frontMatter(text: string): unknown {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/)
  return m ? parse(m[1]) : null
}

const issues = (e: z.ZodError) => e.issues.map((i) => `${i.path.join('.') || '(root)'}: ${i.message}`)

export function validateContent(root: string): Result {
  const errors: string[] = []
  const fail = (file: string, message: string) => errors.push(`${relative(root, file) || file}: ${message}`)

  let domains: z.infer<typeof domainSchema>[] = []
  const domainsFile = join(root, 'data/domains.yaml')
  try {
    const parsed = z.array(domainSchema).safeParse(parse(readFileSync(domainsFile, 'utf8')))
    if (parsed.success) domains = parsed.data
    else for (const m of issues(parsed.error)) fail(domainsFile, m)
  } catch (e) {
    fail(domainsFile, `cannot read: ${(e as Error).message}`)
  }
  const total = domains.reduce((n, d) => n + d.weight, 0)
  if (domains.length > 0 && total !== 100) fail(domainsFile, `domain weights add up to ${total}, expected 100`)
  const domainIds = new Set(domains.map((d) => d.id))

  const topics: string[] = []
  const seenTopic = new Set<string>()
  for (const file of markdownFiles(join(root, 'content/study'))) {
    const fm = readFront(file, fail)
    if (fm === undefined) continue
    const parsed = pageSchema(topicExtraSchema).safeParse(fm)
    if (!parsed.success) {
      for (const m of issues(parsed.error)) fail(file, m)
      continue
    }
    const { topic_id, domain_id } = parsed.data.extra
    if (seenTopic.has(topic_id)) fail(file, `duplicate topic_id ${topic_id}`)
    seenTopic.add(topic_id)
    if (!domainIds.has(domain_id)) fail(file, `domain_id ${domain_id} is not in data/domains.yaml`)
    topics.push(topic_id)
  }

  const questions: Answers['questions'] = {}
  for (const file of markdownFiles(join(root, 'content/questions'))) {
    const fm = readFront(file, fail)
    if (fm === undefined) continue
    const parsed = pageSchema(questionExtraSchema).safeParse(fm)
    if (!parsed.success) {
      for (const m of issues(parsed.error)) fail(file, m)
      continue
    }
    const q = parsed.data.extra
    const optionIds = q.options.map((o) => o.id)
    if (q.question_id in questions) fail(file, `duplicate question_id ${q.question_id}`)
    if (!domainIds.has(q.domain_id)) fail(file, `domain_id ${q.domain_id} is not in data/domains.yaml`)
    if (new Set(optionIds).size !== optionIds.length) fail(file, 'option ids are not unique')
    if (!optionIds.includes(q.correct)) fail(file, `correct ${q.correct} is not among the options ${optionIds.join(', ')}`)
    const explained = Object.keys(q.rationale.breakdown).sort().join('')
    if (explained !== [...optionIds].sort().join('')) fail(file, `rationale.breakdown must explain exactly the options ${optionIds.join(', ')}`)
    questions[q.question_id] = { domain: q.domain_id, correct: q.correct, options: optionIds }
  }

  if (errors.length > 0) return { ok: false, errors }
  return { ok: true, answers: { topics, questions, domains: domains.map(({ id, weight }) => ({ id, weight })) } }
}

function readFront(file: string, fail: (file: string, message: string) => void): unknown | undefined {
  try {
    const fm = frontMatter(readFileSync(file, 'utf8'))
    if (fm === null || typeof fm !== 'object') {
      fail(file, 'no YAML front matter')
      return undefined
    }
    return fm
  } catch (e) {
    fail(file, `invalid front matter: ${(e as Error).message}`)
    return undefined
  }
}

// CLI: `node scripts/content.ts [root]`
if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  const root = process.argv[2] ?? process.cwd()
  const result = validateContent(root)
  if (!result.ok) {
    for (const e of result.errors) console.error(`content: ${e}`)
    process.exit(1)
  }
  const out = join(root, 'src/generated/answers.json')
  mkdirSync(join(root, 'src/generated'), { recursive: true })
  writeFileSync(out, `${JSON.stringify(result.answers, null, 2)}\n`)
  console.log(`content: ${result.answers.topics.length} topics, ${Object.keys(result.answers.questions).length} questions -> ${relative(root, out)}`)
}
