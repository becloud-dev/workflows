# Changelog

## [0.4.1](https://github.com/becloud-dev/workflows/compare/v0.4.0...v0.4.1) (2026-10-22)


### Bug Fixes

* **dev-execute:** give the executor's commits a defined git identity ([#97](https://github.com/becloud-dev/workflows/issues/97)) ([4bacfce](https://github.com/becloud-dev/workflows/commit/4bacfceae9288ae1ad473336646ac6ac19ff47e6))

## [0.4.0](https://github.com/becloud-dev/workflows/compare/v0.3.0...v0.4.0) (2026-10-15)


### Features

* **dev-execute:** move the round checks to the cli and run the gate in its own job ([#90](https://github.com/becloud-dev/workflows/issues/90)) ([3c94c2f](https://github.com/becloud-dev/workflows/commit/3c94c2fdbffd52dd0dc2fcba67b834d3b79f5409))
* **dev-execute:** pin the approved plan and move the executor checks to the cli ([#88](https://github.com/becloud-dev/workflows/issues/88)) ([fc3df33](https://github.com/becloud-dev/workflows/commit/fc3df335e6559c7d71b8e04214fccab9c99e6d5e))
* **dev-round:** make the executor's agent calls through the cli ([#91](https://github.com/becloud-dev/workflows/issues/91)) ([bb55604](https://github.com/becloud-dev/workflows/commit/bb556042da2b25c5f75d2c522ecbb29d36ee8686))

## [0.3.0](https://github.com/becloud-dev/workflows/compare/v0.2.1...v0.3.0) (2026-10-14)


### Features

* **cli:** move the backlog planner to the rust cli ([#83](https://github.com/becloud-dev/workflows/issues/83)) ([fbbf1f7](https://github.com/becloud-dev/workflows/commit/fbbf1f7bbb1702ad98b125a647026352dda0f203)), closes [#82](https://github.com/becloud-dev/workflows/issues/82)

## [0.2.1](https://github.com/becloud-dev/workflows/compare/v0.2.0...v0.2.1) (2026-10-13)


### Bug Fixes

* **agent-calls:** load no project settings, hooks or CLAUDE.md from the checkout ([#80](https://github.com/becloud-dev/workflows/issues/80)) ([fee4a41](https://github.com/becloud-dev/workflows/commit/fee4a417f4e4d28b8f44d6a605892c9a23a05374)), closes [#78](https://github.com/becloud-dev/workflows/issues/78)

## [0.2.0](https://github.com/becloud-dev/workflows/compare/v0.1.0...v0.2.0) (2026-10-13)


### ⚠ BREAKING CHANGES

* **dev:** run the executor push and pull request under a strict App ([#23](https://github.com/becloud-dev/workflows/issues/23))

### Features

* **ci:** audit pull request workflow changes with zizmor ([#24](https://github.com/becloud-dev/workflows/issues/24)) ([ed468fc](https://github.com/becloud-dev/workflows/commit/ed468fc2a53d22d9fd65f8b248c1aea5f5c58edc))
* **dev-round:** fail the round on deletions outside the plan ([#37](https://github.com/becloud-dev/workflows/issues/37)) ([8f4884d](https://github.com/becloud-dev/workflows/commit/8f4884d97d62c1f2ab320440ef8ccf697d9885cc))
* **dev:** allow the executor to remove files with git rm ([#17](https://github.com/becloud-dev/workflows/issues/17)) ([5a7db28](https://github.com/becloud-dev/workflows/commit/5a7db283e3756aa945c6429549ba36d416df453b))
* **dev:** run the executor push and pull request under a strict App ([#23](https://github.com/becloud-dev/workflows/issues/23)) ([c4642bf](https://github.com/becloud-dev/workflows/commit/c4642bfee45f8f83fb41007cab521e447ae2136d))
* **template:** add the static site content build and validator ([b8d6975](https://github.com/becloud-dev/workflows/commit/b8d6975467fbe9ae221324e52d787d7346c2b40f))
* **template:** add the static site worker logic ([3e04c70](https://github.com/becloud-dev/workflows/commit/3e04c7049ae8de195093c0a13b437c364cf6e656))


### Bug Fixes

* **ci:** audit the workflow files and consumer templates with zizmor ([#26](https://github.com/becloud-dev/workflows/issues/26)) ([34680e0](https://github.com/becloud-dev/workflows/commit/34680e0dab7ebb905e924c0a82bb919564c7271d))
* **ci:** give every permission a reason and scope the callers to their jobs ([#28](https://github.com/becloud-dev/workflows/issues/28)) ([e399872](https://github.com/becloud-dev/workflows/commit/e3998721d8ddd39074181d84b953716fefad30b5))
* **dev-execute:** fetch with --update-shallow so the clean-dir push works from a shallow checkout ([#50](https://github.com/becloud-dev/workflows/issues/50)) ([eae66bf](https://github.com/becloud-dev/workflows/commit/eae66bfa7f541fc0d0dbb9325c816fa0bc052581))
* **dev-execute:** publish the branch from a job that runs no round code ([#58](https://github.com/becloud-dev/workflows/issues/58)) ([73676d2](https://github.com/becloud-dev/workflows/commit/73676d22484d42abb47c598bae2e63ffe51b23e6))
* **dev-execute:** push from a clean git dir so checkout hooks and config do not run ([#48](https://github.com/becloud-dev/workflows/issues/48)) ([4fbdc1d](https://github.com/becloud-dev/workflows/commit/4fbdc1df1f4fa1926b608a84f96f39925fcbd1d6))
* **dev-execute:** recheck the plan scope before publishing ([#64](https://github.com/becloud-dev/workflows/issues/64)) ([b77d25b](https://github.com/becloud-dev/workflows/commit/b77d25beb25bb192196a9dcfcec6208f7a54f5eb))
* **dev-round:** fail the round for workflow changes not named in the plan ([#51](https://github.com/becloud-dev/workflows/issues/51)) ([fc0a429](https://github.com/becloud-dev/workflows/commit/fc0a429c9f3aaf14b56ef9f1d26a7bbf34f33b51))
* **dev-round:** let a change that adds no tests pass the execution check ([#41](https://github.com/becloud-dev/workflows/issues/41)) ([39fd4ab](https://github.com/becloud-dev/workflows/commit/39fd4ab798d0b9563a0aeb331a4a9c231cec798e))
* **dev:** link security controls to criteria and tests by number ([3294865](https://github.com/becloud-dev/workflows/commit/3294865703b0bc2cf058bddb4b9243c9bd74b80b))
* **release-issues:** shorten long titles instead of rejecting the list ([#60](https://github.com/becloud-dev/workflows/issues/60)) ([0663641](https://github.com/becloud-dev/workflows/commit/0663641d5db15a859ae095f3d6d44d37c2b12f03))
* **release:** bump the minor version for breaking changes below 1.0.0 ([#29](https://github.com/becloud-dev/workflows/issues/29)) ([914d63d](https://github.com/becloud-dev/workflows/commit/914d63d0a2afc33e2aa6938f368840faee389eb0))
