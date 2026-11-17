#!/usr/bin/env bash

# 创建 GitHub Release。
#
# 用法：create_release.bash VERSION
#
# 参数：
#   VERSION     skopeo 版本，如 v1.25.2
#
# 环境变量：
#   GH_TOKEN      gh CLI 凭据
#   GH_REPO       目标仓库
#   GITHUB_SHA    Release 指向的 commit；留空则由 gh 用默认分支

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

V="${1:-}"

if [[ -z "${V}" ]]; then
    echo "usage: create_release.bash VERSION" >&2
    exit 1
fi

if gh release view "${V}" --json tagName >/dev/null 2>&1; then
    echo "skip: ${V} already released, refusing to overwrite"
    exit 0
fi

create_args=(
    "${V}"
    --title "${V}"
    --notes "Upstream release: ${GITHUB_SERVER_URL:-https://github.com}/containers/skopeo/releases/tag/${V}"
)

if [[ -n "${GITHUB_SHA:-}" ]]; then
    create_args+=(--target "${GITHUB_SHA}")
fi

gh release create "${create_args[@]}"

{
    echo "### Released ${V}"
    echo
    echo "- release: ${GITHUB_SERVER_URL:-https://github.com}/${GH_REPO:-}/releases/tag/${V}"
} | emit_summary
