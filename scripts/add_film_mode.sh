#!/usr/bin/env bash

# Author: Adrian Gadient
# Last updated: 2025/12/12
# This script copies the content of FilmMode tag to Keywords for JPG files only in a selected folder

# Check if exiftool is installed
if ! command -v exiftool &> /dev/null; then
    echo "❌ Error: exiftool is not installed or not in PATH."
    echo "Install it with: brew install exiftool (macOS) or apt install exiftool (Linux)"
    exit 1
fi

# 1) Ask user to drag the folder into the terminal
read -p $'Drag the \033[1;32mfolder with images\033[0m into this Terminal window, then press [ENTER]: ' folder

# Validate folder exists
if [[ ! -d "$folder" ]]; then
    echo "❌ Error: '$folder' is not a valid directory."
    exit 1
fi

# Check if folder contains JPG files
if ! ls "$folder"/*.jpg "$folder"/*.JPG "$folder"/*.jpeg "$folder"/*.JPEG 2>/dev/null | head -1 | grep -q .; then
    echo "❌ Error: No JPG files (.jpg, .JPG, .jpeg, .JPEG) found in folder."
    exit 1
fi

# 2) Show preview of JPG files with FilmMode tags
echo
echo "Folder: $folder"
echo "Previewing JPG files with FilmMode tags:"
exiftool -FilmMode -n "$folder"/*.jpg "$folder"/*.JPG "$folder"/*.jpeg "$folder"/*.JPEG 2>/dev/null | head -10
echo

# 3) Confirm with user before modifying files
read -p $'You are about to \033[1;31mPERMANENTLY modify EXIF metadata\033[0m in ALL JPG files in this folder. Continue? [y/N]: ' confirm

case "$confirm" in
    [yY]|[yY][eE][sS])
        echo "✅ Running exiftool on JPG files only..."
        exiftool -overwrite_original '-keywords+<FilmMode' '-keywords<${keywords;NoDups}' \
                 -ext jpg -ext jpeg -r "$folder"
        echo "✅ Done! Created backup files with _original suffix."
        ;;
    *)
        echo "❌ Aborted. No files were changed."
        exit 1
        ;;
esac
