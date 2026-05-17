#!/usr/bin/env python3
import argparse
import json
from roadmap_lib import load_features, repo_name, run, select_features


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("feature_id")
    parser.add_argument("--repo", default=repo_name())
    parser.add_argument("--merge-method", default="squash", choices=["merge", "squash", "rebase"])
    args = parser.parse_args()

    feature = select_features(load_features(), args.feature_id)[0]
    result = run([
        "gh", "pr", "list",
        "--repo", args.repo,
        "--head", feature["branch"],
        "--base", "main",
        "--state", "open",
        "--json", "number,isDraft,url,labels",
    ])
    prs = json.loads(result.stdout)
    if not prs:
        raise SystemExit(f"No open integration PR found for {feature['branch']}")

    pr = prs[0]
    label_names = {label["name"] for label in pr.get("labels", [])}
    if "approved-to-merge" not in label_names:
        raise SystemExit(
            f"Refusing to promote {feature['id']}: integration PR must have the approved-to-merge label."
        )

    if pr["isDraft"]:
        run(["gh", "pr", "ready", str(pr["number"]), "--repo", args.repo])

    run([
        "gh", "pr", "merge",
        str(pr["number"]),
        "--repo", args.repo,
        f"--{args.merge_method}",
        "--delete-branch",
    ])
    print(f"promoted {feature['id']} via {pr['url']}")


if __name__ == "__main__":
    main()
