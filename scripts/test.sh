#!/bin/bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_configuration="${CONFIGURATION:-debug}"
source "$repo_root/scripts/stage-package.sh"
prepare_priorities_package "$repo_root"

swift test "${priorities_swift_options[@]}" --configuration "$build_configuration" "$@"
