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
  nrmactest-runner.sh list
  nrmactest-runner.sh run [--binlog-events EVENTS] [test-name]
  nrmactest-runner.sh print-env

Subcommands:
  list        List all registered test cases on the remote server
  run         Run all tests (or a specific named test);
              pulls all ttilog.* back to src/components/rootfs/oam/log/
  print-env   Print resolved remote server settings

Options for 'run':
  --binlog-events EVENTS
              Pipe-separated list of binlog event keys to enable, or 'all'.
              If omitted, no BINLOG_EVENTS is set (only GENERAL events logged).
              Available keys: mac-uci, mac-ulsch, mac-ulsch-harq, mac-dlsch,
              mac-dlsch-harq, mac-dlsch-retx, mac-ta, mac-dlla, mac-ulla,
              rlc-srb, rlc-drbam, rlc-drbum, mac-csi, mac-srs, mac-dtx
              Example: --binlog-events 'mac-ulsch|mac-dlsch|mac-ta'
              Example: --binlog-events all
EOF
}

# Find the context file that contains build server config by scanning index.md
find_build_server_context() {
  if [[ ! -f "${INDEX_FILE}" ]]; then
    return 1
  fi
  grep -oP 'context_\d+\.md' "${INDEX_FILE}" | while read -r fname; do
    local fpath="${ARCHIVE_DIR}/${fname}"
    if [[ -f "${fpath}" ]] && grep -q 'Build Server IP' "${fpath}"; then
      echo "${fpath}"
      return 0
    fi
  done
}

read_context_value() {
  local key=$1
  local file=$2
  local pattern="- ${key}: "
  awk -v pat="${pattern}" '
    index($0, pat) == 1 { print substr($0, length(pat) + 1); exit }
  ' "${file}" 2>/dev/null || true
}

require_env() {
  local ctx_file
  ctx_file=$(find_build_server_context)

  if [[ -z "${ctx_file}" ]]; then
    echo "ERROR: No build server context file found in ${INDEX_FILE}" >&2
    echo "Please provide server info and use the docs-archive skill to archive it as a context entry." >&2
    exit 1
  fi

  REMOTE_HOST=$(read_context_value "Build Server IP" "${ctx_file}")
  REMOTE_USER=$(read_context_value "User" "${ctx_file}")
  REMOTE_PROJECT=$(read_context_value "Remote project" "${ctx_file}")
  REMOTE_SRC="${REMOTE_PROJECT}/src"
  LOCAL_LOG_DIR="${REPO_ROOT}/src/components/rootfs/oam/log"

  if [[ -z "${REMOTE_HOST}" || -z "${REMOTE_USER}" || -z "${REMOTE_PROJECT}" ]]; then
    echo "ERROR: Could not parse build server settings from ${ctx_file}" >&2
    exit 1
  fi
}

cmd_print_env() {
  require_env
  echo "REMOTE_HOST:    ${REMOTE_HOST}"
  echo "REMOTE_USER:    ${REMOTE_USER}"
  echo "REMOTE_SRC:     ${REMOTE_SRC}"
  echo "LOCAL_LOG_DIR:  ${LOCAL_LOG_DIR}"
}

cmd_list() {
  require_env
  ssh "${REMOTE_USER}@${REMOTE_HOST}" bash <<EOF
set -euo pipefail
cd ${REMOTE_SRC}
export PATH=\$PWD/components/rootfs/bts/bin:\$PATH
export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH:-}
export LD_LIBRARY_PATH=\$PWD/components/rootfs/bts/lib:\$LD_LIBRARY_PATH
nrMacTest list
EOF
}

cmd_run() {
  local binlog_events=""
  local test_name=""

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --binlog-events)
        shift
        binlog_events="${1:-}"
        shift
        ;;
      *)
        test_name="$1"
        shift
        ;;
    esac
  done

  require_env
  # Accept '[Suite]test', 'test', or 'Suite' formats.
  # UnitTest++ matches on the test function name only.
  if [[ "${test_name}" == *']'* ]]; then
    # '[EnvTestDemo]demo' -> 'demo'
    test_name="${test_name##*]}"
  elif [[ -n "${test_name}" && "${test_name}" != *'.'* ]]; then
    # Might be a suite name like 'EnvTestDemo'; try to find the test function name.
    local matched
    matched=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" bash -c "
      export PATH=\"${REMOTE_SRC}/components/rootfs/bts/bin:\$PATH\"
      export LD_LIBRARY_PATH=\"${REMOTE_SRC}/components/rootfs/bts/lib:\$LD_LIBRARY_PATH\"
      nrMacTest list 2>/dev/null | grep '\\[${test_name}\\]' | sed 's/.*]//' | head -1
    " 2>/dev/null || true)
    if [[ -n "${matched}" ]]; then
      test_name="${matched}"
    fi
  fi

  # Build binlog environment line
  local binlog_env=""
  if [[ -n "${binlog_events}" ]]; then
    binlog_env="export BINLOG_PATH=\$PWD/components/rootfs/oam/log; export BINLOG_EVENTS='${binlog_events}';"
  fi

  mkdir -p "${LOCAL_LOG_DIR}"

  local remote_log_dir="\$PWD/components/rootfs/oam/log"
  # Name screen log after test case for disambiguation; fallback for all-tests run
  local screen_log_name="nrmactest_output"
  if [[ -n "${test_name}" ]]; then
    screen_log_name="nrmactest_${test_name}"
  fi
  local remote_log_file="${screen_log_name}.log"
  local test_rc=0

  ssh "${REMOTE_USER}@${REMOTE_HOST}" bash <<EOF || test_rc=$?
set -euo pipefail
cd ${REMOTE_SRC}
export PATH=\$PWD/components/rootfs/bts/bin:\$PATH
export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH:-}
export LD_LIBRARY_PATH=\$PWD/components/rootfs/bts/lib:\$LD_LIBRARY_PATH
mkdir -p ${remote_log_dir}
${binlog_env}
set +e
LOGGER_LEVEL=7 nrMacTest ${test_name} 2>&1 | tee ${remote_log_dir}/${remote_log_file}
test_rc=\${PIPESTATUS[0]}
set -e
exit \${test_rc}
EOF

  echo
  echo "=== Pulling all log files via scp ==="

  # 1. Screen output log
  scp "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_SRC}/components/rootfs/oam/log/${remote_log_file}" \
    "${LOCAL_LOG_DIR}/"
  echo "[screen] ${LOCAL_LOG_DIR}/${remote_log_file}"

  # 2. Binlog (ttilog) files
  local ttilog_pulled=0
  scp "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_SRC}/components/rootfs/oam/log/ttilog.*" \
    "${LOCAL_LOG_DIR}/" 2>/dev/null && ttilog_pulled=1 || true

  echo
  echo "=== Pull Summary ==="
  echo "Screen log : ${LOCAL_LOG_DIR}/${remote_log_file}"
  if [[ ${ttilog_pulled} -eq 1 ]]; then
    echo "Binlog     : ${LOCAL_LOG_DIR}/ttilog.*"
  else
    echo "Binlog     : (no ttilog files found on remote)"
  fi
  echo "==================="

  return "${test_rc}"
}

main() {
  local subcommand="${1:-}"
  if [[ -z "${subcommand}" ]]; then
    usage
    exit 1
  fi
  shift || true

  case "${subcommand}" in
    list)      cmd_list ;;
    run)       cmd_run "$@" ;;
    print-env) cmd_print_env ;;
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
