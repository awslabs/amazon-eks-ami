#!/usr/bin/env bash
#
# Retry wrapper for dnf commands that fetch from NVIDIA's CUDA repository.
#
# That repository is served by a single mirror. When its CDN resets an HTTP/2 stream
# ("Curl error (92): Stream error in the HTTP/2 framing layer ... INTERNAL_ERROR") dnf
# exhausts its one-entry mirror list almost immediately and fails the whole transaction
# with "Cannot download, all mirrors were already tried without success". The reset hits
# a single object at a time and is transient, so the same fetch succeeds on a later try.
#
# Retrying here, rather than letting the build fail and be rebuilt, keeps whatever has
# already been downloaded on this instance, so each retry has less left to fetch than a
# fresh build would.
#
# Log lines go to stderr, so dnf_retry is safe to use inside a command substitution.

# Guarded: re-declaring a readonly is fatal under `set -o errexit`, so a second source
# of this file would abort the build.
if [ -z "${DNF_RETRY_ATTEMPTS:-}" ]; then
  readonly DNF_RETRY_ATTEMPTS=5
  readonly DNF_RETRY_BASE_DELAY_SECONDS=20
fi

# Runs `sudo dnf "$@"`, retrying with a linear backoff.
function dnf_retry() {
  local attempt
  for ((attempt = 1; attempt <= DNF_RETRY_ATTEMPTS; attempt++)); do
    # After a failure, serialize downloads: fewer concurrent streams on the single
    # connection whose streams the server is resetting.
    local parallel_opt=()
    if [ "${attempt}" -gt 1 ]; then
      parallel_opt=(--setopt=max_parallel_downloads=1)
    fi

    if sudo dnf "${parallel_opt[@]}" "$@"; then
      return 0
    fi

    if [ "${attempt}" -lt "${DNF_RETRY_ATTEMPTS}" ]; then
      local delay=$((attempt * DNF_RETRY_BASE_DELAY_SECONDS))
      echo >&2 "dnf_retry: 'dnf $*' failed (attempt ${attempt}/${DNF_RETRY_ATTEMPTS}), retrying in ${delay}s"
      # Drop cached metadata only; downloaded packages are kept.
      sudo dnf clean expire-cache >&2 || true
      sleep "${delay}"
    fi
  done

  echo >&2 "dnf_retry: 'dnf $*' failed after ${DNF_RETRY_ATTEMPTS} attempts"
  return 1
}
