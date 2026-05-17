#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from roadmap_lib import issue_title, load_features, repo_name, run, select_features


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


def find_integration_pr(repo, feature):
    result = run([
        "gh", "pr", "list",
        "--repo", repo,
        "--head", feature["branch"],
        "--base", "main",
        "--state", "open",
        "--json", "number,url",
    ])
    prs = json.loads(result.stdout)
    return prs[0] if prs else None


def main():
    parser = argparse.ArgumentParser(description="Record human feedback for a roadmap feature branch.")
    parser.add_argument("feature_id")
    parser.add_argument("feedback", nargs="?", default="")
    parser.add_argument("--repo", default=repo_name())
    parser.add_argument("--start-agent", action="store_true")
    parser.add_argument("--provider", default="copilot", choices=["copilot", "manual", "codex"])
    args = parser.parse_args()

    feedback = args.feedback.strip() or sys.stdin.read().strip()
    if not feedback:
        raise SystemExit("Feedback is required.")

    feature = select_features(load_features(), args.feature_id)[0]
    issue_number = find_issue(args.repo, feature)
    pr = find_integration_pr(args.repo, feature)
    body = f"""Human review requested changes for `{feature['id']}`.

Feedback:
{feedback}
"""

    if issue_number:
        run(["gh", "issue", "comment", str(issue_number), "--repo", args.repo, "--body", body])
        run(["gh", "issue", "edit", str(issue_number), "--repo", args.repo, "--add-label", "needs-changes"])
        run(["gh", "issue", "edit", str(issue_number), "--repo", args.repo, "--remove-label", "approved-to-merge"], check=False)

    if pr:
        run(["gh", "pr", "comment", str(pr["number"]), "--repo", args.repo, "--body", body])
        run(["gh", "pr", "edit", str(pr["number"]), "--repo", args.repo, "--add-label", "needs-changes"])
        run(["gh", "pr", "edit", str(pr["number"]), "--repo", args.repo, "--remove-label", "approved-to-merge"], check=False)

    if args.start_agent:
        subprocess.run([
            sys.executable,
            "script/start_agent_task.py",
            feature["id"],
            "--repo",
            args.repo,
            "--provider",
            args.provider,
            "--feedback",
            feedback,
        ], check=True)
    else:
        print("Feedback recorded. Use --start-agent to dispatch a follow-up agent task.")


if __name__ == "__main__":
    main()
