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

declare -a missingFonts
declare -a usedFonts
declare -a uselessFonts
declare -a embeddedFonts

declare -a neededFonts

json="$(mkvmerge -J "$1")"
IFS="$nl"
embeddedFonts=( $(printAttachedFontsMatroska "$1") )
neededFonts=( $(printUsedFontsMatroska "$1" | sort | uniq) )
missingFonts=( "${neededFonts[@]}" )
uselessFonts=( "${embeddedFonts[@]}" )

for testedFont in "${neededFonts[@]}"
do
	# Looks trough each embedded font
	foundFont=false
	for testedEmbeddedFont in "${embeddedFonts[@]}"
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
					if [[ "$fontFilename" = "$testedEmbeddedFontname" ]]
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

printf "\e[32mUsed fonts: %s\n" "${usedFonts[@]}"
printf "\e[31mMissing fonts: %s\n" "${missingFonts[@]}"
printf "\e[1;33mUseless fonts: %s\e[0m\n" "${uselessFonts[@]}"
