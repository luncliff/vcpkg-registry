#!/usr/bin/env bash
set -euo pipefail

: "${VCPKG_ROOT:?VCPKG_ROOT must point to the vcpkg checkout}"
: "${VCPKG_PORTS:?Pass VCPKG_PORTS as a space-separated list of port specs}"

VCPKG_TRIPLET="${VCPKG_TRIPLET:-x64-linux}"
read -r -a ports <<< "$VCPKG_PORTS"

if ((${#ports[@]} == 0)); then
    printf '%s\n' "VCPKG_PORTS must include at least one port spec" >&2
    exit 2
fi

vcpkg="${VCPKG_ROOT}/vcpkg"
if [[ ! -x "$vcpkg" ]]; then
    printf 'vcpkg executable not found: %s\n' "$vcpkg" >&2
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
overlay_ports="$(cd -- "${script_dir}/../ports" && pwd)"

exec "$vcpkg" install "${ports[@]}" \
    --triplet="${VCPKG_TRIPLET}" \
    --overlay-ports="${overlay_ports}"
