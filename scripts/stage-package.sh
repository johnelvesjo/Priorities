#!/bin/bash

# SwiftPM's linker file lists cannot reliably represent literal quotes in paths.
# Build a private source snapshot in a generated path without those characters.
prepare_priorities_package() {
    local source_root="$1"
    priorities_stage_root="$(mktemp -d /private/tmp/priorities-swift.XXXXXX)"
    trap cleanup_priorities_package EXIT

    cp "$source_root/Package.swift" "$priorities_stage_root/Package.swift"
    cp -R "$source_root/Sources" "$priorities_stage_root/Sources"
    if [[ -d "$source_root/Tests" ]]; then
        cp -R "$source_root/Tests" "$priorities_stage_root/Tests"
    fi

    export CLANG_MODULE_CACHE_PATH="$priorities_stage_root/.build/ModuleCache"
    export SWIFTPM_MODULECACHE_OVERRIDE="$priorities_stage_root/.build/ModuleCache"
    mkdir -p "$CLANG_MODULE_CACHE_PATH" "$priorities_stage_root/.swiftpm/cache" "$priorities_stage_root/.swiftpm/config" "$priorities_stage_root/.swiftpm/security"

    priorities_swift_options=(
        --package-path "$priorities_stage_root"
        --scratch-path "$priorities_stage_root/.build"
        --cache-path "$priorities_stage_root/.swiftpm/cache"
        --config-path "$priorities_stage_root/.swiftpm/config"
        --security-path "$priorities_stage_root/.swiftpm/security"
        --disable-sandbox
        --build-system native
    )
}

cleanup_priorities_package() {
    case "${priorities_stage_root:-}" in
        /private/tmp/priorities-swift.*)
            rm -rf -- "$priorities_stage_root"
            ;;
    esac
}
