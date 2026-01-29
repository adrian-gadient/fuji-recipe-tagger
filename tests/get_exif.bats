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
  load 'test_helper/bats-file/load'

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
    return 1
  fi
  
  # Count JPG files for validation
  JPG_COUNT=$(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | wc -l)
  if [ "$JPG_COUNT" -eq 0 ]; then
    echo "Warning: No JPG files found in $INPUT_DIR"
  fi
}

# Clean up temp output files after every single test
teardown() {
  if [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ]; then
    chmod -R +w "$TEST_ROOT" 2>/dev/null || true
    rm -rf "$TEST_ROOT"
  fi
}
# Verify script file exists and has execute permission
@test "script exists and is executable" {
  assert_file_exist "$SCRIPT_PATH"
  assert_file_executable "$SCRIPT_PATH"
}

# Test script correctly rejects empty input directory
@test "fails when input dir is empty" {
  # simulate user entering empty input directory and verify script fails
  run bash "$SCRIPT_PATH" <<< $'\n'"$OUTPUT_DIR"$'\n'
  assert_failure
  assert_output --partial "Input path"
}

# Test script handles nonexistent input directory
@test "fails when input dir does not exist" {
  # simulate invalid path
  run bash "$SCRIPT_PATH" <<< "/nonexistent/path"$'\n'"$OUTPUT_DIR"$'\n'
  assert_failure
  assert_output --partial "Input path"
}

# Check if there are jpgs
@test "fails when no JPG files found in input directory" {
  local empty_dir="$TEST_ROOT/empty_images"
  mkdir -p "$empty_dir"
  
  run bash "$SCRIPT_PATH" <<< "$empty_dir"$'\n'"$OUTPUT_DIR"$'\n'
  
  assert_failure
  assert_output --partial "No JPG"
}

# Test script rejects empty output directory
@test "fails when output dir is empty" {
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n\n'
  assert_failure
  assert_output --partial "Destination folder"
}

# Test script handles nonexistent output directory
@test "fails when output dir does not exist" {
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"/nonexistent/path"$'\n'
  assert_failure
  assert_output --partial "Destination folder"
}

# Test script fails when output directory lacks write permissions
@test "fails when output dir is not writable" {
  local readonly_dir="$TEST_ROOT/readonly"
  mkdir -p "$readonly_dir"
  chmod -w "$readonly_dir"
  
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$readonly_dir"$'\n'
  
  assert_failure
  assert_output --partial "not writable"
  
  # Cleanup: restore permissions for teardown
  chmod +w "$readonly_dir"
}

# Test happy flow - script works as expected under normal conditions
@test "processes all JPGs in testdata/images" {
  # Skip if no test images available
  if [ "$JPG_COUNT" -eq 0 ]; then
    skip "No JPG files found in testdata"
  fi
  
  # Run script, mimic user typing two paths and pressing enter ('\n') when prompted
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n' 
  
  # Verify exit code is 0 (success)
  assert_success
  # Check that script output contains these strings
  assert_output --partial "JPG/JPEG files to process"
  assert_output --partial "Starting EXIF extraction"
  assert_output --partial "Exif metadata extraction succeeded"
  assert_output --partial "Output saved here"
  
  # Find generated CSV file(s)
  local csv_file
  # '-print -quit' finds the first match and immediately exits
  csv_file="$(find "$OUTPUT_DIR" -name "pics_metadata_*.csv" -print -quit)"
  
  # Verify CSV exists and is not empty
  assert [ -n "$csv_file" ]  # Variable is not empty (a file was found)        
  assert_file_exist "$csv_file"  # The file path is valid and exists    
  assert [ -s "$csv_file" ]   # File has content (size > 0 bytes)
  
  # Verify CSV has expected headers
  # Read first line
  run head -n1 "$csv_file"
  assert_output --partial "SourceFile"
  assert_output --partial "FileName"
  assert_output --partial "Make"
  assert_output --partial "Model" 
  assert_output --partial "DateTimeOriginal" 
  assert_output --partial "FilmMode" 
  assert_output --partial "GrainEffectSize" 
  assert_output --partial "GrainEffectRoughness" 
  assert_output --partial "ColorChromeEffect" 
  assert_output --partial "ColorChromeFXBlue" 
  assert_output --partial "WhiteBalance" 
  assert_output --partial "WhiteBalanceFineTune" 
  assert_output --partial "DevelopmentDynamicRange" 
  assert_output --partial "HighlightTone" 
  assert_output --partial "ShadowTone" 
  assert_output --partial "Saturation" 
  assert_output --partial "Sharpness" 
  assert_output --partial "NoiseReduction" 
  assert_output --partial "Clarity" 
  assert_output --partial "ColorTemperature" 
  # Example images don't include Keywords yet
  # assert_output --partial "Keywords" 

  # Verify CSV has data rows (at least header + 1 row)
  local row_count
  row_count=$(wc -l < "$csv_file")
  assert [ "$row_count" -gt 1 ]
  
  # Verify row count matches or exceeds JPG count
  # (CSV has header + data rows, so total should be JPG_COUNT + 1)
  assert [ "$row_count" -ge $((JPG_COUNT + 1)) ] # '-ge' means greater than or equal 
}

# Test CSV contains Fujifilm data from real images
@test "CSV contains Fujifilm EXIF data" {
  # Skip if no test images
  if [ "$JPG_COUNT" -eq 0 ]; then
    skip "No JPG files found in testdata"
  fi
  
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
  assert_success
  
  local csv_file
  csv_file="$(find "$OUTPUT_DIR" -name "pics_metadata_*.csv" -print -quit)"
  assert [ -n "$csv_file" ] # Variable is not empty (a file was found)
  
  # Check for Fujifilm-specific data
  run grep -i "FUJIFILM" "$csv_file"
  assert_success
  
  # Check for Fujifilm X-series cameras used to create test images
  run grep -iE "X-Pro|X-T|X-H" "$csv_file"
  assert_success
}
