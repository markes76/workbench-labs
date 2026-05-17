#!/usr/bin/env python3
import argparse
import json
from roadmap_lib import find_pr_by_branch, gh_api_json, load_features, repo_name, run, select_features


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("feature_id")
    parser.add_argument("--repo", default=repo_name())
    parser.add_argument("--merge-method", default="squash", choices=["merge", "squash", "rebase"])
    args = parser.parse_args()

    feature = select_features(load_features(), args.feature_id)[0]
    pr = find_pr_by_branch(args.repo, feature["branch"], state="open")
    if not pr:
        raise SystemExit(f"No open integration PR found for {feature['branch']}")

    label_names = {label["name"] for label in pr.get("labels", [])}
    if "approved-to-merge" not in label_names:
        raise SystemExit(
            f"Refusing to promote {feature['id']}: integration PR must have the approved-to-merge label."
        )

    if pr["isDraft"]:
        raise SystemExit(
            f"Refusing to promote {feature['id']}: integration PR #{pr['number']} is still a draft. "
            "Run script/approve_feature.py locally first."
        )

    gh_api_json(
        f"repos/{args.repo}/pulls/{pr['number']}/merge",
        method="PUT",
        data={"merge_method": args.merge_method},
    )
    run(["gh", "api", "--method", "DELETE", f"repos/{args.repo}/git/refs/heads/{feature['branch']}"], check=False)
    print(f"promoted {feature['id']} via {pr['url']}")


if __name__ == "__main__":
    main()
