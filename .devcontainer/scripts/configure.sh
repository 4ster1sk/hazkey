#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_dir="${repo_root}/build"
build_type="${HAZKEY_BUILD_TYPE:-Debug}"
ggml_vulkan="${HAZKEY_GGML_VULKAN:-OFF}"

mkdir -p "${build_dir}"

cmake \
  -S "${repo_root}" \
  -B "${build_dir}" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE="${build_type}" \
  -DGGML_VULKAN="${ggml_vulkan}"
