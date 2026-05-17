# Agentic Roadmap Workflow

Workbench Labs uses a human-gated feature branch loop. Automation can create branches, dispatch agent work, and prepare pull requests, but a feature does not merge to `main` until the app has been built and reviewed locally.

## Branch Model

- `main` is the releasable app branch.
- Each roadmap item in `roadmap/features.json` owns one long-lived branch: `feature/<feature-id>`.
- Each feature branch has one draft integration PR back to `main`.
- Agent implementation PRs should target the feature branch, not `main`.

## One-Time Setup

Run these after changing `roadmap/features.json`:

```sh
python3 script/sync_roadmap_issues.py
python3 script/seed_feature_branches.py --feature-id all
python3 script/refresh_feature_branches.py --feature-id all
```

The same tasks are available in GitHub Actions:

- **Roadmap Sync** creates or updates roadmap issues and labels.
- **Seed Feature Branches** creates feature branches and draft integration PRs.

Use `refresh_feature_branches.py` after workflow, CI, or shared foundation changes so existing feature branches inherit the newest automation before agents open implementation PRs against them.

## Dispatch Agent Work

Start a Copilot cloud-agent task for a roadmap feature:

```sh
python3 script/start_agent_task.py tool-categories --provider copilot
```

Or from GitHub Actions, run **Agent Dispatch** with the feature id.

Provider notes:

- `copilot` calls `gh agent-task create` and uses `.github/agents/workbench-feature-builder.md`.
- `manual` posts the generated prompt to the roadmap issue for a human or external agent.
- `codex` posts the generated prompt for a local Codex session; it does not pretend to run a cloud Codex worker.

If GitHub Actions should dispatch Copilot tasks, add a repository secret named `COPILOT_AGENT_TOKEN` with permission to create agent tasks. Local dispatch can use your existing `gh` login.

## Local Human Review

When a feature branch is ready for testing, run:

```sh
python3 script/review_feature.py tool-categories
```

This creates or refreshes a detached worktree beside the main checkout, builds the app bundle from `feature/tool-categories`, and opens that build. Your main checkout stays on `main`.

After testing the actual macOS app:

```sh
python3 script/request_feature_changes.py tool-categories "Describe what must be fixed"
```

To immediately start a follow-up agent with the same feedback:

```sh
python3 script/request_feature_changes.py tool-categories "Describe what must be fixed" --start-agent --provider copilot
```

When the feature is good:

```sh
python3 script/approve_feature.py tool-categories
```

Approval adds the `approved-to-merge` label and starts **Promote Feature**. That workflow uses the `human-approval` environment, so GitHub can require your manual approval before the merge job runs.

## Promotion Rules

`script/promote_feature.py` refuses to merge unless the feature integration PR has the `approved-to-merge` label. This keeps accidental workflow dispatches from bypassing local review.

The expected loop is:

1. Roadmap issue exists.
2. `feature/<id>` branch and draft integration PR exist.
3. Agent work lands into `feature/<id>`.
4. You run `script/review_feature.py <id>` and test the app locally.
5. You either request changes or approve the feature.
6. **Promote Feature** merges the approved integration PR to `main`.

## Recommended First Features

Start with these P0 branches because they improve the foundation for later agents:

- `tool-categories`
- `external-process-runner`
- `file-result-handling`
