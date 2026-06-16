#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_dir="${repo_root}/build"

if [[ ! -f "${build_dir}/build.ninja" ]]; then
  "${repo_root}/.devcontainer/scripts/configure.sh"
fi

cmake --build "${build_dir}" --parallel "$(nproc)"
