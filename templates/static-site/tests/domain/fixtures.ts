import type { Answers } from '../../scripts/content.ts'

/** Two domains (40/60); domain 1 has 3 questions, domain 2 has 5. Correct option is always "B". */
export function fixtureContent(): Answers {
  const questions: Answers['questions'] = {}
  const add = (id: string, domain: number) => {
    questions[id] = {
      domain,
      correct: 'B',
      text: `Question ${id}?`,
      options: [
        { id: 'A', text: 'First' },
        { id: 'B', text: 'Second' },
        { id: 'C', text: 'Third' },
      ],
    }
  }
  for (const id of ['a1', 'a2', 'a3']) add(id, 1)
  for (const id of ['b1', 'b2', 'b3', 'b4', 'b5']) add(id, 2)
  return {
    topics: ['topic-one', 'topic-two', 'topic-three'],
    questions,
    domains: [
      { id: 1, title: 'Fundamentals', weight: 40 },
      { id: 2, title: 'Applications', weight: 60 },
    ],
  }
}

/** A deterministic random source: cycles through the given values in [0, 1). */
export const seq = (...values: number[]) => {
  let i = 0
  return () => values[i++ % values.length] as number
}
