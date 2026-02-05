#!/usr/bin/env bash
# ============================================================================
# Bats test suite for scripts/macOS/get_exif.sh
# ============================================================================
# Author: Adrian Gadient
# Last updated: 27 January 2026
# Run locally with: bats tests/
# Run in docker: docker compose run --rm bats
# 
# What this test suite does:
# - Verifies the EXIF extraction script works correctly
# - Tests input validation (missing directories, empty folders, permissions)
# - Ensures CSV output is created with correct structure and data
# - Validates that Fujifilm camera metadata is properly extracted
# - Uses real test images in tests/testdata/images/ directory
# ============================================================================

# ============================================================================
# SETUP - Runs before EVERY test
# ============================================================================
# This function prepares a clean testing environment for each test.
# It loads helper libraries, sets up directories, and validates that
# test images exist. Each test gets its own isolated temporary directory.
setup() {
  
  # Load bats helper libraries for advanced assertions
  # These provide functions like assert_success, assert_output, assert_file_exist
  load 'test_helper/bats-support/load'    # Core support functions
  load 'test_helper/bats-assert/load'     # Assertion functions (assert_success, etc.)
  load 'test_helper/bats-file/load'       # File-related assertions

  # Get the directory containing this test file
  # This works even if the test is run from a different directory
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  
  # Derive repository root by going up one level from tests/ directory
  # Example: if DIR is /repo/tests, REPO_ROOT becomes /repo
  REPO_ROOT="$(cd "$DIR/.." && pwd)"
  
  # Add scripts directory to PATH so we can run our script by name
  # This allows us to find the script without specifying full path every time
  PATH="$REPO_ROOT/scripts:$PATH"

  # Create unique temporary directory for this test run
  # Using mktemp ensures a unique name and prevents conflicts
  # This prevents test interference when running multiple tests in parallel
  TEST_ROOT="$(mktemp -d)"
  
  # Point to the directory containing test images (JPG files)
  # These are real Fujifilm photos used to validate EXIF extraction
  INPUT_DIR="$REPO_ROOT/tests/testdata/images"
  
  # Define output directory inside temp folder
  # This is where the script will write the CSV file with extracted metadata
  OUTPUT_DIR="$TEST_ROOT/output"
  
  # Store full path to the script we're testing
  # This makes it easy to reference the script in all our tests
  SCRIPT_PATH="$REPO_ROOT/scripts/macOS/get_exif.sh"
  
  # Create the output directory structure
  mkdir -p "$OUTPUT_DIR"
  
  # Verify that testdata/images directory exists and contains test photos
  # Without test images, most tests cannot run
  if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: $INPUT_DIR not found - create tests/testdata/images/ with JPGs"
    return 1
  fi
  
  # Count how many JPG files are available for testing
  # We use this count later to verify all images were processed
  # The find command searches for files ending in .jpg or .jpeg (case-insensitive)
  JPG_COUNT=$(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | wc -l)
  
  # Warn if no test images found (some tests will be skipped)
  if [ "$JPG_COUNT" -eq 0 ]; then
    echo "Warning: No JPG files found in $INPUT_DIR"
  fi
}

# ============================================================================
# TEARDOWN - Runs after EVERY test
# ============================================================================
# This function cleans up after each test by removing temporary files.
# This keeps the test environment clean and prevents disk space issues.
teardown() {
  # Only clean up if TEST_ROOT was set and exists
  if [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ]; then
    # Make sure all files are writable before deleting
    # The '|| true' ensures this doesn't fail if some files are already writable
    chmod -R +w "$TEST_ROOT" 2>/dev/null || true
    # Remove entire temporary directory tree
    rm -rf "$TEST_ROOT"
  fi
}

# ============================================================================
# TESTS - Input Validation
# ============================================================================
# These tests verify the script properly validates user input and fails
# gracefully with helpful error messages when given invalid paths.

# ----------------------------------------------------------------------------
# Test 1: Basic sanity check
# ----------------------------------------------------------------------------
# Verify the script file exists and has execute permission.
# This is a smoke test - if this fails, nothing else will work.
@test "script exists and is executable" {
  # Check file exists
  assert_file_exist "$SCRIPT_PATH"
  # Check file has execute permission (can be run)
  assert_file_executable "$SCRIPT_PATH"
}

