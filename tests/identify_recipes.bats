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
  # Test metadata CSV with headers and 2 rows
  cat > "$INPUT_DIR/pics_metadata.csv" << 'EOF'
# TODO just added test
SourceFile,FileName,Make,Model,DateTimeOriginal,FilmMode,GrainEffectSize,GrainEffectRoughness,ColorChromeEffect,ColorChromeFXBlue,WhiteBalance,ColorTemperature,WhiteBalanceFineTune,DevelopmentDynamicRange,HighlightTone,ShadowTone,Saturation,Sharpness,NoiseReduction,Clarity
/tests/testdata/images/PRO36627.JPG,PRO36627.JPG,FUJIFILM	X-Pro3	2026:01:28 15:40:32	Classic Chrome	Small	Weak	Strong	Off	Kelvin	5900	Red -20, Blue +80	100	0 (normal)	0 (normal)	+2 (high)	Soft	-2 (weak)	0
EOF

  # Test recipes CSV with matching recipe
  cat > "$INPUT_DIR/recipes.csv" << 'EOF'
# TODO just added test
filmsim	,FilmMode,Deve lopmentDynamicRange,GrainEffectSize,GrainEffectRoughness,ColorChromeEffect,ColorChromeFXBlue,WhiteBalance,ColorTemperature,WhiteBalanceFineTune,HighlightTone,ShadowTone,Saturation,Sharpness,NoiseReduction,Clarity
McCurry,Classic Chrome,100,Small,Weak,Strong,Off,Kelvin,5900,"Red -20, Blue +80",0 (normal), 0 (normal),+2 (high),Soft,-2 (weak),0

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

# # Test Miller dependency check
# @test "fails when Miller (mlr) is missing" {
#   # Temporarily remove Miller from PATH
#   local old_path="$PATH"
#   PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$(which mlr 2>/dev/null || echo "")" | tr '\n' ':' | sed 's/:$//')
  
#   run bash "$SCRIPT_PATH" <<< $'"$TESTDATA_DIR/metadata/test_metadata.csv\n'"$TESTDATA_DIR/recipes/test_recipes.csv\n"'"$OUTPUT_DIR\n'
#   assert_failure
#   assert_output --partial "Miller (mlr) is required"
# }

# # Test fails with empty tags file input
# @test "fails when tags CSV is empty" {
#   # Create empty tags file
#   touch "$TEST_ROOT/empty_tags.csv"
  
#   run bash "$SCRIPT_PATH" <<< $'"$TEST_ROOT/empty_tags.csv\n'"$TESTDATA_DIR/recipes/test_recipes.csv\n"'"$OUTPUT_DIR\n'
#   assert_failure
#   assert_output --partial "Tags CSV is empty or has no header"
# }

# # Test fails with empty recipes file input
# @test "fails when recipes CSV is empty" {
#   # Create empty recipes file
#   touch "$TEST_ROOT/empty_recipes.csv"
  
#   run bash "$SCRIPT_PATH" <<< $'"$TESTDATA_DIR/metadata/test_metadata.csv\n'"$TEST_ROOT/empty_recipes.csv\n"'"$OUTPUT_DIR\n'
#   assert_failure
#   assert_output --partial "Recipes CSV is empty or has no header"
# }

# # Test fails when tags file does not exist
# @test "fails when tags file does not exist" {
#   run bash "$SCRIPT_PATH" <<< $'/nonexistent/tags.csv\n'"$TESTDATA_DIR/recipes/test_recipes.csv\n"'"$OUTPUT_DIR\n'
#   assert_failure
#   assert_output --partial "Tags file not found"
# }

# # Test fails when recipes file does not exist
# @test "fails when recipes file does not exist" {
#   run bash "$SCRIPT_PATH" <<< $'"$TESTDATA_DIR/metadata/test_metadata.csv\n'/nonexistent/recipes.csv\n'"$OUTPUT_DIR\n'
#   assert_failure
#   assert_output --partial "Recipes file not found"
# }

# # Test fails when output folder does not exist
# @test "fails when output folder does not exist" {
#   run bash "$SCRIPT_PATH" <<< $'"$TESTDATA_DIR/metadata/test_metadata.csv\n'"$TESTDATA_DIR/recipes/test_recipes.csv\n'/nonexistent/output\n'
#   assert_failure
#   assert_output --partial "Output folder not found"
# }

# # Test fails when output folder is not writable
# @test "fails when output folder is not writable" {
#   mkdir -p "$TEST_ROOT/readonly"
#   chmod -w "$TEST_ROOT/readonly"
  
#   run bash "$SCRIPT_PATH" <<< $'"$TESTDATA_DIR/metadata/test_metadata.csv\n'"$TESTDATA_DIR/recipes/test_recipes.csv\n'"$TEST_ROOT/readonly\n'
#   assert_failure
#   assert_output --partial "Output folder not writable"
# }

# # Test happy path - successful matching with perfect data
# @test "successfully matches recipes with perfect data" {
#   local tags_file="$TESTDATA_DIR/metadata/test_metadata.csv"
#   local recipes_file="$TESTDATA_DIR/recipes/test_recipes.csv"
  
