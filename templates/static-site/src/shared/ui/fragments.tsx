import type { Report } from '../../domain/exam.ts'

// Fragments only: the Worker never answers a whole page (the pages are static, built by Zola).

export const Notice = (props: { message: string }) => (
  <p class="notice" role="alert">
    {props.message}
  </p>
)

/** The "mark complete" control on a study topic and its result. */
export const ProgressControl = (props: { topic: string; done: boolean; notice?: string }) => (
  <div id="progress" class="progress-control">
    {props.done ? <p class="done">Completed</p> : null}
    <button
      type="button"
      class={props.done ? '' : 'primary'}
      hx-put={`/x/progress/${props.topic}`}
      hx-vals={JSON.stringify({ done: props.done ? 'false' : 'true' })}
      hx-target="#progress"
      hx-swap="outerHTML"
      hx-disabled-elt="this"
    >
      {props.done ? 'Mark as not complete' : 'Mark as complete'}
    </button>
    {props.notice ? <Notice message={props.notice} /> : null}
  </div>
)

export const ProgressSummary = (props: { done: number; total: number }) => (
  <div id="progress-summary" class="progress-summary">
    <p>
      {props.done} of {props.total} topics complete
    </p>
    <progress max={props.total} value={props.done} />
  </div>
)

/** The answer to a practice question; the rationale is pulled from the question's static page. */
export const Feedback = (props: { questionId: string; correct: boolean; right: string }) => (
  <div class={props.correct ? 'feedback correct' : 'feedback incorrect'}>
    <p>
      <strong>{props.correct ? 'Correct' : 'Incorrect'}</strong>
      {props.correct ? null : ` The correct answer is ${props.right}.`}
    </p>
    <div
      hx-get={`/questions/${props.questionId}/`}
      hx-trigger="load"
      hx-select="#rationale"
      hx-swap="outerHTML"
      hx-boost="false"
    />
  </div>
)

export const formatClock = (seconds: number): string => {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  const mm = h > 0 ? String(m).padStart(2, '0') : String(m)
  return `${h > 0 ? `${h}:` : ''}${mm}:${String(s).padStart(2, '0')}`
}

export const Timer = (props: { seconds: number }) => (
  <p id="exam-timer" class="timer" hx-get="/x/exam/timer" hx-trigger="every 15s" hx-swap="outerHTML">
    Time left {formatClock(props.seconds)}
  </p>
)

export const ExamStart = (props: { size: number; minutes: number; notice?: string }) => (
  <div id="exam">
    <p>
      {props.size} questions, {props.minutes} minutes. Your answers stay in this browser.
    </p>
    {props.notice ? <Notice message={props.notice} /> : null}
    <button type="button" class="primary" hx-post="/x/exam" hx-target="#exam" hx-swap="outerHTML">
      Start exam
    </button>
  </div>
)

export type ExamQuestionView = {
  n: number
  total: number
  text: string
  options: { id: string; text: string }[]
  chosen?: string
  flagged: boolean
  seconds: number
  grid: { n: number; answered: boolean; flagged: boolean }[]
}

export const ExamQuestion = (v: ExamQuestionView) => (
  <div id="exam">
    <Timer seconds={v.seconds} />
    <p class="eyebrow">
      Question {v.n} of {v.total}
    </p>
    <p>{v.text}</p>
    <form hx-put={`/x/exam/${v.n}/answer`} hx-target="#exam" hx-swap="outerHTML" hx-trigger="change">
      <fieldset>
        <legend class="visually-hidden">Options</legend>
        {v.options.map((o) => (
          <label class="option">
            <input type="radio" name="option" value={o.id} checked={v.chosen === o.id} /> <span>
              <strong>{o.id}.</strong> {o.text}
            </span>
          </label>
        ))}
      </fieldset>
    </form>
    <p class="exam-actions">
      <button
        type="button"
        hx-put={`/x/exam/${v.n}/flag`}
        hx-vals={JSON.stringify({ flag: v.flagged ? 'false' : 'true' })}
        hx-target="#exam"
        hx-swap="outerHTML"
      >
        {v.flagged ? 'Remove flag' : 'Flag for review'}
      </button>
      {v.n > 1 ? (
        <button type="button" hx-get={`/x/exam/${v.n - 1}`} hx-target="#exam" hx-swap="outerHTML">
          Previous
        </button>
      ) : null}
      {v.n < v.total ? (
        <button type="button" hx-get={`/x/exam/${v.n + 1}`} hx-target="#exam" hx-swap="outerHTML">
          Next
        </button>
      ) : null}
    </p>
    <ol class="exam-grid">
      {v.grid.map((g) => (
        <li class={`${g.answered ? 'answered' : ''} ${g.flagged ? 'flagged' : ''}`.trim() || undefined}>
          <button type="button" hx-get={`/x/exam/${g.n}`} hx-target="#exam" hx-swap="outerHTML">
            {g.n}
          </button>
        </li>
      ))}
    </ol>
    <button
      type="button"
      class="danger"
      hx-post="/x/exam/finish"
      hx-confirm="Finish the exam now? Unanswered questions count as wrong."
      hx-target="#exam"
      hx-swap="outerHTML"
    >
      Finish exam
    </button>
  </div>
)

export const ExamReport = (props: {
  report: Report
  titles: Record<number, string>
  answered: number
  total: number
  expired: boolean
}) => (
  <div id="exam" class="report">
    <h2>
      Score {props.report.scaled} / 1000
    </h2>
    <p class={props.report.passed ? 'pass' : 'fail'}>
      <strong>{props.report.passed ? 'Passed' : 'Not passed'}</strong> (pass mark 700)
    </p>
    <p>
      {props.answered} of {props.total} questions answered{props.expired ? '; the time ran out' : ''}.
    </p>
    <table>
      <thead>
        <tr>
          <th>Domain</th>
          <th>Correct</th>
          <th>Percent</th>
        </tr>
      </thead>
      <tbody>
        {props.report.perDomain.map((d) => (
          <tr>
            <td>
              {d.domain}. {props.titles[d.domain] ?? ''}
            </td>
            <td>
              {d.correct} / {d.total}
            </td>
            <td>{d.percent}%</td>
          </tr>
        ))}
      </tbody>
    </table>
    <button type="button" class="primary" hx-post="/x/exam" hx-target="#exam" hx-swap="outerHTML">
      Start a new exam
    </button>
  </div>
)
