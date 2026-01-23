#!/usr/bin/env bats
# Bats test file located at: tests/get_exif.bats
# Tests the script: scripts/macOS/get_exif.sh
# Execute tests with command:  "bats tests/"

setup() {
  # Since tests are in ./tests/, BATS_TEST_DIRNAME = /path/to/repo/tests
  # Remove trailing "/tests" to get the repository root
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests}"

  TEST_ROOT="$(mktemp -d)"

  # Path to real test JPGs
  REAL_JPG_SOURCE="$REPO_ROOT/testdata/images/PRO34551.jpg"

  INPUT_DIR="$TEST_ROOT/input"
  OUTPUT_DIR="$TEST_ROOT/output"

  mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"

  # Copy test JPG into isolated input directory
  cp "$REAL_JPG_SOURCE" "$INPUT_DIR/real_sample.jpg"

  # Path to script under test
  SCRIPT_PATH="$REPO_ROOT/scripts/macOS/get_exif.sh"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "fails when input dir missing" {
  run bash "$SCRIPT_PATH" <<< $'\n'"$OUTPUT_DIR"$'\n'
  [ "$status" -ne 0 ]
}

@test "fails when output dir missing" {
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n\n'
  [ "$status" -ne 0 ]
}

@test "creates CSV with EXIF data from real JPG" {
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
  [ "$status" -eq 0 ]

  csv_file="$(ls "$OUTPUT_DIR"/pics_metadata_*.csv 2>/dev/null | head -n1)"
  [ -n "$csv_file" ]
  [ -s "$csv_file" ]

  run grep -E 'FileName,Make,Model,DateTimeOriginal' "$csv_file"
  [ "$status" -eq 0 ]

  run grep -E 'FUJIFILM' "$csv_file"
  [ "$status" -eq 0 ]
}
