
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- Regularly render `README.Rmd` to keep `README.md` up-to-date. -->

[![Tests](https://github.com/adrian-gadient/fuji-recipe-tagger/workflows/Tests/badge.svg)](https://github.com/adrian-gadient/fuji-recipe-tagger/actions)

# How to auto-tag Fuji recipes to photos

## Brief summary

This project explains how to quickly extract hidden camera settings  
from your Fuji photos, identify the recipe used during shooting, and
save that information in a much more accessible way. This works with
`Bash` / `Shell` code (scripts for Mac OSX are
[here](https://github.com/adrian-gadient/fuji-recipe-tagger/tree/main/scripts/macOS)).

## Introduction

**Background:** Fujifilm X cameras have gained popularity among
photographers for their **film simulation recipes**—custom settings
combinations that recreate classic film looks straight out of camera (as
JPG files). Owners tweak parameters like Film Mode, Grain Effect, and
Color Temperature to achieve these effects. A popular site that shares
many recipes is [fujixweekly.com](https://fujixweekly.com).

**The challenge:** Identifying which recipe had been used for taking a
specific picture is tedious because the relevant information is stored
in **EXIF metadata**. Accessing these requires specialized software
(e.g., Lightroom plugins) and lots of menu navigation.

**The solution:** This repository provides a simple workflow to use code
to **automatically identify** Fujifilm recipes and **store** them
directly in your pictures’ metadata — making the process fast and
effortless even for many photos. The only effort is to create a list
with all their recipes. The scripts are completely free to use and open
source.

## Prerequisites

This code was developed on **Mac OSX**. Windows users need to adapt it.
To run the code, you need a few things:

### List of recipes

You need to prepare a list with the recipes you are using (see further
down).

### Scripts

**Option 1:** Download the whole repository as a ZIP file (hit the green
button `<> Code` and then `Download ZIP`), unzip, and find the scripts
files in the folder `scripts/macOS`.

**Option 2:** Open the
[scripts/macOS](https://github.com/adrian-gadient/fuji-recipe-tagger/tree/main/scripts/macOS)
directory in your browser, click on each script and download it via the
`Download raw file` icon.

### Access to the **Terminal**

**Command-line interface for running scripts.** Press `Cmd+Space`, type
“Terminal”, hit \[ENTER\]—or find it in Applications/Utilities. For more
details, consult the [Apple
guide](https://support.apple.com/guide/terminal/open-or-quit-terminal-apd5265185d-f365-44cb-8b09-71a064a42125/mac).

If you drag the scripts into the Terminal and get *Permission denied*,
the file lacks execute permissions. In this case, you need to make the
script(s) executable by typing `chmod +x /path/to/your/script.sh`. After
pressing \[ENTER\], you should be able to drag the script into the
Terminal and run it. Note that you need to do this separately for each
script you want to use.

#### `exiftool`

This tool reads and writes image metadata (EXIF). The installation guide
can be found [here](https://exiftool.org/install.html).

#### `awk`

Text processing and pattern scanning utility. Used to compare new photos
against recipes and to check the output. This should be pre-installed on
Mac. If you want to learn more about it, here is a [macOS awk
guide](https://ss64.com/osx/awk.html)

#### `Miller`

Used for reading, transforming, joining, filtering, and cleaning CSV
data. Can be installed with
[Homebrew](https://miller.readthedocs.io/en/latest/install.html).

## Workflow

Below you find three sequential scripts (and an independent fourth
script for tagging “film mode”). You can either execute them
sequentially or stop after steps 1 or 2. You can use the scripts for
photos that are already part of a photo collection and / or management
tool (e.g., **DigiKam** or **Lightroom**).

**Important**: When you’re planning to add your recipe to pictures
stored in a photo management tool, you may inadvertently override
existing keywords. To make sure this doesn’t happen, you should store
any metadata from these applications directly in the photos or create a
backup.

### Prepare a list with all your film simulations

To determine which simulation was used to create a photo, you need a
list with the “recipes” you have used. Currently, the following tags are
used to identify recipes:

- FilmMode
- DevelopmentDynamicRange
- ColorChromeEffect
- ColorChromeFXBlue
- GrainEffectSize
- GrainEffectRoughness
- ColorTemperature
- WhiteBalanceFineTune (the values do not correspond to the camera
  settings)
- HighlightTone
- ShadowTone
- Saturation
- Sharpness
- NoiseReduction
- Clarity

If the recipes file containts *WhiteBalance* and *Exposure*, these
settings are currently ignored. The reason is that they cause problems
because the same setting is stored differently in different camera
models. Moreover, they have little diagnostic value.

Below are two recipes to illustrate how such a list may look like. Note
that FilmMode has no value when Acros is chosen.

| filmsim | Source | FilmMode | DevelopmentDynamicRange | GrainEffectSize | GrainEffectRoughness | ColorChromeEffect | ColorChromeFXBlue | WhiteBalance | ColorTemperature | WhiteBalanceFineTune | HighlightTone | ShadowTone | Saturation | Sharpness | NoiseReduction | Clarity |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| Documentary | <https://www.kevinmullinsphotography.co.uk/blog/fujifilm-recipe-documentary-colour> | Classic Chrome | 400 | Small | Weak | Weak | Off | Auto | NA | Red +40, Blue -20 | -1 (medium soft) | +2 (hard) | 0 (normal) | Hard | 2 | -4 (weakest) |
| Kodachrome II V2 | <https://fujixweekly.com/2021/04/05/two-fujifilm-x-trans-iv-film-simulation-recipes-kodachrome-ii/> | Classic Chrome | 200 | Small | Weak | Strong | Weak | Auto (ambiance priority) | NA | Red +60, Blue -100 | +1 (medium hard) | 1.5 | +1 (medium high) | Hard | 2 | -4 (weakest) |

Possible **procedure** to create such a list:

1.  Open a spreadsheet (e.g., Excel) and enter the settings (`values`;
    e.g., film mode = “Classic Chrome”) required for a specific recipe.

2.  It may be helpful to first import the metadata of some pictures.
    Inspecting the `pics_metadata.csv` file (see step 1) will help to
    find the relevant tag names and values to specify the “ingredients”
    of your recipes.

3.  Save all your recipes in a **csv** file (e.g., `recipes.csv`).

**Important**: The values in your recipe file need to **exactly** match
those stored in the pictures’ metadata. Avoid divergent spelling, extra
spaces, etc. Missing information is best left empty.

#### Tip

You can add other information to your recipes file such as the source /
author of the recipe or how settings must look on your camera.
Additional variables will be ignored during the matching process.

### Step 1: Import metadata from photos

Import metadata with **`get_exif.sh`** . To run the code, simply drag
this file into the Terminal an press \[ENTER\]. Follow the instructions.
This generates the file `pics_metadata_DATE_TIME.csv`, which includes
the path to your photos and the settings (e.g., Sharpness) used to
create them.

### Step 2: Identify which simulation was used to create a photo

Drag **`identify_recipes.sh`** into the Terminal and press \[ENTER\].
Follow the instructions.

This script does the real magic: It compares the extracted EXIF metadata
of the photos to your list of recipes and creates two files:

- `matched_recipes.csv` includes the path to and name of pictures with a
  matching recipe in your list.  
- `unmatched_jpgs.csv` features images from your input file that cannot
  be matched. This file is helpful to find incomplete or incorrect
  entries in the recipes file.

The outcome will look something like this:

| SourceFile                             | FileName     | filmsim          |
|:---------------------------------------|:-------------|:-----------------|
| /Pictures/2023/2023-07-29/PRO30254.JPG | PRO30254.JPG | Kodak Portra 800 |
| /Pictures/2023/2023-07-29/PRO30252.JPG | PRO30252.JPG | Kodak Portra 800 |
| /Pictures/2023/2023-07-29/PRO30253.JPG | PRO30253.JPG | Kodak Portra 800 |
| /Pictures/2023/2023-07-29/PRO30247.JPG | PRO30247.JPG | Kodacolor        |

### Step 3: Add information to keywords tag

Drag **`add_recipes.sh`** into the Terminal to programmatically create
or update the tag “Keywords” in each picture’s metadata according to the
file `matched_recipes.csv`. This script doesn’t delete any information
in the tag “Keywords”. Duplicate entries are avoided.

In contrast to the Fuji specific metadata (e.g., Sharpness), the
**“Keywords”** tag is **commonly recognized** by various software
(incl. Lightroom). It even appears in Mac’s Finder when you click on
“Get Info” (or Command + i).

## Bonus: Add FilmMode to keywords

If you only (or additionally) want to add the content from the tag
`FilmMode` to `Keywords`, there’s also code for that: Just drag
**`add_film_mode.sh`** (download raw file
[here](https://github.com/adrian-gadient/fuji-recipe-tagger/blob/a80499388401f4c01e1aab15ec3ea525463dfc6d/scripts/macOS/add_film_mode.sh))
into the Terminal, hit \[ENTER\] and follow the instructions.

## Questions, feedback, contributions

I hope the scripts will be useful to many people. If you try them, let
me know how they work for you. For
[bugs](https://github.com/adrian-gadient/fuji-recipe-tagger/issues/new?template=bug_report.md&title=bug%3A+%5Bshort+description%5D),
[feature
request](https://github.com/adrian-gadient/fuji-recipe-tagger/issues/new?labels=enhancement&title=feat%3A+%5Byour+idea%5D),
or
[questions](https://github.com/adrian-gadient/fuji-recipe-tagger/issues/new?labels=question&title=question%3A+%5Bshort+description%5D),
please create a new issue.

If you have suggestions for code improvement, please get in touch, too.

## AI tools used

Perplexity was used to translate the data wrangling process from `R` to
`Bash` / `Shell`, to generate most of the `Bash` / `Shell` code, and to
refine the documentation. To develop the test and implemen them in
Docker, I consulted Claude AI.
