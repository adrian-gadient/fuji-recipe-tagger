#!/usr/bin/env bats
load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'

setup() {
  # EXACTLY your working pattern - this works!
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests}"
  script_path="$REPO_ROOT/scripts/macOS/get_exif.sh"
  
  [ -f "$script_path" ] || fail "Script not found: $script_path"
  
  TEST_ROOT="$(mktemp -d)"
  INPUT_DIR="$TEST_ROOT/input"
  OUTPUT_DIR="$TEST_ROOT/output"
  mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "script exists and is executable" {
  [ -x "$script_path" ]
}

@test "fails when exiftool is missing" {
  local old_path="$PATH"
  PATH="/nonexistent"
  run "$script_path" <<< $'/tmp\n/tmp\n'
  PATH="$old_path"
  assert_failure 4
  assert_output --partial "exiftool is not installed"
}

@test "fails with invalid input directory" {
  run "$script_path" <<< $'invalid-dir\n/tmp\n'
  assert_failure 1
  assert_output --partial "Input path is empty or not a directory"
}

@test "fails with invalid output directory" {
  run "$script_path" <<< $'/tmp\ninvalid-dir\n'
  assert_failure 2
  assert_output --partial "Destination folder is empty or not a directory"
}

@test "processes JPG files and creates CSV (mocked)" {
  # Create test JPG files in input dir
  touch "$INPUT_DIR/test1.jpg" "$INPUT_DIR/test2.jpg"
  
  # Mock exiftool in PATH
  cat > "$TEST_ROOT/exiftool" << 'EOF'
#!/bin/bash
cat << 'CSV'
SourceFile,FileName,Make,Model
/path/test1.jpg,test1.jpg,Canon,EOS 5D
/path/test2.jpg,test2.jpg,Nikon,D750
CSV
EOF
  chmod +x "$TEST_ROOT/exiftool"
  
  PATH="$TEST_ROOT:$PATH" run "$script_path" <<< $"$INPUT_DIR\n$OUTPUT_DIR\ny\n"
  
  assert_success
  assert_output --partial "Output saved here"
  
  local output_csv
  output_csv=$(find "$OUTPUT_DIR" -name "pics_metadata_*.csv" | head -1)
  [ -f "$output_csv" ]
  [ -s "$output_csv" ]
}

@test "handles existing output file gracefully" {
  # Pre-create fake existing CSV
  local fake_csv="$OUTPUT_DIR/pics_metadata_20260123_060000.csv"
  echo "old,data" > "$fake_csv"
  
  # Mock exiftool
  cat > "$TEST_ROOT/exiftool" << 'EOF'
#!/bin/bash
echo "SourceFile,FileName"
echo "test.jpg,test.jpg"
EOF
  chmod +x "$TEST_ROOT/exiftool"
  
  PATH="$TEST_ROOT:$PATH" run "$script_path" <<< $"$INPUT_DIR\n$OUTPUT_DIR\nn\n"
  
  assert_failure 6
  assert_output --partial "Aborting to avoid overwrite"
}
