#!/bin/bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_configuration="${CONFIGURATION:-release}"
app_bundle="$repo_root/dist/Priorities.app"

source "$repo_root/scripts/stage-package.sh"
prepare_priorities_package "$repo_root"

swift build "${priorities_swift_options[@]}" --configuration "$build_configuration" --product Priorities
binary_directory="$(swift build "${priorities_swift_options[@]}" --configuration "$build_configuration" --show-bin-path)"

mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$binary_directory/Priorities" "$app_bundle/Contents/MacOS/.Priorities.$$.new"
mv -f "$app_bundle/Contents/MacOS/.Priorities.$$.new" "$app_bundle/Contents/MacOS/Priorities"
cp "$repo_root/Resources/Info.plist" "$app_bundle/Contents/Info.plist"
chmod +x "$app_bundle/Contents/MacOS/Priorities"
/usr/bin/plutil -lint "$app_bundle/Contents/Info.plist"
/usr/bin/codesign --force --sign - --identifier se.johnelvesjo.priorities "$app_bundle"
/usr/bin/codesign --verify --strict "$app_bundle"
printf 'Built %s\n' "$app_bundle"
