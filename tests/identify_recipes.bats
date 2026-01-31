#!/usr/bin/env bash
# ============================================================================
# Bats test suite for film recipe matching script
# ============================================================================
# Author: Adrian Gadient
# Last updated: January 28, 2026
# Run with: bats tests/
#
# What this test suite does:
# - Verifies the recipe matching script works correctly
# - Tests edge cases like missing columns and quoted paths
# - Runs in isolated temporary directories to avoid conflicts
# - Ensures output files are created with correct structure
# - Copies test output to tests/debug_output/ for inspection

# ============================================================================

# ============================================================================
# SETUP - Runs before EVERY test
# ============================================================================
# This function prepares a clean testing environment for each test.
# It creates temporary directories, loads helper libraries, and sets up
# the test data files. This ensures each test starts fresh and isolated.
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
  
  # Define debug directory for persistent test output inspection
  # This directory will contain a copy of the last test run's output
  DEBUG_ROOT="$REPO_ROOT/tests/debug_output"
  
  # Define input directory inside temp folder
  # This will hold our test CSV files (metadata and recipes)
  INPUT_DIR="$TEST_ROOT/input"
  
  # Define output directory inside temp folder
  # This is where the script will write its results
  OUTPUT_DIR="$TEST_ROOT/output"
  
  # Store full path to the script we're testing
  # This makes it easy to reference the script in all our tests
  SCRIPT_PATH="$REPO_ROOT/scripts/macOS/identify_recipes.sh"

  # Create the input directory structure
  mkdir -p "$INPUT_DIR"

  # Create the output directory structure
  mkdir -p "$OUTPUT_DIR"
  
  # Create minimal test CSV files with sample data
  # This function is defined below and creates realistic test data
  create_test_files
  
  # Verify Miller (mlr) is installed - it's required by script
  # If not installed, skip all tests with a helpful message
  if ! command -v mlr >/dev/null 2>&1; then
    skip "Miller (mlr) not installed - install with: brew install miller"
  fi
}

# ============================================================================
# TEST DATA CREATION
# ============================================================================
# Creates minimal but realistic CSV files for testing (meta data and recipe).
# These files contain just enough data to test the matching logic without
# being overly complex. The metadata matches the recipe so we can verify
# successful matching.
create_test_files() {
  # Create test metadata CSV file
  # This represents the photo metadata exported from camera (via exiftool)
  # Contains one photo with all the settings needed to match a recipe
  cat > "$INPUT_DIR/pics_metadata.csv" << 'EOF'
SourceFile,FileName,Make,Model,DateTimeOriginal,FilmMode,GrainEffectSize,GrainEffectRoughness,ColorChromeEffect,ColorChromeFXBlue,WhiteBalance,ColorTemperature,WhiteBalanceFineTune,DevelopmentDynamicRange,HighlightTone,ShadowTone,Saturation,Sharpness,NoiseReduction,Clarity
/tests/testdata/images/PRO36627.JPG,PRO36627.JPG,FUJIFILM,X-Pro3,2026:01:28 15:40:32,Classic Chrome,Small,Weak,Strong,Off,Kelvin,5900,"Red -20, Blue +80",100,0 (normal),0 (normal),+2 (high),Soft,-2 (weak),0
EOF

  # Create test recipes CSV file
  # This contains one recipe ("McCurry") that matches the photo above
  # All the camera settings match between the metadata and this recipe
  cat > "$INPUT_DIR/recipes.csv" << 'EOF'
filmsim,FilmMode,DevelopmentDynamicRange,GrainEffectSize,GrainEffectRoughness,ColorChromeEffect,ColorChromeFXBlue,WhiteBalance,ColorTemperature,WhiteBalanceFineTune,HighlightTone,ShadowTone,Saturation,Sharpness,NoiseReduction,Clarity
McCurry,Classic Chrome,100,Small,Weak,Strong,Off,Kelvin,5900,"Red -20, Blue +80",0 (normal),0 (normal),+2 (high),Soft,-2 (weak),0
EOF
}

