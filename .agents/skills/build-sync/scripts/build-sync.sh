#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(CDPATH= cd -- "${SKILL_DIR}/../../.." && pwd)
INDEX_FILE="${REPO_ROOT}/docs/archive/index.md"
ARCHIVE_DIR="${REPO_ROOT}/docs/archive"

usage() {
  cat <<'EOF'
Usage:
  .agents/skills/build-sync/scripts/build-sync.sh print-env
  .agents/skills/build-sync/scripts/build-sync.sh push
  .agents/skills/build-sync/scripts/build-sync.sh pull
  .agents/skills/build-sync/scripts/build-sync.sh build

Reads build-server settings from a context file referenced in docs/archive/index.md.
EOF
}

# Find the context file that contains build server config by scanning index.md
find_build_server_context() {
  if [[ ! -f "${INDEX_FILE}" ]]; then
    return 1
  fi
  # Look for a context entry whose description mentions 构建服务器 or build-sync
  grep -oP 'context_\d+\.md' "${INDEX_FILE}" | while read -r fname; do
    local ctx_file_path="${ARCHIVE_DIR}/${fname}"
    if [[ -f "${ctx_file_path}" ]] && grep -q 'Build Server IP' "${ctx_file_path}"; then
      echo "${ctx_file_path}"
      return 0
    fi
  done
}

# Read "- Key: Value" from a context file
read_context_value() {
  local key=$1
  local file=$2
  local pattern="- ${key}: "
  awk -v pat="${pattern}" '
    index($0, pat) == 1 { print substr($0, length(pat) + 1); exit }
  ' "${file}" 2>/dev/null || true
}

require_memory() {
  local ctx_file
  ctx_file=$(find_build_server_context)

  if [[ -z "${ctx_file}" ]]; then
    echo "No build server context file found in ${INDEX_FILE}" >&2
    echo "Please provide server info and use the docs-archive skill to archive it as a context entry." >&2
    exit 1
  fi

  IP=$(read_context_value "Build Server IP" "${ctx_file}")
  USER_NAME=$(read_context_value "User" "${ctx_file}")
  REMOTE_PROJECT=$(read_context_value "Remote project" "${ctx_file}")
  LOCAL_PROJECT=$(read_context_value "Local project" "${ctx_file}")

  local missing=""
  [[ -z "${IP}" ]]             && missing="${missing} 'Build Server IP'"
  [[ -z "${USER_NAME}" ]]      && missing="${missing} 'User'"
  [[ -z "${REMOTE_PROJECT}" ]] && missing="${missing} 'Remote project'"
  [[ -z "${LOCAL_PROJECT}" ]]  && missing="${missing} 'Local project'"

  if [[ -n "${missing}" ]]; then
    echo "Incomplete build server settings in ${ctx_file}" >&2
    echo "Missing:${missing}" >&2
    exit 1
  fi
}

run_rsync_makefiles() {
  local src_root=$1
  local dst_root=$2
  local mod

  for mod in binlog l2app mac macphy nrmactest rlc rlcio rlctest; do
    rsync -avz \
      "${src_root}/src/components/callp/${mod}/Makefile" \
      "${dst_root}/src/components/callp/${mod}/Makefile"
  done
}

cmd_print_env() {
  require_memory
  cat <<EOF
IP=${IP}
USER=${USER_NAME}
REMOTE_PROJECT=${REMOTE_PROJECT}
LOCAL_PROJECT=${LOCAL_PROJECT}
EOF
}

cmd_push() {
  require_memory
  rsync -avz "${LOCAL_PROJECT}/src/duapp/" "${USER_NAME}@${IP}:${REMOTE_PROJECT}/src/duapp/"
  run_rsync_makefiles "${LOCAL_PROJECT}" "${USER_NAME}@${IP}:${REMOTE_PROJECT}"
}

cmd_pull() {
  require_memory
  rsync -avz "${USER_NAME}@${IP}:${REMOTE_PROJECT}/src/duapp/" "${LOCAL_PROJECT}/src/duapp/"
  run_rsync_makefiles "${USER_NAME}@${IP}:${REMOTE_PROJECT}" "${LOCAL_PROJECT}"
}

cmd_build() {
  require_memory
  ssh "${USER_NAME}@${IP}" "cd ${REMOTE_PROJECT}/src && make -j8 do_strip=1"
}

main() {
  local subcommand=${1:-}
  if [[ -z "${subcommand}" ]]; then
    usage
    exit 1
  fi
  shift || true

  case "${subcommand}" in
    print-env) cmd_print_env ;;
    push) cmd_push ;;
    pull) cmd_pull ;;
    build) cmd_build ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "Unknown subcommand: ${subcommand}" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
