#!/usr/bin/env bash
# Bats test suite for film recipe matching script
# Author: Adrian Gadient
# Last updated: January 28, 2026
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
  
  # Define input dire inside temp folder
  INPUT_DIR="$TEST_ROOT/input"
  
  # Define output dir inside temp folder
  OUTPUT_DIR="$TEST_ROOT/output"
  
  # Full path to script under test
  SCRIPT_PATH="$REPO_ROOT/scripts/macOS/identify_recipes.sh"

  # Create input directory
  mkdir -p "$INPUT_DIR"

  # Create output directory
  mkdir -p "$OUTPUT_DIR"
  
  # Create minimal test CSV files
  create_test_files
  
  # Verify Miller is available (required by script)
  if ! command -v mlr >/dev/null 2>&1; then
    skip "Miller (mlr) not installed - install with: brew install miller"
  fi
}

# Create minimal test CSV files for consistent testing
create_test_files() {
  # Test metadata CSV with headers and 1 data row
  cat > "$INPUT_DIR/pics_metadata.csv" << 'EOF'
SourceFile,FileName,Make,Model,DateTimeOriginal,FilmMode,GrainEffectSize,GrainEffectRoughness,ColorChromeEffect,ColorChromeFXBlue,WhiteBalance,ColorTemperature,WhiteBalanceFineTune,DevelopmentDynamicRange,HighlightTone,ShadowTone,Saturation,Sharpness,NoiseReduction,Clarity
/tests/testdata/images/PRO36627.JPG,PRO36627.JPG,FUJIFILM,X-Pro3,2026:01:28 15:40:32,Classic Chrome,Small,Weak,Strong,Off,Kelvin,5900,"Red -20, Blue +80",100,0 (normal),0 (normal),+2 (high),Soft,-2 (weak),0
EOF

  # Test recipes CSV with matching recipe
  cat > "$INPUT_DIR/recipes.csv" << 'EOF'
filmsim,FilmMode,DevelopmentDynamicRange,GrainEffectSize,GrainEffectRoughness,ColorChromeEffect,ColorChromeFXBlue,WhiteBalance,ColorTemperature,WhiteBalanceFineTune,HighlightTone,ShadowTone,Saturation,Sharpness,NoiseReduction,Clarity
McCurry,Classic Chrome,100,Small,Weak,Strong,Off,Kelvin,5900,"Red -20, Blue +80",0 (normal),0 (normal),+2 (high),Soft,-2 (weak),0
EOF
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
  assert [ -x "$SCRIPT_PATH" ]
}

@test "successfully matches recipes with perfect data" {
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR/pics_metadata.csv"$'\n'"$INPUT_DIR/recipes.csv"$'\n'"$OUTPUT_DIR"$'\n'
  
  assert_success
  assert_output --partial "✓ All paths valid"
  
  # Verify main output exists and has data
  assert_file_exist "$OUTPUT_DIR/matched_recipes.csv"
  assert [ -s "$OUTPUT_DIR/matched_recipes.csv" ]
  
  # Verify header structure
  run head -n 1 "$OUTPUT_DIR/matched_recipes.csv"
  assert_output --partial "SourceFile,FileName,filmsim"
}

@test "handles quote-wrapped paths from drag-and-drop" {
  run bash "$SCRIPT_PATH" <<< "\"$INPUT_DIR/pics_metadata.csv\""$'\n'"\"$INPUT_DIR/recipes.csv\""$'\n'"\"$OUTPUT_DIR\""$'\n'
  assert_success
  assert_file_exist "$OUTPUT_DIR/matched_recipes.csv"
}

@test "handles missing columns in metadata file" {
  cat > "$INPUT_DIR/minimal_metadata.csv" << 'EOF'
SourceFile,FileName,ColorTemperature
/Photos/img1.jpg,img1.jpg,5500
EOF
  
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR/minimal_metadata.csv"$'\n'"$INPUT_DIR/recipes.csv"$'\n'"$OUTPUT_DIR"$'\n'
  
  assert_success
  assert_output --partial "Columns missing in metadata file"
  assert_output --partial "Missing columns are added"
}