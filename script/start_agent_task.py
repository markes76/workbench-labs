#!/usr/bin/env python3
import argparse
import json
import tempfile
from pathlib import Path
from roadmap_lib import agent_prompt, issue_title, load_features, repo_name, run, select_features


def find_issue(repo, feature):
    title = issue_title(feature)
    result = run([
        "gh", "issue", "list",
        "--repo", repo,
        "--state", "open",
        "--search", f'"{title}" in:title',
        "--json", "number,title",
    ])
    for issue in json.loads(result.stdout):
        if issue["title"] == title:
            return issue["number"]
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("feature_id")
    parser.add_argument("--repo", default=repo_name())
    parser.add_argument("--provider", default="copilot", choices=["copilot", "manual", "codex"])
    parser.add_argument("--feedback", default="")
    parser.add_argument("--custom-agent", default="workbench-feature-builder")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    feature = select_features(load_features(), args.feature_id)[0]
    issue_number = find_issue(args.repo, feature)
    prompt = agent_prompt(feature, issue_number=issue_number, feedback=args.feedback or None)

    if args.dry_run:
        print(prompt)
        return

    if args.provider in ("manual", "codex"):
        print(prompt)
        if issue_number:
            run([
                "gh", "issue", "comment",
                str(issue_number),
                "--repo", args.repo,
                "--body", f"""Agent prompt prepared for `{feature['id']}` on `{feature['branch']}`.

Provider: `{args.provider}`

```text
{prompt}
```""",
            ])
            run([
                "gh", "issue", "edit",
                str(issue_number),
                "--repo", args.repo,
                "--add-label", "agent-ready",
            ])
        return

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".md", delete=False) as handle:
        handle.write(prompt)
        prompt_path = handle.name

    try:
        result = run([
            "gh", "agent-task", "create",
            "--repo", args.repo,
            "--base", feature["branch"],
            "--custom-agent", args.custom_agent,
            "--from-file", prompt_path,
        ])
        output = result.stdout.strip()
        print(output)

        if issue_number:
            run([
                "gh", "issue", "comment",
                str(issue_number),
                "--repo", args.repo,
                "--body", f"Started Copilot cloud-agent work for `{feature['id']}` on base branch `{feature['branch']}`.\n\n{output}",
            ])
            run([
                "gh", "issue", "edit",
                str(issue_number),
                "--repo", args.repo,
                "--add-label", "agent-working",
            ])
    finally:
        Path(prompt_path).unlink(missing_ok=True)


if __name__ == "__main__":
    main()
