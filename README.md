# MKVFontMan

## Automatically manage fonts embedded in Matroska files

This script allows to easily add and remove fonts from a Matroska files that are used to display subtitles (commonly used on SSA/ASS fonts)

### WARNING: This project is still WIP. It works, but on a single file as of now, and the arguments parser is very basic

## Features

- Display the list of useful, useless and missing fonts in a file with the `info` mode
- Automatically extract all the fonts and put them in a "font store" to be used later
- Automatically remove useless fonts and attach missing fonts (if they are present il the font store) with the `autoclean` mode
- Separate file that contains functions to easily add to your own script

## How to use - command line

Simply call `mkvfontman.sh` with the arguments (see below). **WARNING** as of now, the "font store" directory is inside your current directory. You should always call the script when you are in its folder to avoid getting "fontsore" folders everywhere

### Usage

- `mkvfontman.sh help`
Displays very basic help information (will be improved)
- `mkvfontman.sh {list | autoclean} {file}`
List the used, unused and missing fonts in `file` (with the `list` mode)
Remove unused fonts and add missing ones in `file` (with the `autoclean` mode)

## Requirements

- A `bash` that is not 500 years old
- `mkvtoolnix` ([link](https://mkvtoolnix.download/downloads.html "link"))
- `fontconfig` (for the `fc-scan` command)

## Usage in scripts

You can also use this script in your own bash scripts by first putting `souce {path/to/mkvfontman/lib.sh}` and then using the following functions:
- `printFontsAss {file}`
Prints all fonts used by an .ass or .ssa file passed as $1 on stdin
The output format is `{font family name}`
- `printUsedFontsMatroska {file}`<sup>1</sup>
Prints all fonts used by a Matroska file on stdin, by first extracting all ASS/SSA subtitles from the file (mkv/mks/mka) passed as $1
The output format is `{font family name}`
- `printAttachedFontsMatroska {file}`<sup>1</sup>
Prints all fonts attached to a Matroska file passed as $1 on stdin. This will also add the fonts to the "font store"
The output format is `{font filename};{font family name}[,font family name 2, ...]`
- `parseMkv {file}`
Parse missing, used and unused fonts from a Matroska container passed as $1.
This will update the following arrays:
	- `availableFonts`: All the fonts present in the file (format: `{font filename};{font family name}[,font family name 2, ...]`)
	- `neededFonts`: All the fonts that are truely usefull in the file (format: `{font family name}`)
	- `missingFonts`: All the needed fonts that are missing in the file (format: `{font family name}`)
	-`uselessFonts`: All the useless fonts that are in the file (format: `{font filename};{font family name}[,font family name 2, ...]`)
- `parseFontList`
Parse missing and useless fonts by using `availableFonts` and `neededFonts`
- `parseFontStore`
Parse the font store for missing font to add.
Takes the font list in `missingFonts` and adds the files to the array `fontsToAdd`
- `cleanMatroska`<sup>1</sup>
Clean a Matroska file passed as $1 by removing the fonts listed in `uselessFonts` and adding the ones in `fontsToAdd`

<sup>1</sup>: **NOTE**: the variable `json` must first be set by using `json="$(mkvmerge -J "[FILE]")"`. This is done to avoid calling `mkvmerge -J` at each step
Note on formats:
SSA/ASS subtitles refer to their fonts by using the font **family name** like "Arial". However, the filename of the font is different (it could just be `ArIaL.ttf` or `LookAtThisAwsomeFont.ttf`). That's why we need to know the font file name ot add or remove it, but also its family name to know if the font is used or not