#   run bash "$SCRIPT_PATH" <<< $'"$tags_file\n'"$recipes_file\n"'"$OUTPUT_DIR\n'
  
#   assert_success
#   assert_output --partial "✓ All paths valid"
#   assert_output --partial "Processing CSVs using Miller"
#   assert_output --partial "List of matched jpgs saved to"
  
#   # Verify output CSV exists
#   local output_csv="$OUTPUT_DIR/matched_recipes.csv"
#   assert_file_exist "$output_csv"
#   assert [ -s "$output_csv" ]
  
#   # Verify output has expected columns
#   run head -n 1 "$output_csv"
#   assert_output --partial "SourceFile,FileName,filmsim"
  
#   # Verify data rows exist (should have 1 perfect match)
#   local row_count=$(wc -l < "$output_csv")
#   assert [ "$row_count" -eq 2 ]  # header + 1 matched row
# }

# # Test handles missing columns in metadata (script should fill with NA)
# @test "handles missing columns in metadata file" {
#   # Create metadata missing some join columns
#   cat > "$TESTDATA_DIR/metadata/missing_cols.csv" << 'EOF'
# SourceFile,FileName,ColorTemperature
# /Photos/img1.jpg,img1.jpg,5500
# EOF
  
#   local tags_file="$TESTDATA_DIR/metadata/missing_cols.csv"
#   local recipes_file="$TESTDATA_DIR/recipes/test_recipes.csv"
  
#   run bash "$SCRIPT_PATH" <<< $'"$tags_file\n'"$recipes_file\n"'"$OUTPUT_DIR\n'
  
#   assert_success
#   assert_output --partial "Columns missing in metadata file"
#   assert_output --partial "Missing columns are added to metadata file and filled with NA"
  
#   local output_csv="$OUTPUT_DIR/matched_recipes.csv"
#   assert_file_exist "$output_csv"
# }

# # Test creates unmatched file when matches are incomplete
# @test "creates unmatched file for incomplete matches" {
#   local tags_file="$TESTDATA_DIR/metadata/test_metadata.csv"
#   local recipes_file="$TESTDATA_DIR/recipes/test_recipes.csv"
  
#   run bash "$SCRIPT_PATH" <<< $'"$tags_file\n'"$recipes_file\n"'"$OUTPUT_DIR\n'
#   assert_success
  
#   # Should create unmatched file for img2.jpg (missing filmsim)
#   local unmatched_csv="$OUTPUT_DIR/unmatched_jpgs.csv"
#   assert_file_exist "$unmatched_csv"
#   run grep "img2.jpg" "$unmatched_csv"
#   assert_success
# }

# # Test processing summary shows correct counts
# @test "processing summary shows correct match counts" {
#   local tags_file="$TESTDATA_DIR/metadata/test_metadata.csv"
#   local recipes_file="$TESTDATA_DIR/recipes/test_recipes.csv"
  
#   run bash "$SCRIPT_PATH" <<< $'"$tags_file\n'"$recipes_file\n"'"$OUTPUT_DIR\n'
#   assert_success
  
#   # Should show 2 input photos, 1 matched
#   assert_output --partial "Number of input photos:    2"
#   assert_output --partial "Recipes successfully matched: 1"
# }

# # Test handles quote-wrapped paths (drag-and-drop from Finder)
# @test "handles quote-wrapped paths from drag-and-drop" {
#   local quoted_tags='"'"$TESTDATA_DIR/metadata/test_metadata.csv"'"'
#   local quoted_recipes='"'"$TESTDATA_DIR/recipes/test_recipes.csv"'"'
#   local quoted_output='"'"$OUTPUT_DIR"'"'
  
#   run bash "$SCRIPT_PATH" <<< "$quoted_tags"$'\n'"$quoted_recipes"$'\n'"$quoted_output"$'\n'
#   assert_success
  
#   local output_csv="$OUTPUT_DIR/matched_recipes.csv"
#   assert_file_exist "$output_csv"
#   assert [ -s "$output_csv" ]
# }

# # Test warns about large files (over 30MB)
# @test "warns about large input files" {
#   # Create large dummy file (>30MB)
#   local large_file="$TEST_ROOT/large.csv"
#   head -n1 "$TESTDATA_DIR/metadata/test_metadata.csv" > "$large_file"
#   # Add enough dummy data to exceed 30MB
#   for i in {1..100000}; do
#     echo "/Photos/img$i.jpg,img$i.jpg,Classic Chrome,Classic,Standard,Weak,Weak,Weak,Weak,5500,0,-2,-1,0,0,Standard,Medium" >> "$large_file"
#   done
  
#   run bash "$SCRIPT_PATH" <<< $'"$large_file\n'"$TESTDATA_DIR/recipes/test_recipes.csv\n"'"$OUTPUT_DIR\n'
#   assert_success
#   assert_output --partial "File $large_file is large"
# }
