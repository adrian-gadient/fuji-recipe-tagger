#!/usr/bin/env bash

# Script: identify_recipes.sh
# Description: Identifies film recipes based on the metadata of photos
# Either type in the Terminal: ./identify_recipes.sh
# or drag this file into the Terminal and press ENTER
#   Follow prompts to select input directory and output location
# Requirements: Miller
# Author: Adrian Gadient
# Last updated: 2025/12/4

# Options to make script fail fast and avoid subtle bugs
set -euo pipefail

# Wrapper function for Miller commands with error handling
## This captures the Miller commands, checks its success, and outputs errors with context 
run_miller() {
  local output
  if ! output=$(mlr "$@" 2>&1); then
    echo -e "\033[31mERROR: Miller command failed: mlr $*\n$output\033[0m" >&2
    exit 1
  fi
  echo "$output"
}

# Command availability check ------------------------------------------------------------
echo "Checking required tools..."
if ! command -v mlr >/dev/null 2>&1; then
  echo -e "\033[31mERROR: Miller (mlr) is required but not found. Install with: brew install miller (Mac) or apt install miller (Linux)\033[0m" >&2
  exit 1
fi
echo "✓ Miller found"
echo ""

# Prompt user for input/output paths -------------------------------------------------------
echo -e "Drag the csv file containing your picture\'s \033[1;32mMETADATA\033[0m into the Terminal, then press [ENTER] "
read -r tags

echo -e "Drag the csv file containing your \033[1;32mRECIPES\033[0m into the Terminal, then press [ENTER] " recipes
read -r recipes

echo -e "Drag the folder \033[1;32mpath for the output\033[0m (csv with picture + matching recipe) into the Terminal, then press [ENTER] " folder_path
read -r folder_path

# Prepare processing -----------------------------------------------------------------------

