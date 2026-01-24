#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests}"
  TEST_ROOT="$(mktemp -d)"
  
  REAL_JPG_SOURCE="$REPO_ROOT/tests/testdata/images/PRO34551.jpg"
  INPUT_DIR="$TEST_ROOT/input"
  OUTPUT_DIR="$TEST_ROOT/output"
  SCRIPT_PATH="$REPO_ROOT/scripts/macOS/get_exif.sh"
  
  mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"
  cp "$REAL_JPG_SOURCE" "$INPUT_DIR/real_sample.jpg"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

bats_test_function --description script\ exists\ and\ is\ executable  --tags "" --tags "" -- test_script_exists_and_is_executable;test_script_exists_and_is_executable() { 
  [ -f "$SCRIPT_PATH" ]
  [ -x "$SCRIPT_PATH" ]
}

bats_test_function --description fails\ when\ input\ dir\ is\ empty  --tags "" --tags "" -- test_fails_when_input_dir_is_empty;test_fails_when_input_dir_is_empty() { 
  run bash "$SCRIPT_PATH" <<< $'\n'"$OUTPUT_DIR"$'\n'
  
  assert_failure 1
  assert_output --partial "Input path is empty or not a directory"
}

bats_test_function --description fails\ when\ input\ dir\ does\ not\ exist  --tags "" --tags "" -- test_fails_when_input_dir_does_not_exist;test_fails_when_input_dir_does_not_exist() { 
  run bash "$SCRIPT_PATH" <<< "/nonexistent/path"$'\n'"$OUTPUT_DIR"$'\n'
  
  assert_failure 1
  assert_output --partial "Input path is empty or not a directory"
}

bats_test_function --description fails\ when\ output\ dir\ is\ empty  --tags "" --tags "" -- test_fails_when_output_dir_is_empty;test_fails_when_output_dir_is_empty() { 
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n\n'
  
  assert_failure 2
  assert_output --partial "Destination folder is empty or not a directory"
}

bats_test_function --description fails\ when\ output\ dir\ does\ not\ exist  --tags "" --tags "" -- test_fails_when_output_dir_does_not_exist;test_fails_when_output_dir_does_not_exist() { 
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"/nonexistent/path"$'\n'
  
  assert_failure 2
  assert_output --partial "Destination folder is empty or not a directory"
}

bats_test_function --description fails\ when\ output\ dir\ is\ not\ writable  --tags "" --tags "" -- test_fails_when_output_dir_is_not_writable;test_fails_when_output_dir_is_not_writable() { 
  local readonly_dir="$TEST_ROOT/readonly"
  mkdir -p "$readonly_dir"
  chmod -w "$readonly_dir"
  
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$readonly_dir"$'\n'
  
  assert_failure 3
  assert_output --partial "Destination folder is not writable"
  
  chmod +w "$readonly_dir"
}

bats_test_function --description fails\ when\ no\ JPG\ files\ found  --tags "" --tags "" -- test_fails_when_no_JPG_files_found;test_fails_when_no_JPG_files_found() { 
  local empty_dir="$TEST_ROOT/empty"
  mkdir -p "$empty_dir"
  
  run bash "$SCRIPT_PATH" <<< "$empty_dir"$'\n'"$OUTPUT_DIR"$'\n'
  
  assert_failure 5
  assert_output --partial "No JPG/JPEG files found"
}

bats_test_function --description creates\ CSV\ with\ EXIF\ data\ from\ real\ JPG  --tags "" --tags "" -- test_creates_CSV_with_EXIF_data_from_real_JPG;test_creates_CSV_with_EXIF_data_from_real_JPG() { 
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
  
  assert_success
  assert_output --partial "JPG/JPEG files to process"
  assert_output --partial "Starting EXIF extraction"
  assert_output --partial "Exif metadata extraction succeeded"
  assert_output --partial "Output saved here"
  
  local csv_file
  csv_file="$(find "$OUTPUT_DIR" -name "pics_metadata_*.csv" | head -n1)"
  
  [ -n "$csv_file" ]
  [ -f "$csv_file" ]
  [ -s "$csv_file" ]
}

bats_test_function --description CSV\ contains\ expected\ headers  --tags "" --tags "" -- test_CSV_contains_expected_headers;test_CSV_contains_expected_headers() { 
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
  assert_success
  
  local csv_file
  csv_file="$(find "$OUTPUT_DIR" -name "pics_metadata_*.csv" | head -n1)"
  
  run head -n1 "$csv_file"
  assert_output --partial "SourceFile"
  assert_output --partial "FileName"
  assert_output --partial "Make"
  assert_output --partial "Model"
  assert_output --partial "DateTimeOriginal"
}

bats_test_function --description CSV\ contains\ FUJIFILM\ camera\ data  --tags "" --tags "" -- test_CSV_contains_FUJIFILM_camera_data;test_CSV_contains_FUJIFILM_camera_data() { 
  run bash "$SCRIPT_PATH" <<< "$INPUT_DIR"$'\n'"$OUTPUT_DIR"$'\n'
  assert_success
  
  local csv_file
  csv_file="$(find "$OUTPUT_DIR" -name "pics_metadata_*.csv" | head -n1)"
  
  run grep -i "FUJIFILM" "$csv_file"
  assert_success
  
  run grep "real_sample.jpg" "$csv_file"
  assert_success
}
