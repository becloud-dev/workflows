import { z } from 'zod'

const id = z.string().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, 'use lower-case words joined by hyphens')
const optionId = z.string().regex(/^[A-Z]$/, 'an option id is one capital letter')

export const domainSchema = z.object({
  id: z.number().int().positive(),
  title: z.string().min(1),
  weight: z.number().int().min(1).max(100),
})

export const topicExtraSchema = z.strictObject({
  topic_id: id,
  domain_id: z.number().int().positive(),
  estimated_reading_time: z.string().min(1),
  summary: z.array(z.string().min(1)).min(1),
  comparison_table: z
    .strictObject({ headers: z.array(z.string().min(1)).min(1), rows: z.array(z.array(z.string())) })
    .optional(),
  exam_tip: z.string().min(1).optional(),
  exam_trap: z.string().min(1).optional(),
})

export const questionExtraSchema = z.strictObject({
  question_id: id,
  domain_id: z.number().int().positive(),
  type: z.literal('single-choice'),
  question_text: z.string().min(1),
  options: z.array(z.strictObject({ id: optionId, text: z.string().min(1) })).min(2).max(6),
  correct: optionId,
  rationale: z.strictObject({
    summary: z.string().min(1),
    breakdown: z.record(optionId, z.string().min(1)),
  }),
})

export const pageSchema = <T extends z.ZodType>(extra: T) =>
  z.looseObject({ title: z.string().min(1), extra })