# ----------------------------------------------------------------------------
# Test 2: Empty input directory
# ----------------------------------------------------------------------------
# Test that script rejects when user presses Enter without typing a path.
# This simulates user accidentally pressing Enter at the first prompt.
@test "fails when input dir is empty" {
  # Simulate user entering empty input directory (just pressing Enter)
  # First $'\n' = empty input, second $'\n' = output directory prompt
  run bash "$SCRIPT_PATH" <<< $'\n'"$OUTPUT_DIR"$'\n'
  
  # Script should fail (non-zero exit code)
  assert_failure
  
  # Error message should mention "Input path"
  assert_output --partial "Input path"
}

# ----------------------------------------------------------------------------
# Test 3: Nonexistent input directory
# ----------------------------------------------------------------------------
# Test that script catches when user provides a path that doesn't exist.
# This is a common user error (typo, wrong path, etc.)
@test "fails when input dir does not exist" {
  # Simulate user typing a path that doesn't exist on the filesystem
  run bash "$SCRIPT_PATH" <<< "/nonexistent/path"$'\n'"$OUTPUT_DIR"$'\n'
  
  # Script should fail with error message
  assert_failure
  assert_output --partial "Input path"
}

# ----------------------------------------------------------------------------
# Test 4: Empty directory (no JPG files)
# ----------------------------------------------------------------------------
# Test that script detects when input directory has no JPG files to process.
# User might accidentally select wrong folder or a folder with only RAW files.
@test "fails when no JPG files found in input directory" {
  # Create an empty directory (no files inside)
  local empty_dir="$TEST_ROOT/empty_images"
  mkdir -p "$empty_dir"
  
  # Run script pointing to empty directory
  run bash "$SCRIPT_PATH" <<< "$empty_dir"$'\n'"$OUTPUT_DIR"$'\n'
  
  # Should fail because there's nothing to process
  assert_failure
  assert_output --partial "No JPG"
}

# ----------------------------------------------------------------------------
# Test 5: Empty output directory
# ----------------------------------------------------------------------------
# Test that script rejects when user doesn't provide output directory.
# This simulates user pressing Enter at the second prompt without typing.
@test "fails when output dir is empty" {
  # First input = valid input dir, second input = empty (just Enter key)
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n\n'
  
  # Should fail with helpful message about destination folder
  assert_failure
  assert_output --partial "Destination folder"
}

# ----------------------------------------------------------------------------
# Test 6: Nonexistent output directory
# ----------------------------------------------------------------------------
# Test that script catches when output directory doesn't exist.
# User might typo the path or forget to create the folder first.
@test "fails when output dir does not exist" {
  # Provide valid input dir but invalid output dir
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"/nonexistent/path"$'\n'
  
  # Should fail with error about destination folder
  assert_failure
  assert_output --partial "Destination folder"
}

# ----------------------------------------------------------------------------
# Test 7: Output directory not writable
# ----------------------------------------------------------------------------
# Test that script detects permission issues before attempting to write.
# This prevents cryptic errors later during CSV file creation.
@test "fails when output dir is not writable" {
  if [ -f /.dockerenv ]; then
  skip "Permission test unreliable in Docker (runs as root)"
fi

  # Create a directory but remove write permissions
  local readonly_dir="$TEST_ROOT/readonly"
  mkdir -p "$readonly_dir"
  chmod -w "$readonly_dir"  # Remove write permission
  
  # Try to use read-only directory as output location
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$readonly_dir"$'\n'
  
  # Should fail before processing any files
  assert_failure
  assert_output --partial "not writable"
  
  # Cleanup: restore write permissions so teardown can delete the directory
  chmod +w "$readonly_dir"
}

# ============================================================================
# TESTS - Functionality
# ============================================================================
# These tests verify the script's core functionality: extracting EXIF data
# from JPG files and creating a properly formatted CSV output.

