#!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests}"
  script_path="$REPO_ROOT/scripts/macOS/get_exif.sh"
  [ -f "$script_path" ] || fail "Script not found: $script_path"
  
  TEST_ROOT="$(mktemp -d)"
  INPUT_DIR="$TEST_ROOT/testdata/images"
  OUTPUT_DIR="$TEST_ROOT/testdata/output"
  mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "script exists and is executable" {
  [ -x "$script_path" ]
}

@test "fails with invalid input directory" {
  run bash -c "printf 'invalid-dir\n/tmp\n' | $script_path"
  assert_failure 1
  assert_output --partial "Input path is empty or not a directory"
}

@test "fails with invalid output directory" {
  run bash -c "printf '/tmp\ninvalid-dir\n' | $script_path"
  assert_failure 2
  assert_output --partial "Destination folder is empty or not a directory"
}

@test "processes JPG files and creates CSV (mocked)" {
  # Create test JPG files
  touch "$INPUT_DIR"/{test1.jpg,test2.jpg}
  
  # Mock exiftool - MUST match exact tags script requests
  cat > "$TEST_ROOT/exiftool" << 'EOF'
#!/bin/bash
cat << 'CSV'
SourceFile,FileName,Make,Model,DateTimeOriginal
'$INPUT_DIR/test1.jpg',test1.jpg,Canon,EOS 5D,2025:01:23 10:00:00
'$INPUT_DIR/test2.jpg',test2.jpg,Nikon,D750,2025:01:23 14:00:00
CSV
EOF
  chmod +x "$TEST_ROOT/exiftool"
  
  PATH="$TEST_ROOT:$PATH" run bash -c "printf '$INPUT_DIR\n$OUTPUT_DIR\ny\n' | $script_path"
  
  assert_success
  assert_output --partial "Output saved here"
  
  local output_csv
  output_csv=$(find "$OUTPUT_DIR" -name "pics_metadata_*.csv" | head -1)
  [ -f "$output_csv" ]
  [ -s "$output_csv" ]
}


