
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- Regularly render `README.Rmd` to keep `README.md` up-to-date. -->

# How to auto-tag Fuji recipes to photos

**Background:** Fujifilm X cameras have gained popularity among
photographers for their **film simulation recipes**—custom settings
combinations that recreate classic film looks. Owners tweak parameters
like Film Mode, Grain Effect, and Color Temperature to achieve these
effects. A key resource is the popular site
[fujixweekly.com](https://fujixweekly.com), which shares many recipes.

**The challenge:** Identifying which recipe had been used after taking a
specific picture is tedious because the relevant information is stored
in **EXIF metadata**. Accessing these requires specialized software
(e.g., Lightroom plugins) and lots of menu navigation.

**The solution:** This repository provides simple code and workflow to
**automatically identify** Fujifilm recipes and **store** them directly
in pictures’ metadata—making the process fast and effortless.

# Prerequisites

This code was developed on **Mac OSX**. Windows users need to adapt it.
To run the code, you need access to the **Terminal**. You must have
installed `exiftool`, `Miller`, and `awk`. You also require a list that
holds the recipes’ settings.

If you drag the script into Terminal and get *Permission denied*, the
file lacks execute permissions. In this case, you need to make the
script(s) executable by typing `chmod +x /path/to/your/script.sh`. After
pressing \[ENTER\], you should be able to drag the script into the
Terminal and run it. Note that you need to do this separately for each
script you want to use.

# Workflow

I provide three sequential scripts. You can either execute them
sequentially or stop after steps 1 or 2. Step 1

## Prepare a list with all your film simulations

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

3.  Save all your recipes in a csv file (e.g., `recipes.csv`).

### Tip

You can add other information to your recipes file such as the source /
author of the recipe or how settings must look on your camera.
Additional variables will be ignored during the matching process.

## Step 1: Import metadata from photos

Import metadata with **`get_exif.sh`**. Simply drag this file into the
Terminal an press \[ENTER\]. Follow the instructions. This generates the
file `pics_metadata_DATE_TIME.csv`, which includes the path to your
photos and the settings used to create them.

**Important**: When you’re planning to add your recipe to pictures
stored in a photo management tool such as **DigiKam** or **Lightroom**,
you may inadvertently override existing keyowrds. To make sure this
doesn’t happen, you should store any Metadata from these applications
directly in the photos or create a backup.

## Step 2: Identify which simulation was used to create a photo

Drag **`identify_recipes.sh`** into the Terminal and press \[ENTER\].
Follow the instructions.

This script compares the extracted EXIF metadata to your recipes and
creates two files: `matched_recipes.csv` includes the path to and name
of each picture and the recipe used to create it. Images from your input
file that cannot be matched are saved in `unmatched_jpgs.csv`. The
latter file is helpful to find incomplete or incorrect entries in the
recipes file.

The outcome will look something like this:

| SourceFile                             | FileName     | filmsim          |
|:---------------------------------------|:-------------|:-----------------|
| /Pictures/2023/2023-07-29/PRO30254.JPG | PRO30254.JPG | Kodak Portra 800 |
| /Pictures/2023/2023-07-29/PRO30252.JPG | PRO30252.JPG | Kodak Portra 800 |
| /Pictures/2023/2023-07-29/PRO30253.JPG | PRO30253.JPG | Kodak Portra 800 |
| /Pictures/2023/2023-07-29/PRO30247.JPG | PRO30247.JPG | Kodacolor        |

## Step 3: Add informaiton to keywords tag

Drag **`add_recipes.sh`** into the Terminal to programmatically create
or update the tag “Keywords” in each picture’s metadata according to the
file `matched_recipes.csv`. This script doesn’t delete any information
in the tag “Keywords”. Duplicate entries are avoided.

# Bonus: Add FilmMode to keywords

If you only (or additionally) want to add the content from the tag
`FilmMode` to `Keywords`, there’s also code for that: Just darg
**`add_film_mode.sh`** into the Terminal, hit \[ENTER\] and follow the
instructions.

# AI tools used

Perplexity was used to generate most of the `bash` code, to translate
the data wrangling process from `R` to `bash`, and to refine the
documentation.
