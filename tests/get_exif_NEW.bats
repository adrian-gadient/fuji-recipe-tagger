#!/usr/bin/env bash
# Bats test suite for scripts/macOS/get_exif.sh
# Author: Adrian Gadient
# Last updated 27 January 2026
# Run with: bats tests/

# Create setup that runs before every test to ensure isolated environment
setup() {
  
  # Load helper libraries
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'

   # get the containing directory of this file
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  
  # Derive repo root (go up one level from tests/)
  REPO_ROOT="$(cd "$DIR/.." && pwd)"
  
  # make executables in scripts/ visible to PATH
  PATH="$REPO_ROOT/scripts:$PATH"

  # Create unique temp directory 
  # Prevents test interference when running in parallel
  TEST_ROOT="$(mktemp -d)"
  
  # Indicate path to test images
  INPUT_DIR="$REPO_ROOT/tests/testdata/images"
  
  # Define output dir inside temp folder
  OUTPUT_DIR="$TEST_ROOT/output"
  
  # Full path to script under test
  SCRIPT_PATH="$REPO_ROOT/scripts/macOS/get_exif.sh"
  
  # Create output directory
  mkdir -p "$OUTPUT_DIR"
  
  # Verify testdata/images directory exists and contains JPGs
  if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: $INPUT_DIR not found - create tests/testdata/images/ with JPGs"
    exit 1
  fi
  
  # Count JPG files for validation
  JPG_COUNT=$(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | wc -l)
  if [ "$JPG_COUNT" -eq 0 ]; then
    echo "Warning: No JPG files found in $INPUT_DIR"
  fi
}

# Clean up temp output files after every single test
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
  local empty_input="$TEST_ROOT/empty"
  mkdir -p "$empty_input"
  
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

# Test happy path - script processes ALL JPGs in testdata/images/
@test "processes all JPGs in testdata/images" {
  # Run script with real testdata directory
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
  
  [ "$status" -eq 0 ]                           # Must exit successfully
  
  # Verify expected console output
  [[ "$output" == *"JPG/JPEG files to process"* ]]
  [[ "$output" == *"Starting EXIF extraction"* ]]
  [[ "$output" == *"Exif metadata extraction succeeded"* ]]
  [[ "$output" == *"Output saved here"* ]]
  
  # Find ALL generated CSV files (mapfile replacement - portable Bash 3.x+)
  local csv_files=()
  while IFS= read -r -d '' csv_file; do
    csv_files+=("$csv_file")
  done < <(find "$OUTPUT_DIR" -name "pics_metadata_*.csv" -print0 2>/dev/null)
  
  # Verify at least one CSV was created
  [ ${#csv_files[@]} -gt 0 ]
  
  # Verify each CSV is valid
  for csv_file in "${csv_files[@]}"; do
    [ -f "$csv_file" ]
    [ -s "$csv_file" ]  # Non-empty
    
    # Check for expected CSV headers
    run head -n1 "$csv_file"
    [[ "$output" == *"SourceFile"* ]]
    [[ "$output" == *"FileName"* ]]
    [[ "$output" == *"Make"* ]]
  done
  
  # Verify number of CSV rows roughly matches JPG count
  local total_csv_rows=0
  for csv_file in "${csv_files[@]}"; do
    total_csv_rows=$((total_csv_rows + $(wc -l < "$csv_file")))
  done
  local jpg_count
  jpg_count=$(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | wc -l)
  [ "$total_csv_rows" -ge "$jpg_count" ]
}

# Test CSV contains Fujifilm data from real images
@test "CSV contains Fujifilm EXIF data" {
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
  [ "$status" -eq 0 ]
  
  local csv_file
  csv_file="$(ls "$OUTPUT_DIR"/pics_metadata_*.csv 2>/dev/null | head -n1)"
  [ -n "$csv_file" ]
  
  # Check for Fujifilm-specific data
  run grep -i "FUJIFILM" "$csv_file"
  [ "$status" -eq 0 ]
  
  # Check for Fujifilm X-series cameras
  run grep -i "X-Pro\|X-T\|X-H" "$csv_file"
  [ "$status" -eq 0 ]
}
