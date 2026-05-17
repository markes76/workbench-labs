#!/usr/bin/env python3
import argparse
import json
import shutil
import tempfile
from pathlib import Path
from roadmap_lib import add_issue_labels, find_pr_by_branch, gh_api_json, load_features, pr_body, repo_name, run, select_features


def remote_branch_exists(branch):
    result = run(["git", "ls-remote", "--heads", "origin", branch], check=False)
    return bool(result.stdout.strip())


def pr_exists(repo, branch):
    return find_pr_by_branch(repo, branch, state="all")


def create_branch(repo, feature):
    branch = feature["branch"]
    if remote_branch_exists(branch):
        print(f"branch exists: {branch}")
        return

    temp_dir = Path(tempfile.mkdtemp(prefix="workbench-feature-"))
    try:
        run(["git", "worktree", "add", "-B", branch, str(temp_dir), "origin/main"])
        active_dir = temp_dir / "roadmap" / "active"
        active_dir.mkdir(parents=True, exist_ok=True)
        tracking_file = active_dir / f"{feature['id']}.md"
        tracking_file.write_text(pr_body(feature), encoding="utf-8")
        run(["git", "add", str(tracking_file.relative_to(temp_dir))], cwd=temp_dir)
        run(["git", "commit", "-m", f"Seed {feature['title']} feature branch"], cwd=temp_dir)
        run(["git", "push", "-u", "origin", f"HEAD:{branch}"], cwd=temp_dir)
        print(f"created branch: {branch}")
    finally:
        run(["git", "worktree", "remove", "--force", str(temp_dir)], check=False)
        shutil.rmtree(temp_dir, ignore_errors=True)


def create_pr(repo, feature):
    branch = feature["branch"]
    existing = pr_exists(repo, branch)
    if existing:
        print(f"integration PR exists for {branch}: {existing['url']}")
        return
    pr = gh_api_json(
        f"repos/{repo}/pulls",
        method="POST",
        data={
            "base": "main",
            "head": branch,
            "draft": True,
            "title": f"[Feature] {feature['title']}",
            "body": pr_body(feature),
        },
    )
    add_issue_labels(repo, pr["number"], ["roadmap", "feature-integration", "needs-human-review"])
    print(pr["html_url"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=repo_name())
    parser.add_argument("--feature-id", default="all")
    args = parser.parse_args()

    run(["git", "fetch", "origin", "main"])
    for feature in select_features(load_features(), args.feature_id):
        create_branch(args.repo, feature)
        create_pr(args.repo, feature)


if __name__ == "__main__":
    main()
