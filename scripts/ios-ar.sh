#!/usr/bin/env bash
set -euo pipefail

: "${IOS_SDK:?}"

# Apple's ar does not support @response-file arguments (used by newer Lake
# versions when the object-file list would exceed argv limits). Expand any
# @<file> arg by parsing the file with shell-style quoting before exec'ing ar.
args=()
for a in "$@"; do
  case "$a" in
    @*)
      rsp="${a#@}"
      # xargs honors shell quoting and emits one argument per NUL.
      while IFS= read -r -d '' tok; do
        args+=("$tok")
      done < <(xargs -n1 printf '%s\0' < "$rsp")
      ;;
    *)
      args+=("$a")
      ;;
  esac
done

exec xcrun --sdk "$IOS_SDK" ar "${args[@]}"
