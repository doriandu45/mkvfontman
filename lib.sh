#!/bin/bash

# Newline constant used to add '\n' to strings
# See https://stackoverflow.com/a/64938613
nl="$(printf '\nq')"
nl=${nl%q}

# Prints all fonts used by an .ass or .ssa file passed as $1
function printFontsAss() {
	# Main styles
	grep '^Style: *' "$1" | awk -F',' '{print $2}'
	# Fonts embedded in lines with "\fn"
	grep -Eho '\\fn[^\\}]*[\\}]' "$1" | sed -E 's/\\fn(.*)./\1/'
}


# Prints all fonts used by a Matroska file, by first extracting all ASS/SSA subtitles from the file (mkv/mks/mka) passed as $1
# json must be set with "mkvmerge -J" so we only pasre the mkv once
function printUsedFontsMatroska () {
	local subsTracks="$(echo $json | jq -r '.tracks  | map( select (.codec=="SubStationAlpha") | .properties.codec_id  +";"+ (.id | tostring) ) | join("\n") ')"
	local IFS="$nl"
	printf '[\n'>"./mkvextractArgs.tmp"
	for track in $subsTracks
	do
		local IFS=";"
		local codec id
		read codec id<<<$track
		printf '\t"'${id}':'$1'_track'${id}'.'$(echo ${codec: -3} | tr '[:upper:]' '[:lower:]')'"'>>"./mkvextractArgs.tmp"
		# If it's not the last track
		[[ "$track" = "$(tail -n 1 <<<$subsTracks)" ]] || printf ','>>"./mkvextractArgs.tmp"
		printf '\n'>>"./mkvextractArgs.tmp"
	done
	printf ']'>>"./mkvextractArgs.tmp"
	IFS=" "
	mkvextract "$1" tracks @"./mkvextractArgs.tmp" 1>&2 # We redirect the progression to stderr so it won't get into the printed fonts on stdout
	for track in $subsTracks
	do
		local IFS=";"
		local codec id
		read codec id<<<$track
		printFontsAss "$1_track${id}.$(echo ${codec: -3} | tr '[:upper:]' '[:lower:]')"
	done
}

# Prints all fonts attached in a Matroska file passed as $1 by extracting them into a font store
# json must be set with "mkvmerge -J" so we only pasre the mkv once
function printAttachedFontsMatroska() {
	local attachFiles="$(echo $json | jq -r '.attachments  | map(  (.id | tostring) +";" + .file_name ) | join("\n") ')"
	local IFS="$nl"
	printf '[\n'>"./mkvextractArgs.tmp"
	for file in $attachFiles
	do
		local IFS=";"
		local id name
		read id name<<<$file
		printf '\t"'${id}':fontstore/%s"' "$name">>"./mkvextractArgs.tmp"
		# If it's not the last track
		[[ "$file" = "$(tail -n 1 <<<$attachFiles)" ]] || printf ','>>"./mkvextractArgs.tmp"
		printf '\n'>>"./mkvextractArgs.tmp"
	done
	printf ']'>>"./mkvextractArgs.tmp"
	IFS="$nl"
	mkvextract "$1" attachments @"./mkvextractArgs.tmp" 1>&2 # We redirect the progression to stderr so it won't get into the printed fonts on stdout
	for file in $attachFiles
	do
		local IFS=";"
		local id name
		read id name<<<$file
		printf '%s;%s\n' "$name" "$(fc-scan "fontstore/$name" -f "%{family}\n")"
	done
}

# Parse missing, used and unused fonts from a Matroska container passed as $1
function parseMkv() {
	json="$(mkvmerge -J "$1")"
	local IFS="$nl"
	availableFonts=( $(printAttachedFontsMatroska "$1") )
	neededFonts=( $(printUsedFontsMatroska "$1" | sort | uniq) )
	missingFonts=( "${neededFonts[@]}" )
	uselessFonts=( "${availableFonts[@]}" )
	
	parseFontList
}

# Parse missing and useless fonts by using availableFonts and neededFonts
function parseFontList() {
	local IFS="$nl"
	for testedFont in "${neededFonts[@]}"
	do
		# Looks trough each embedded font
		local foundFont=false
		for testedEmbeddedFont in "${availableFonts[@]}"
		do
			IFS=";"
			read embeddedFilename embeddedFontNames<<<$testedEmbeddedFont
			IFS=","
			for testedEmbeddedFontname in $embeddedFontNames
			do
				if [[ "$testedEmbeddedFontname" = "$testedFont" ]]
				then
					usedFonts+=( "${embeddedFilename} ($testedEmbeddedFontname)" )
					IFS="$nl"
					# We remove the font from the missing list
					for i in "${!missingFonts[@]}"
					do
						if [[ "${missingFonts[$i]}" = "$testedEmbeddedFontname" ]]
						then
							unset "missingFonts[$i]"
							break
						fi
					done
					# We remove the font from the useless list
					for i in "${!uselessFonts[@]}"
					do
						IFS=";"
						read fontFilename fontNames<<<"${uselessFonts[$i]}"
						if [[ "$fontFilename" = "$embeddedFilename" ]]
						then
							unset "uselessFonts[$i]"
							break
						fi
					done
					foundFont=true
					break
				fi
			done
			[[ $foundFont = true ]] && break
		done
	done
}

