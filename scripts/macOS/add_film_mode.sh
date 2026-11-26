#!/usr/bin/env bash

# Author: Adrian Gadient
# Last updated: 2025/12/12
# This script copies the content of FilmMode tag to Keywords for supported image files in a selected folder

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

# Check if folder contains supported image files
if ! ls "$folder"/*.jpg "$folder"/*.JPG "$folder"/*.jpeg "$folder"/*.JPEG "$folder"/*.heic "$folder"/*.HEIC "$folder"/*.heif "$folder"/*.HEIF "$folder"/*.hif "$folder"/*.HIF 2>/dev/null | head -1 | grep -q .; then
    echo "❌ Error: No supported image files (JPG/JPEG/HEIC/HEIF/HIF) found in folder."
    exit 1
fi

# 2) Show preview of image files with FilmMode tags
echo
echo "Folder: $folder"
echo "Previewing image files with FilmMode tags:"
exiftool -FilmMode -n "$folder"/*.jpg "$folder"/*.JPG "$folder"/*.jpeg "$folder"/*.JPEG "$folder"/*.heic "$folder"/*.HEIC "$folder"/*.heif "$folder"/*.HEIF "$folder"/*.hif "$folder"/*.HIF 2>/dev/null | head -10
echo

# 3) Confirm with user before modifying files
read -p $'You are about to \033[1;31mPERMANENTLY modify EXIF metadata\033[0m in ALL image files in this folder. Continue? [y/N]: ' confirm

case "$confirm" in
    [yY]|[yY][eE][sS])
        echo "✅ Running exiftool on image files..."
        exts=(-ext jpg -ext jpeg -ext heic -ext heif -ext hif)
        # Pass 1: append FilmMode to IPTC Keywords (JPG) and XMP Subject (JPG + HEIC)
        exiftool -overwrite_original '-keywords+<FilmMode' '-XMP-dc:Subject+<FilmMode' \
                 "${exts[@]}" -r "$folder"
        # Pass 2: remove duplicates (keeps existing keywords)
        exiftool -overwrite_original -sep '##' \
                 '-keywords<${keywords;NoDups}' '-XMP-dc:Subject<${XMP-dc:Subject;NoDups}' \
                 "${exts[@]}" -r "$folder"
        echo "✅ Done!"
        ;;
    *)
        echo "❌ Aborted. No files were changed."
        exit 1
        ;;
esac
