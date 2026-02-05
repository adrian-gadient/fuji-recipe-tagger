#!/usr/bin/env bash
# ============================================================================
# Bats test suite for add_recipe.sh (keyword tagger script)
# ============================================================================
# Author: Adrian Gadient
# Last updated: January 31, 2026
# Run locally with: bats tests/
# Run in docker: docker compose run --rm bats
# Run with debug output: DEBUG_TESTS=1 bats tests/
#
# What this test suite does:
# - Verifies the keyword tagging script works correctly
# - Tests adding recipe names to photo EXIF Keywords field
# - Uses real JPG files and exiftool for realistic testing
# - Validates that keywords are actually written to photo metadata
# - Tests edge cases like missing files and invalid CSV formats
# ============================================================================

# ============================================================================
# SETUP - Runs before EVERY test
# ============================================================================
# This function prepares a clean testing environment for each test.
# It creates temporary directories, copies test images, and sets up
# the test data files. This ensures each test starts fresh and isolated.
setup() {
  # Load bats helper libraries for advanced assertions
  load 'test_helper/bats-support/load'    # Core support functions
  load 'test_helper/bats-assert/load'     # Assertion functions
  load 'test_helper/bats-file/load'       # File-related assertions

  # Get the directory containing this test file
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  
  # Derive repository root by going up one level from tests/
  REPO_ROOT="$(cd "$DIR/.." && pwd)"
  
  # Add scripts directory to PATH
  PATH="$REPO_ROOT/scripts:$PATH"

  # Create unique temporary directory for this test run
  TEST_ROOT="$(mktemp -d)"
  
  # Define debug directory for persistent test output inspection
  DEBUG_ROOT="$REPO_ROOT/tests/debug_output"
  
  # Path to test images (read-only original files)
  TESTDATA_DIR="$REPO_ROOT/tests/testdata/images"
  
  # Working directory for test images (copies we can modify)
  WORK_DIR="$TEST_ROOT/images"
  
  # Directory for CSV input files
  INPUT_DIR="$TEST_ROOT/input"
  
  # Full path to the script we're testing
  SCRIPT_PATH="$REPO_ROOT/scripts/macOS/add_recipes.sh"

  # Create necessary directories
  mkdir -p "$WORK_DIR"
  mkdir -p "$INPUT_DIR"
  
  # Copy test images to working directory so we can modify them
  # We don't want to modify the original test images
  if [ -d "$TESTDATA_DIR" ]; then
    # Copy all JPG files from testdata to working directory
    find "$TESTDATA_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -exec cp {} "$WORK_DIR/" \;
  fi
  
  # Verify required tools are installed
  if ! command -v exiftool >/dev/null 2>&1; then
    skip "exiftool not installed - install with: brew install exiftool"
  fi
  
  if ! command -v mlr >/dev/null 2>&1; then
    skip "Miller (mlr) not installed - install with: brew install miller"
  fi
  
  # Count available test images
  JPG_COUNT=$(find "$WORK_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | wc -l)
  
  if [ "$JPG_COUNT" -eq 0 ]; then
    skip "No test images found in $TESTDATA_DIR"
  fi
}

# ============================================================================
# TEARDOWN - Runs after EVERY test
# ============================================================================
# Cleans up temporary files and optionally saves debug output.
teardown() {
  if [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ]; then
    # Copy test output to debug directory ONLY if DEBUG_TESTS is set
    # Usage: DEBUG_TESTS=1 bats tests/
    if [ -n "$DEBUG_ROOT" ] && [ -n "$DEBUG_TESTS" ]; then
      mkdir -p "$DEBUG_ROOT"
      rm -rf "$DEBUG_ROOT"/*
      cp -r "$TEST_ROOT"/* "$DEBUG_ROOT/" 2>/dev/null || true
      echo "Test run completed at: $(date)" > "$DEBUG_ROOT/test_timestamp.txt"
      echo "Original temp location: $TEST_ROOT" >> "$DEBUG_ROOT/test_timestamp.txt"
    fi
    
    chmod -R +w "$TEST_ROOT" 2>/dev/null || true
    rm -rf "$TEST_ROOT"
  fi
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Get the first JPG file in the working directory
get_test_image() {
  find "$WORK_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print -quit
}

# Read Keywords field from an image using exiftool
get_image_keywords() {
  local image_path="$1"
  exiftool -Keywords -s3 "$image_path" 2>/dev/null || echo ""
}

# ============================================================================
# TESTS
# ============================================================================

# ----------------------------------------------------------------------------
# Test 1: Basic sanity check
# ----------------------------------------------------------------------------
# Verify the script file exists and has execute permission.
# This is a smoke test - if this fails, nothing else will work.
@test "script exists and is executable" {
  assert_file_exist "$SCRIPT_PATH"
  assert [ -x "$SCRIPT_PATH" ]
}

# ----------------------------------------------------------------------------
# Test 2: Fails with empty CSV path
# ----------------------------------------------------------------------------
# Tests that the script rejects empty input (user just pressing Enter).
# The script should fail with a clear error message.
@test "fails when CSV path is empty" {
  run bash "$SCRIPT_PATH" <<< $'\n'
  
  assert_failure
  assert_output --partial "ERROR: CSV file path is empty"
}

# ----------------------------------------------------------------------------
# Test 3: Fails when CSV file doesn't exist
# ----------------------------------------------------------------------------
# Tests that the script validates file existence before processing.
# Prevents cryptic errors later in the workflow.
@test "fails when CSV file does not exist" {
  run bash "$SCRIPT_PATH" <<< "/nonexistent/file.csv"$'\n'
  
  assert_failure
  assert_output --partial "ERROR: CSV file path is empty or not a file"
}

# ----------------------------------------------------------------------------
# Test 4: Successfully adds recipe keyword to image
# ----------------------------------------------------------------------------
# Tests the core functionality: adding a recipe name to a photo's keywords.
# This uses real exiftool commands on actual JPG files to validate
# that the EXIF metadata is correctly modified.
@test "adds recipe keyword to real JPG file" {
  # Skip if no test images available
  if [ "$JPG_COUNT" -eq 0 ]; then
    skip "No test images available"
  fi
  
  # Get first test image from working directory
  local test_image=$(get_test_image)
  assert [ -n "$test_image" ]
  
  # Get original keywords (if any) before modification
  local original_keywords=$(get_image_keywords "$test_image")
  
  # Create CSV with image path and recipe name
  # This simulates the output from identify_recipes.sh
  cat > "$INPUT_DIR/matched_recipes.csv" << EOF
SourceFile,FileName,filmsim
$test_image,$(basename "$test_image"),McCurry
EOF
  
  # Run the script with the CSV path as input
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR/matched_recipes.csv"$'\n'
  
  # Verify script completed successfully (exit code 0)
  assert_success
  assert_output --partial "✓ Keywords updated successfully"
  
  # Read the keywords from the image after script runs
  local new_keywords=$(get_image_keywords "$test_image")
    
  # Verify that "McCurry" is now in the keywords field
  # Use [[ ]] directly instead of wrapping in assert
  [[ "$new_keywords" == *"McCurry"* ]]
}

# ----------------------------------------------------------------------------
# Test 5: Handles multiple images
# ----------------------------------------------------------------------------
# Tests batch processing of multiple images with different recipes.
# Validates that the script correctly loops through CSV rows and applies
# the correct recipe to each corresponding image.
@test "adds keywords to multiple images" {
  # Need at least 2 images for this test
  if [ "$JPG_COUNT" -lt 2 ]; then
    skip "Need at least 2 test images"
  fi
  
  # Get first two test images
  local images=($(find "$WORK_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | head -n 2))
  local image1="${images[0]}"
  local image2="${images[1]}"
  
  # Create CSV with multiple images and different recipes
  cat > "$INPUT_DIR/matched_recipes.csv" << EOF
SourceFile,FileName,filmsim
$image1,$(basename "$image1"),McCurry
$image2,$(basename "$image2"),Kodachrome
EOF
  
  # Run the script
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR/matched_recipes.csv"$'\n'
  
  # Verify script succeeded
  assert_success
  assert_output --partial "Processing 2 rows"
  
  # Read keywords from both images
  local keywords1=$(get_image_keywords "$image1")
  local keywords2=$(get_image_keywords "$image2")
    
  # Verify each image got its correct recipe
  [[ "$keywords1" == *"McCurry"* ]]
  [[ "$keywords2" == *"Kodachrome"* ]]
}

# ----------------------------------------------------------------------------
# Test 6: Handles quote-wrapped paths
# ----------------------------------------------------------------------------
# When users drag files into Terminal on macOS, paths get wrapped in quotes.
# This test ensures the script correctly strips those quotes before processing.
@test "handles quote-wrapped CSV paths from drag-and-drop" {
  if [ "$JPG_COUNT" -eq 0 ]; then
    skip "No test images available"
  fi
  
  local test_image=$(get_test_image)
  
  cat > "$INPUT_DIR/matched_recipes.csv" << EOF
SourceFile,FileName,filmsim
$test_image,$(basename "$test_image"),TestRecipe
EOF
  
  # Run with quoted path (simulating drag-and-drop behavior)
  # The \" escapes quotes so they're passed literally to the script
  run bash "$SCRIPT_PATH" <<< "\"$INPUT_DIR/matched_recipes.csv\""$'\n'
  
  # Verify script succeeded despite quoted path
  assert_success
  
  # Verify keyword was actually added to the image
  local keywords=$(get_image_keywords "$test_image")
  [[ "$keywords" == *"TestRecipe"* ]]
}

# ----------------------------------------------------------------------------
# Test 7: Handles CSV with FileName column (common format)
# ----------------------------------------------------------------------------
# The output from identify_recipes.sh includes a FileName column.
# This test validates the script correctly extracts only the needed columns
# (SourceFile and filmsim) and ignores the FileName column.
@test "works with CSV containing FileName column" {
  if [ "$JPG_COUNT" -eq 0 ]; then
    skip "No test images available"
  fi
  
  local test_image=$(get_test_image)
  
  # Create CSV with FileName column (script should ignore it using mlr cut)
  cat > "$INPUT_DIR/with_filename.csv" << EOF
SourceFile,FileName,filmsim
$test_image,$(basename "$test_image"),WithFilename
EOF
  
  # Run the script
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR/with_filename.csv"$'\n'
  
  # Verify script succeeded
  assert_success
  assert_output --partial "Using columns: SourceFile, filmsim"
  
  # Verify keyword was added correctly
  local keywords=$(get_image_keywords "$test_image")
  [[ "$keywords" == *"WithFilename"* ]]
}