#!/usr/bin/env bash
#
# Sync reusable agent content from public repositories into this project's
# provider-neutral .agents/ tree.
#
# Usage:
#   .agents/scripts/updater.sh
#   AGENTS_SOURCE_ROOT=/tmp/my-agent-sources .agents/scripts/updater.sh
#
# The source repositories are temporary working copies. The project's .agents/
# directory is the portable artifact that can be copied to another repository.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
AGENTS_ROOT="$PROJECT_ROOT/.agents"
SOURCE_ROOT="${AGENTS_SOURCE_ROOT:-${TMPDIR:-/tmp}/agent-sources}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

require_command git
require_command rsync

mkdir -p "$SOURCE_ROOT"

clone_or_update() {
  local owner="$1"
  local url="$2"
  local checkout="$SOURCE_ROOT/$owner"

  if [[ -d "$checkout/.git" ]]; then
    printf 'Updating %s (%s)\n' "$owner" "$url"
    git -C "$checkout" fetch --depth=1 --no-tags origin HEAD
    git -C "$checkout" reset --hard FETCH_HEAD >/dev/null
  else
    printf 'Cloning %s (%s)\n' "$owner" "$url"
    rm -rf "$checkout"
    git clone --depth=1 --filter=blob:none --no-tags "$url" "$checkout"
  fi
}

sync_category() {
  local owner="$1"
  local category="$2"
  local source_path="$3"
  local source_dir="$SOURCE_ROOT/$owner/$source_path"
  local destination="$AGENTS_ROOT/$category/$owner"

  if [[ ! -d "$source_dir" ]]; then
    printf 'warning: %s has no %s directory; skipping %s/%s\n' \
      "$owner" "$source_path" "$category" "$owner" >&2
    return 0
  fi

  mkdir -p "$destination"
  rsync -a --delete --exclude='.git/' "$source_dir/" "$destination/"
}

sync_repo() {
  local owner="$1"
  local url="$2"
  shift 2

  clone_or_update "$owner" "$url"

  # Remaining arguments are pairs: destination category and source path.
  while (($#)); do
    if (($# < 2)); then
      printf 'error: incomplete mapping for %s\n' "$owner" >&2
      exit 1
    fi
    sync_category "$owner" "$1" "$2"
    shift 2
  done
}

sync_optional_repo() {
  if ! sync_repo "$@"; then
    printf 'warning: optional source could not be synchronized; continuing\n' >&2
  fi
}

# Public sources. Keep mappings explicit so adding a repository cannot
# accidentally place content in the wrong category.
sync_repo "ecc" "https://github.com/affaan-m/ECC.git" \
  agents agents \
  skills skills \
  commands commands \
  hooks hooks \
  rules rules

sync_repo "obra" "https://github.com/obra/superpowers.git" \
  hooks hooks \
  skills skills

sync_repo "remotion" "https://github.com/remotion-dev/skills.git" \
  skills skills

sync_repo "wshobson" "https://github.com/wshobson/agents.git" \
  plugins .agents/plugins

sync_repo "addyosmani" "https://github.com/addyosmani/agent-skills.git" \
  skills skills \
  agents agents \
  hooks hooks



printf 'Agent content updated in %s\n' "$AGENTS_ROOT"