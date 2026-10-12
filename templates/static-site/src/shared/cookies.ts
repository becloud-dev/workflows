import type { Context } from 'hono'
import { getCookie, setCookie } from 'hono/cookie'

// The visitor's state lives in cookies the Worker reads and writes (docs/DESIGN.md): progress, practice
// results and the running exam. They are not secrets: HttpOnly keeps scripts away from them and Lax keeps
// other sites from sending them. No `Secure`: the site is HTTPS-only behind Cloudflare, and a Secure
// cookie is dropped over the http://127.0.0.1 of the local test harness.
export const COOKIES = { progress: 'progress', practice: 'practice', exam: 'exam' } as const

const ONE_YEAR = 365 * 24 * 60 * 60

export const readCookie = (c: Context, name: (typeof COOKIES)[keyof typeof COOKIES]) => getCookie(c, name)

export const writeCookie = (c: Context, name: (typeof COOKIES)[keyof typeof COOKIES], value: string) =>
  setCookie(c, name, value, { path: '/', maxAge: ONE_YEAR, httpOnly: true, sameSite: 'Lax' })
