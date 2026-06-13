#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <package_root> <output_dir> <project_version> <target_arch> <distro_label> [git_ref] [git_sha]" >&2
}

if [[ $# -lt 5 ]]; then
    usage
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKAGE_ROOT="$1"
OUTPUT_DIR="$2"
PROJECT_VERSION="$3"
TARGET_ARCH="$4"
DISTRO_LABEL="$5"
GIT_REF="${6:-}"
GIT_SHA="${7:-}"

case "$TARGET_ARCH" in
x86_64) DEB_ARCH=amd64 ;;
aarch64) DEB_ARCH=arm64 ;;
*)
    echo "unsupported arch: $TARGET_ARCH" >&2
    exit 1
    ;;
esac

resolve_deb_version() {
    if [[ "$GIT_REF" =~ ^refs/tags/v?(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}-1"
        return
    fi

    local shortsha="${GIT_SHA:0:7}"
    if [[ -z "$shortsha" ]]; then
        shortsha="unknown"
    fi
    echo "${PROJECT_VERSION}-1~git${shortsha}"
}

DEB_VERSION="$(resolve_deb_version)"

if [[ ! -d "$PACKAGE_ROOT/usr" ]]; then
    echo "package root does not contain usr/: $PACKAGE_ROOT" >&2
    exit 1
fi

STAGING="$(mktemp -d)"
SHLIBDEPS_ROOT="$(mktemp -d)"
trap 'rm -rf "$STAGING" "$SHLIBDEPS_ROOT"' EXIT

mkdir -p "$STAGING/DEBIAN"
cp -a "$PACKAGE_ROOT/usr" "$STAGING/"

mkdir -p "$SHLIBDEPS_ROOT/debian"
cat >"$SHLIBDEPS_ROOT/debian/control" <<EOF
Source: fcitx5-hazkey
Section: utils
Priority: optional
Maintainer: Unofficial Package <invalid@example.invalid>

Package: fcitx5-hazkey
Architecture: $DEB_ARCH
Depends:
Description: Japanese input method for fcitx5, powered by azooKey engine
 stub for dpkg-shlibdeps
EOF

mapfile -d '' -t ELF_FILES < <(
    find "$STAGING/usr" -type f -print0 | while IFS= read -r -d '' file; do
        if file -b "$file" | grep -q 'ELF'; then
            printf '%s\0' "$file"
        fi
    done
)

declare -A SHLIBDEPS_DIR_SET=()
add_shlibdep_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || return
    SHLIBDEPS_DIR_SET["$dir"]=1
}
for libdir in "$STAGING/usr/lib/"*-linux-gnu "$STAGING/usr/lib"; do
    add_shlibdep_dir "$libdir"
done
while IFS= read -r -d '' libdir; do
    add_shlibdep_dir "$libdir"
done < <(find "$STAGING/usr/lib" -type d \( -name libllama -o -name backends \) -print0)

SHLIBDEPS_ARGS=()
for libdir in "${!SHLIBDEPS_DIR_SET[@]}"; do
    SHLIBDEPS_ARGS+=(-l"$libdir")
done

SHLIBS_DEPENDS=""
if ((${#ELF_FILES[@]} > 0)); then
    shlibdeps_cmd=(dpkg-shlibdeps --ignore-missing-info)
    for elf in "${ELF_FILES[@]}"; do
        shlibdeps_cmd+=(-e "$elf")
    done
    shlibdeps_cmd+=("${SHLIBDEPS_ARGS[@]}")
    shlibdeps_stderr="$STAGING/dpkg-shlibdeps.stderr"
    if SHLIBS_DEPENDS="$(
        cd "$SHLIBDEPS_ROOT"
        "${shlibdeps_cmd[@]}" -O 2>"$shlibdeps_stderr" | sed 's/^shlibs:Depends=//'
    )"; then
        :
    else
        cat "$shlibdeps_stderr" >&2
        SHLIBS_DEPENDS=""
    fi
fi

EXPLICIT_DEPS="fcitx5 (>= 5.0.4), qt6-qpa-plugins (>= 6.2)"
if [[ -n "$SHLIBS_DEPENDS" ]]; then
    DEPENDS="${EXPLICIT_DEPS}, ${SHLIBS_DEPENDS}"
else
    echo "failed to resolve shared library dependencies for ${DISTRO_LABEL}/${DEB_ARCH}" >&2
    exit 1
fi

INSTALLED_SIZE="$(du -sk "$STAGING/usr" | awk '{print $1}')"

CONTROL_TEMPLATE="$REPO_ROOT/packaging/debian/control.in"
CONTROL_OUT="$STAGING/DEBIAN/control"
python3 - <<'PY' "$CONTROL_TEMPLATE" "$CONTROL_OUT" "$DEB_VERSION" "$DEB_ARCH" "$INSTALLED_SIZE" "$DEPENDS"
import pathlib
import sys

template_path, output_path, version, arch, installed_size, depends = sys.argv[1:]
text = pathlib.Path(template_path).read_text()
text = (
    text.replace("@VERSION@", version)
    .replace("@ARCH@", arch)
    .replace("@INSTALLED_SIZE@", installed_size)
    .replace("@DEPENDS@", depends)
)
pathlib.Path(output_path).write_text(text)
PY

(
    cd "$STAGING"
    find usr -type f -exec md5sum {} + | sed 's|^\./||'
) >"$STAGING/DEBIAN/md5sums"

mkdir -p "$OUTPUT_DIR"
DEB_NAME="fcitx5-hazkey_${DEB_VERSION}-${DISTRO_LABEL}_${DEB_ARCH}.deb"
fakeroot dpkg-deb --build "$STAGING" "$OUTPUT_DIR/$DEB_NAME"
echo "Created $OUTPUT_DIR/$DEB_NAME"
