#!/usr/bin/env python3
import argparse
import shutil
import tempfile
from pathlib import Path
from roadmap_lib import load_features, repo_name, run, select_features


def remote_branch_exists(branch):
    result = run(["git", "ls-remote", "--heads", "origin", branch], check=False)
    return bool(result.stdout.strip())


def refresh_feature(repo, feature):
    branch = feature["branch"]
    if not remote_branch_exists(branch):
        print(f"skip missing branch: {branch}")
        return

    temp_dir = Path(tempfile.mkdtemp(prefix="workbench-refresh-"))
    try:
        run(["git", "worktree", "add", "--detach", str(temp_dir), f"origin/{branch}"])
        run(["git", "switch", "-C", branch], cwd=temp_dir)
        merge = run(["git", "merge", "--no-edit", "origin/main"], cwd=temp_dir, check=False)
        if merge.returncode != 0:
            raise SystemExit(f"Could not merge origin/main into {branch}:\n{merge.stdout}{merge.stderr}")
        run(["git", "push", "origin", f"HEAD:{branch}"], cwd=temp_dir)
        print(f"refreshed {branch}")
    finally:
        run(["git", "worktree", "remove", "--force", str(temp_dir)], check=False)
        shutil.rmtree(temp_dir, ignore_errors=True)


def main():
    parser = argparse.ArgumentParser(description="Merge the latest main branch into roadmap feature branches.")
    parser.add_argument("--repo", default=repo_name())
    parser.add_argument("--feature-id", default="all")
    args = parser.parse_args()

    run(["git", "fetch", "origin", "main"])
    for feature in select_features(load_features(), args.feature_id):
        refresh_feature(args.repo, feature)


if __name__ == "__main__":
    main()
