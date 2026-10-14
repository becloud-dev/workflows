# Research: AWS as a backend

Moved from the former `third-party-review.md` and the CLI design draft, entries kept as written. Decisions in force are
in [decisions.md](../decisions.md); where a later entry corrects an earlier one, the entry says so.
Each entry names its sources, marks inference, and lists what is unverified.

## AWS as a backend: Bedrock, Lambda, EventBridge, DynamoDB (read 2026-10-13, survey depth)

Objective (owner, 2026-10-13): lowest cost, all in the free tier if possible. Scope (owner): Bedrock
for model calls, and Lambda, EventBridge and DynamoDB to help the workflow. Runners are out of scope.

Sources read: docs.aws.amazon.com `awsaccountbilling/.../free-tier-plans.html` and
`.../tracking-free-tier-usage.html`; aws.amazon.com `free/`, `free/free-tier-faqs/`, `lambda/pricing/`,
`dynamodb/pricing/on-demand/`, `eventbridge/pricing/`, `s3/pricing/`, `kms/pricing/`,
`systems-manager/pricing/`, `secrets-manager/pricing/`, `aws-cost-management/aws-budgets/pricing/`,
`bedrock/pricing/`; `bedrock/latest/userguide/model-card-anthropic-claude-haiku-5-5.html`;
`eventbridge/latest/userguide/eb-saas-furls.html`; docs.github.com `actions/concepts/billing-and-usage`
and the OIDC-in-AWS guide; claude-code-action `docs/cloud-providers.md`. Pricing pages were read
through a page summarizer; the figures below are the quoted ones.

Facts read:
- Account plans. The Free plan "ends after six months or when your credits are fully used", then
  "your account closes automatically"; content is kept 90 days. It excludes "certain AWS
  Marketplace offers that can incur charges", and it upgrades to Paid on joining AWS Organizations.
  The Paid plan has every service; Always Free offers apply "as long as you are an AWS customer".
  Credits: $100 at sign-up plus up to $100 earned; their expiry is given as 6 months and as 12
  months on the same FAQ page.
- Always Free on both plans (tracking page): Lambda, DynamoDB (capacity hours, Streams requests,
  storage), CloudWatch Events (event chunks, scheduled invocations), SQS, SNS, Step Functions, KMS
  requests, CloudWatch, action-enabled Budgets. S3 is credits only for new accounts.
- Lambda: 1M requests and 400,000 GB-seconds a month free; then $0.20 per 1M requests and
  $0.0000166667 per GB-second (x86). Function URLs have no separate fee.
- DynamoDB: 25 GB, 25 WCU and 25 RCU a month, per Region and payer, in provisioned mode on the
  Standard table class. On-demand is not in the free tier: $0.625 per 1M writes, $0.125 per 1M
  reads, $0.25 per GB-month (us-east-1).
- EventBridge: AWS management events are free; custom and partner events cost $1.00 per 1M, with
  no free tier; Scheduler has 14M invocations a month free; Pipes $0.40 per 1M; API destinations
  $0.20 per 1M.
- The EventBridge GitHub quick start deploys a public Lambda function URL that checks GitHub's
  signature, through CloudFormation; the secret is in Secrets Manager ($0.40 per secret a month,
  $0.05 per 10,000 calls). GitHub holds one webhook secret, so a rotation drops deliveries until
  both sides match (up to an hour).
- Parameter Store standard parameters: no charge at standard throughput. KMS: AWS managed keys
  cost nothing to keep; 20,000 requests a month free; a customer managed key is $1 a month.
- Budgets: notifications are free; the first two action-enabled budgets are free, then $0.10 a day.
- Bedrock, Claude Haiku 5.5: "billed through AWS Marketplace"; IDs `anthropic.claude-haiku-5-5`,
  geo `us.`/`eu.` and `global.` profiles (no in-Region inference in us-east-1); Standard tier only
  (no Flex, Batch or Priority); on `bedrock-runtime`, Structured outputs is listed as not
  supported; prompt caching is supported. No free tier statement for Anthropic models.
- claude-code-action on Bedrock: `use_bedrock: "true"`, OIDC only, credentials from
  `aws-actions/configure-aws-credentials`, the job needs `id-token: write`; a cross-region
  profile needs model access in every Region it routes to.
- GitHub OIDC to AWS: provider `https://token.actions.githubusercontent.com`, audience
  `sts.amazonaws.com`, the trust policy checks `token.actions.githubusercontent.com:sub` (for
  example `repo:<org>/<repo>:ref:refs/heads/<branch>`).
- GitHub: "Actions usage is free for standard GitHub-hosted runners in public repositories, and
  for self-hosted runners" (the 2,000-minute figure in `docs/third-party-review.md` applies to
  private repositories).
- The AWS Price List API offer for `AmazonBedrock` in us-east-1 has 1,082 products and none for
  a 5.5 model, which fits Marketplace billing: the Claude rates are on the Marketplace listing.
- DynamoDB (`Expressions.ConditionExpressions.html`): a `PutItem` with
  `attribute_not_exists(<key>)` writes only when no item has that key; otherwise DynamoDB rejects
  it with "The conditional request failed".
- Claude Code (`code.claude.com/docs/en/headless`): `--json-schema` with `--output-format json`
  returns the result in `structured_output`; the page does not say how it is enforced or name
  Bedrock. In `--bare` mode the subscription login is not read, while "Amazon Bedrock ... continue
  to read their own provider credentials as usual". Changelog 2.1.288 added
  `CLAUDE_CODE_DISABLE_STRUCTURED_OUTPUTS` for "gateways that reject structured outputs".

Inference (not verified):
- The Free plan cannot hold a backend: it closes after six months, and Claude on Bedrock is a
  Marketplace offer it likely excludes. The fit is a Paid plan account that uses only Always Free
  services, guarded by a zero-spend budget; the AWS side can then cost $0 a month at this volume,
  and Bedrock tokens are the only real cost.
- Push, not pull: each workflow job assumes its own IAM role through OIDC (one role per
  `docs/stages.md` row) and the CLI writes to DynamoDB. No public endpoint and no stored secret,
  unlike the quick start.
- Events at $0: DynamoDB Streams to Lambda (Streams requests are Always Free) instead of custom
  events on a bus ($1 per 1M, cents at this volume but not free). Scheduler covers timed work.
- Run state: a provisioned DynamoDB table within 25 WCU/RCU. The plan is written once at approval
  with a conditional put, by a role the rounds job cannot assume; the publish job reads it there.
  That closes the #65 class by identity rather than by comment authorship.
- Agent knowledge: owner-accepted rules and findings as DynamoDB items; no vector store at this
  scale (S3 Vectors and knowledge bases cost money).
- Bedrock spend cap: an action-enabled budget that attaches a deny on `bedrock:InvokeModel`.

Not verified (gaps):
- Bedrock per-token prices for Claude 5.5: not on the rendered pricing page nor in the Price List
  API; the Marketplace listing (Haiku 5.5 product `prod-6cyn7tgqazjhu`) or the console has them.
- Whether Claude on Bedrock is available on the Free plan.
- Whether Claude Code's `--json-schema` works on Bedrock for Haiku 5.5, given Structured outputs is
  listed as unsupported on `bedrock-runtime`; every stage relies on it. Needs a live call on an
  account; the docs read do not settle it.
- Streams-to-Lambda delivery (read in the design pass); whether a failed conditional write
  consumes write capacity.
- How quickly a budget action fires after spend crosses the threshold.
- Credit expiry (6 or 12 months): AWS's FAQ states both.
- Owner: AWS account, region, monthly budget.
