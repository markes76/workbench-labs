#!/usr/bin/env python3
import argparse
import json
import subprocess
from roadmap_lib import issue_body, issue_title, load_features, repo_name, run, select_features


LABELS = {
    "roadmap": ("7057ff", "Tracked from roadmap/features.json"),
    "agent-ready": ("0e8a16", "Ready to dispatch to a coding agent"),
    "agent-working": ("fbca04", "Agent work has been started"),
    "needs-human-review": ("d93f0b", "Needs human review or manual verification"),
    "needs-changes": ("d73a4a", "Human requested follow-up changes"),
    "approved-to-merge": ("0e8a16", "Human approved merge or promotion"),
    "feature-integration": ("1d76db", "Long-lived feature integration PR"),
    "blocked": ("b60205", "Blocked by dependency, decision, or failing checks"),
}


def ensure_label(repo, name, color, description):
    result = run(["gh", "label", "create", name, "--repo", repo, "--color", color, "--description", description], check=False)
    if result.returncode != 0 and "already exists" not in result.stderr:
        raise SystemExit(result.stderr)
    if result.returncode != 0:
        run(["gh", "label", "edit", name, "--repo", repo, "--color", color, "--description", description])


def find_issue(repo, title):
    result = run([
        "gh", "issue", "list",
        "--repo", repo,
        "--state", "all",
        "--search", f'"{title}" in:title',
        "--json", "number,title",
    ])
    for issue in json.loads(result.stdout):
        if issue["title"] == title:
            return issue["number"]
    return None


def sync_issue(repo, feature):
    title = issue_title(feature)
    labels = [
        "roadmap",
        "agent-ready",
        "needs-human-review",
        f"priority-{feature['priority'].lower()}",
        f"area-{feature['area']}",
    ]
    for label in labels:
        if label.startswith("priority-"):
            ensure_label(repo, label, "5319e7", f"{feature['priority']} roadmap priority")
        elif label.startswith("area-"):
            ensure_label(repo, label, "c5def5", f"{feature['area']} roadmap area")

    number = find_issue(repo, title)
    body = issue_body(feature)
    if number:
        run(["gh", "issue", "edit", str(number), "--repo", repo, "--body", body, "--add-label", ",".join(labels)])
        print(f"updated issue #{number}: {title}")
        return number

    result = run([
        "gh", "issue", "create",
        "--repo", repo,
        "--title", title,
        "--body", body,
        "--label", ",".join(labels),
    ])
    print(result.stdout.strip())
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=repo_name())
    parser.add_argument("--feature-id", default="all")
    args = parser.parse_args()

    repo = args.repo
    for name, (color, description) in LABELS.items():
        ensure_label(repo, name, color, description)

    features = select_features(load_features(), args.feature_id)
    for feature in features:
        sync_issue(repo, feature)


if __name__ == "__main__":
    main()
