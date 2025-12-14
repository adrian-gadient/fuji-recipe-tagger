#!/usr/bin/env bash

# Add recipe to tag "Keywords" in each photo

# 1) drag this into the terminal 
# 2) press ENTER 
# 3) drag requested files into the Terminal 

# Options to make script fail fast and avoid subtle bugs
set -euo pipefail

read -p $'Drag \033[1;32mcsv file with sourcefile paths and recipes\033[0m into the Terminal (typically 'sourcefile_filmsim.csv'), then press [ENTER] ' csv_path

csv_path=${csv_path#\"}; csv_path=${csv_path%\"}  # remove quotes if any

# Ensure that the CSV exists and is readable
if [[ -z "$csv_path" || ! -f "$csv_path" ]]; then
  echo -e "\033[31mERROR: CSV file path is empty or not a file: $csv_path\033[0m" >&2
  exit 1
fi

# Check available columns and create clean CSV with only SourceFile,filmsim
echo "Checking CSV columns..."
available_cols=$(head -n 1 "$csv_path" | tr ',' '\n' | tr -d '\r' | sort)
echo "Available columns: $available_cols"

# Extract only SourceFile and filmsim columns (handles FileName presence)
clean_csv=$(mktemp)
mlr --csv cut -f SourceFile,filmsim "$csv_path" > "$clean_csv"

echo "✓ Using columns: SourceFile, filmsim"
echo "Processing $(mlr --csv count "$clean_csv" | tail -n1) rows..."

# Process the clean CSV
while IFS=, read -r file filmsim; do
  # Skip header and ensure columns are not empty
  [[ "$file" = "SourceFile" || -z "$file" || -z "$filmsim" ]] && continue
  if ! exiftool -overwrite_original -keywords-="$filmsim" -keywords+="$filmsim" "$file"; then
    echo -e "\033[31mFailed to update keywords for file: $file\033[0m" >&2
  fi
done < "$clean_csv"

rm "$clean_csv"
echo -e "\033[32m✓ Keywords updated successfully!\033[0m"
