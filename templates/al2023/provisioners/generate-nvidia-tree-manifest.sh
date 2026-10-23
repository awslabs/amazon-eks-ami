#!/usr/bin/env bash

# generates a JSON file listing the files and scriptlets of the rpms staged in each nvidia driver tree

set -o pipefail
set -o nounset
set -o errexit
shopt -s inherit_errexit

if [ "$#" -ne 1 ]; then
  echo "usage: $0 OUTPUT_FILE"
  exit 1
fi

OUTPUT_FILE="$1"

if [ "${ENABLE_ACCELERATOR:-}" != "nvidia" ]; then
  echo '{}' > "${OUTPUT_FILE}"
  exit 0
fi

readonly NVIDIA_TREE_ROOT="/opt/nvidia"
readonly SCRIPTLET_TAGS=(PRETRANS PREIN POSTIN PREUN POSTUN POSTTRANS)

# signatures are already checked when the rpms are downloaded
function rpm-query() {
  rpm --query --package --nosignature --nodigest "$@"
}

function package-scriptlets() {
  local RPM="$1"
  local SCRIPTLETS='{}'
  local TAG PROG BODY TRIGGER

  for TAG in "${SCRIPTLET_TAGS[@]}"; do
    PROG=$(rpm-query --queryformat "[%{${TAG}PROG} ]" "${RPM}")
    BODY=$(rpm-query --queryformat "%{${TAG}}" "${RPM}")
    [ "${BODY}" != "(none)" ] || BODY=""
    if [ -n "${PROG}" ] || [ -n "${BODY}" ]; then
      SCRIPTLETS=$(jq --compact-output --arg tag "${TAG,,}" --arg prog "${PROG% }" --arg body "${BODY}" \
        '.[$tag] = {prog: $prog, body: $body}' <<< "${SCRIPTLETS}")
    fi
  done

  for TRIGGER in triggers filetriggers; do
    BODY=$(rpm-query "--${TRIGGER}" "${RPM}")
    if [ -n "${BODY}" ]; then
      SCRIPTLETS=$(jq --compact-output --arg tag "${TRIGGER}" --arg body "${BODY}" \
        '.[$tag] = {prog: "", body: $body}' <<< "${SCRIPTLETS}")
    fi
  done

  echo "${SCRIPTLETS}"
}

function package-record() {
  local TREE="$1"
  local SECTION="$2"
  local RPM="$3"
  local NAME VERSION SCRIPTLETS

  NAME=$(rpm-query --queryformat '%{NAME}' "${RPM}")
  VERSION=$(rpm-query --queryformat '%{VERSION}' "${RPM}")
  SCRIPTLETS=$(package-scriptlets "${RPM}")
  # kmod sources are deleted once they're built, so they're left out
  # the file list goes through stdin because it can be too long for an argument
  rpm-query --queryformat '[%{FILENAMES}\n]' "${RPM}" \
    | jq --compact-output --raw-input --slurp \
      --arg tree "${TREE}" --arg section "${SECTION}" --arg name "${NAME}" --arg version "${VERSION}" \
      --argjson scriptlets "${SCRIPTLETS}" \
      'split("\n") | map(select(length > 0)) | sort
        | if $section == "kmods" then map(select(startswith("/usr/src/") | not)) else . end
        | {tree: $tree, section: $section, name: $name, entry: {version: $version, files: ., scriptlets: $scriptlets}}'
}

function records() {
  local TREE_DIR TREE VERSION RPM

  shopt -s nullglob
  for TREE_DIR in "${NVIDIA_TREE_ROOT}"/*/; do
    TREE_DIR="${TREE_DIR%/}"
    TREE=$(basename "${TREE_DIR}")
    # only driver trees carry the marker, see install-nvidia-drivers.sh
    [ -f "${TREE_DIR}/.tree-${TREE}" ] || continue
    VERSION=$(cat "${TREE_DIR}/.version")
    jq --null-input --compact-output --arg tree "${TREE}" --arg version "${VERSION}" '{tree: $tree, driver_version: $version}'
    for RPM in "${TREE_DIR}"/.rpms/*.rpm; do
      package-record "${TREE}" packages "${RPM}"
    done
    for RPM in "${TREE_DIR}"/flavors/*/.sources/*.rpm; do
      package-record "${TREE}" kmods "${RPM}"
    done
  done
}

function manifest() {
  local RECORDS
  RECORDS=$(records)
  # the same package staged twice in a tree, e.g. for two flavors, would be ambiguous
  jq --slurp --sort-keys --arg root "${NVIDIA_TREE_ROOT}" '
    reduce .[] as $r ({schema_version: 1, trees: {}};
      if $r.section == null then .trees[$r.tree] = {driver_version: $r.driver_version, packages: {}, kmods: {}}
      elif .trees[$r.tree][$r.section] | has($r.name) then error("\($r.name) is staged more than once in the \($r.tree) tree")
      else .trees[$r.tree][$r.section][$r.name] = $r.entry end)
    | if .trees == {} then error("no NVIDIA driver trees found under \($root)") else . end
    | if any(.trees[]; .packages == {} or .kmods == {}) then error("a tree under \($root) has no packages or kmods, the rpms may have moved") else . end' <<< "${RECORDS}"
}

# don't fail the build, write error to the file
# an error here is likely the script itself and not the AMI
# it gets flagged when manifests are compared
ERROR_LOG=$(mktemp) || ERROR_LOG=/dev/null
set +o errexit
MANIFEST=$(
  set -o errexit
  manifest 2> "${ERROR_LOG}"
)
STATUS=$?
set -o errexit
cat "${ERROR_LOG}" >&2

if [ "${STATUS}" -ne 0 ]; then
  echo >&2 "ERROR: failed to generate the NVIDIA tree manifest (exit ${STATUS}), recording the failure in ${OUTPUT_FILE}"
  MANIFEST=$(jq --null-input --arg error "generate-nvidia-tree-manifest.sh failed with exit ${STATUS}: $(tail --bytes 2000 "${ERROR_LOG}")" \
    '{schema_version: 1, error: $error}') \
    || MANIFEST='{"schema_version": 1, "error": "generate-nvidia-tree-manifest.sh failed, see the build log"}'
fi
[ "${ERROR_LOG}" = /dev/null ] || rm -f "${ERROR_LOG}"
echo "${MANIFEST}" > "${OUTPUT_FILE}"
