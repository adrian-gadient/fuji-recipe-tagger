#!/usr/bin/env bats

# Bats test file located at: tests/get_exif.bats
# Tests the script: scripts/macOS/get_exif.sh
# Execute tests with command:  "bats tests/"

load '/opt/bats-helpers/bats-support/load'
load '/opt/bats-helpers/bats-assert/load'

setup() {

  # Since tests are in ./tests/, BATS_TEST_DIRNAME = /path/to/repo/tests
  # Remove trailing "/tests" to get the repository root
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests}"
  script_path="$REPO_ROOT/scripts/macOS/get_exif.sh"
  [ -f "$script_path" ] || fail "Script not found: $script_path"
  
  TEST_ROOT="$(mktemp -d)"
  INPUT_DIR="$TEST_ROOT/testdata/images"
  OUTPUT_DIR="$TEST_ROOT/testdata/output"
  mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "script exists and is executable" {
  [ -x "$script_path" ]
}

@test "fails with invalid input directory" {
  run bash -c "printf 'invalid-dir\n/tmp\n' | $script_path"
  assert_failure 1
  assert_output --partial "Input path is empty or not a directory"
}

@test "fails with invalid output directory" {
  run bash -c "printf '/tmp\ninvalid-dir\n' | $script_path"
  assert_failure 2
  assert_output --partial "Destination folder is empty or not a directory"
}




