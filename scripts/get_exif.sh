#!/usr/bin/env bash

# Author: Adrian Gadient
# Last updated: 2025/12/4
# Creates csv with exif metadata

# Instructions:
# 1) drag this into the terminal 
# 2) press ENTER 
# 3) drag requested files into terminal 

set -euo pipefail
export LC_ALL=C.UTF-8

# Ask for folder containing pictures
echo -e "Drag \033[32mfolder with photos\033[0m here, then press [Enter]"
read input_path

# Ask user for output CSV path
echo -e "Drag \033[32mdestination folder\033[0m for output here, then press [Enter]" 
read folder_path

# Validate inputs and tool availability

# Strip wrapping quotes which Terminal drag & drop may add
input_path=${input_path#\"}; input_path=${input_path%\"}
folder_path=${folder_path#\"}; folder_path=${folder_path%\"}

# Basic validation
if [[ -z "$input_path" || ! -d "$input_path" ]]; then
  echo -e "\033[31mERROR: Input path is empty or not a directory: $input_path\033[0m" >&2
  exit 1
fi

if [[ -z "$folder_path" || ! -d "$folder_path" ]]; then
  echo -e "\033[31mERROR: Destination folder is empty or not a directory: $folder_path\033[0m" >&2
  exit 2
fi

if [[ ! -w "$folder_path" ]]; then
  echo -e "\033[31mERROR: Destination folder is not writable: $folder_path\033[0m" >&2
  exit 3
fi

# Check exiftool exists
if ! command -v exiftool >/dev/null 2>&1; then
  echo -e "\033[31mERROR: exiftool is not installed or not in PATH.\033[0m" >&2
  exit 4
fi

# Check if JPG files exist (recursively)
jpg_count=$(find "$input_path" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) | wc -l)

if (( jpg_count == 0 )); then
  echo -e "\033[31mERROR: No JPG/JPEG files found in $input_path.\033[0m" >&2
  exit 5
fi

echo -e "\033[33mFound $jpg_count JPG/JPEG files to process.\033[0m"

# Set destination and name for the output CSV
output_csv="$folder_path/pics_metadata_$(date +%Y%m%d_%H%M%S).csv"

# If output exists, ask if it should be replaced
if [[ -e "$output_csv" ]]; then
  echo -e "\033[38;5;208mFile '$output_csv' exists. Overwrite? [y/N]\033[0m"
  read -r reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo -e "\033[31mAborting to avoid overwrite.\033[0m" >&2
    exit 6
  fi
fi

# Give user feedback that metadata extraction is starting
echo -e "\033[33mStarting EXIF extraction. This may take a moment...\033[0m"

# run exiftool and check if successful
if exiftool -progress -r -ext jpg -ext jpeg -FileName -Make -Model -DateTimeOriginal -FilmMode -GrainEffectSize -GrainEffectRoughness -ColorChromeEffect -ColorChromeFXBlue -WhiteBalance -ColorTemperature -WhiteBalanceFineTune -DevelopmentDynamicRange -HighlightTone -ShadowTone -Saturation -Sharpness -NoiseReduction -Clarity -Keywords -csv "$input_path" > "$output_csv"
then
  echo -e "\033[33m Exif metadata extraction succeeded.\033[0m"
  echo -e "\033[32m Output saved here\033[0m: $output_csv"
else
  echo -e "\033[31mThere was a problem. It wasn't possible to generate the requested file.\033[0m" >&2
  exit 7                          
fi

if [[ ! -s "$output_csv" ]]; then
  echo -e "\033[33mWarning: Output file is empty — no metadata was extracted.\033[0m"
fi