#!/usr/bin/env bash

@test "extract_meta.sh produces expected CSV for sample photo" {
  # Create a minimal test fixture (real photo or dummy with metadata)
  mkdir -p tests/fixtures
  cp ./tests/testdata/images/PRO34551.jpg tests/fixtures/sample.jpg  # replace with real test image
  
  # Run your script, capture output to temp file
  run ../scripts/macOS/get_exif.sh ./tests/fixtures/sample.jpg > actual.csv
  
  # Compare against your saved benchmark/snapshot
  [ -f ./tests/snapshots/metadata.csv ] || {
    echo "Snapshot with extracted metadata missing! Place it here: test/snapshots/metadata.csv"
    exit 1
  }
  
  # Compare files (exact match)
  diff ./tests/snapshots/metadata.csv actual.csv
  
  # Clean up
  rm -f actual.csv
}
