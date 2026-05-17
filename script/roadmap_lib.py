#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FEATURES_PATH = ROOT / "roadmap" / "features.json"


def run(args, *, cwd=ROOT, input_text=None, check=True):
    result = subprocess.run(
        args,
        cwd=str(cwd),
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and result.returncode != 0:
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)
    return result


def load_features():
    with FEATURES_PATH.open("r", encoding="utf-8") as handle:
        features = json.load(handle)
    seen = set()
    for feature in features:
        feature_id = feature["id"]
        if feature_id in seen:
            raise SystemExit(f"Duplicate roadmap feature id: {feature_id}")
        seen.add(feature_id)
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", feature_id):
            raise SystemExit(f"Invalid feature id: {feature_id}")
        expected_branch = f"feature/{feature_id}"
        if feature.get("branch") != expected_branch:
            raise SystemExit(f"{feature_id} must use branch {expected_branch}")
    return features


def select_features(features, feature_id):
    if feature_id in ("", "all", None):
        return features
    selected = [feature for feature in features if feature["id"] == feature_id]
    if not selected:
        raise SystemExit(f"No roadmap feature found for id: {feature_id}")
    return selected


def repo_name():
    env_repo = os.environ.get("GITHUB_REPOSITORY")
    if env_repo:
        return env_repo
    result = run(["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"])
    return result.stdout.strip()


def issue_title(feature):
    return f"[Roadmap:{feature['id']}] {feature['title']}"


def issue_body(feature):
    acceptance = "\n".join(f"- [ ] {item}" for item in feature["acceptance"])
    tests = "\n".join(f"- `{item}`" for item in feature.get("tests", []))
    return f"""## Summary
{feature['summary']}

## Feature Branch
`{feature['branch']}`

## Priority
`{feature['priority']}`

## Area
`{feature['area']}`

## Acceptance Criteria
{acceptance}

## Required Checks
{tests}

## Human Loop
- Agent implementation PRs should target `{feature['branch']}`.
- Merge agent PRs into `{feature['branch']}` only after review.
- Promote `{feature['branch']}` into `main` only after the integration PR is approved.
"""


def pr_body(feature):
    acceptance = "\n".join(f"- [ ] {item}" for item in feature["acceptance"])
    return f"""This is the long-lived integration PR for `{feature['id']}`.

## Summary
{feature['summary']}

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `{feature['branch']}`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `{feature['branch']}`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
{acceptance}
"""


def agent_prompt(feature, issue_number=None, feedback=None):
    acceptance = "\n".join(f"- {item}" for item in feature["acceptance"])
    tests = "\n".join(f"- {item}" for item in feature.get("tests", []))
    issue_line = f"GitHub issue: #{issue_number}\n" if issue_number else ""
    feedback_block = f"\nHuman feedback to address:\n{feedback}\n" if feedback else ""
    return f"""Implement the next working slice of this Workbench Labs roadmap feature.

Feature id: {feature['id']}
Title: {feature['title']}
Base branch: {feature['branch']}
{issue_line}
Summary:
{feature['summary']}

Acceptance criteria:
{acceptance}

Required checks:
{tests}
{feedback_block}
Engineering constraints:
- Preserve the existing SwiftPM macOS app architecture.
- Prefer small, reviewable changes that compile and test cleanly.
- Add or update focused tests.
- Keep normal tool execution local/offline.
- Do not add real credentials, real API keys, or copied third-party branding.
- If the full feature is too large, implement a coherent vertical slice and document the remaining work in the PR.
"""
