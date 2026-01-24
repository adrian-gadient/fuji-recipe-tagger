#!/usr/bin/env bash
# Bats test suite for scripts/macOS/get_exif.sh
# Run with: bats tests/

# Create setup that runs before test to ensure isolated environment
setup() {
  # Strip "/tests" to get repo root 
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests}"
  
  # Create unique temp directory 
  # Prevents test interference when running in parallel
  TEST_ROOT="$(mktemp -d)"
  
  # Define input/output dirs INSIDE our temp folder (isolated from filesystem)
  INPUT_DIR="$TEST_ROOT/input"
  OUTPUT_DIR="$TEST_ROOT/output"
  
  # Full path to script under test
  SCRIPT_PATH="$REPO_ROOT/scripts/macOS/get_exif.sh"
  
  # Create empty input/output directories
  mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"
  
  # Copy real Fujifilm test image (if it exists in testdata/)
  REAL_JPG_SOURCE="$REPO_ROOT/tests/testdata/images/PRO34551.jpg"
  if [ -f "$REAL_JPG_SOURCE" ]; then
    # Copy with test-friendly name
    cp "$REAL_JPG_SOURCE" "$INPUT_DIR/real_sample.jpg"
  else
    # Graceful fallback - create empty placeholder so tests still run
    echo "Warning: Test JPG missing at $REAL_JPG_SOURCE"
    touch "$INPUT_DIR/real_sample.jpg"
  fi
}

# Runs AFTER every single test - cleans up temp files
teardown() {
  # Safe cleanup (only if TEST_ROOT was created)
  [ -n "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}

# Verify script file exists and has execute permission
@test "script exists and is executable" {
  [ -f "$SCRIPT_PATH" ]          # File exists
  [ -x "$SCRIPT_PATH" ]          # Has execute bit set
}

# Test script correctly rejects empty input directory
@test "fails when input dir is empty" {
  # Simulate user pressing Enter (empty input) then typing output dir
  run bash "$SCRIPT_PATH" <<< $'\n'"$OUTPUT_DIR"$'\n'
  [ "$status" -ne 0 ]            # Must exit non-zero
  [[ "$output" == *"Input path"* ]]  # Shows expected error message
}

# Test script handles nonexistent input directory
@test "fails when input dir does not exist" {
  run bash "$SCRIPT_PATH" <<< "/nonexistent/path"$'\n'"$OUTPUT_DIR"$'\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Input path"* ]]
}

# Test script rejects empty output directory
@test "fails when output dir is empty" {
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Destination folder"* ]]
}

# Test script handles nonexistent output directory
@test "fails when output dir does not exist" {
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"/nonexistent/path"$'\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Destination folder"* ]]
}

# Test script fails when output directory lacks write permissions
@test "fails when output dir is not writable" {
  # Create readonly directory
  local readonly_dir="$TEST_ROOT/readonly"
  mkdir -p "$readonly_dir"
  chmod -w "$readonly_dir"       # Remove write permission
  
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$readonly_dir"$'\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"not writable"* ]]
  
  # Restore permissions (suppress errors if already deleted)
  chmod +w "$readonly_dir" 2>/dev/null || true
}

# Test script fails when input directory contains no JPG files
@test "fails when no JPG files found" {
  local empty_dir="$TEST_ROOT/empty"
  mkdir -p "$empty_dir"
  
  run bash "$SCRIPT_PATH" <<< "$empty_dir"$'\n'"$OUTPUT_DIR"$'\n'
  [ "$status" -ne 0 ]
  [[ "$output" == *"No JPG"* ]]
}

# Test happy path - script processes real JPG and creates CSV
@test "creates CSV when JPG present" {
  # Skip if real test image is missing from repo
  if [ -f "$REPO_ROOT/tests/testdata/images/PRO34551.jpg" ]; then
    # Run script with valid input/output directories
    run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
    
    [ "$status" -eq 0 ]                           # Must exit successfully
    [[ "$output" == *"JPG/JPEG files to process"* ]]  # Expected console output
    
    # Find generated CSV file (matches script's naming pattern)
    local csv_file
    csv_file="$(ls "$OUTPUT_DIR"/pics_metadata_*.csv 2>/dev/null | head -n1)"
    
    [ -n "$csv_file" ]    # CSV filename found
    [ -f "$csv_file" ]    # CSV file exists
    [ -s "$csv_file" ]    # CSV file is non-empty
  else
    skip "Real test JPG missing from testdata/"
  fi
}

# Test script handles missing JPG gracefully (empty placeholder file)
@test "fails gracefully without real JPG" {
  # Remove JPG file, leaving only empty placeholder
  rm -f "$INPUT_DIR/real_sample.jpg"
  
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
  [ "$status" -ne 0 ]      # Should fail (no real JPG)
  [[ "$output" == *"No JPG"* ]]  # Shows expected "no JPGs" error
}
