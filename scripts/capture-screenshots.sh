#!/usr/bin/env bash
# Capture App Store screenshots for WorldTV using the dedicated XCUITest class
# (WorldTVUITests/ScreenshotTests.swift). Requires a network connection because
# Home content is fetched from the live catalog.
#
# The screenshot tests attach each PNG to the test result as an XCTAttachment
# named "<platform>--<name>". This script runs the tests on the store devices,
# exports the attachments from the resulting xcresult bundle with
# `xcrun xcresulttool export attachments`, and renames them into
# docs/screenshots/store/<platform>/<name>.png.
#
# Usage:
#   scripts/capture-screenshots.sh [all|ios|mac|tvos]
#   scripts/capture-screenshots.sh --platform ios --output docs/screenshots/store
#
# Options:
#   --platform all|ios|mac|tvos   Which platforms to capture (default: all)
#   --output DIR                  Where to write PNGs (default: docs/screenshots/store)
#   --derived-data DIR            xcodebuild DerivedData path
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/WorldTV.xcodeproj"
SCHEME="WorldTV"

PLATFORM="all"
OUTPUT="$ROOT/docs/screenshots/store"
DERIVED_DATA="$ROOT/build/derived-data-screenshots"
RESULT_DIR="$ROOT/build/screenshot-results"

usage() {
    sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform) PLATFORM="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --derived-data) DERIVED_DATA="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) PLATFORM="$1"; shift ;;
    esac
done

case "$PLATFORM" in
    all|ios|mac|tvos) ;;
    *) echo "Unknown platform '$PLATFORM' (expected all|ios|mac|tvos)." >&2; exit 1 ;;
esac

mkdir -p "$OUTPUT" "$RESULT_DIR"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# find_sim <device name> <runtime substring>
find_sim() {
    local json
    json="$(xcrun simctl list devices available -j)"
    python3 - "$1" "$2" "$json" <<'PY'
import json
import sys

name, runtime = sys.argv[1], sys.argv[2]
data = json.loads(sys.argv[3]).get("devices", {})
needle = runtime.replace(" ", "-").replace(".", "-")
for os_name, devices in data.items():
    if needle not in os_name:
        continue
    for device in devices:
        if device["name"] == name:
            print(device["udid"])
            sys.exit(0)
sys.exit(1)
PY
}

# export_screenshots <xcresult bundle> <label>
# Moves the screenshot attachments into $OUTPUT/<label>/<name>.png.
export_screenshots() {
    local bundle="$1"
    local label="$2"
    local target="$OUTPUT/$label"
    local attachments="$RESULT_DIR/$label-attachments"
    local manifest="$attachments/manifest.json"

    mkdir -p "$target"
    rm -rf "$attachments"
    xcrun xcresulttool export attachments \
        --path "$bundle" --output-path "$attachments" >/dev/null 2>&1 || return 0

    if [[ ! -f "$manifest" ]]; then
        log "No screenshot attachments found for $label."
        return 0
    fi

    rm -f "$target"/*.png
    python3 - "$attachments" "$target" <<'PY'
import json
import os
import re
import shutil
import sys

attachments_dir, target = sys.argv[1], sys.argv[2]
pattern = re.compile(r"^(?P<rest>.*)--(?P<name>.*)_\d+_[0-9A-Fa-f-]+\.png$")
manifest_path = os.path.join(attachments_dir, "manifest.json")
data = json.load(open(manifest_path))

moved = 0
for entry in data:
    for attachment in entry.get("attachments", []):
        exported = attachment.get("exportedFileName", "")
        human = attachment.get("suggestedHumanReadableName", "")
        match = pattern.match(human)
        if not match:
            continue
        name = match.group("name")
        source = os.path.join(attachments_dir, exported)
        if not os.path.isfile(source):
            continue
        destination = os.path.join(target, name + ".png")
        shutil.move(source, destination)
        moved += 1
print(moved)
PY
    local count
    count="$(find "$target" -name '*.png' | wc -l | tr -d ' ')"
    log "Collected $count PNG(s) into $target"
}

# run_tests <label> <xcodebuild args...>
run_tests() {
    local label="$1"
    shift
    local bundle="$RESULT_DIR/$label-$(date +%s).xcresult"
    log "Running screenshot tests: $label"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$bundle" \
        -only-testing:WorldTVUITests/ScreenshotTests \
        "$@" test 2>&1 | tee "$RESULT_DIR/$label.log"
    export_screenshots "$bundle" "$label"
}

run_ios_iphone() {
    run_tests "ios-iphone" \
        -destination "platform=iOS Simulator,id=$(find_sim "iPhone 17 Pro Max" "iOS 26.5")"
}

run_ios_ipad() {
    run_tests "ios-ipad" \
        -destination "platform=iOS Simulator,id=$(find_sim "iPad Pro 13-inch (M5)" "iOS 26.5")"
}

run_mac() {
    run_tests "mac" -destination "platform=macOS"
}

run_tvos() {
    run_tests "tvos" \
        -destination "platform=tvOS Simulator,id=$(find_sim "Apple TV 4K (3rd generation) (at 1080p)" "tvOS 26.5")"
}

case "$PLATFORM" in
    all)
        run_ios_iphone
        run_ios_ipad
        run_mac
        run_tvos
        ;;
    ios)
        run_ios_iphone
        run_ios_ipad
        ;;
    mac)
        run_mac
        ;;
    tvos)
        run_tvos
        ;;
esac

log "Screenshots written to $OUTPUT"
find "$OUTPUT" -name "*.png" | sort
