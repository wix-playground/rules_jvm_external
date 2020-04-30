#!/usr/bin/env bash

set -euo pipefail
readonly maven_install_json_loc={maven_install_location}
# This script is run as a `sh_binary`, so ensure we are in the calling workspace before running Bazel.
readonly execution_root=$(cd "$(dirname "$maven_install_json_loc")" && bazel info execution_root)
readonly workspace_name=$(basename "$execution_root")
# `jq` is a platform-specific dependency with an unpredictable path.
readonly jq=$(find external/ -name jq -perm -o+x)
cat <<"RULES_JVM_EXTERNAL_EOF" | "$jq" --sort-keys --indent 4 . - > "$maven_install_json_loc.json"
{dependency_tree_json}
RULES_JVM_EXTERNAL_EOF
sed -e 's/null/None/g' -e '1s/^/DEPENDENCY_CLOSURE = /' < "$maven_install_json_loc.json" > "$maven_install_json_loc.bzl"

if [ "{predefined_maven_install}" = "True" ]; then
    echo "Successfully pinned resolved artifacts for @{repository_name}, $maven_install_json_loc is now up-to-date."
else
    echo "Successfully pinned resolved artifacts for @{repository_name} in $maven_install_json_loc." \
      "This file should be checked in your version control system."
    echo
    echo "Next, please update your WORKSPACE file by adding the maven_install_json attribute" \
      "and loading pinned_maven_install from @{repository_name}//:defs.bzl".
    echo
    echo "For example:"
    echo
    cat <<EOF
=============================================================

maven_install(
    artifacts = # ...,
    repositories = # ...,
    maven_install_json = "@$workspace_name//:{repository_name}_install.json",
)

load("@{repository_name}//:defs.bzl", "pinned_maven_install")
pinned_maven_install()

=============================================================
Alternatively:
=============================================================

load("@$workspace_name//:{repository_name}_install.bzl", "DEPENDENCY_CLOSURE")

maven_install(
    artifacts = # ...,
    repositories = # ...,
    maven_install_dict = DEPENDENCY_CLOSURE,
)

load("@{repository_name}//:defs.bzl", "pinned_maven_install")
pinned_maven_install()

=============================================================
EOF

    echo
    echo "To update {repository_name}_install.json, run this command to re-pin the unpinned repository:"
    echo
    echo "    bazel run @unpinned_{repository_name}//:pin"
fi
echo
