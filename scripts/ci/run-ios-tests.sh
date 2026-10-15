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

# UI tests are written and audited on iPhone 18 Pro, and some layouts only fit that screen,
# so prefer it on the newest iOS runtime instead of whichever iPhone is listed first.
DEVICE_ID=$(xcrun simctl list devices available -j | ruby -rjson -e '
    preferred = "iPhone 18 Pro"
    iphones = JSON.parse(STDIN.read)["devices"].flat_map do |runtime, devices|
        version = runtime[/iOS-(\d+(?:-\d+)*)/, 1]
        next [] unless version
        devices.select { |item| item["isAvailable"] && item["name"].start_with?("iPhone") }
               .map { |item| item.merge("version" => Gem::Version.new(version.tr("-", "."))) }
    end
    abort "No available iPhone simulator" if iphones.empty?
    device = iphones.select { |item| item["name"] == preferred }.max_by { |item| item["version"] } ||
             iphones.max_by { |item| item["version"] }
    STDERR.puts "Simulator: #{device["name"]} (iOS #{device["version"]})"
    puts device["udid"]
')

# Booting first avoids the test runner crashing while a cold simulator is still starting up.
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b

# Retry once so a single simulator launch hiccup does not fail a shard; a test that fails twice still fails.
retry=()
if [[ "$1" == ui ]]; then
    retry=(-retry-tests-on-failure -test-iterations 2)
fi

# Diagnostics collection after the run hung for its full 600-second timeout on hosted runners.
xcodebuild \
    -project WhereIsMyFriend.xcodeproj \
    -scheme WhereIsMyFriend \
    -configuration Debug \
    -destination "id=$DEVICE_ID" \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    CODE_SIGNING_ALLOWED=NO \
    "${selection[@]}" \
    ${retry[@]+"${retry[@]}"} \
    test