# Parse the font store for missing font to add.
# Takes the font list in missingFonts and adds the files to fontsToAdd
# TODO: Use a lookup table instead of scanning each file in the fontstore each time we want to add a font
function parseFontStore() {
	local IFS="$nl"
	for file in $(ls fontstore)
	do
		local fontName="$(fc-scan "fontstore/$file" -f "%{family}\n")"
		local foundFont=false
		IFS=","
		for testedFontName in $fontName
		do
			IFS="$nl"
			for testedMissingFont in "${missingFonts[@]}"
			do
				if [[ "$testedMissingFont" = "$testedFontName" ]]
				then
					fontsToAdd+=( "$file" )
					foundFont=true
					# We remove the font from the missing list
					for i in "${!missingFonts[@]}"
					do
						if [[ "${missingFonts[$i]}" = "$testedMissingFont" ]]
						then
							unset "missingFonts[$i]"
							break
						fi
					done
					break
				fi
			done
			[[ foundFont = true ]] && break
		done
	done
}

# Clean a Matroska file passed as $1 by removing the fonts in uselessFonts and adding the ones in fontsToAdd
# json must be set with "mkvmerge -J" so we only pasre the mkv once
function cleanMatroska() {
	# If for some reason we have nothing to do
	[[ "${#fontsToAdd[@]}" = "0" &&  "${#uselessFonts[@]}" = "0" ]] && return
	printf '[\n'>"./mkvmegreArgs.tmp"
	# Remove useless fonts
	if [[ "${#uselessFonts[@]}" != "0" ]]
	then
		printf '\t"--attachments",\n'>>"./mkvmegreArgs.tmp"
		printf '\t"!'>>"./mkvmegreArgs.tmp"
		local IFS="$nl"
		local attachFiles="$(echo $json | jq -r '.attachments  | map(  (.id | tostring) +";" + .file_name ) | join("\n") ')"
		for toRemove in "${uselessFonts[@]}"
		do
			# Useless fonts are separated by ';'
			IFS=";"
			read fontFile fontNames<<<$toRemove
			IFS="$nl"
			for file in $attachFiles
			do
				local IFS=";"
				local id name
				read id name<<<$file
				printf $id>>"./mkvmegreArgs.tmp"
				# If it's not the last file
				[[ "$file" = "$(tail -n 1 <<<$attachFiles)" ]] || printf ','>>"./mkvmegreArgs.tmp"
			done
			printf '"'>>"./mkvmegreArgs.tmp"
			[[ "${#fontsToAdd[@]}" != "0" ]] && printf ','>>"./mkvmegreArgs.tmp"
			printf '\n'>>"./mkvmegreArgs.tmp"
		done
	fi
	
	# Add missing fonts
	if [[ "${#fontsToAdd[@]}" != "0" ]]
	then
		for file in "${fontsToAdd[@]}"
		do
			mime="$(file --mime-type -b "fontstore/$file")"
			printf '\t"--attachment-name",\n'>>"./mkvmegreArgs.tmp"
			printf '\t"%s",\n' "$file">>"./mkvmegreArgs.tmp"
			printf '\t"--attachment-mime-type",\n'>>"./mkvmegreArgs.tmp"
			printf '\t"%s",\n' "$mime">>"./mkvmegreArgs.tmp"
			printf '\t"--attach-file",\n'>>"./mkvmegreArgs.tmp"
			printf '\t"fontstore/%s"' "$file">>"./mkvmegreArgs.tmp"
			# If it's not the last file
			[[ "$file" = "${fontsToAdd[-1]}" ]] || printf ','>>"./mkvmegreArgs.tmp"
			printf '\n'>>"./mkvmegreArgs.tmp"
		done
	fi
	printf ']'>>"./mkvmegreArgs.tmp"
	mkvmerge -o "${1%.*}_clean.${1: -3}" "$1" @"./mkvmegreArgs.tmp"
	
}

declare -a missingFonts
declare -a usedFonts
declare -a uselessFonts
declare -a availableFonts

declare -a neededFonts
declare -a fontsToAdd