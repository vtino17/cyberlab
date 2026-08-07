#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./installer.sh

docker() {
    case "$1" in
        --version) echo "Docker version test" ;;
        compose) [[ "${2:-}" == "version" ]] ;;
    esac
}

output="$(check_docker)"
grep -q "Docker Compose found" <<<"$output"

missing_output="$(env PATH=/nonexistent /bin/bash -c 'source ./installer.sh; check_docker' 2>&1 || true)"
if grep -q "Docker is required" <<<"$missing_output"; then
    exit 0
fi
exit 1
