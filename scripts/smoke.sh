#!/usr/bin/env bash
set -euo pipefail

base_url=${1:?Provide the app base URL}
attempts=${2:-30}

for ((attempt = 1; attempt <= attempts; attempt++)); do
  health=$(curl --silent --fail --max-time 5 "${base_url%/}/_stcore/health") || health=""
  if [[ "$health" == "ok" ]]; then
    app_shell=$(curl --silent --fail --max-time 5 "${base_url%/}/") || app_shell=""
    if [[ "$app_shell" == *'<div id="root">'* ]]; then
      printf 'Streamlit health and HTML checks passed at %s\n' "$base_url"
      exit 0
    fi
  fi
  sleep 2
done

printf 'Streamlit smoke check timed out at %s\n' "$base_url" >&2
exit 1
