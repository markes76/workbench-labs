#!/usr/bin/env python3
import argparse
import json
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
        run(["gh", "issue", "comment", str(issue_number), "--repo", args.repo, "--body", body])
        run(["gh", "issue", "edit", str(issue_number), "--repo", args.repo, "--add-label", "approved-to-merge"])
        run(["gh", "issue", "edit", str(issue_number), "--repo", args.repo, "--remove-label", "needs-changes"], check=False)

    run(["gh", "pr", "comment", str(pr["number"]), "--repo", args.repo, "--body", body])
    run(["gh", "pr", "edit", str(pr["number"]), "--repo", args.repo, "--add-label", "approved-to-merge"])
    run(["gh", "pr", "edit", str(pr["number"]), "--repo", args.repo, "--remove-label", "needs-changes"], check=False)

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
