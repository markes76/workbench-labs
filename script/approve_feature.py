#!/usr/bin/env python3
import argparse
import json
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
    parser = argparse.ArgumentParser(description="Approve a roadmap feature branch and trigger guarded promotion.")
    parser.add_argument("feature_id")
    parser.add_argument("--repo", default=repo_name())
    parser.add_argument("--merge-method", default="squash", choices=["merge", "squash", "rebase"])
    parser.add_argument("--no-trigger", action="store_true")
    args = parser.parse_args()

    feature = select_features(load_features(), args.feature_id)[0]
    issue_number = find_issue(args.repo, feature)
    pr = find_integration_pr(args.repo, feature)
    if not pr:
        raise SystemExit(f"No open integration PR found for {feature['branch']}")

    body = f"Human review approved `{feature['id']}` for promotion to `main`."
    if issue_number:
        add_issue_comment(args.repo, issue_number, body)
        add_issue_labels(args.repo, issue_number, "approved-to-merge")
        remove_issue_label(args.repo, issue_number, "needs-changes")

    add_issue_comment(args.repo, pr["number"], body)
    add_issue_labels(args.repo, pr["number"], "approved-to-merge")
    remove_issue_label(args.repo, pr["number"], "needs-changes")

    if pr["isDraft"]:
        run(["gh", "pr", "ready", str(pr["number"]), "--repo", args.repo])

    if args.no_trigger:
        print(f"Approved {feature['id']}; promotion workflow was not triggered.")
        return

    run([
        "gh", "workflow", "run",
        "promote-feature.yml",
        "--repo", args.repo,
        "-f", f"feature_id={feature['id']}",
        "-f", f"merge_method={args.merge_method}",
    ])
    print(f"Approved {feature['id']} and triggered promote-feature.yml.")


if __name__ == "__main__":
    main()