# Remove possible leading and trailing quotes
# (may be added when dragging files into the Terminal)
## Remove leading double quotes from variable if present
tags=${tags#\"}; 
recipes=${recipes#\"}; 
folder_path=${folder_path#\"}; 
## Remove trailing double quote if it exists
tags=${tags%\"};
recipes=${recipes%\"};
folder_path=${folder_path%\"}

# Path validation check 
echo "Validating input paths + files..."

# Check files exist and are readable
if [[ ! -f "$tags" ]]; then
  echo -e "\033[31mERROR: Tags file not found: $tags\033[0m" >&2
  exit 1
fi
if [[ ! -f "$recipes" ]]; then
  echo -e "\033[31mERROR: Recipes file not found: $recipes\033[0m" >&2
  exit 1
fi
if [[ ! -d "$folder_path" ]]; then
  echo -e "\033[31mERROR: Output folder not found: $folder_path\033[0m" >&2
  exit 1
fi
if [[ ! -w "$folder_path" ]]; then
  echo -e "\033[31mERROR: Output folder not writable: $folder_path\033[0m" >&2
  exit 1
fi

# Check CSVs are non-empty and have headers
if [[ ! -s "$tags" ]] || ! head -n1 "$tags" >/dev/null 2>&1; then
  echo -e "\033[31mERROR: Tags CSV is empty or has no header: $tags\033[0m" >&2
  exit 1
fi
if [[ ! -s "$recipes" ]] || ! head -n1 "$recipes" >/dev/null 2>&1; then
  echo -e "\033[31mERROR: Recipes CSV is empty or has no header: $recipes\033[0m" >&2
  exit 1
fi

output_csv="$folder_path/matched_recipes.csv"
echo -e "\033[33m✓ All paths valid\033[0m"

# Create temporary directory for intermediate CSV files during processing
tmpdir=$(mktemp -d)
# Make cleanup automatic
## Ensure that the entire temp directory gets deleted when the script exits, even if it crashes midway
trap 'rm -rf "$tmpdir"' EXIT

# Creates variable that holds the full path to a temporary CSV file  for the processed recipes 
recipes_sel="$tmpdir/recipes_sel.csv"
# Path to CSV with reordered tags (to match join column order)
tags_reordered="$tmpdir/tags_reordered.csv"
# Path to the output of the Miller (mlr) join operation that merges tags and recipes 
joined="$tmpdir/joined.csv"

# Replace missing or empty values with "NA" in the tags file
tags_filled="$tmpdir/tags_filled.csv"
run_miller --csv put '
  for (k, v in $*) {
    if (!is_present($[k]) || $[k] == "") {
      $[k] = "NA"
    }
  }
' "$tags" > "$tags_filled"
tags="$tags_filled"

# Replace missing or empty values with "NA" in the recipes file
recipes_filled="$tmpdir/recipes_filled.csv"
run_miller --csv put '
  for (k, v in $*) {
    if (!is_present($[k]) || $[k] == "") {
      $[k] = "NA"
    }
  }
' "$recipes" > "$recipes_filled"
recipes="$recipes_filled"

echo "Processing CSVs using Miller..."

# Define join columns
join_cols=(
  FilmMode
  DevelopmentDynamicRange
  ColorChromeEffect
  ColorChromeFXBlue
  GrainEffectSize
  GrainEffectRoughness
  ColorTemperature
  WhiteBalanceFineTune
  HighlightTone
  ShadowTone
  Saturation
  Sharpness
  NoiseReduction
  Clarity
)

# Join all elements of the join_cols array into a single comma-separated string required for Miller’s join 
join_cols_csv=$(IFS=, ; echo "${join_cols[*]}")

# Warn about missing required columns (non-fatal) -----------------------------
echo "Checking required columns in input files..."

# Check recipes file for missing join columns
missing_in_recipes=()
for col in "${join_cols[@]}"; do
if ! head -n 1 "$recipes" | grep -q ",$col," && ! head -n 1 "$recipes" | grep -q "^$col," && ! head -n 1 "$recipes" | grep -q ",$col$"; then
  missing_in_recipes+=("$col")
fi

done

# Check tags file for missing join columns  
missing_in_tags=()
for col in "${join_cols[@]}"; do
  if ! head -n 1 "$tags" | grep -q ",$col," && ! head -n 1 "$tags" | grep -q "^$col," && ! head -n 1 "$tags" | grep -q ",$col$"; then
    missing_in_tags+=("$col")
  fi
done

# Show warnings if any columns are missing
if [ ${#missing_in_recipes[@]} -gt 0 ]; then
  echo -e "\033[31mWARNING: Recipes file missing columns:\033[0m ${missing_in_recipes[*]}"
  echo "  Join will skip these columns or fail to match."
fi

if [ ${#missing_in_tags[@]} -gt 0 ]; then
  echo -e "\033[31mWARNING: Columns missing in metadata file:\033[0m ${missing_in_tags[*]}"
  echo -e "\033[33mMissing columns are added to metadata file and filled with NA.\033[0m"
fi

if [ ${#missing_in_recipes[@]} -eq 0 ] && [ ${#missing_in_tags[@]} -eq 0 ]; then
  echo -e "\033[33m✓ All required columns found in both files\033[0m"
fi
echo ""

if [ ${#missing_in_tags[@]} -gt 0 ]; then
  # Construct mlr put expression to add missing columns filled with "NA"
  mlr_put_expr=""
  for col in "${missing_in_tags[@]}"; do
    mlr_put_expr+="if (!is_present(\$$col)) { \$$col = \"NA\" }; "
  done
  tags_completed="$tmpdir/tags_completed.csv"
  run_miller --csv put "$mlr_put_expr" "$tags" > "$tags_completed"
  tags="$tags_completed"
fi

# Check File Sizes and Warn if too Large
max_size=$((30*1024*1024)) # 30 MB limit
for file in "$tags" "$recipes"; do
  size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")
  if [[ "$size" -gt "$max_size" ]]; then
    echo -e "\033[33mWARNING: File $file is large ($(numfmt --to=iec "$size")) which may affect performance.\033[0m"
  fi
done

# Start data processing -----------------------------------------------------------------
# 1) Select filmsim + join cols on recipes, reorder cols according to join_cols
## Miller's join command requires join key columns to be positioned as the FIRST columns 
## in identical order in both input files for the join to work correctly.
## Therefore place filmsim after the other join cols
run_miller --csv cut -f filmsim,"$join_cols_csv" "$recipes" | run_miller --csv reorder -f "$join_cols_csv,filmsim" > "$recipes_sel"

# 2) Get all columns from tags header
## Create a newline-separated list of all column headers in the tags CSV. 
## Used later to distinguish between join columns and non-join columns.
all_tag_cols=$(head -n1 "$tags" | tr ',' '\n' | tr -d '\r')

# 3) Determine non-join columns in tags
non_join_cols=$(comm -23 <(echo "$all_tag_cols" | sort -u) <(printf "%s\n" "${join_cols[@]}" | sort -u) | paste -sd, -)

# 4) Rearrange columns in tags: join_cols first, then the rest
## Construct a comma-separated string defining the desired order of columns for the tags CSV
new_tag_order="$join_cols_csv,$non_join_cols"
## Enforce column ordering for a successful Miller join with the reordered recipes CSV 
## (ensuring that the join keys lead the table)
run_miller --csv reorder -f "$new_tag_order" "$tags" > "$tags_reordered"

# 5) Left join tags with recipes on join cols (keys must be first columns and ordered same)
run_miller --csv join --ul -j "$join_cols_csv" -f "$recipes_sel" "$tags_reordered" > "$joined"

# 6) Filter rows where both filmsim and SourceFile are present and non-empty,
#    then select SourceFile, FileName, and filmsim columns for output
run_miller --csv filter 'is_present($filmsim) && $filmsim != "" && is_present($SourceFile) && $SourceFile != ""' "$joined" | \
run_miller --csv put '$tmpSF = $SourceFile; $tmpFN = $FileName; $tmpFS = $filmsim; unset $SourceFile; unset $FileName; unset $filmsim; $SourceFile=$tmpSF; $FileName=$tmpFN; $filmsim=$tmpFS' then cut -f SourceFile,FileName,filmsim > "$output_csv"

# 7) Show processing summary --------------------------------------------------------
echo "Processing summary:"
tags_rows=$(run_miller --csv count "$tags" | tail -n1)
matched_rows=$(run_miller --csv count "$output_csv" 2>/dev/null | tail -n1 || echo "0")

echo -e "\033[33m- Number of input photos:\033[0m    $tags_rows "
echo -e "\033[33m- Recipes successfully matched:\033[0m $matched_rows "
if [ "$matched_rows" -eq 0 ]; then
  echo -e "\033[31mNo matches found. Check column values or missing columns.\033[0m"
fi
echo ""

if [ "$matched_rows" -gt "$tags_rows" ]; then
  echo -e "\033[31mWarning: There are more matched photos than input photos. This is probably because your recipe file includes duplicate entries.\033[0m"
  echo ""
fi


# 8) Final status message --------------------------------------------------------
if [ -f "$output_csv" ]; then
  echo -e "\033[32mList of matched jpgs saved to:\033[0m $output_csv"
else
  echo -e "\033[31mFailed to create output file.\033[0m"
fi

# 9) Find missing FileName entries (only create file if unmatched exist)
missing_jpgs_csv="$folder_path/unmatched_jpgs.csv"

# Extract unique FileNames from output (matched) and tags (all)
run_miller --csv cut -f FileName "$output_csv" | tail -n +2 | sort -u > "$tmpdir/output_fns.txt" 2>/dev/null || true
run_miller --csv cut -f FileName "$tags" | tail -n +2 | sort -u > "$tmpdir/all_fns.txt" 2>/dev/null || true

# Find what's in tags but NOT in output 
awk 'NR==FNR{seen[$0]=1; next} !($0 in seen)' "$tmpdir/output_fns.txt" "$tmpdir/all_fns.txt" > "$tmpdir/missing.txt"

missing_count=$(wc -l < "$tmpdir/missing.txt")

# ONLY create unmatched CSV if there are actually unmatched files
if [ "$missing_count" -gt 0 ]; then
  echo "FileName" > "$missing_jpgs_csv"
  cat "$tmpdir/missing.txt" >> "$missing_jpgs_csv"
  echo -e "\033[31mList of unmatched jpgs saved to:\033[0m $missing_jpgs_csv"
  echo ""
fi
