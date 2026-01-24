#!/usr/bin/env bash

setup() {
  # Get repo root safely
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests}"
  
  # Create isolated temp dir
  TEST_ROOT="$(mktemp -d)"
  INPUT_DIR="$TEST_ROOT/input"
  OUTPUT_DIR="$TEST_ROOT/output"
  SCRIPT_PATH="$REPO_ROOT/scripts/macOS/get_exif.sh"
  
  # Create dirs
  mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"
  
  # Copy test JPG ONLY if it exists (skip gracefully if missing)
  REAL_JPG_SOURCE="$REPO_ROOT/tests/testdata/images/PRO34551.jpg"
  if [ -f "$REAL_JPG_SOURCE" ]; then
    cp "$REAL_JPG_SOURCE" "$INPUT_DIR/real_sample.jpg"
  else
    echo "Warning: Test image not found at $REAL_JPG_SOURCE, skipping copy"
    touch "$INPUT_DIR/real_sample.jpg"  # Create empty placeholder
  fi
}

teardown() {
  [ -n "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}

@test "script exists and is executable" {
  [ -f "$SCRIPT_PATH" ]
  [ -x "$SCRIPT_PATH" ]
}

@test "fails when input dir is empty" {
  run bash "$SCRIPT_PATH" <<< $'\n'"$OUTPUT_DIR"$'\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Input path"* ]]
}

@test "fails when input dir does not exist" {
  run bash "$SCRIPT_PATH" <<< "/nonexistent/path"$'\n'"$OUTPUT_DIR"$'\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Input path"* ]]
}

@test "fails when output dir is empty" {
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Destination folder"* ]]
}

@test "fails when output dir does not exist" {
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"/nonexistent/path"$'\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Destination folder"* ]]
}

@test "fails when output dir is not writable" {
  local readonly_dir="$TEST_ROOT/readonly"
  mkdir -p "$readonly_dir"
  chmod -w "$readonly_dir"
  
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$readonly_dir"$'\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"not writable"* ]]
  chmod +w "$readonly_dir" 2>/dev/null || true
}

@test "fails when no JPG files found" {
  local empty_dir="$TEST_ROOT/empty"
  mkdir -p "$empty_dir"
  run bash "$SCRIPT_PATH" <<< "$empty_dir"$'\n'"$OUTPUT_DIR"$'\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"No JPG"* ]]
}

@test "creates CSV when JPG present" {
  # Only test happy path if we have a real JPG
  if [ -f "$REPO_ROOT/tests/testdata/images/PRO34551.jpg" ]; then
    run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"JPG/JPEG files to process"* ]]
    
    local csv_file
    csv_file="$(ls "$OUTPUT_DIR"/pics_metadata_*.csv 2>/dev/null | head -n1)"
    [ -n "$csv_file" ]
    [ -f "$csv_file" ]
    [ -s "$csv_file" ]
  else
    skip "Real test JPG missing"
  fi
}

@test "fails gracefully without real JPG" {
  # Test with empty placeholder (script should fail cleanly)
  rm -f "$INPUT_DIR/real_sample.jpg"
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"No JPG"* ]]
}

