// Which study topics the visitor marked complete. The state lives in a cookie (a sorted, dot-joined
// list of topic ids) and is rendered by the Worker; nothing is stored server-side.

/**
 * Cookie values stay under this many characters, leaving room for name and attributes (RFC 6265: 4096).
 * Values use only URL-safe characters (`.` and `!` as separators), so the encoded length is the same.
 */
export const MAX_VALUE = 3000

export const serializeProgress = (ids: readonly string[]): string => [...ids].sort().join('.')

/** The topic ids in a cookie value that exist in the content; repeated and unknown ids are dropped. */
export function parseProgress(raw: string | undefined, known: ReadonlySet<string>): string[] {
  if (!raw) return []
  const out = new Set<string>()
  for (const id of raw.split('.')) if (known.has(id)) out.add(id)
  return [...out].sort()
}

/** Marks a topic done or not done. Adding one that would not fit the cookie leaves the list as it is. */
export function setDone(done: readonly string[], id: string, on: boolean, known: ReadonlySet<string>): string[] {
  if (!known.has(id)) return [...done]
  const next = new Set(done)
  if (on) next.add(id)
  else next.delete(id)
  const list = [...next].sort()
  return on && serializeProgress(list).length > MAX_VALUE ? [...done] : list
}
