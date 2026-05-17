#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from roadmap_lib import (
    add_issue_comment,
    add_issue_labels,
    find_issue_by_title,
    find_pr_by_branch,
    issue_title,
    load_features,
    remove_issue_label,
    repo_name,
    run,
    select_features,
)


def find_issue(repo, feature):
    return find_issue_by_title(repo, issue_title(feature), state="open")


def find_integration_pr(repo, feature):
    return find_pr_by_branch(repo, feature["branch"], state="open")


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
        add_issue_comment(args.repo, issue_number, body)
        add_issue_labels(args.repo, issue_number, "needs-changes")
        remove_issue_label(args.repo, issue_number, "approved-to-merge")

    if pr:
        add_issue_comment(args.repo, pr["number"], body)
        add_issue_labels(args.repo, pr["number"], "needs-changes")
        remove_issue_label(args.repo, pr["number"], "approved-to-merge")

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
