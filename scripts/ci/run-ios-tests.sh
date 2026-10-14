#!/bin/bash
# Runs the iOS unit tests, or one shard of the UI tests, on an available iPhone simulator.
#
#   scripts/ci/run-ios-tests.sh unit
#   scripts/ci/run-ios-tests.sh ui <shard> <shard-count>
#
# UI tests are split round-robin in declaration order so slow suites spread across shards.
# testCapture* methods render marketing and App Store screenshots rather than verify behavior;
# run them by hand with -only-testing when assets need refreshing.
set -euo pipefail
cd "$(dirname "$0")/../.."

UI_TEST_FILE=WhereIsMyFriendUITests/PrototypeUITests.swift
UI_TEST_CLASS=WhereIsMyFriendUITests/PrototypeUITests

ui_test_names() {
    sed -nE 's/^    func (test[A-Za-z0-9_]+)\(\).*/\1/p' "$UI_TEST_FILE" | grep -v '^testCapture'
}

case "${1:-}" in
    unit)
        selection=(-only-testing:WhereIsMyFriendTests)
        ;;
    ui)
        shard=${2:?missing shard number}
        count=${3:?missing shard count}
        selection=()
        index=0
        while read -r name; do
            if (( index % count == shard - 1 )); then
                selection+=("-only-testing:$UI_TEST_CLASS/$name")
            fi
            index=$((index + 1))
        done < <(ui_test_names)
        if (( ${#selection[@]} == 0 )); then
            echo "::error::UI test shard $shard/$count selected no tests."
            exit 1
        fi
        echo "UI test shard $shard/$count: ${#selection[@]} of $index tests"
        ;;
    *)
        echo "usage: $0 unit | ui <shard> <shard-count>" >&2
        exit 64
        ;;
esac

if [[ -n "${LIST_ONLY:-}" ]]; then
    printf '%s\n' "${selection[@]}"
    exit 0
fi

DEVICE_ID=$(xcrun simctl list devices available -j | ruby -rjson -e '
    devices = JSON.parse(STDIN.read)["devices"].values.flatten
    device = devices.find { |item| item["name"].start_with?("iPhone") && item["isAvailable"] }
    abort "No available iPhone simulator" unless device
    puts device["udid"]
')

xcodebuild \
    -project WhereIsMyFriend.xcodeproj \
    -scheme WhereIsMyFriend \
    -configuration Debug \
    -destination "id=$DEVICE_ID" \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    "${selection[@]}" \
    test