# ----------------------------------------------------------------------------
# Test 8: Happy path - successful EXIF extraction
# ----------------------------------------------------------------------------
# This is the main test that validates the entire workflow works correctly.
# It processes real JPG files and verifies the CSV output is complete and correct.
@test "processes all JPGs in testdata/images" {
  # Skip this test if no test images are available
  # This prevents false failures when test environment isn't fully set up
  if [ "$JPG_COUNT" -eq 0 ]; then
    skip "No JPG files found in testdata"
  fi
  
  # Run script and simulate user entering two paths:
  # 1st prompt: input directory with JPG files
  # 2nd prompt: output directory for CSV file
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n' 
  
  # Verify script completed successfully (exit code 0)
  assert_success
  
  # Check that script printed expected progress messages
  # These messages indicate the script is working through its workflow
  assert_output --partial "JPG/JPEG files to process"
  assert_output --partial "Starting EXIF extraction"
  assert_output --partial "Exif metadata extraction succeeded"
  assert_output --partial "Output saved here"
  
  # Find the generated CSV file
  # Script names files like "pics_metadata_20260127_143022.csv"
  local csv_file
  # '-print -quit' finds the first match and immediately exits (faster)
  csv_file="$(find "$OUTPUT_DIR" -name "pics_metadata_*.csv" -print -quit)"
  
  # Verify CSV file was created and has content
  assert [ -n "$csv_file" ]        # Variable is not empty (a file was found)
  assert_file_exist "$csv_file"    # The file path is valid and exists
  assert [ -s "$csv_file" ]        # File has content (size > 0 bytes)
  
  # Verify CSV has all expected column headers
  # These are the EXIF fields we expect to extract from Fujifilm cameras
  # Read first line of CSV (the header row)
  run head -n1 "$csv_file"
  
  # Check for essential metadata columns
  assert_output --partial "SourceFile"       # Full path to original image
  assert_output --partial "FileName"         # Just the filename
  assert_output --partial "Make"             # Camera manufacturer (e.g., FUJIFILM)
  assert_output --partial "Model"            # Camera model (e.g., X-Pro3)
  assert_output --partial "DateTimeOriginal" # When photo was taken
  
  # Check for Fujifilm film simulation settings
  assert_output --partial "FilmMode"         # Film simulation (e.g., Classic Chrome)
  assert_output --partial "GrainEffectSize"  # Grain effect intensity
  assert_output --partial "GrainEffectRoughness" # Grain texture
  assert_output --partial "ColorChromeEffect"    # Color chrome setting
  assert_output --partial "ColorChromeFXBlue"    # Blue tone adjustment
  
  # Check for white balance and color settings
  assert_output --partial "WhiteBalance"         # WB mode (Auto, Daylight, etc.)
  assert_output --partial "WhiteBalanceFineTune" # Fine-tune adjustments
  assert_output --partial "ColorTemperature"     # Kelvin temperature
  
  # Check for exposure and tone settings
  assert_output --partial "DevelopmentDynamicRange" # Dynamic range setting
  assert_output --partial "HighlightTone"           # Highlight adjustment
  assert_output --partial "ShadowTone"              # Shadow adjustment
  
  # Check for image processing settings
  assert_output --partial "Saturation"    # Color intensity
  assert_output --partial "Sharpness"     # Sharpness level
  assert_output --partial "NoiseReduction" # NR setting
  assert_output --partial "Clarity"       # Clarity adjustment
  
  # Note: Example images don't include Keywords field yet
  # Uncomment when test images include keyword metadata:
  # assert_output --partial "Keywords"
  
  # Verify CSV has data rows (not just a header)
  # Count total lines in file
  local row_count
  row_count=$(wc -l < "$csv_file")
  
  # Must have at least 2 lines (header + 1 data row)
  assert [ "$row_count" -gt 1 ]
  
  # Verify number of data rows matches or exceeds number of JPG files
  # CSV structure: 1 header row + N data rows (one per JPG)
  # So total rows should be JPG_COUNT + 1
  # Using -ge (greater than or equal) allows for edge cases
  assert [ "$row_count" -ge $((JPG_COUNT + 1)) ]
}

# ----------------------------------------------------------------------------
# Test 9: Verify Fujifilm-specific EXIF data
# ----------------------------------------------------------------------------
# This test specifically checks that Fujifilm camera metadata is present.
# It validates that the extraction is working for the target camera brand.
@test "CSV contains Fujifilm EXIF data" {
  # Skip if no test images available
  if [ "$JPG_COUNT" -eq 0 ]; then
    skip "No JPG files found in testdata"
  fi
  
  # Run the script to generate CSV
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
  assert_success
  
  # Find generated CSV file
  local csv_file
  csv_file="$(find "$OUTPUT_DIR" -name "pics_metadata_*.csv" -print -quit)"
  assert [ -n "$csv_file" ]  # Verify file was found
  
  # Check that CSV contains "FUJIFILM" in the Make column
  # Using grep -i for case-insensitive search
  run grep -i "FUJIFILM" "$csv_file"
  assert_success  # grep returns 0 if pattern found, non-zero if not
  
  # Check for specific Fujifilm X-series camera models
  # These are the cameras used to create our test images
  # -E enables extended regex, allowing | (OR) operator
  run grep -iE "X-Pro|X-T|X-H" "$csv_file"
  assert_success  # Should find at least one X-series model name
}