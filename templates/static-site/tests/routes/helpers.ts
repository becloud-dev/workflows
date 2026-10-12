import { createApp } from '../../src/app.tsx'
import type { Answers } from '../../scripts/content.ts'
import { fixtureContent, seq } from '../domain/fixtures.ts'

/** A visitor: keeps the cookies the Worker sets and sends them back, like a browser. */
export function visitor(opts: { content?: Answers; now?: () => number; examSize?: number; examMinutes?: number } = {}) {
  const jar = new Map<string, string>()
  let clock = 1_700_000_000_000
  const app = createApp(opts.content ?? fixtureContent(), {
    now: opts.now ?? (() => clock),
    random: seq(0.1, 0.9, 0.4, 0.6),
    examSize: opts.examSize ?? 5,
    examMinutes: opts.examMinutes ?? 90,
  })

  async function request(path: string, init: { method?: string; body?: Record<string, string> } = {}) {
    const headers: Record<string, string> = { 'HX-Request': 'true' }
    if (jar.size > 0) headers.cookie = [...jar].map(([k, v]) => `${k}=${v}`).join('; ')
    const res = await app.request(path, {
      method: init.method ?? 'GET',
      headers,
      body: init.body ? new URLSearchParams(init.body) : undefined,
    })
    for (const line of res.headers.getSetCookie()) {
      const [pair] = line.split(';')
      const eq = (pair as string).indexOf('=')
      const name = (pair as string).slice(0, eq)
      const value = (pair as string).slice(eq + 1)
      if (/Max-Age=0|Expires=Thu, 01 Jan 1970/i.test(line) || value === '') jar.delete(name)
      else jar.set(name, value)
    }
    return { status: res.status, headers: res.headers, text: await res.text(), setCookies: res.headers.getSetCookie() }
  }

  return {
    request,
    get: (p: string) => request(p),
    put: (p: string, body: Record<string, string> = {}) => request(p, { method: 'PUT', body }),
    post: (p: string, body: Record<string, string> = {}) => request(p, { method: 'POST', body }),
    cookie: (name: string) => jar.get(name),
    advance: (ms: number) => {
      clock += ms
    },
    jar,
  }
}