# ============================================================================
# TEARDOWN - Runs after EVERY test
# ============================================================================
# This function cleans up after each test by removing temporary files.
# If folder with output should be kept for debugging run as follows:
# DEBUG_TESTS=1 bats tests/
# This will keep the output from the last test

teardown() {
  # Only proceed if TEST_ROOT was set and exists
  if [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ]; then
    # Copy test output to debug directory ONLY if DEBUG_TESTS is set
    # Usage: DEBUG_TESTS=1 bats tests/
    if [ -n "$DEBUG_ROOT" ] && [ -n "$DEBUG_TESTS" ]; then
      # Create debug directory if it doesn't exist
      mkdir -p "$DEBUG_ROOT"
      
      # Clear previous debug output to avoid confusion
      rm -rf "$DEBUG_ROOT"/*
      
      # Copy entire test output structure to debug directory
      # The '2>/dev/null || true' prevents errors if nothing to copy
      cp -r "$TEST_ROOT"/* "$DEBUG_ROOT/" 2>/dev/null || true
      
      # Create a timestamp file so you know when this was generated
      echo "Test run completed at: $(date)" > "$DEBUG_ROOT/test_timestamp.txt"
      echo "Original temp location: $TEST_ROOT" >> "$DEBUG_ROOT/test_timestamp.txt"
    fi
    
    # Make sure all files are writable before deleting
    # The '|| true' ensures this doesn't fail if some files are already writable
    chmod -R +w "$TEST_ROOT" 2>/dev/null || true
    
    # Remove entire temporary directory tree
    rm -rf "$TEST_ROOT"
  fi
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
  # Check file exists
  assert_file_exist "$SCRIPT_PATH"
  # Check file has execute permission (can be run)
  assert [ -x "$SCRIPT_PATH" ]
}


# ----------------------------------------------------------------------------
# Test 2: Handles macOS drag-and-drop behavior
# ----------------------------------------------------------------------------
# When users drag files into Terminal on macOS, paths often get wrapped in quotes.
# This test ensures the script correctly strips those quotes before processing.
# Example: "/path/to/file.csv" should be treated as /path/to/file.csv
@test "handles quote-wrapped paths from drag-and-drop" {
  # Run script with paths wrapped in double quotes (simulating drag-and-drop)
  # The \" escapes the quotes so they're passed literally to the script
  run bash "$SCRIPT_PATH" <<< "\"$INPUT_DIR/pics_metadata.csv\""$'\n'"\"$INPUT_DIR/recipes.csv\""$'\n'"\"$OUTPUT_DIR\""$'\n'
  
  # Verify script succeeded despite the quoted paths
  assert_success
  
  # Verify output was still created correctly
  assert_file_exist "$OUTPUT_DIR/matched_recipes.csv"
}

# ----------------------------------------------------------------------------
# Test 3: Graceful handling of incomplete data
# ----------------------------------------------------------------------------
# Tests that the script handles metadata files missing some columns.
# The script should automatically add missing columns and fill them with "NA".
# This is a common scenario when using different camera models or export settings.
@test "handles missing columns in metadata file" {
  # Create a minimal metadata file with only 3 columns instead of all 20
  # This simulates incomplete metadata export
  cat > "$INPUT_DIR/minimal_metadata.csv" << 'EOF'
SourceFile,FileName,ColorTemperature
/Photos/img1.jpg,img1.jpg,5500
EOF
  
  # Run script with the incomplete metadata file
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR/minimal_metadata.csv"$'\n'"$INPUT_DIR/recipes.csv"$'\n'"$OUTPUT_DIR"$'\n'
  
  # Script should still succeed (not crash)
  assert_success
  
  # Verify script detected and warned about missing columns
  assert_output --partial "Columns missing in metadata file"
  
  # Verify script automatically handled the issue
  assert_output --partial "Missing columns are added"
}


# ----------------------------------------------------------------------------
# Test 4: Happy path - everything works perfectly
# ----------------------------------------------------------------------------
# Tests the main workflow with perfect data where everything should match.
# This is the most important test - if this passes, the core logic works.
# The script expects 3 inputs via stdin: metadata file, recipes file, output dir
@test "successfully matches recipes with perfect data" {
  # Run the script and simulate user typing three file paths
  # The <<< syntax feeds input to stdin, $'\n' represents pressing Enter
  # Format: metadata_path [ENTER] recipes_path [ENTER] output_path [ENTER]
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR/pics_metadata.csv"$'\n'"$INPUT_DIR/recipes.csv"$'\n'"$OUTPUT_DIR"$'\n'
  
  # Verify the script completed successfully (exit code 0)
  assert_success
  
  # Verify the script printed the expected validation message
  assert_output --partial "✓ All paths valid"
  
  # Verify main output file was created and has data
  assert_file_exist "$OUTPUT_DIR/matched_recipes.csv"
  # The -s flag checks that file is not empty (size > 0)
  assert [ -s "$OUTPUT_DIR/matched_recipes.csv" ]
  
  # Verify the output CSV has the correct header structure
  # We expect three columns: SourceFile, FileName, and filmsim (recipe name)
  run head -n 1 "$OUTPUT_DIR/matched_recipes.csv"
  assert_output --partial "SourceFile,FileName,filmsim"
}

# ----------------------------------------------------------------------------
# Test 5: Validates matching logic
# ----------------------------------------------------------------------------
@test "does not match when recipe settings differ" {
  # Create metadata with TWO photos:
  # 1. One that matches the recipe (PRO36627)
  # 2. One that doesn't match (PRO36628 with different FilmMode)
  cat > "$INPUT_DIR/mixed_metadata.csv" << 'EOF'
SourceFile,FileName,Make,Model,DateTimeOriginal,FilmMode,GrainEffectSize,GrainEffectRoughness,ColorChromeEffect,ColorChromeFXBlue,WhiteBalance,ColorTemperature,WhiteBalanceFineTune,DevelopmentDynamicRange,HighlightTone,ShadowTone,Saturation,Sharpness,NoiseReduction,Clarity
/tests/testdata/images/PRO36627.JPG,PRO36627.JPG,FUJIFILM,X-Pro3,2026:01:28 15:40:32,Classic Chrome,Small,Weak,Strong,Off,Kelvin,5900,"Red -20, Blue +80",100,0 (normal),0 (normal),+2 (high),Soft,-2 (weak),0
/tests/testdata/images/PRO36628.JPG,PRO36628.JPG,FUJIFILM,X-Pro3,2026:01:28 16:00:00,PRO Neg. Std,Small,Weak,Strong,Off,Kelvin,5900,"Red -20, Blue +80",100,0 (normal),0 (normal),+2 (high),Soft,-2 (weak),0
EOF
  
  # Run script with mixed metadata (one match, one non-match)
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR/mixed_metadata.csv"$'\n'"$INPUT_DIR/recipes.csv"$'\n'"$OUTPUT_DIR"$'\n'
  
  # Script should still succeed (not crash)
  assert_success
  
  # Verify matched output file was created
  assert_file_exist "$OUTPUT_DIR/matched_recipes.csv"
  
  # Verify matched output has header + 1 matched row (2 lines total)
  local matched_count=$(wc -l < "$OUTPUT_DIR/matched_recipes.csv")
  assert [ "$matched_count" -eq 2 ]
  
  # Verify the matching photo is in the output
  run grep "PRO36627.JPG" "$OUTPUT_DIR/matched_recipes.csv"
  assert_success
  
  # Verify unmatched file was created
  assert_file_exist "$OUTPUT_DIR/unmatched_jpgs.csv"
  
  # Verify the non-matching photo is in the unmatched file
  run grep "PRO36628.JPG" "$OUTPUT_DIR/unmatched_jpgs.csv"
  assert_success
  
  # Verify the matching photo is NOT in the unmatched file
  run grep "PRO36627.JPG" "$OUTPUT_DIR/unmatched_jpgs.csv"
  assert_failure
}