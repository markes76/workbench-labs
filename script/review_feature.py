#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from roadmap_lib import load_features, run, select_features


ROOT = Path(__file__).resolve().parents[1]


def remote_branch_exists(branch):
    result = run(["git", "ls-remote", "--heads", "origin", branch], check=False)
    return bool(result.stdout.strip())


def worktree_uses_git(path):
    return (path / ".git").exists()


def main():
    parser = argparse.ArgumentParser(description="Build and open a roadmap feature branch for local human review.")
    parser.add_argument("feature_id")
    parser.add_argument("--worktree-dir", default="")
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    feature = select_features(load_features(), args.feature_id)[0]
    branch = feature["branch"]
    worktree_dir = Path(args.worktree_dir).expanduser() if args.worktree_dir else ROOT.parent / f"WorkbenchLabs-review-{feature['id']}"
    worktree_dir = worktree_dir.resolve()

    if not remote_branch_exists(branch):
        raise SystemExit(f"Remote branch does not exist yet: {branch}")
    run([
        "git",
        "fetch",
        "origin",
        "+refs/heads/main:refs/remotes/origin/main",
        f"+refs/heads/{branch}:refs/remotes/origin/{branch}",
    ])

    if worktree_dir.exists() and not worktree_uses_git(worktree_dir):
        raise SystemExit(f"Review directory exists but is not a git worktree: {worktree_dir}")

    if not worktree_dir.exists():
        run(["git", "worktree", "add", "--detach", str(worktree_dir), f"origin/{branch}"])
    else:
        run([
            "git",
            "fetch",
            "origin",
            f"+refs/heads/{branch}:refs/remotes/origin/{branch}",
        ], cwd=worktree_dir)
        run(["git", "checkout", "--detach", f"origin/{branch}"], cwd=worktree_dir)

    info = {
        "feature_id": feature["id"],
        "title": feature["title"],
        "branch": branch,
        "worktree": str(worktree_dir),
    }
    print(json.dumps(info, indent=2))

    if not args.skip_build:
        run(["./script/build_and_run.sh", "--build"], cwd=worktree_dir)

    app_path = worktree_dir / "dist" / "WorkbenchLabs.app"
    if not args.no_open:
        if not app_path.exists():
            raise SystemExit(f"Built app bundle not found: {app_path}")
        run(["open", "-n", str(app_path)], cwd=worktree_dir)

    print("\nLocal review build is ready.")
    print(f"Review app: {app_path}")
    print(f"Request changes: ./script/request_feature_changes.py {feature['id']} \"Describe the required fixes\"")
    print(f"Approve: ./script/approve_feature.py {feature['id']}")


if __name__ == "__main__":
    main()
